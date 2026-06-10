--!strict
-- Formulas.luau
-- Single source of truth for every balance formula. The server is the only
-- authority on damage; the client may use these for UI previews only.

local Formulas = {}

-- ============================== LEVELING ==================================

-- XP required to advance FROM `level` to `level + 1`. Smooth quadratic curve
-- tuned so level 500 takes roughly 2,000 hours of mixed play.
function Formulas.XPForLevel(level: number): number
	return math.floor(100 + (level ^ 1.85) * 12)
end

function Formulas.TotalXPToLevel(level: number): number
	local total = 0
	for i = 1, level - 1 do
		total += Formulas.XPForLevel(i)
	end
	return total
end

-- ============================== STATS =====================================

-- Stat growth: base stat scaled by level, rarity multiplier, evolution stage
-- and ascension stars.
function Formulas.ComputeStat(base: number, level: number, rarityMult: number, evolutionStage: number, ascension: number): number
	local levelMult = 1 + (level - 1) * 0.045
	local evoMult = 1 + (evolutionStage - 1) * 0.25
	local ascMult = 1 + ascension * 0.06
	return math.floor(base * levelMult * rarityMult * evoMult * ascMult)
end

-- ============================== DAMAGE ====================================

-- Elemental advantage wheel. Attacker element -> defender element -> mult.
local ELEMENT_ADVANTAGE: { [string]: string } = {
	Fire = "Ice",
	Ice = "Wind",
	Wind = "Earth",
	Earth = "Lightning",
	Lightning = "Water",
	Water = "Fire",
	Light = "Dark",
	Dark = "Light",
}

function Formulas.ElementMultiplier(attackerElement: string, defenderElement: string): number
	if ELEMENT_ADVANTAGE[attackerElement] == defenderElement then
		return 1.3
	elseif ELEMENT_ADVANTAGE[defenderElement] == attackerElement then
		return 0.75
	end
	return 1.0
end

export type DamageInput = {
	Attack: number,
	SkillMultiplier: number,
	SkillLevel: number,
	Defense: number,
	AttackerElement: string,
	DefenderElement: string,
	IsCritical: boolean,
	CritDamage: number, -- e.g. 1.5 = +50%
}

function Formulas.ComputeDamage(input: DamageInput): number
	local skillMult = input.SkillMultiplier * (1 + (input.SkillLevel - 1) * 0.08)
	local raw = input.Attack * skillMult
	-- Diminishing-returns mitigation: DEF never fully nullifies damage.
	local mitigation = input.Defense / (input.Defense + 100 + input.Attack * 0.5)
	local damage = raw * (1 - mitigation)
	damage *= Formulas.ElementMultiplier(input.AttackerElement, input.DefenderElement)
	if input.IsCritical then
		damage *= input.CritDamage
	end
	-- +-5% variance so numbers feel organic.
	damage *= 0.95 + math.random() * 0.10
	return math.max(1, math.floor(damage))
end

-- ============================== PVP / ELO =================================

function Formulas.EloChange(winnerRating: number, loserRating: number): (number, number)
	local K = 32
	local expectedWin = 1 / (1 + 10 ^ ((loserRating - winnerRating) / 400))
	local delta = math.floor(K * (1 - expectedWin) + 0.5)
	return delta, -delta
end

return Formulas
