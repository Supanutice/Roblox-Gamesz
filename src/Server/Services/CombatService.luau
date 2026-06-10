--!strict
-- CombatService.luau
-- Server combat brain. Receives client ACTION REQUESTS, validates everything
-- (cooldowns, range, stamina, energy, state), then drives HitboxService and
-- DamageService. The client's only job is animation and prediction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Configs.CombatConfig)
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local Remotes = require(Shared.Net.Remotes)

local CombatService = { Name = "CombatService" }

export type CombatState = {
	Model: Model,
	-- Combo
	ComboIndex: number,
	LastM1At: number,
	AirHits: number,
	-- Cooldowns: actionKey -> readyAt (os.clock)
	Cooldowns: { [string]: number },
	-- Resources
	Energy: number,
	Stamina: number,
	UltimatesUsedThisLife: number,
	-- Defensive state
	Blocking: boolean,
	BlockStartedAt: number,
	CounterReadyUntil: number,
	IFrameUntil: number,
	-- Status-effect-driven modifiers (written by StatusEffectService)
	MovementMultiplier: number,
	DefenseMultiplier: number,
	ActionsDisabled: boolean,
	-- Awakening
	AwakenedUntil: number,
}

local states: { [Model]: CombatState } = {}
local HitboxService, DamageService, StatusEffectService, CharacterService, AntiCheatService

-- ============================ STATE MANAGEMENT =============================

function CombatService:RegisterEntity(model: Model): CombatState
	local state: CombatState = {
		Model = model,
		ComboIndex = 0,
		LastM1At = 0,
		AirHits = 0,
		Cooldowns = {},
		Energy = 0,
		Stamina = CombatConfig.Stamina.Max,
		UltimatesUsedThisLife = 0,
		Blocking = false,
		BlockStartedAt = 0,
		CounterReadyUntil = 0,
		IFrameUntil = 0,
		MovementMultiplier = 1,
		DefenseMultiplier = 1,
		ActionsDisabled = false,
		AwakenedUntil = 0,
	}
	states[model] = state
	model.Destroying:Once(function()
		states[model] = nil
	end)
	return state
end

function CombatService:GetState(model: Model): CombatState?
	return states[model]
end

-- ============================== VALIDATION =================================

local function getValidatedState(player: Player): (CombatState?, Model?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	local state = states[character]
	if not state or state.ActionsDisabled then
		return nil, nil
	end
	return state, character
end

local function onCooldown(state: CombatState, key: string): boolean
	return os.clock() < (state.Cooldowns[key] or 0)
end

local function setCooldown(state: CombatState, key: string, duration: number)
	state.Cooldowns[key] = os.clock() + duration
end

local function damageMultiplierFor(state: CombatState): number
	return if os.clock() < state.AwakenedUntil then 1 + CombatConfig.Awakening.StatBonus else 1
end

-- ================================ ACTIONS ==================================

local function handleM1(player: Player, comboIndex: unknown)
	local state, character = getValidatedState(player)
	if not state or not character then
		return
	end
	local now = os.clock()
	-- Rate limit: server decides the combo index, the client only animates.
	if now - state.LastM1At < CombatConfig.M1.HitWindowSeconds then
		AntiCheatService:Flag(player, "M1RateLimit")
		return
	end
	if now - state.LastM1At > CombatConfig.M1.ComboResetSeconds then
		state.ComboIndex = 0
	end
	state.ComboIndex = (state.ComboIndex % CombatConfig.M1.ComboLength) + 1
	state.LastM1At = now

	local isFinisher = state.ComboIndex == CombatConfig.M1.ComboLength
	local multiplier = (if isFinisher then CombatConfig.M1.FinisherMultiplier else CombatConfig.M1.BaseDamageMultiplier)
		* damageMultiplierFor(state)

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local targets = HitboxService:SweepFront(root, CombatConfig.M1.Range, 6, character)
	for _, target in targets do
		DamageService:ApplyDamage({
			Attacker = character,
			Victim = target.Model,
			SkillMultiplier = multiplier,
			Knockback = if isFinisher then CombatConfig.M1.KnockbackFinisher else 0,
		})
		-- M1 energy gain (per swing that lands).
		state.Energy = math.min(CombatConfig.Energy.Max, state.Energy + CombatConfig.Energy.PerM1Hit)
	end

	Remotes.Event("CombatStateChanged"):FireClient(player, "Combo", { Index = state.ComboIndex, Energy = state.Energy })
end

local function handleHeavy(player: Player)
	local state, character = getValidatedState(player)
	if not state or not character then
		return
	end
	if onCooldown(state, "Heavy") then
		return
	end
	setCooldown(state, "Heavy", CombatConfig.Heavy.Cooldown)

	-- Charge time is enforced server-side: damage lands after the delay.
	task.delay(CombatConfig.Heavy.ChargeSeconds, function()
		if not character.Parent then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local launches = state.ComboIndex >= CombatConfig.M1.ComboLength - 1
		local targets = HitboxService:SweepFront(root, CombatConfig.Heavy.Range, 7, character)
		for _, target in targets do
			DamageService:ApplyDamage({
				Attacker = character,
				Victim = target.Model,
				SkillMultiplier = (if launches then CombatConfig.AirCombo.LaunchMultiplier else CombatConfig.Heavy.DamageMultiplier)
					* damageMultiplierFor(state),
				Knockback = if launches then 0 else CombatConfig.Heavy.Knockback,
				IsHeavy = true,
			})
			if launches then
				-- Launcher: pop the target up for air combos.
				target.RootPart.AssemblyLinearVelocity = Vector3.new(0, CombatConfig.AirCombo.LaunchVelocity, 0)
			end
		end
	end)
end

local function handleDash(player: Player, direction: unknown)
	local state, character = getValidatedState(player)
	if not state or not character then
		return
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude == 0 then
		return
	end
	if onCooldown(state, "Dash") or state.Stamina < CombatConfig.Stamina.DashCost then
		return
	end
	setCooldown(state, "Dash", CombatConfig.Dash.Cooldown)
	state.Stamina -= CombatConfig.Stamina.DashCost
	state.IFrameUntil = os.clock() + CombatConfig.Dash.IFrameSeconds
	-- Whitelist this burst of speed so AntiCheat doesn't flag it.
	AntiCheatService:AllowBurst(player, CombatConfig.Dash.DurationSeconds + 0.2)

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local unit = direction.Unit
	root.AssemblyLinearVelocity = Vector3.new(unit.X, 0, unit.Z)
		* (CombatConfig.Dash.Distance / CombatConfig.Dash.DurationSeconds)
end

local function handleSkill(player: Player, skillSlot: unknown, aimPosition: unknown)
	local state, character = getValidatedState(player)
	if not state or not character then
		return
	end
	if skillSlot ~= 1 and skillSlot ~= 2 then
		AntiCheatService:Flag(player, "BadSkillSlot")
		return
	end
	if typeof(aimPosition) ~= "Vector3" then
		return
	end

	local equipped = CharacterService:GetActiveCharacterDef(player)
	if not equipped then
		return
	end
	local skill = if skillSlot == 1 then equipped.Def.Skill1 else equipped.Def.Skill2
	local key = "Skill" .. tostring(skillSlot)
	if onCooldown(state, key) then
		return
	end
	setCooldown(state, key, skill.Cooldown)

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	-- Aim position can't be across the map.
	local clampedAim = aimPosition
	if (aimPosition - root.Position).Magnitude > 60 then
		clampedAim = root.Position + (aimPosition - root.Position).Unit * 60
	end

	local skillLevel = equipped.Instance.SkillLevels[skillSlot] or 1

	if skill.Multiplier <= 0 then
		-- Utility/heal skill: affects allies near the aim point.
		local targets = HitboxService:SweepSphere(clampedAim, 14, nil)
		for _, target in targets do
			if Players:GetPlayerFromCharacter(target.Model) then
				DamageService:ApplyHeal(character, target.Model, 1.5 + skillLevel * 0.1)
			end
		end
	else
		local targets = HitboxService:SweepSphere(clampedAim, 12, character)
		for _, target in targets do
			DamageService:ApplyDamage({
				Attacker = character,
				Victim = target.Model,
				SkillMultiplier = skill.Multiplier * damageMultiplierFor(state),
				SkillLevel = skillLevel,
				Element = equipped.Def.Element,
				StatusEffect = skill.StatusEffect,
			})
		end
	end

	Remotes.Event("CombatStateChanged"):FireClient(player, "SkillUsed",
		{ Slot = skillSlot, CooldownEnds = state.Cooldowns[key] })
end

local function handleUltimate(player: Player, aimPosition: unknown)
	local state, character = getValidatedState(player)
	if not state or not character then
		return
	end
	if typeof(aimPosition) ~= "Vector3" then
		return
	end
	if state.Energy < CombatConfig.Energy.UltimateCost then
		AntiCheatService:Flag(player, "UltimateNoEnergy")
		return
	end
	local equipped = CharacterService:GetActiveCharacterDef(player)
	if not equipped then
		return
	end

	state.Energy = 0
	state.UltimatesUsedThisLife += 1
	-- Cinematic i-frames while the finisher camera plays.
	state.IFrameUntil = os.clock() + 2.5

	-- Awakening unlock.
	if state.UltimatesUsedThisLife >= CombatConfig.Awakening.RequiredUltimates then
		state.AwakenedUntil = os.clock() + CombatConfig.Awakening.DurationSeconds
		Remotes.Event("CombatStateChanged"):FireClient(player, "Awakened",
			{ Until = state.AwakenedUntil })
	end

	local ultimate = equipped.Def.Ultimate
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local clampedAim = aimPosition
	if (aimPosition - root.Position).Magnitude > 80 then
		clampedAim = root.Position + (aimPosition - root.Position).Unit * 80
	end

	-- Tell everyone nearby to play the cinematic.
	Remotes.Event("CombatStateChanged"):FireAllClients("UltimateCast", {
		Caster = character,
		CinematicId = ultimate.CinematicId,
		Position = clampedAim,
	})

	-- Damage lands when the cinematic peaks.
	task.delay(1.2, function()
		if not character.Parent then
			return
		end
		local skillLevel = equipped.Instance.SkillLevels[3] or 1
		local targets = HitboxService:SweepSphere(clampedAim, 22, character)
		for _, target in targets do
			DamageService:ApplyDamage({
				Attacker = character,
				Victim = target.Model,
				SkillMultiplier = ultimate.Multiplier * damageMultiplierFor(state),
				SkillLevel = skillLevel,
				Element = equipped.Def.Element,
				StatusEffect = ultimate.StatusEffect,
				Knockback = 45,
			})
		end
	end)
end

local function handleBlock(player: Player, isBlocking: unknown)
	local state = getValidatedState(player)
	if not state then
		return
	end
	if typeof(isBlocking) ~= "boolean" then
		return
	end
	if isBlocking and not state.Blocking then
		state.Blocking = true
		state.BlockStartedAt = os.clock()
	elseif not isBlocking then
		state.Blocking = false
	end
end

-- ================================ LIFECYCLE ================================

function CombatService:Init(registry)
	HitboxService = registry.HitboxService
	DamageService = registry.DamageService
	StatusEffectService = registry.StatusEffectService
	CharacterService = registry.CharacterService
	AntiCheatService = registry.AntiCheatService
end

function CombatService:Start()
	Remotes.Event("CombatRequestM1").OnServerEvent:Connect(handleM1)
	Remotes.Event("CombatRequestHeavy").OnServerEvent:Connect(handleHeavy)
	Remotes.Event("CombatRequestDash").OnServerEvent:Connect(handleDash)
	Remotes.Event("CombatRequestSkill").OnServerEvent:Connect(handleSkill)
	Remotes.Event("CombatRequestUltimate").OnServerEvent:Connect(handleUltimate)
	Remotes.Event("CombatRequestBlock").OnServerEvent:Connect(handleBlock)

	-- Stamina regen + state ticking.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, state in states do
				if not state.Blocking then
					state.Stamina = math.min(CombatConfig.Stamina.Max,
						state.Stamina + CombatConfig.Stamina.RegenPerSecond * 0.5)
				end
			end
		end
	end)

	-- Register player characters as combat entities on spawn.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			self:RegisterEntity(character)
			CharacterService:ApplyStatsToCharacter(player, character)
		end)
	end)
end

return CombatService
