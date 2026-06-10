--!strict
-- DamageService.luau
-- The ONLY code path that changes a Humanoid's health in combat. Centralizing
-- damage means: one place for mitigation, crits, elements, block/perfect-block,
-- i-frames, knockback, kill credit and damage validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Utilities.Formulas)
local CombatConfig = require(Shared.Configs.CombatConfig)
local Signal = require(Shared.Utilities.Signal)
local Remotes = require(Shared.Net.Remotes)

local DamageService = {
	Name = "DamageService",
	EntityDied = Signal.new(),    -- (victimModel, killerPlayer?)
	DamageDealt = Signal.new(),   -- (attackerModel, victimModel, amount)
}

local CombatService, StatusEffectService, AntiCheatService

export type DamageRequest = {
	Attacker: Model,
	Victim: Model,
	SkillMultiplier: number,
	SkillLevel: number?,
	Element: string?,
	StatusEffect: string?,
	Knockback: number?,
	IsHeavy: boolean?,
}

-- Stats come from model attributes, written by CharacterService (players)
-- or AIController/BossAI (NPCs) when the entity spawns.
local function readStats(model: Model)
	return {
		Attack = model:GetAttribute("ATK") :: number? or 10,
		Defense = model:GetAttribute("DEF") :: number? or 0,
		Element = model:GetAttribute("Element") :: string? or "Fire",
		CritChance = model:GetAttribute("CritChance") :: number? or 0.05,
		CritDamage = model:GetAttribute("CritDamage") :: number? or 1.5,
	}
end

function DamageService:ApplyDamage(request: DamageRequest): number
	local victimHumanoid = request.Victim:FindFirstChildOfClass("Humanoid")
	if not victimHumanoid or victimHumanoid.Health <= 0 then
		return 0
	end

	local victimState = CombatService:GetState(request.Victim)
	local attackerStats = readStats(request.Attacker)
	local victimStats = readStats(request.Victim)

	-- I-frames (dash, cutscene, revive protection).
	if victimState and os.clock() < victimState.IFrameUntil then
		return 0
	end

	local isCrit = math.random() < attackerStats.CritChance
	local damage = Formulas.ComputeDamage({
		Attack = attackerStats.Attack,
		SkillMultiplier = request.SkillMultiplier,
		SkillLevel = request.SkillLevel or 1,
		Defense = victimStats.Defense * (victimState and victimState.DefenseMultiplier or 1),
		AttackerElement = request.Element or attackerStats.Element,
		DefenderElement = victimStats.Element,
		IsCritical = isCrit,
		CritDamage = attackerStats.CritDamage,
	})

	-- Blocking. Heavy attacks break normal block but not perfect block.
	if victimState and victimState.Blocking then
		local sinceBlock = os.clock() - victimState.BlockStartedAt
		if sinceBlock <= CombatConfig.Block.PerfectWindowSeconds then
			damage = math.floor(damage * (1 - CombatConfig.Block.PerfectReduction))
			victimState.CounterReadyUntil = os.clock() + CombatConfig.Block.PerfectCounterWindow
			Remotes.Event("CombatStateChanged"):FireAllClients("PerfectBlock", { Victim = request.Victim })
		elseif not request.IsHeavy then
			damage = math.floor(damage * (1 - CombatConfig.Block.DamageReduction))
		else
			-- Guard break: cancel block and stagger.
			victimState.Blocking = false
			StatusEffectService:Apply(request.Victim, "Stun", request.Attacker, 0.8)
		end
	end

	-- Outgoing damage sanity ceiling (anti-exploit tripwire).
	if AntiCheatService then
		damage = AntiCheatService:ClampDamage(request.Attacker, damage)
	end

	if damage <= 0 then
		return 0
	end

	victimHumanoid:TakeDamage(damage)

	-- Status effect application rides on the hit.
	if request.StatusEffect then
		StatusEffectService:Apply(request.Victim, request.StatusEffect, request.Attacker)
	end

	-- Knockback.
	local victimRoot = request.Victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = request.Attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if request.Knockback and request.Knockback > 0 and victimRoot and attackerRoot then
		local direction = (victimRoot.Position - attackerRoot.Position).Unit
		victimRoot.AssemblyLinearVelocity = direction * request.Knockback + Vector3.new(0, request.Knockback * 0.3, 0)
	end

	-- Energy economy.
	local attackerPlayer = Players:GetPlayerFromCharacter(request.Attacker)
	local attackerState = CombatService:GetState(request.Attacker)
	if attackerState then
		attackerState.Energy = math.min(CombatConfig.Energy.Max, attackerState.Energy + CombatConfig.Energy.PerSkillHit)
	end
	if victimState then
		local percentLost = damage / victimHumanoid.MaxHealth * 100
		victimState.Energy = math.min(CombatConfig.Energy.Max,
			victimState.Energy + percentLost * CombatConfig.Energy.PerDamageTakenPercent)
	end

	-- Notify clients for damage numbers / hit VFX.
	if attackerPlayer then
		Remotes.Event("CombatHitConfirmed"):FireClient(attackerPlayer,
			request.Victim, damage, isCrit, request.Element or attackerStats.Element)
	end

	DamageService.DamageDealt:Fire(request.Attacker, request.Victim, damage)

	if victimHumanoid.Health <= 0 then
		DamageService.EntityDied:Fire(request.Victim, attackerPlayer)
	end

	return damage
end

-- Direct healing (Support skills). Negative damage is never allowed through
-- ApplyDamage, so healing has its own validated path.
function DamageService:ApplyHeal(healer: Model, target: Model, multiplier: number)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stats = readStats(healer)
	local amount = math.floor(stats.Attack * multiplier)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

function DamageService:Init(registry)
	CombatService = registry.CombatService
	StatusEffectService = registry.StatusEffectService
	AntiCheatService = registry.AntiCheatService
end

return DamageService
