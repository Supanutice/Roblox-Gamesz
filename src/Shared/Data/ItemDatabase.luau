--!strict
-- ItemDatabase.luau
-- Weapons, materials and consumables. Characters live in CharacterDatabase.

export type ItemDef = {
	Id: string,
	Name: string,
	Category: "Weapon" | "Material" | "Consumable" | "Cosmetic",
	Rarity: string,
	Stackable: boolean,
	MaxStack: number,
	Description: string,
	-- Weapons
	WeaponStats: { ATK: number, CritChance: number?, Element: string? }?,
	-- Consumables
	UseEffect: { Type: string, Amount: number }?,
	-- Economy
	SellGold: number,
	Tradeable: boolean,
}

local function item(entry: ItemDef): ItemDef
	return entry
end

local Items: { [string]: ItemDef } = {
	-- ============================ WEAPONS =================================
	WPN_TRAINING_KATANA = item({
		Id = "WPN_TRAINING_KATANA", Name = "Training Katana", Category = "Weapon",
		Rarity = "Common", Stackable = false, MaxStack = 1,
		Description = "Every legend starts with a wooden sword.",
		WeaponStats = { ATK = 15 }, SellGold = 50, Tradeable = true,
	}),
	WPN_SHINOBI_TANTO = item({
		Id = "WPN_SHINOBI_TANTO", Name = "Shinobi Tanto", Category = "Weapon",
		Rarity = "Rare", Stackable = false, MaxStack = 1,
		Description = "Light, quick, and quieter than a held breath.",
		WeaponStats = { ATK = 45, CritChance = 0.05 }, SellGold = 800, Tradeable = true,
	}),
	WPN_SOUL_CLEAVER = item({
		Id = "WPN_SOUL_CLEAVER", Name = "Soul Cleaver", Category = "Weapon",
		Rarity = "Epic", Stackable = false, MaxStack = 1,
		Description = "Forged in the Soul Empire; hums near the dying.",
		WeaponStats = { ATK = 110, Element = "Dark" }, SellGold = 6_000, Tradeable = true,
	}),
	WPN_LEVIATHAN_FANG = item({
		Id = "WPN_LEVIATHAN_FANG", Name = "Leviathan Fang", Category = "Weapon",
		Rarity = "Legendary", Stackable = false, MaxStack = 1,
		Description = "A fang pried from the Grand Ocean's apex predator.",
		WeaponStats = { ATK = 220, CritChance = 0.10, Element = "Water" }, SellGold = 40_000, Tradeable = true,
	}),
	WPN_STARFALL_EDGE = item({
		Id = "WPN_STARFALL_EDGE", Name = "Starfall Edge", Category = "Weapon",
		Rarity = "Mythic", Stackable = false, MaxStack = 1,
		Description = "Cooled from a falling star above the Celestial Kingdom.",
		WeaponStats = { ATK = 380, CritChance = 0.15, Element = "Light" }, SellGold = 150_000, Tradeable = false,
	}),

	-- =========================== MATERIALS ================================
	MAT_EVO_SHARD = item({
		Id = "MAT_EVO_SHARD", Name = "Evolution Shard", Category = "Material",
		Rarity = "Rare", Stackable = true, MaxStack = 999,
		Description = "Crystallized potential. Characters crave it.",
		SellGold = 100, Tradeable = true,
	}),
	MAT_EVO_CORE = item({
		Id = "MAT_EVO_CORE", Name = "Evolution Core", Category = "Material",
		Rarity = "Epic", Stackable = true, MaxStack = 999,
		Description = "A dense core of refined evolution shards.",
		SellGold = 1_000, Tradeable = true,
	}),
	MAT_EVO_CRYSTAL = item({
		Id = "MAT_EVO_CRYSTAL", Name = "Evolution Crystal", Category = "Material",
		Rarity = "Legendary", Stackable = true, MaxStack = 999,
		Description = "Resonates with characters approaching their final form.",
		SellGold = 8_000, Tradeable = true,
	}),
	MAT_DIVINE_EMBER = item({
		Id = "MAT_DIVINE_EMBER", Name = "Divine Ember", Category = "Material",
		Rarity = "Divine", Stackable = true, MaxStack = 99,
		Description = "A spark from the first star. Required for final evolutions.",
		SellGold = 100_000, Tradeable = false,
	}),
	MAT_SKILL_SCROLL = item({
		Id = "MAT_SKILL_SCROLL", Name = "Skill Scroll", Category = "Material",
		Rarity = "Rare", Stackable = true, MaxStack = 999,
		Description = "Forbidden techniques, neatly transcribed.",
		SellGold = 250, Tradeable = true,
	}),

	-- ========================== CONSUMABLES ===============================
	CON_HP_POTION = item({
		Id = "CON_HP_POTION", Name = "Vitality Tonic", Category = "Consumable",
		Rarity = "Common", Stackable = true, MaxStack = 99,
		Description = "Restores 30% HP. Tastes like regret and strawberries.",
		UseEffect = { Type = "HealPercent", Amount = 0.30 }, SellGold = 25, Tradeable = true,
	}),
	CON_ENERGY_DRINK = item({
		Id = "CON_ENERGY_DRINK", Name = "Spirit Soda", Category = "Consumable",
		Rarity = "Rare", Stackable = true, MaxStack = 99,
		Description = "Grants 30 ultimate energy instantly.",
		UseEffect = { Type = "Energy", Amount = 30 }, SellGold = 120, Tradeable = true,
	}),
	CON_XP_BOOST = item({
		Id = "CON_XP_BOOST", Name = "Sage's Incense", Category = "Consumable",
		Rarity = "Epic", Stackable = true, MaxStack = 99,
		Description = "+50% XP for 30 minutes.",
		UseEffect = { Type = "XPBoost", Amount = 0.5 }, SellGold = 500, Tradeable = false,
	}),
	CON_SUMMON_TICKET = item({
		Id = "CON_SUMMON_TICKET", Name = "Summon Ticket", Category = "Consumable",
		Rarity = "Epic", Stackable = true, MaxStack = 999,
		Description = "One free pull on the standard banner.",
		UseEffect = { Type = "Summon", Amount = 1 }, SellGold = 0, Tradeable = false,
	}),
}

return { ById = Items }
