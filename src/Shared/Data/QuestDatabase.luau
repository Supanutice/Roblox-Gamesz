--!strict
-- QuestDatabase.luau
-- Main, side, daily and weekly quest definitions. QuestService owns runtime
-- progress; this file is pure data.

export type Objective = {
	Type: "Kill" | "Collect" | "Talk" | "Reach" | "DefeatBoss" | "CompleteDungeon" | "WinPvP" | "Summon",
	TargetId: string?, -- enemy id / item id / npc id / boss id / location id
	Count: number,
}

export type QuestDef = {
	Id: string,
	Name: string,
	Type: "Main" | "Side" | "Daily" | "Weekly",
	WorldId: string?,
	GiverNPC: string?,
	RequiredLevel: number,
	PrerequisiteQuest: string?,
	Objectives: { Objective },
	Rewards: { [string]: number }, -- currency/item id -> amount, plus XP
	Description: string,
}

local function quest(q: QuestDef): QuestDef
	return q
end

local Quests: { [string]: QuestDef } = {
	-- ======================= WORLD 1: BEGINNER ISLAND ======================
	Q_W1_001 = quest({
		Id = "Q_W1_001", Name = "Welcome, Warrior", Type = "Main",
		WorldId = "W1_BEGINNER_ISLAND", GiverNPC = "NPC_W1_ELDER", RequiredLevel = 1,
		Objectives = { { Type = "Talk", TargetId = "NPC_W1_SENSEI", Count = 1 } },
		Rewards = { XP = 100, Gold = 500 },
		Description = "Elder Hamato wants you to meet Sensei Roku at the dojo.",
	}),
	Q_W1_002 = quest({
		Id = "Q_W1_002", Name = "Bandit Trouble", Type = "Main",
		WorldId = "W1_BEGINNER_ISLAND", GiverNPC = "NPC_W1_SENSEI", RequiredLevel = 2,
		PrerequisiteQuest = "Q_W1_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W1_BANDIT", Count = 8 } },
		Rewards = { XP = 350, Gold = 1200, CON_HP_POTION = 3 },
		Description = "Cove bandits are harassing the village. Show them your training.",
	}),
	Q_W1_003 = quest({
		Id = "Q_W1_003", Name = "Fangs in the Dark", Type = "Main",
		WorldId = "W1_BEGINNER_ISLAND", GiverNPC = "NPC_W1_ELDER", RequiredLevel = 5,
		PrerequisiteQuest = "Q_W1_002",
		Objectives = {
			{ Type = "Kill", TargetId = "EN_W1_WOLF", Count = 10 },
			{ Type = "Collect", TargetId = "MAT_EVO_SHARD", Count = 3 },
		},
		Rewards = { XP = 700, Gold = 2500, MAT_SKILL_SCROLL = 2 },
		Description = "Shorefang wolves carry strange shards. The Elder wants samples.",
	}),
	Q_W1_004 = quest({
		Id = "Q_W1_004", Name = "First Summons", Type = "Side",
		WorldId = "W1_BEGINNER_ISLAND", GiverNPC = "NPC_W1_MERCHANT", RequiredLevel = 5,
		Objectives = { { Type = "Summon", Count = 1 } },
		Rewards = { XP = 200, Gems = 100 },
		Description = "Merchant Yui insists you try the summoning altar. 'It's fate!'",
	}),
	Q_W1_BOSS = quest({
		Id = "Q_W1_BOSS", Name = "Terror of the Tide", Type = "Main",
		WorldId = "W1_BEGINNER_ISLAND", GiverNPC = "NPC_W1_ELDER", RequiredLevel = 15,
		PrerequisiteQuest = "Q_W1_003",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W1_KRAKEN_SPAWN", Count = 1 } },
		Rewards = { XP = 3000, Gold = 10000, Gems = 250, CON_SUMMON_TICKET = 1 },
		Description = "Something vast stirs beneath Broken Shore. End it, and the Shinobi Nation opens to you.",
	}),

	-- ======================= WORLD 2: SHINOBI NATION =======================
	Q_W2_001 = quest({
		Id = "Q_W2_001", Name = "Audience with the Lady", Type = "Main",
		WorldId = "W2_SHINOBI_NATION", GiverNPC = "NPC_W2_KAGE", RequiredLevel = 25,
		PrerequisiteQuest = "Q_W1_BOSS",
		Objectives = { { Type = "Talk", TargetId = "NPC_W2_KAGE", Count = 1 } },
		Rewards = { XP = 1500, Gold = 5000 },
		Description = "Lady Shirayuki has heard of the warrior who slew the tide-terror.",
	}),
	Q_W2_002 = quest({
		Id = "Q_W2_002", Name = "Renegade Purge", Type = "Main",
		WorldId = "W2_SHINOBI_NATION", GiverNPC = "NPC_W2_KAGE", RequiredLevel = 28,
		PrerequisiteQuest = "Q_W2_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W2_GENIN", Count = 15 } },
		Rewards = { XP = 4000, Gold = 12000, MAT_EVO_SHARD = 10 },
		Description = "Renegade genin defect to the Oni-masked cult daily. Thin their ranks.",
	}),
	Q_W2_003 = quest({
		Id = "Q_W2_003", Name = "Strings Attached", Type = "Side",
		WorldId = "W2_SHINOBI_NATION", GiverNPC = "NPC_W2_SPYMASTER", RequiredLevel = 35,
		Objectives = { { Type = "Kill", TargetId = "EN_W2_PUPPET", Count = 20 } },
		Rewards = { XP = 5000, Gold = 15000, MAT_SKILL_SCROLL = 5 },
		Description = "Someone is pulling the cursed puppets' strings. Cut them. All of them.",
	}),
	Q_W2_004 = quest({
		Id = "Q_W2_004", Name = "Shadow Examination", Type = "Main",
		WorldId = "W2_SHINOBI_NATION", GiverNPC = "NPC_W2_KAGE", RequiredLevel = 45,
		PrerequisiteQuest = "Q_W2_002",
		Objectives = {
			{ Type = "Kill", TargetId = "EN_W2_JONIN", Count = 10 },
			{ Type = "Reach", TargetId = "FT_W2_TOWER", Count = 1 },
		},
		Rewards = { XP = 9000, Gold = 25000, Gems = 150 },
		Description = "Pass the Shadow Examination to earn an audience atop Kage Tower.",
	}),
	Q_W2_BOSS = quest({
		Id = "Q_W2_BOSS", Name = "The Shogun of Shadows", Type = "Main",
		WorldId = "W2_SHINOBI_NATION", GiverNPC = "NPC_W2_KAGE", RequiredLevel = 60,
		PrerequisiteQuest = "Q_W2_004",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W2_SHADOW_SHOGUN", Count = 1 } },
		Rewards = { XP = 25000, Gold = 60000, Gems = 400, MAT_EVO_CORE = 5 },
		Description = "The cult's master reveals himself. The nation holds its breath.",
	}),

	-- ======================== WORLD 3: SOUL EMPIRE =========================
	Q_W3_001 = quest({
		Id = "Q_W3_001", Name = "Crossing Over", Type = "Main",
		WorldId = "W3_SOUL_EMPIRE", GiverNPC = "NPC_W3_CAPTAIN", RequiredLevel = 70,
		PrerequisiteQuest = "Q_W2_BOSS",
		Objectives = { { Type = "Kill", TargetId = "EN_W3_HOLLOW", Count = 20 } },
		Rewards = { XP = 40000, Gold = 80000 },
		Description = "Hollow wraiths leak through the rift. Captain Seijuro needs sword-arms.",
	}),
	Q_W3_002 = quest({
		Id = "Q_W3_002", Name = "A Reaper's Due", Type = "Main",
		WorldId = "W3_SOUL_EMPIRE", GiverNPC = "NPC_W3_CAPTAIN", RequiredLevel = 90,
		PrerequisiteQuest = "Q_W3_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W3_REAPER", Count = 15 } },
		Rewards = { XP = 70000, Gold = 120000, MAT_EVO_CORE = 8 },
		Description = "Fallen reapers hunt the living now. Grant them rest.",
	}),
	Q_W3_003 = quest({
		Id = "Q_W3_003", Name = "The Gatekeeper's Riddle", Type = "Side",
		WorldId = "W3_SOUL_EMPIRE", GiverNPC = "NPC_W3_GATEKEEPER", RequiredLevel = 100,
		Objectives = { { Type = "Reach", TargetId = "FT_W3_RIFT", Count = 1 } },
		Rewards = { XP = 50000, Gems = 300 },
		Description = "Answer Wol's riddle, or walk the long way to the Hollow Rift. Forever.",
	}),
	Q_W3_BOSS = quest({
		Id = "Q_W3_BOSS", Name = "Monarch of the Hollow", Type = "Main",
		WorldId = "W3_SOUL_EMPIRE", GiverNPC = "NPC_W3_CAPTAIN", RequiredLevel = 120,
		PrerequisiteQuest = "Q_W3_002",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W3_HOLLOW_MONARCH", Count = 1 } },
		Rewards = { XP = 200000, Gold = 300000, Gems = 600, MAT_EVO_CRYSTAL = 2 },
		Description = "The rift has a king. Dethrone him.",
	}),

	-- ======================== WORLD 4: GRAND OCEAN =========================
	Q_W4_001 = quest({
		Id = "Q_W4_001", Name = "Set Sail", Type = "Main",
		WorldId = "W4_GRAND_OCEAN", GiverNPC = "NPC_W4_CAPTAIN", RequiredLevel = 140,
		PrerequisiteQuest = "Q_W3_BOSS",
		Objectives = { { Type = "Kill", TargetId = "EN_W4_PIRATE", Count = 25 } },
		Rewards = { XP = 300000, Gold = 400000 },
		Description = "Captain Marisol offers passage — if you clear the reef of pirates first.",
	}),
	Q_W4_002 = quest({
		Id = "Q_W4_002", Name = "Iron and Salt", Type = "Main",
		WorldId = "W4_GRAND_OCEAN", GiverNPC = "NPC_W4_CAPTAIN", RequiredLevel = 170,
		PrerequisiteQuest = "Q_W4_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W4_MARINE", Count = 20 } },
		Rewards = { XP = 500000, Gold = 600000, MAT_EVO_CRYSTAL = 1 },
		Description = "The Iron Marines mistake you for a pirate. Their mistake.",
	}),
	Q_W4_003 = quest({
		Id = "Q_W4_003", Name = "What the Compass Found", Type = "Side",
		WorldId = "W4_GRAND_OCEAN", GiverNPC = "NPC_W4_BROKER", RequiredLevel = 190,
		Objectives = { { Type = "Reach", TargetId = "FT_W4_ISLE", Count = 1 }, { Type = "Collect", TargetId = "MAT_EVO_CORE", Count = 10 } },
		Rewards = { XP = 400000, Gems = 500 },
		Description = "Broker Quill's compass spins over Skull Isle. Bring back whatever it wants.",
	}),
	Q_W4_BOSS = quest({
		Id = "Q_W4_BOSS", Name = "The Deep Answers", Type = "Main",
		WorldId = "W4_GRAND_OCEAN", GiverNPC = "NPC_W4_CAPTAIN", RequiredLevel = 220,
		PrerequisiteQuest = "Q_W4_002",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W4_LEVIATHAN", Count = 1 } },
		Rewards = { XP = 1500000, Gold = 1200000, Gems = 800, MAT_EVO_CRYSTAL = 4 },
		Description = "Every sailor's nightmare has a name. Today it learns yours.",
	}),

	-- ======================== WORLD 5: DEMON REALM =========================
	Q_W5_001 = quest({
		Id = "Q_W5_001", Name = "Hold the Bastion", Type = "Main",
		WorldId = "W5_DEMON_REALM", GiverNPC = "NPC_W5_WARDEN", RequiredLevel = 230,
		PrerequisiteQuest = "Q_W4_BOSS",
		Objectives = { { Type = "Kill", TargetId = "EN_W5_IMP", Count = 40 }, { Type = "Kill", TargetId = "EN_W5_FIEND", Count = 15 } },
		Rewards = { XP = 3000000, Gold = 2000000 },
		Description = "The Last Bastion holds the realm's only safe gate. Keep it that way.",
	}),
	Q_W5_002 = quest({
		Id = "Q_W5_002", Name = "Sentinels of the Throne", Type = "Main",
		WorldId = "W5_DEMON_REALM", GiverNPC = "NPC_W5_WARDEN", RequiredLevel = 290,
		PrerequisiteQuest = "Q_W5_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W5_ARCHDEMON", Count = 10 } },
		Rewards = { XP = 6000000, Gold = 4000000, MAT_EVO_CRYSTAL = 6 },
		Description = "Ten archdemons guard the Obsidian Approach. The Warden counts them daily. Make her count to zero.",
	}),
	Q_W5_BOSS = quest({
		Id = "Q_W5_BOSS", Name = "Regicide", Type = "Main",
		WorldId = "W5_DEMON_REALM", GiverNPC = "NPC_W5_WARDEN", RequiredLevel = 330,
		PrerequisiteQuest = "Q_W5_002",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W5_DEMON_KING", Count = 1 } },
		Rewards = { XP = 20000000, Gold = 10000000, Gems = 1500, MAT_DIVINE_EMBER = 1 },
		Description = "The Demon King has ruled for ten thousand years. Terms are not negotiable.",
	}),

	-- ===================== WORLD 6: CELESTIAL KINGDOM ======================
	Q_W6_001 = quest({
		Id = "Q_W6_001", Name = "The Gate of Dawn", Type = "Main",
		WorldId = "W6_CELESTIAL_KINGDOM", GiverNPC = "NPC_W6_ORACLE", RequiredLevel = 350,
		PrerequisiteQuest = "Q_W5_BOSS",
		Objectives = { { Type = "Kill", TargetId = "EN_W6_SERAPH", Count = 30 } },
		Rewards = { XP = 40000000, Gold = 15000000 },
		Description = "Even heaven has traitors. Oracle Selene names them: the Fallen.",
	}),
	Q_W6_002 = quest({
		Id = "Q_W6_002", Name = "Heralds of the End", Type = "Main",
		WorldId = "W6_CELESTIAL_KINGDOM", GiverNPC = "NPC_W6_ORACLE", RequiredLevel = 420,
		PrerequisiteQuest = "Q_W6_001",
		Objectives = { { Type = "Kill", TargetId = "EN_W6_VOIDBORN", Count = 20 } },
		Rewards = { XP = 100000000, Gold = 30000000, MAT_DIVINE_EMBER = 1 },
		Description = "The Voidborn whisper of an Arbiter. The Oracle stops smiling.",
	}),
	Q_W6_BOSS = quest({
		Id = "Q_W6_BOSS", Name = "The Final Verdict", Type = "Main",
		WorldId = "W6_CELESTIAL_KINGDOM", GiverNPC = "NPC_W6_ORACLE", RequiredLevel = 480,
		PrerequisiteQuest = "Q_W6_002",
		Objectives = { { Type = "DefeatBoss", TargetId = "BOSS_W6_CELESTIAL_ARBITER", Count = 1 } },
		Rewards = { XP = 500000000, Gold = 100000000, Gems = 5000, MAT_DIVINE_EMBER = 3 },
		Description = "The Arbiter judged this world unworthy. Appeal the verdict. Loudly.",
	}),

	-- ============================== DAILIES ================================
	Q_DAILY_KILLS = quest({
		Id = "Q_DAILY_KILLS", Name = "Daily Training", Type = "Daily", RequiredLevel = 1,
		Objectives = { { Type = "Kill", Count = 50 } },
		Rewards = { XP = 1000, Gold = 5000, Gems = 30 },
		Description = "Defeat 50 enemies anywhere.",
	}),
	Q_DAILY_DUNGEON = quest({
		Id = "Q_DAILY_DUNGEON", Name = "Daily Delve", Type = "Daily", RequiredLevel = 10,
		Objectives = { { Type = "CompleteDungeon", Count = 1 } },
		Rewards = { XP = 1500, RaidTokens = 5, Gems = 30 },
		Description = "Clear any dungeon once.",
	}),
	Q_DAILY_SUMMON = quest({
		Id = "Q_DAILY_SUMMON", Name = "Daily Fortune", Type = "Daily", RequiredLevel = 5,
		Objectives = { { Type = "Summon", Count = 1 } },
		Rewards = { Gold = 3000, Gems = 20 },
		Description = "Perform 1 summon.",
	}),

	-- ============================== WEEKLIES ===============================
	Q_WEEKLY_BOSSES = quest({
		Id = "Q_WEEKLY_BOSSES", Name = "Weekly Hunt", Type = "Weekly", RequiredLevel = 15,
		Objectives = { { Type = "DefeatBoss", Count = 5 } },
		Rewards = { XP = 20000, Gems = 300, RaidTokens = 25 },
		Description = "Defeat 5 world bosses this week.",
	}),
	Q_WEEKLY_PVP = quest({
		Id = "Q_WEEKLY_PVP", Name = "Weekly Gauntlet", Type = "Weekly", RequiredLevel = 30,
		Objectives = { { Type = "WinPvP", Count = 10 } },
		Rewards = { Gems = 400, Gold = 50000 },
		Description = "Win 10 PvP matches in any mode.",
	}),
}

return { ById = Quests }
