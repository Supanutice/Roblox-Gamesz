--!strict
-- StatusEffectData.luau
-- Definitions for every status effect. StatusEffectService (server) owns the
-- simulation; clients only render the VFX named here.

export type StatusEffectDef = {
	Id: string,
	Name: string,
	Type: "DamageOverTime" | "Control" | "Debuff",
	Duration: number,
	TickInterval: number?,
	-- DoT damage per tick as a fraction of the APPLIER's ATK.
	TickMultiplier: number?,
	MaxStacks: number,
	-- Control / debuff payloads
	MovementMultiplier: number?, -- 0 = rooted
	DisablesActions: boolean?,
	DefenseMultiplier: number?,
	VFXId: string,
	IconId: string,
}

local Effects: { [string]: StatusEffectDef } = {
	Burn = {
		Id = "Burn", Name = "Burn", Type = "DamageOverTime",
		Duration = 5, TickInterval = 1, TickMultiplier = 0.15, MaxStacks = 2,
		VFXId = "VFX_STATUS_BURN", IconId = "ICON_BURN",
	},
	Poison = {
		Id = "Poison", Name = "Poison", Type = "DamageOverTime",
		Duration = 8, TickInterval = 1, TickMultiplier = 0.08, MaxStacks = 3,
		VFXId = "VFX_STATUS_POISON", IconId = "ICON_POISON",
	},
	Bleed = {
		Id = "Bleed", Name = "Bleed", Type = "DamageOverTime",
		Duration = 6, TickInterval = 0.5, TickMultiplier = 0.05, MaxStacks = 5,
		VFXId = "VFX_STATUS_BLEED", IconId = "ICON_BLEED",
	},
	Freeze = {
		Id = "Freeze", Name = "Freeze", Type = "Control",
		Duration = 2.5, MaxStacks = 1,
		MovementMultiplier = 0, DisablesActions = true,
		VFXId = "VFX_STATUS_FREEZE", IconId = "ICON_FREEZE",
	},
	Shock = {
		Id = "Shock", Name = "Shock", Type = "Debuff",
		Duration = 4, TickInterval = 1, TickMultiplier = 0.05, MaxStacks = 1,
		MovementMultiplier = 0.7, DefenseMultiplier = 0.85,
		VFXId = "VFX_STATUS_SHOCK", IconId = "ICON_SHOCK",
	},
	Stun = {
		Id = "Stun", Name = "Stun", Type = "Control",
		Duration = 1.5, MaxStacks = 1,
		MovementMultiplier = 0, DisablesActions = true,
		VFXId = "VFX_STATUS_STUN", IconId = "ICON_STUN",
	},
}

-- Diminishing returns on control effects so PvP chains can't perma-lock:
-- each reapplication within DR window lasts 50% as long, immune on 3rd.
local ControlDR = {
	WindowSeconds = 12,
	Multipliers = { 1.0, 0.5, 0 },
}

return {
	Effects = Effects,
	ControlDR = ControlDR,
}
