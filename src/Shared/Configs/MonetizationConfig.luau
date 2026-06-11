--!strict
-- MonetizationConfig.luau
-- COSMETICS-ONLY monetization. Nothing in this file may grant stats,
-- characters, or progression speed beyond the battle pass XP track that is
-- also fully earnable free. Code review rule: any PR touching this file
-- that adds power is rejected.

return {
	-- Developer Products (Robux). Ids are placeholders until registered.
	Products = {
		GEMS_SMALL = { ProductId = 0, Gems = 100, Robux = 80 },
		GEMS_MEDIUM = { ProductId = 0, Gems = 550, Robux = 400 },
		GEMS_LARGE = { ProductId = 0, Gems = 1200, Robux = 800 },
		-- Gems buy summons & cosmetics; every gem source also exists free.
	},

	GamePasses = {
		BATTLE_PASS_PREMIUM = { PassId = 0, Robux = 800 },
		VIP_COSMETIC_PACK = { PassId = 0, Robux = 400 }, -- title + aura + emote
	},

	BattlePass = {
		SeasonLengthDays = 56,
		Tiers = 50,
		XPPerTier = 1000,
		-- Free track: currencies + materials. Premium track: cosmetics + extra
		-- currencies. No premium-exclusive characters or stats.
		FreeTrackHighlights = { "Gems x2000 total", "Evolution materials", "Summon tickets x10" },
		PremiumTrackHighlights = { "Seasonal skin set", "Mount skin", "Ultimate VFX recolor", "Gems x3000 total" },
		-- Claimable tier rewards (EconomyService merges the matching rules).
		FreeRewards = {
			EveryTier = { Gold = 2_000 },
			Every5 = { Gems = 60 },
			Every10 = { CON_SUMMON_TICKET = 1, MAT_EVO_SHARD = 5 },
		},
		PremiumRewards = {
			EveryTier = { Gems = 60 },
			-- Every 10th premium tier also unlocks a seasonal cosmetic:
			CosmeticIdPattern = "BP_S%d_TIER%d_SKIN",
		},
	},

	CosmeticShop = {
		Categories = { "CharacterSkins", "MountSkins", "Auras", "UltimateVFX", "Emotes", "Titles" },
		RotationDays = 3,
	},
}
