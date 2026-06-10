--!strict
-- StatusEffectService.luau
-- Server simulation of Burn/Freeze/Shock/Poison/Bleed/Stun with stacking
-- rules and PvP diminishing returns. Clients only render VFX on notify.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatusEffectData = require(Shared.Data.StatusEffectData)
local Remotes = require(Shared.Net.Remotes)

local StatusEffectService = { Name = "StatusEffectService" }

type ActiveEffect = {
	Def: StatusEffectData.StatusEffectDef,
	Applier: Model,
	ExpiresAt: number,
	Stacks: number,
	NextTickAt: number?,
}

type EntityEffects = {
	Active: { [string]: ActiveEffect },
	-- Control-effect diminishing returns bookkeeping.
	DRCounts: { [string]: { Count: number, WindowEndsAt: number } },
}

local entities: { [Model]: EntityEffects } = {}
local DamageService, CombatService

local function getEntry(model: Model): EntityEffects
	local entry = entities[model]
	if not entry then
		entry = { Active = {}, DRCounts = {} }
		entities[model] = entry
		model.Destroying:Once(function()
			entities[model] = nil
		end)
	end
	return entry
end

function StatusEffectService:Apply(victim: Model, effectId: string, applier: Model, durationOverride: number?)
	local def = StatusEffectData.Effects[effectId]
	if not def then
		warn(`[StatusEffect] Unknown effect "{effectId}"`)
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local entry = getEntry(victim)
	local duration = durationOverride or def.Duration

	-- Diminishing returns for control effects (PvP lock prevention).
	if def.Type == "Control" then
		local dr = entry.DRCounts[effectId]
		local now = os.clock()
		if not dr or now > dr.WindowEndsAt then
			dr = { Count = 0, WindowEndsAt = now + StatusEffectData.ControlDR.WindowSeconds }
			entry.DRCounts[effectId] = dr
		end
		dr.Count += 1
		local mult = StatusEffectData.ControlDR.Multipliers[math.min(dr.Count, #StatusEffectData.ControlDR.Multipliers)]
		duration *= mult
		if duration <= 0 then
			return -- immune this window
		end
	end

	local active = entry.Active[effectId]
	if active then
		active.Stacks = math.min(active.Stacks + 1, def.MaxStacks)
		active.ExpiresAt = os.clock() + duration
		active.Applier = applier
	else
		entry.Active[effectId] = {
			Def = def,
			Applier = applier,
			ExpiresAt = os.clock() + duration,
			Stacks = 1,
			NextTickAt = if def.TickInterval then os.clock() + def.TickInterval else nil,
		}
	end

	-- Push control/debuff payloads onto the combat state.
	local state = CombatService:GetState(victim)
	if state then
		StatusEffectService:_recomputeModifiers(victim)
	end

	Remotes.Event("StatusEffectApplied"):FireAllClients(victim, effectId, duration)
end

function StatusEffectService:Cleanse(victim: Model, count: number)
	local entry = entities[victim]
	if not entry then
		return
	end
	for effectId in entry.Active do
		if count <= 0 then
			break
		end
		entry.Active[effectId] = nil
		count -= 1
	end
	self:_recomputeModifiers(victim)
end

function StatusEffectService:HasEffect(victim: Model, effectId: string): boolean
	local entry = entities[victim]
	return entry ~= nil and entry.Active[effectId] ~= nil
end

-- Combines all active movement/defense/action modifiers into the combat state.
function StatusEffectService:_recomputeModifiers(victim: Model)
	local state = CombatService:GetState(victim)
	if not state then
		return
	end
	local movement, defense, disabled = 1, 1, false
	local entry = entities[victim]
	if entry then
		for _, active in entry.Active do
			local def = active.Def
			if def.MovementMultiplier then
				movement = math.min(movement, def.MovementMultiplier)
			end
			if def.DefenseMultiplier then
				defense = math.min(defense, def.DefenseMultiplier)
			end
			if def.DisablesActions then
				disabled = true
			end
		end
	end
	state.MovementMultiplier = movement
	state.DefenseMultiplier = defense
	state.ActionsDisabled = disabled

	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local baseSpeed = victim:GetAttribute("BaseWalkSpeed") :: number? or 16
		humanoid.WalkSpeed = baseSpeed * movement
	end
end

function StatusEffectService:Init(registry)
	DamageService = registry.DamageService
	CombatService = registry.CombatService
end

function StatusEffectService:Start()
	-- One global tick loop instead of a thread per effect: O(entities) per
	-- 0.25s, friendly to the 60 FPS server budget.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for model, entry in entities do
				local changed = false
				for effectId, active in entry.Active do
					if now >= active.ExpiresAt then
						entry.Active[effectId] = nil
						changed = true
					elseif active.NextTickAt and now >= active.NextTickAt then
						active.NextTickAt = now + (active.Def.TickInterval :: number)
						local applierATK = active.Applier:GetAttribute("ATK") :: number? or 10
						local tickDamage = math.floor(applierATK * (active.Def.TickMultiplier :: number) * active.Stacks)
						local humanoid = model:FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.Health > 0 and tickDamage > 0 then
							humanoid:TakeDamage(tickDamage)
							if humanoid.Health <= 0 then
								DamageService.EntityDied:Fire(model,
									game:GetService("Players"):GetPlayerFromCharacter(active.Applier))
							end
						end
					end
				end
				if changed then
					self:_recomputeModifiers(model)
				end
			end
		end
	end)
end

return StatusEffectService
