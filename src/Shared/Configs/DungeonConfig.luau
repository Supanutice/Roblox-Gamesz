--!strict
-- DungeonConfig.luau
-- One instanced dungeon per world. Waves reference enemy ids from that
-- world's WorldConfig enemy table; the final wave spawns ELITE versions
-- (EliteMultiplier on HP/ATK). Enemy HP additionally scales with party size.

export type Wave = {
	Enemies: { { Id: string, Count: number } },
	Elite: boolean?,
}

export type DungeonDef = {
	Id: string,
	Name: string,
	WorldId: string,
	RequiredLevel: number,
	Waves: { Wave },
	EliteMultiplier: number,
	TimeLimitSeconds: number,
	Rewards: { [string]: number }, -- granted to every participant on clear
}

local Dungeons: { DungeonDef } = {
	{
		Id = "D1_TIDE_CAVERN", Name = "Tide Cavern", WorldId = "W1_BEGINNER_ISLAND",
		RequiredLevel = 8, EliteMultiplier = 6, TimeLimitSeconds = 480,
		Waves = {
			{ Enemies = { { Id = "EN_W1_BANDIT", Count = 4 } } },
			{ Enemies = { { Id = "EN_W1_WOLF", Count = 4 }, { Id = "EN_W1_BANDIT", Count = 2 } } },
			{ Enemies = { { Id = "EN_W1_GOLEM", Count = 3 } } },
			{ Enemies = { { Id = "EN_W1_ROGUE_NINJA", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 2_500, Gold = 6_000, RaidTokens = 5, MAT_EVO_SHARD = 4 },
	},
	{
		Id = "D2_PUPPET_WORKSHOP", Name = "Puppet Workshop", WorldId = "W2_SHINOBI_NATION",
		RequiredLevel = 32, EliteMultiplier = 6, TimeLimitSeconds = 480,
		Waves = {
			{ Enemies = { { Id = "EN_W2_GENIN", Count = 5 } } },
			{ Enemies = { { Id = "EN_W2_PUPPET", Count = 4 } } },
			{ Enemies = { { Id = "EN_W2_JONIN", Count = 3 } } },
			{ Enemies = { { Id = "EN_W2_ONI_MASK", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 12_000, Gold = 25_000, RaidTokens = 8, MAT_EVO_SHARD = 10 },
	},
	{
		Id = "D3_HOLLOW_DEPTHS", Name = "Hollow Depths", WorldId = "W3_SOUL_EMPIRE",
		RequiredLevel = 80, EliteMultiplier = 7, TimeLimitSeconds = 540,
		Waves = {
			{ Enemies = { { Id = "EN_W3_HOLLOW", Count = 6 } } },
			{ Enemies = { { Id = "EN_W3_REAPER", Count = 4 } } },
			{ Enemies = { { Id = "EN_W3_SOULKNIGHT", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 90_000, Gold = 140_000, RaidTokens = 12, MAT_EVO_CORE = 3 },
	},
	{
		Id = "D4_SUNKEN_FLEET", Name = "Sunken Fleet", WorldId = "W4_GRAND_OCEAN",
		RequiredLevel = 150, EliteMultiplier = 7, TimeLimitSeconds = 540,
		Waves = {
			{ Enemies = { { Id = "EN_W4_PIRATE", Count = 6 } } },
			{ Enemies = { { Id = "EN_W4_MARINE", Count = 5 } } },
			{ Enemies = { { Id = "EN_W4_SERPENT", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 700_000, Gold = 700_000, RaidTokens = 18, MAT_EVO_CORE = 6 },
	},
	{
		Id = "D5_EMBER_PITS", Name = "Ember Pits", WorldId = "W5_DEMON_REALM",
		RequiredLevel = 240, EliteMultiplier = 8, TimeLimitSeconds = 600,
		Waves = {
			{ Enemies = { { Id = "EN_W5_IMP", Count = 8 } } },
			{ Enemies = { { Id = "EN_W5_FIEND", Count = 5 } } },
			{ Enemies = { { Id = "EN_W5_ARCHDEMON", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 7_000_000, Gold = 4_500_000, RaidTokens = 25, MAT_EVO_CRYSTAL = 2 },
	},
	{
		Id = "D6_ASTRAL_FOUNDRY", Name = "Astral Foundry", WorldId = "W6_CELESTIAL_KINGDOM",
		RequiredLevel = 360, EliteMultiplier = 8, TimeLimitSeconds = 600,
		Waves = {
			{ Enemies = { { Id = "EN_W6_SERAPH", Count = 6 } } },
			{ Enemies = { { Id = "EN_W6_CONSTRUCT", Count = 5 } } },
			{ Enemies = { { Id = "EN_W6_VOIDBORN", Count = 1 } }, Elite = true },
		},
		Rewards = { XP = 120_000_000, Gold = 35_000_000, RaidTokens = 40, MAT_EVO_CRYSTAL = 5 },
	},
}

local DungeonConfig = {
	Dungeons = Dungeons,
	ById = {} :: { [string]: DungeonDef },
	-- Party-size HP scaling: hp * (Base + PerMember * memberCount)
	PartyScaling = { Base = 0.5, PerMember = 0.25 },
}

for _, dungeon in Dungeons do
	DungeonConfig.ById[dungeon.Id] = dungeon
end

return DungeonConfig
