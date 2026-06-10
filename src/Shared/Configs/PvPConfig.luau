--!strict
-- PvPConfig.luau

return {
	Modes = {
		Ranked1v1 = { TeamSize = 1, Ranked = true, MapId = "ARENA_COLOSSEUM" },
		Casual1v1 = { TeamSize = 1, Ranked = false, MapId = "ARENA_COLOSSEUM" },
		Arena3v3 = { TeamSize = 3, Ranked = true, MapId = "ARENA_SKYRING" },
		GuildWar = { TeamSize = 5, Ranked = false, MapId = "ARENA_WARFIELD" },
	},

	Matchmaking = {
		StartingRating = 1000,
		-- Search range widens the longer a player waits.
		InitialRatingRange = 100,
		RangeGrowthPerSecond = 10,
		MaxRatingRange = 600,
		QueueTickSeconds = 2,
	},

	Ranks = {
		-- Min rating for each rank, ascending.
		{ Name = "Bronze", MinRating = 0 },
		{ Name = "Silver", MinRating = 1100 },
		{ Name = "Gold", MinRating = 1300 },
		{ Name = "Platinum", MinRating = 1500 },
		{ Name = "Diamond", MinRating = 1700 },
		{ Name = "Master", MinRating = 1900 },
		{ Name = "Grandmaster", MinRating = 2200 },
	},

	Match = {
		DurationSeconds = 180,
		BestOf = 3,
		RespawnSeconds = 5,
		-- PvP damage is normalized so collection depth, not wallet, decides.
		StatNormalization = 0.5, -- 50% of stat gaps are flattened in ranked
	},

	SeasonRewards = {
		Bronze = { Gems = 100 },
		Silver = { Gems = 250 },
		Gold = { Gems = 500 },
		Platinum = { Gems = 900, RaidTokens = 50 },
		Diamond = { Gems = 1500, RaidTokens = 100 },
		Master = { Gems = 2500, RaidTokens = 200 },
		Grandmaster = { Gems = 4000, RaidTokens = 400 },
	},
}
