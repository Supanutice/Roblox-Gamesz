--!strict
-- BossDatabase.luau
-- World / raid / event boss definitions: phases, mechanics, enrage, loot.
-- BossAI (server) executes the pattern lists defined here.

export type BossPhase = {
	HealthThreshold: number, -- phase begins when HP fraction <= threshold
	Name: string,
	AttackPattern: { string }, -- ability ids executed in sequence by BossAI
	SpeedMultiplier: number,
	DamageMultiplier: number,
	MechanicNote: string,
}

export type LootEntry = { ItemId: string, Chance: number, Min: number, Max: number }

export type BossDef = {
	Id: string,
	Name: string,
	Category: "World" | "Raid" | "Event",
	Level: number,
	Element: string,
	BaseHealth: number,
	BaseAttack: number,
	BaseDefense: number,
	Phases: { BossPhase },
	EnrageSeconds: number, -- after this, +100% damage and speed
	RespawnSeconds: number,
	IntroCutsceneId: string,
	DefeatCutsceneId: string,
	LootTable: { LootEntry },
	GuaranteedRewards: { [string]: number },
}

local function boss(b: BossDef): BossDef
	return b
end

local Bosses: { [string]: BossDef } = {
	BOSS_W1_KRAKEN_SPAWN = boss({
		Id = "BOSS_W1_KRAKEN_SPAWN", Name = "Kraken Spawn", Category = "World",
		Level = 20, Element = "Water",
		BaseHealth = 45_000, BaseAttack = 180, BaseDefense = 90,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Surfacing", AttackPattern = { "TENTACLE_SLAM", "INK_SPRAY" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Telegraphed slams; teaches dodging." },
			{ HealthThreshold = 0.4, Name = "Frenzy", AttackPattern = { "TENTACLE_SWEEP", "WHIRLPOOL", "INK_SPRAY" },
				SpeedMultiplier = 1.3, DamageMultiplier = 1.25,
				MechanicNote = "Whirlpool pulls players; break line-of-sight behind rocks." },
		},
		EnrageSeconds = 300, RespawnSeconds = 600,
		IntroCutsceneId = "CUT_W1_KRAKEN_INTRO", DefeatCutsceneId = "CUT_W1_KRAKEN_DEFEAT",
		LootTable = {
			{ ItemId = "WPN_TRAINING_KATANA", Chance = 0.3, Min = 1, Max = 1 },
			{ ItemId = "MAT_EVO_SHARD", Chance = 0.8, Min = 2, Max = 5 },
			{ ItemId = "CON_HP_POTION", Chance = 1.0, Min = 2, Max = 4 },
		},
		GuaranteedRewards = { Gold = 5_000, XP = 2_000 },
	}),

	BOSS_W2_SHADOW_SHOGUN = boss({
		Id = "BOSS_W2_SHADOW_SHOGUN", Name = "Shadow Shogun", Category = "World",
		Level = 65, Element = "Dark",
		BaseHealth = 400_000, BaseAttack = 650, BaseDefense = 320,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Way of the Blade", AttackPattern = { "IAIJUTSU_DASH", "SHURIKEN_FAN" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Dash is parryable; perfect block staggers him." },
			{ HealthThreshold = 0.6, Name = "Art of Shadows", AttackPattern = { "SHADOW_CLONES", "SMOKE_FIELD", "IAIJUTSU_DASH" },
				SpeedMultiplier = 1.2, DamageMultiplier = 1.15,
				MechanicNote = "Spawns 3 clones; only the real one casts shadows." },
			{ HealthThreshold = 0.25, Name = "Forbidden Mask", AttackPattern = { "ONI_BEAM", "SHADOW_CLONES", "ARENA_DARKNESS" },
				SpeedMultiplier = 1.4, DamageMultiplier = 1.4,
				MechanicNote = "Arena darkens; follow his burning mask to dodge the beam." },
		},
		EnrageSeconds = 420, RespawnSeconds = 900,
		IntroCutsceneId = "CUT_W2_SHOGUN_INTRO", DefeatCutsceneId = "CUT_W2_SHOGUN_DEFEAT",
		LootTable = {
			{ ItemId = "WPN_SHINOBI_TANTO", Chance = 0.25, Min = 1, Max = 1 },
			{ ItemId = "MAT_EVO_SHARD", Chance = 1.0, Min = 5, Max = 12 },
			{ ItemId = "MAT_SKILL_SCROLL", Chance = 0.6, Min = 1, Max = 3 },
		},
		GuaranteedRewards = { Gold = 30_000, XP = 15_000 },
	}),

	BOSS_W3_HOLLOW_MONARCH = boss({
		Id = "BOSS_W3_HOLLOW_MONARCH", Name = "Hollow Monarch", Category = "World",
		Level = 130, Element = "Dark",
		BaseHealth = 2_800_000, BaseAttack = 1_900, BaseDefense = 900,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Crowned Sorrow", AttackPattern = { "VOID_CLAW", "WAIL" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Wail applies Fear (reversed controls) unless blocked." },
			{ HealthThreshold = 0.5, Name = "Court of Hollows", AttackPattern = { "SUMMON_HOLLOWS", "VOID_CLAW", "CERO_BEAM" },
				SpeedMultiplier = 1.15, DamageMultiplier = 1.3,
				MechanicNote = "Adds must die fast or they heal the Monarch 5%/each." },
			{ HealthThreshold = 0.2, Name = "Throne of Nothing", AttackPattern = { "CERO_BARRAGE", "VOID_ZONE", "WAIL" },
				SpeedMultiplier = 1.35, DamageMultiplier = 1.6,
				MechanicNote = "Void zones persist; arena shrinks. DPS race." },
		},
		EnrageSeconds = 480, RespawnSeconds = 1200,
		IntroCutsceneId = "CUT_W3_MONARCH_INTRO", DefeatCutsceneId = "CUT_W3_MONARCH_DEFEAT",
		LootTable = {
			{ ItemId = "WPN_SOUL_CLEAVER", Chance = 0.15, Min = 1, Max = 1 },
			{ ItemId = "MAT_EVO_CORE", Chance = 0.9, Min = 2, Max = 6 },
		},
		GuaranteedRewards = { Gold = 150_000, XP = 90_000, RaidTokens = 10 },
	}),

	BOSS_W4_LEVIATHAN = boss({
		Id = "BOSS_W4_LEVIATHAN", Name = "The Leviathan", Category = "World",
		Level = 225, Element = "Water",
		BaseHealth = 18_000_000, BaseAttack = 5_200, BaseDefense = 2_400,
		Phases = {
			{ HealthThreshold = 1.0, Name = "From the Trench", AttackPattern = { "TIDAL_CRASH", "BITE" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Fought from ship decks; falling in the water = heavy DoT." },
			{ HealthThreshold = 0.55, Name = "Drowned Sky", AttackPattern = { "RAIN_OF_FANGS", "TIDAL_CRASH", "DIVE" },
				SpeedMultiplier = 1.2, DamageMultiplier = 1.3,
				MechanicNote = "Dives then breaches under a random player — watch the bubbles." },
			{ HealthThreshold = 0.2, Name = "The Trench Answers", AttackPattern = { "MAELSTROM", "RAIN_OF_FANGS", "BITE" },
				SpeedMultiplier = 1.4, DamageMultiplier = 1.7,
				MechanicNote = "Maelstrom drags ships; rotate to the outer ring." },
		},
		EnrageSeconds = 540, RespawnSeconds = 1800,
		IntroCutsceneId = "CUT_W4_LEVIATHAN_INTRO", DefeatCutsceneId = "CUT_W4_LEVIATHAN_DEFEAT",
		LootTable = {
			{ ItemId = "WPN_LEVIATHAN_FANG", Chance = 0.08, Min = 1, Max = 1 },
			{ ItemId = "MAT_EVO_CRYSTAL", Chance = 0.5, Min = 1, Max = 2 },
			{ ItemId = "MAT_EVO_CORE", Chance = 1.0, Min = 4, Max = 10 },
		},
		GuaranteedRewards = { Gold = 800_000, XP = 600_000, RaidTokens = 20 },
	}),

	BOSS_W5_DEMON_KING = boss({
		Id = "BOSS_W5_DEMON_KING", Name = "Demon King Balgaroth", Category = "World",
		Level = 340, Element = "Fire",
		BaseHealth = 120_000_000, BaseAttack = 14_000, BaseDefense = 6_500,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Ten Thousand Years of Rule", AttackPattern = { "HELL_CLEAVE", "FLAME_PILLARS" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Pillars spawn on ranged players; stack mid then spread." },
			{ HealthThreshold = 0.65, Name = "The Crown Burns", AttackPattern = { "METEOR_RAIN", "HELL_CLEAVE", "SUMMON_ROYAL_GUARD" },
				SpeedMultiplier = 1.15, DamageMultiplier = 1.35,
				MechanicNote = "Royal guards shield him; kill both within 10s of each other." },
			{ HealthThreshold = 0.3, Name = "True Form", AttackPattern = { "APOCALYPSE_BREATH", "METEOR_RAIN", "FLAME_PILLARS" },
				SpeedMultiplier = 1.3, DamageMultiplier = 1.7,
				MechanicNote = "Breath sweeps 270°; the safe cone is behind his left wing." },
		},
		EnrageSeconds = 600, RespawnSeconds = 3600,
		IntroCutsceneId = "CUT_W5_DEMONKING_INTRO", DefeatCutsceneId = "CUT_W5_DEMONKING_DEFEAT",
		LootTable = {
			{ ItemId = "MAT_EVO_CRYSTAL", Chance = 0.9, Min = 2, Max = 5 },
			{ ItemId = "MAT_DIVINE_EMBER", Chance = 0.05, Min = 1, Max = 1 },
		},
		GuaranteedRewards = { Gold = 5_000_000, XP = 8_000_000, RaidTokens = 40 },
	}),

	BOSS_W6_CELESTIAL_ARBITER = boss({
		Id = "BOSS_W6_CELESTIAL_ARBITER", Name = "The Celestial Arbiter", Category = "World",
		Level = 500, Element = "Light",
		BaseHealth = 900_000_000, BaseAttack = 38_000, BaseDefense = 18_000,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Judgement", AttackPattern = { "VERDICT_BLADE", "STARFALL" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0,
				MechanicNote = "Verdict Blade marks a player; allies must body-block the strike." },
			{ HealthThreshold = 0.6, Name = "Sentence", AttackPattern = { "GRAVITY_DECREE", "STARFALL", "ANGELIC_LEGION" },
				SpeedMultiplier = 1.2, DamageMultiplier = 1.4,
				MechanicNote = "Gravity flips for 10s; aerial combat mandatory." },
			{ HealthThreshold = 0.25, Name = "Execution", AttackPattern = { "WORLD_ERASURE", "VERDICT_BLADE", "GRAVITY_DECREE" },
				SpeedMultiplier = 1.4, DamageMultiplier = 1.8,
				MechanicNote = "World Erasure: 60s channel = wipe. Pure DPS check with rotating safe tiles." },
		},
		EnrageSeconds = 720, RespawnSeconds = 7200,
		IntroCutsceneId = "CUT_W6_ARBITER_INTRO", DefeatCutsceneId = "CUT_W6_ARBITER_DEFEAT",
		LootTable = {
			{ ItemId = "WPN_STARFALL_EDGE", Chance = 0.03, Min = 1, Max = 1 },
			{ ItemId = "MAT_DIVINE_EMBER", Chance = 0.25, Min = 1, Max = 2 },
			{ ItemId = "MAT_EVO_CRYSTAL", Chance = 1.0, Min = 3, Max = 8 },
		},
		GuaranteedRewards = { Gold = 50_000_000, XP = 200_000_000, RaidTokens = 100 },
	}),

	-- ============================ RAID BOSSES ==============================
	BOSS_RAID_VOIDLORD = boss({
		Id = "BOSS_RAID_VOIDLORD", Name = "Voidlord Xal'Qor", Category = "Raid",
		Level = 250, Element = "Dark",
		BaseHealth = 60_000_000, BaseAttack = 8_000, BaseDefense = 4_000,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Umbral Tide", AttackPattern = { "VOID_LASH", "DARK_ORBS" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0, MechanicNote = "Orbs must be intercepted before reaching the lord." },
			{ HealthThreshold = 0.5, Name = "Null Domain", AttackPattern = { "DOMAIN_EXPANSION", "VOID_LASH", "GAZE_OF_NOTHING" },
				SpeedMultiplier = 1.25, DamageMultiplier = 1.5, MechanicNote = "Gaze petrifies anyone facing him — turn away on cue." },
		},
		EnrageSeconds = 600, RespawnSeconds = 0,
		IntroCutsceneId = "CUT_RAID_VOIDLORD_INTRO", DefeatCutsceneId = "CUT_RAID_VOIDLORD_DEFEAT",
		LootTable = { { ItemId = "MAT_EVO_CRYSTAL", Chance = 1.0, Min = 2, Max = 4 } },
		GuaranteedRewards = { RaidTokens = 60, XP = 4_000_000 },
	}),
	BOSS_RAID_SEAMOTHER = boss({
		Id = "BOSS_RAID_SEAMOTHER", Name = "The Seamother", Category = "Raid",
		Level = 300, Element = "Water",
		BaseHealth = 90_000_000, BaseAttack = 10_500, BaseDefense = 5_000,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Lullaby", AttackPattern = { "SIREN_SONG", "CRUSH_WAVE" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0, MechanicNote = "Song charms one player; cleanse or CC them." },
			{ HealthThreshold = 0.4, Name = "Wrath of the Deep", AttackPattern = { "ABYSS_MAW", "CRUSH_WAVE", "SIREN_SONG" },
				SpeedMultiplier = 1.3, DamageMultiplier = 1.6, MechanicNote = "Maw devours the tank without an active shield cooldown." },
		},
		EnrageSeconds = 600, RespawnSeconds = 0,
		IntroCutsceneId = "CUT_RAID_SEAMOTHER_INTRO", DefeatCutsceneId = "CUT_RAID_SEAMOTHER_DEFEAT",
		LootTable = { { ItemId = "MAT_DIVINE_EMBER", Chance = 0.10, Min = 1, Max = 1 }, { ItemId = "MAT_EVO_CRYSTAL", Chance = 1.0, Min = 3, Max = 5 } },
		GuaranteedRewards = { RaidTokens = 80, XP = 9_000_000 },
	}),
	BOSS_RAID_CHRONOS = boss({
		Id = "BOSS_RAID_CHRONOS", Name = "Chronos, the Unwound", Category = "Raid",
		Level = 400, Element = "Lightning",
		BaseHealth = 250_000_000, BaseAttack = 20_000, BaseDefense = 9_000,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Tick", AttackPattern = { "TEMPORAL_SLASH", "REWIND_ZONES" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0, MechanicNote = "Rewind zones teleport you 5s into your past position." },
			{ HealthThreshold = 0.5, Name = "Tock", AttackPattern = { "TIME_STOP", "TEMPORAL_SLASH", "PARADOX_CLONES" },
				SpeedMultiplier = 1.4, DamageMultiplier = 1.6, MechanicNote = "During Time Stop, pre-position: queued damage releases at once." },
		},
		EnrageSeconds = 540, RespawnSeconds = 0,
		IntroCutsceneId = "CUT_RAID_CHRONOS_INTRO", DefeatCutsceneId = "CUT_RAID_CHRONOS_DEFEAT",
		LootTable = { { ItemId = "MAT_DIVINE_EMBER", Chance = 0.20, Min = 1, Max = 1 } },
		GuaranteedRewards = { RaidTokens = 120, XP = 30_000_000 },
	}),

	-- ============================ EVENT BOSS ===============================
	BOSS_EVENT_SOLSTICE = boss({
		Id = "BOSS_EVENT_SOLSTICE", Name = "Solstice Avatar", Category = "Event",
		Level = 200, Element = "Light",
		BaseHealth = 30_000_000, BaseAttack = 6_000, BaseDefense = 3_000,
		Phases = {
			{ HealthThreshold = 1.0, Name = "Festival of Light", AttackPattern = { "SUNBURST", "LANTERN_VOLLEY" },
				SpeedMultiplier = 1.0, DamageMultiplier = 1.0, MechanicNote = "Scales to participant count; seasonal event only." },
		},
		EnrageSeconds = 480, RespawnSeconds = 1800,
		IntroCutsceneId = "CUT_EVENT_SOLSTICE_INTRO", DefeatCutsceneId = "CUT_EVENT_SOLSTICE_DEFEAT",
		LootTable = { { ItemId = "CON_SUMMON_TICKET", Chance = 0.5, Min = 1, Max = 2 } },
		GuaranteedRewards = { EventCurrency = 100, XP = 1_000_000 },
	}),
}

return { ById = Bosses }
