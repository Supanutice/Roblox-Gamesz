--!strict
-- GuildConfig.luau

return {
	CreateCostGems = 500,
	NameMinLength = 3,
	NameMaxLength = 20,
	MaxMembers = 50,

	Ranks = { "Leader", "Officer", "Veteran", "Member" },
	Permissions = {
		Leader = { "Invite", "Kick", "Promote", "Demote", "StartWar", "StartRaid", "EditMOTD", "Disband" },
		Officer = { "Invite", "Kick", "StartRaid", "EditMOTD" },
		Veteran = { "Invite" },
		Member = {},
	},

	Leveling = {
		MaxLevel = 50,
		-- Guild XP from member activity (quests, raids, donations).
		XPPerLevelBase = 10_000, -- * level^1.6
		PerkPerLevels = {
			[5] = { GoldBonus = 0.05 },
			[10] = { XPBonus = 0.05 },
			[20] = { GoldBonus = 0.10, RaidTokenBonus = 0.10 },
			[35] = { XPBonus = 0.10 },
			[50] = { GoldBonus = 0.15, XPBonus = 0.15, RaidTokenBonus = 0.20 },
		},
	},

	Raids = {
		MinMembers = 4,
		WeeklyAttempts = 3,
		BossRotation = { "BOSS_RAID_VOIDLORD", "BOSS_RAID_SEAMOTHER", "BOSS_RAID_CHRONOS" },
	},

	War = {
		DurationHours = 48,
		MinGuildLevel = 5,
		ScorePerKill = 10,
		ScorePerObjective = 50,
		RewardsWinner = { Gems = 1000, RaidTokens = 100 },
		RewardsLoser = { Gems = 300, RaidTokens = 30 },
	},
}
