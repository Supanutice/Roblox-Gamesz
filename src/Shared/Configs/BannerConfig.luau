--!strict
-- BannerConfig.luau
-- Gacha banner definitions and global rate table. Rates are expressed in
-- percent and must sum to 100 exactly (validated by SummonService at boot).

export type Banner = {
	Id: string,
	Name: string,
	Type: "Standard" | "Limited" | "Event",
	CostCurrency: string,
	CostSingle: number,
	CostMulti: number, -- 10-pull (slight discount)
	FeaturedCharacterIds: { string }, -- 50/50 against pool on Legendary+
	RateUpMultiplier: number, -- featured share within their rarity bracket
	StartsAtUnix: number?, -- nil = always on
	EndsAtUnix: number?,
}

return {
	-- Global rarity rates (percent). Mirror the public rates page in-game.
	Rates = {
		Common = 60.0,
		Rare = 25.0,
		Epic = 10.0,
		Legendary = 4.0,
		Mythic = 0.9,
		Secret = 0.09,
		Divine = 0.01,
	},

	Pity = {
		-- Soft pity: starting at this pull count, Legendary+ odds grow per pull.
		SoftPityStart = 50,
		SoftPityBonusPerPull = 2.0, -- +2% Legendary+ chance per pull past soft pity
		-- Hard pity: guaranteed Legendary-or-better at this many pulls without one.
		HardPity = 80,
		-- Separate long pity for Mythic+: guaranteed within this many pulls.
		MythicHardPity = 400,
	},

	Multi = {
		GuaranteedRareMinimum = true, -- every 10-pull contains at least one Rare+
	},

	Banners = {
		{
			Id = "standard",
			Name = "Warrior's Path",
			Type = "Standard",
			CostCurrency = "Gems",
			CostSingle = 100,
			CostMulti = 950,
			FeaturedCharacterIds = {},
			RateUpMultiplier = 1,
		},
		{
			Id = "limited_flame_emperor",
			Name = "Reign of the Flame Emperor",
			Type = "Limited",
			CostCurrency = "Gems",
			CostSingle = 100,
			CostMulti = 950,
			FeaturedCharacterIds = { "CHR_046", "CHR_036" },
			RateUpMultiplier = 2, -- featured units take 2x share of their bracket
		},
		{
			Id = "event_celestial",
			Name = "Celestial Convergence",
			Type = "Event",
			CostCurrency = "EventCurrency",
			CostSingle = 50,
			CostMulti = 475,
			FeaturedCharacterIds = { "CHR_050" },
			RateUpMultiplier = 3,
		},
	} :: { Banner },
}
