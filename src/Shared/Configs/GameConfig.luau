--!strict
-- GameConfig.luau
-- Global constants. Anything a designer might tune lives in a Config module,
-- never inline in a service.

return {
	GameName = "Anime Warriors III",
	DataStoreVersion = 1, -- bump only with a migration in DataService

	Server = {
		MaxPlayers = 20,
		AutoSaveIntervalSeconds = 120,
		ProfileSessionLockTimeoutSeconds = 90,
	},

	Currencies = {
		Gold = { StartingAmount = 500, MaxAmount = 1_000_000_000 },
		Gems = { StartingAmount = 50, MaxAmount = 10_000_000 },
		RaidTokens = { StartingAmount = 0, MaxAmount = 100_000 },
		EventCurrency = { StartingAmount = 0, MaxAmount = 100_000 },
	},

	Team = {
		MaxEquipped = 3, -- characters on the active team
	},

	Limits = {
		MaxCharactersOwned = 500,
		MaxInventorySlots = 400,
		MaxFriends = 100,
		MaxPartySize = 4,
	},

	Rarities = {
		-- Order matters: index = tier. RarityMult feeds Formulas.ComputeStat.
		{ Name = "Common", Color = Color3.fromRGB(170, 170, 170), StatMult = 1.00, MaxEvolution = 2 },
		{ Name = "Rare", Color = Color3.fromRGB(80, 160, 255), StatMult = 1.15, MaxEvolution = 2 },
		{ Name = "Epic", Color = Color3.fromRGB(170, 90, 240), StatMult = 1.35, MaxEvolution = 3 },
		{ Name = "Legendary", Color = Color3.fromRGB(255, 170, 40), StatMult = 1.60, MaxEvolution = 3 },
		{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 70), StatMult = 1.90, MaxEvolution = 4 },
		{ Name = "Secret", Color = Color3.fromRGB(40, 40, 60), StatMult = 2.30, MaxEvolution = 4 },
		{ Name = "Divine", Color = Color3.fromRGB(255, 240, 140), StatMult = 2.80, MaxEvolution = 5 },
	},

	Elements = { "Fire", "Water", "Wind", "Earth", "Light", "Dark", "Lightning", "Ice" },
	Classes = { "Fighter", "Assassin", "Tank", "Mage", "Support" },
}
