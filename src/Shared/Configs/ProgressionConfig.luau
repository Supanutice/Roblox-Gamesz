--!strict
-- ProgressionConfig.luau

return {
	LevelCap = 500,

	Character = {
		LevelUpGoldCostBase = 120, -- * level^1.4
		MaxSkillLevel = 10,
		SkillUpgradeMaterial = "MAT_SKILL_SCROLL",
	},

	Evolution = {
		-- Per evolution stage: required character level + materials.
		Stages = {
			[2] = { RequiredLevel = 40, Gold = 25_000, Materials = { MAT_EVO_SHARD = 20 } },
			[3] = { RequiredLevel = 100, Gold = 120_000, Materials = { MAT_EVO_SHARD = 60, MAT_EVO_CORE = 10 } },
			[4] = { RequiredLevel = 200, Gold = 500_000, Materials = { MAT_EVO_CORE = 40, MAT_EVO_CRYSTAL = 8 } },
			[5] = { RequiredLevel = 350, Gold = 2_000_000, Materials = { MAT_EVO_CRYSTAL = 30, MAT_DIVINE_EMBER = 3 } },
		},
	},

	Ascension = {
		MaxStars = 6,
		-- Ascending consumes duplicate shards of the same character.
		ShardsPerStar = { 10, 20, 40, 80, 120, 200 },
	},

	Weapon = {
		LevelCap = 100,
		UpgradeGoldBase = 80, -- * weaponLevel^1.5
	},

	TalentTree = {
		PointsPerLevels = 5, -- 1 talent point every 5 character levels
		Branches = { "Offense", "Defense", "Utility" },
		MaxPointsPerNode = 5,
	},

	DailyRewards = {
		-- 7-day repeating cycle
		{ Gold = 2_000 },
		{ Gems = 50 },
		{ Gold = 4_000 },
		{ MAT_EVO_SHARD = 5 },
		{ Gems = 80 },
		{ RaidTokens = 10 },
		{ Gems = 150, MAT_EVO_CORE = 2 },
	},

	WeeklyReward = { Gems = 500, RaidTokens = 50 },
}
