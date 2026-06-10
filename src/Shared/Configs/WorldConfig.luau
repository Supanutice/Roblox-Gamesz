--!strict
-- WorldConfig.luau
-- Definitions for all six launch worlds: level bands, NPCs, enemy tables,
-- bosses, fast-travel points, and unlock requirements. Geometry lives in
-- Workspace/Worlds/<WorldId>; this file is the logical layer over it.

export type WorldDef = {
	Id: string,
	Name: string,
	LevelRange: { number },
	UnlockRequirement: { QuestId: string?, PlayerLevel: number },
	NPCs: { { Id: string, Name: string, Role: string } },
	Enemies: { { Id: string, Name: string, Level: number, Element: string } },
	Bosses: { string }, -- BossDatabase ids
	QuestIds: { string },
	FastTravelPoints: { { Id: string, Name: string, Position: Vector3 } },
	Secrets: { { Id: string, Hint: string, Reward: { [string]: number } } },
}

local Worlds: { WorldDef } = {
	{
		Id = "W1_BEGINNER_ISLAND",
		Name = "Beginner Island",
		LevelRange = { 1, 25 },
		UnlockRequirement = { PlayerLevel = 1 },
		NPCs = {
			{ Id = "NPC_W1_ELDER", Name = "Elder Hamato", Role = "QuestGiver" },
			{ Id = "NPC_W1_SMITH", Name = "Smith Daigo", Role = "WeaponShop" },
			{ Id = "NPC_W1_MERCHANT", Name = "Merchant Yui", Role = "ItemShop" },
			{ Id = "NPC_W1_SENSEI", Name = "Sensei Roku", Role = "Trainer" },
		},
		Enemies = {
			{ Id = "EN_W1_BANDIT", Name = "Cove Bandit", Level = 3, Element = "Earth" },
			{ Id = "EN_W1_WOLF", Name = "Shorefang Wolf", Level = 6, Element = "Wind" },
			{ Id = "EN_W1_GOLEM", Name = "Tide Golem", Level = 12, Element = "Water" },
			{ Id = "EN_W1_ROGUE_NINJA", Name = "Rogue Disciple", Level = 18, Element = "Dark" },
		},
		Bosses = { "BOSS_W1_KRAKEN_SPAWN" },
		QuestIds = { "Q_W1_001", "Q_W1_002", "Q_W1_003", "Q_W1_004", "Q_W1_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W1_VILLAGE", Name = "Hamato Village", Position = Vector3.new(0, 10, 0) },
			{ Id = "FT_W1_SHORE", Name = "Broken Shore", Position = Vector3.new(420, 8, 180) },
			{ Id = "FT_W1_PEAK", Name = "Watcher's Peak", Position = Vector3.new(-260, 95, 340) },
		},
		Secrets = {
			{ Id = "SEC_W1_CAVE", Hint = "Behind the waterfall, a chest waits.", Reward = { Gems = 100 } },
			{ Id = "SEC_W1_STATUE", Hint = "Bow before all four shrine statues.", Reward = { Gold = 5000 } },
		},
	},
	{
		Id = "W2_SHINOBI_NATION",
		Name = "Shinobi Nation",
		LevelRange = { 25, 70 },
		UnlockRequirement = { QuestId = "Q_W1_BOSS", PlayerLevel = 20 },
		NPCs = {
			{ Id = "NPC_W2_KAGE", Name = "Lady Shirayuki", Role = "QuestGiver" },
			{ Id = "NPC_W2_TOOLSMITH", Name = "Toolsmith Genba", Role = "WeaponShop" },
			{ Id = "NPC_W2_RAMEN", Name = "Chef Tonkatsu", Role = "ConsumableShop" },
			{ Id = "NPC_W2_SPYMASTER", Name = "Spymaster Kuro", Role = "BountyBoard" },
		},
		Enemies = {
			{ Id = "EN_W2_GENIN", Name = "Renegade Genin", Level = 28, Element = "Wind" },
			{ Id = "EN_W2_PUPPET", Name = "Cursed Puppet", Level = 38, Element = "Earth" },
			{ Id = "EN_W2_JONIN", Name = "Shadow Jonin", Level = 52, Element = "Lightning" },
			{ Id = "EN_W2_ONI_MASK", Name = "Oni-Masked Assassin", Level = 64, Element = "Dark" },
		},
		Bosses = { "BOSS_W2_SHADOW_SHOGUN" },
		QuestIds = { "Q_W2_001", "Q_W2_002", "Q_W2_003", "Q_W2_004", "Q_W2_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W2_GATE", Name = "Hidden Gate", Position = Vector3.new(2000, 12, 0) },
			{ Id = "FT_W2_FOREST", Name = "Whisper Forest", Position = Vector3.new(2380, 20, 410) },
			{ Id = "FT_W2_TOWER", Name = "Kage Tower", Position = Vector3.new(2150, 60, -300) },
		},
		Secrets = {
			{ Id = "SEC_W2_SCROLL", Hint = "The forbidden scroll lies beneath the dojo floor.", Reward = { MAT_SKILL_SCROLL = 5 } },
			{ Id = "SEC_W2_FOX", Hint = "Feed the nine-tailed fox shrine at midnight.", Reward = { Gems = 250 } },
		},
	},
	{
		Id = "W3_SOUL_EMPIRE",
		Name = "Soul Empire",
		LevelRange = { 70, 140 },
		UnlockRequirement = { QuestId = "Q_W2_BOSS", PlayerLevel = 60 },
		NPCs = {
			{ Id = "NPC_W3_CAPTAIN", Name = "Captain Seijuro", Role = "QuestGiver" },
			{ Id = "NPC_W3_ARTIFICER", Name = "Artificer Mion", Role = "WeaponShop" },
			{ Id = "NPC_W3_GATEKEEPER", Name = "Gatekeeper Wol", Role = "FastTravelUnlock" },
		},
		Enemies = {
			{ Id = "EN_W3_HOLLOW", Name = "Hollow Wraith", Level = 75, Element = "Dark" },
			{ Id = "EN_W3_REAPER", Name = "Fallen Reaper", Level = 95, Element = "Ice" },
			{ Id = "EN_W3_SOULKNIGHT", Name = "Soulbound Knight", Level = 120, Element = "Light" },
		},
		Bosses = { "BOSS_W3_HOLLOW_MONARCH" },
		QuestIds = { "Q_W3_001", "Q_W3_002", "Q_W3_003", "Q_W3_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W3_COURT", Name = "Spirit Court", Position = Vector3.new(4000, 15, 0) },
			{ Id = "FT_W3_RIFT", Name = "Hollow Rift", Position = Vector3.new(4400, 5, 520) },
		},
		Secrets = {
			{ Id = "SEC_W3_BLADE", Hint = "A captain's blade rests where the two rivers of souls cross.", Reward = { MAT_EVO_CORE = 5 } },
		},
	},
	{
		Id = "W4_GRAND_OCEAN",
		Name = "Grand Ocean",
		LevelRange = { 140, 230 },
		UnlockRequirement = { QuestId = "Q_W3_BOSS", PlayerLevel = 120 },
		NPCs = {
			{ Id = "NPC_W4_CAPTAIN", Name = "Captain Marisol", Role = "QuestGiver" },
			{ Id = "NPC_W4_SHIPWRIGHT", Name = "Shipwright Bolt", Role = "MountShop" },
			{ Id = "NPC_W4_BROKER", Name = "Broker Quill", Role = "TradePost" },
		},
		Enemies = {
			{ Id = "EN_W4_PIRATE", Name = "Reef Pirate", Level = 150, Element = "Water" },
			{ Id = "EN_W4_MARINE", Name = "Iron Marine", Level = 180, Element = "Earth" },
			{ Id = "EN_W4_SERPENT", Name = "Abyss Serpent", Level = 215, Element = "Lightning" },
		},
		Bosses = { "BOSS_W4_LEVIATHAN" },
		QuestIds = { "Q_W4_001", "Q_W4_002", "Q_W4_003", "Q_W4_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W4_PORT", Name = "Freeport Haven", Position = Vector3.new(6000, 10, 0) },
			{ Id = "FT_W4_ISLE", Name = "Skull Isle", Position = Vector3.new(6550, 12, -380) },
		},
		Secrets = {
			{ Id = "SEC_W4_TREASURE", Hint = "X marks the spot where the broken compass spins.", Reward = { Gold = 250000, Gems = 400 } },
		},
	},
	{
		Id = "W5_DEMON_REALM",
		Name = "Demon Realm",
		LevelRange = { 230, 350 },
		UnlockRequirement = { QuestId = "Q_W4_BOSS", PlayerLevel = 200 },
		NPCs = {
			{ Id = "NPC_W5_WARDEN", Name = "Warden Ilyss", Role = "QuestGiver" },
			{ Id = "NPC_W5_FORGEMASTER", Name = "Forgemaster Gor", Role = "WeaponShop" },
		},
		Enemies = {
			{ Id = "EN_W5_IMP", Name = "Ember Imp", Level = 240, Element = "Fire" },
			{ Id = "EN_W5_FIEND", Name = "Pit Fiend", Level = 290, Element = "Dark" },
			{ Id = "EN_W5_ARCHDEMON", Name = "Archdemon Sentinel", Level = 330, Element = "Fire" },
		},
		Bosses = { "BOSS_W5_DEMON_KING" },
		QuestIds = { "Q_W5_001", "Q_W5_002", "Q_W5_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W5_BASTION", Name = "Last Bastion", Position = Vector3.new(8000, 18, 0) },
			{ Id = "FT_W5_THRONE", Name = "Obsidian Approach", Position = Vector3.new(8420, 40, 600) },
		},
		Secrets = {
			{ Id = "SEC_W5_PACT", Hint = "Sign nothing the smiling demon offers… or do.", Reward = { MAT_EVO_CRYSTAL = 4 } },
		},
	},
	{
		Id = "W6_CELESTIAL_KINGDOM",
		Name = "Celestial Kingdom",
		LevelRange = { 350, 500 },
		UnlockRequirement = { QuestId = "Q_W5_BOSS", PlayerLevel = 320 },
		NPCs = {
			{ Id = "NPC_W6_ORACLE", Name = "Oracle Selene", Role = "QuestGiver" },
			{ Id = "NPC_W6_STARSMITH", Name = "Starsmith Aurelion", Role = "WeaponShop" },
		},
		Enemies = {
			{ Id = "EN_W6_SERAPH", Name = "Fallen Seraph", Level = 370, Element = "Light" },
			{ Id = "EN_W6_CONSTRUCT", Name = "Astral Construct", Level = 420, Element = "Lightning" },
			{ Id = "EN_W6_VOIDBORN", Name = "Voidborn Herald", Level = 480, Element = "Dark" },
		},
		Bosses = { "BOSS_W6_CELESTIAL_ARBITER" },
		QuestIds = { "Q_W6_001", "Q_W6_002", "Q_W6_BOSS" },
		FastTravelPoints = {
			{ Id = "FT_W6_GATE", Name = "Gate of Dawn", Position = Vector3.new(10000, 200, 0) },
			{ Id = "FT_W6_SPIRE", Name = "Infinity Spire", Position = Vector3.new(10300, 380, -250) },
		},
		Secrets = {
			{ Id = "SEC_W6_STAR", Hint = "Catch a falling star before it touches the clouds.", Reward = { MAT_DIVINE_EMBER = 1 } },
		},
	},
}

local WorldConfig = {
	Worlds = Worlds,
	ById = {} :: { [string]: WorldDef },
}

for _, world in Worlds do
	WorldConfig.ById[world.Id] = world
end

return WorldConfig
