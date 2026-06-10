--!strict
-- CharacterDatabase.luau
-- All 50 launch characters. Original IP — names evoke anime archetypes
-- without referencing copyrighted properties.
--
-- BaseStats are stage-1, level-1 values; Formulas.ComputeStat applies level,
-- rarity, evolution and ascension multipliers on top.
-- Skill damage values are multipliers of the character's ATK stat.

export type Skill = {
	Name: string,
	Multiplier: number,
	Cooldown: number,
	StatusEffect: string?, -- key into StatusEffectData
	Description: string,
}

export type Ultimate = {
	Name: string,
	Multiplier: number,
	StatusEffect: string?,
	Description: string,
	CinematicId: string, -- camera/VFX sequence id for the finisher
}

export type CharacterDef = {
	Id: string,
	Name: string,
	Element: string,
	Class: string,
	Rarity: string,
	BaseStats: { HP: number, ATK: number, DEF: number, SPD: number },
	Passive: { Name: string, Description: string },
	Skill1: Skill,
	Skill2: Skill,
	Ultimate: Ultimate,
	EvolutionName: string, -- display name of final evolution form
}

local DB: { [string]: CharacterDef } = {}
local Ordered: { CharacterDef } = {}

local function def(
	id: string, name: string, element: string, class: string, rarity: string,
	stats: { number }, -- HP, ATK, DEF, SPD
	passive: { string }, -- name, description
	s1: { any }, s2: { any }, -- name, mult, cd, status?, desc
	ult: { any }, -- name, mult, status?, desc
	evoName: string
)
	local entry: CharacterDef = {
		Id = id,
		Name = name,
		Element = element,
		Class = class,
		Rarity = rarity,
		BaseStats = { HP = stats[1], ATK = stats[2], DEF = stats[3], SPD = stats[4] },
		Passive = { Name = passive[1], Description = passive[2] },
		Skill1 = { Name = s1[1], Multiplier = s1[2], Cooldown = s1[3], StatusEffect = s1[4], Description = s1[5] },
		Skill2 = { Name = s2[1], Multiplier = s2[2], Cooldown = s2[3], StatusEffect = s2[4], Description = s2[5] },
		Ultimate = { Name = ult[1], Multiplier = ult[2], StatusEffect = ult[3], Description = ult[4], CinematicId = "CINE_" .. id },
		EvolutionName = evoName,
	}
	DB[id] = entry
	table.insert(Ordered, entry)
end

-- ============================ COMMON (14) =================================
def("CHR_001", "Kaito Embren", "Fire", "Fighter", "Common",
	{ 950, 110, 60, 14 },
	{ "Burning Spirit", "+10% ATK while above 70% HP." },
	{ "Flame Jab", 1.2, 6, "Burn", "A quick punch wreathed in flame." },
	{ "Rising Ember", 1.8, 10, nil, "Uppercut that launches the target." },
	{ "Inferno Rush", 4.5, "Burn", "Dash through enemies leaving a trail of fire.", },
	"Blazefist Kaito")
def("CHR_002", "Mira Tidesong", "Water", "Support", "Common",
	{ 1050, 85, 70, 12 },
	{ "Soothing Current", "Allies within 20 studs regen 1% HP/s." },
	{ "Water Whip", 1.1, 6, nil, "Lashing stream of water." },
	{ "Healing Spring", 0, 14, nil, "Heal nearby allies for 150% of ATK." },
	{ "Ocean's Embrace", 3.0, "Freeze", "A tidal wave that heals allies and chills foes." },
	"Tidemother Mira")
def("CHR_003", "Renzo Gale", "Wind", "Assassin", "Common",
	{ 820, 125, 45, 18 },
	{ "Tailwind", "+8% movement speed permanently." },
	{ "Wind Slash", 1.3, 5, nil, "A crescent blade of compressed air." },
	{ "Vacuum Step", 1.0, 9, nil, "Blink behind the target and strike." },
	{ "Tempest Dance", 4.2, nil, "A whirlwind of blade strikes hitting 8 times." },
	"Stormblade Renzo")
def("CHR_004", "Boruta Stonearm", "Earth", "Tank", "Common",
	{ 1400, 80, 110, 9 },
	{ "Granite Skin", "Take 8% reduced damage from all sources." },
	{ "Boulder Toss", 1.2, 7, nil, "Hurl a boulder at range." },
	{ "Earthen Wall", 0, 16, nil, "Raise a wall blocking projectiles for 4s." },
	{ "Tectonic Slam", 3.8, "Stun", "Crack the earth, stunning all nearby enemies." },
	"Mountainheart Boruta")
def("CHR_005", "Sera Dawnlight", "Light", "Mage", "Common",
	{ 880, 115, 55, 13 },
	{ "Radiance", "Skills deal +12% damage to Dark enemies." },
	{ "Light Dart", 1.25, 5, nil, "A piercing ray of light." },
	{ "Blinding Flash", 0.8, 12, "Stun", "Flash that briefly stuns enemies in front." },
	{ "Judgement Beam", 4.4, nil, "A massive column of holy light." },
	"Dawnbringer Sera")
def("CHR_006", "Korin Nightshade", "Dark", "Assassin", "Common",
	{ 830, 128, 42, 17 },
	{ "Shadowmeld", "First hit from stealth deals +25% damage." },
	{ "Dark Fang", 1.3, 6, "Bleed", "A poisoned dagger slash." },
	{ "Smoke Veil", 0, 14, nil, "Vanish for 2s, dropping enemy aggro." },
	{ "Thousand Shadows", 4.3, "Bleed", "Shadow clones strike from every angle." },
	"Voidstalker Korin")
def("CHR_007", "Taro Voltz", "Lightning", "Fighter", "Common",
	{ 920, 118, 55, 16 },
	{ "Static Charge", "Every 5th hit shocks the target." },
	{ "Thunder Hook", 1.25, 6, "Shock", "An electrified hook punch." },
	{ "Volt Sprint", 0.9, 10, nil, "Charge forward as living lightning." },
	{ "Heaven's Bolt", 4.4, "Shock", "Call a colossal lightning strike." },
	"Stormfist Taro")
def("CHR_008", "Yuki Frostpetal", "Ice", "Mage", "Common",
	{ 870, 112, 52, 12 },
	{ "Winter's Grace", "Frozen enemies take +15% damage from you." },
	{ "Ice Lance", 1.3, 6, nil, "A javelin of razor ice." },
	{ "Frost Nova", 1.0, 13, "Freeze", "Burst of cold freezing nearby foes." },
	{ "Eternal Blizzard", 4.2, "Freeze", "A storm of ice engulfs the field." },
	"Permafrost Yuki")
def("CHR_009", "Goro Ironwall", "Earth", "Tank", "Common",
	{ 1450, 75, 118, 8 },
	{ "Bulwark", "Blocking costs 20% less stamina." },
	{ "Shield Bash", 1.1, 7, "Stun", "A stunning shield strike." },
	{ "Taunt Roar", 0, 15, nil, "Force nearby enemies to attack you for 4s." },
	{ "Unbreakable Aegis", 3.0, nil, "Become invulnerable for 4s and reflect 50% damage." },
	"Fortress Goro")
def("CHR_010", "Hana Bloomweaver", "Wind", "Support", "Common",
	{ 1000, 88, 68, 13 },
	{ "Pollen Drift", "Healing skills also cleanse one debuff." },
	{ "Petal Storm", 1.1, 6, nil, "Razor petals slice enemies." },
	{ "Verdant Gift", 0, 14, nil, "Shield an ally for 200% of ATK." },
	{ "Garden of Renewal", 2.8, nil, "A blooming field that heals allies over 6s." },
	"Worldbloom Hana")
def("CHR_011", "Denji Sparkfang", "Lightning", "Assassin", "Common",
	{ 810, 130, 40, 19 },
	{ "Overcharge", "Crits restore 5 energy." },
	{ "Static Slash", 1.3, 5, "Shock", "A crackling blade strike." },
	{ "Flicker Step", 1.0, 9, nil, "Teleport-strike in a zigzag." },
	{ "Lightning Requiem", 4.3, "Shock", "Five flash-steps, five fatal strikes." },
	"Thundergod Denji")
def("CHR_012", "Umi Coralguard", "Water", "Tank", "Common",
	{ 1380, 82, 105, 10 },
	{ "Tideguard", "Gain a 5% max-HP shield every 10s." },
	{ "Coral Smash", 1.15, 7, nil, "Crushing blow with a coral gauntlet." },
	{ "Undertow", 0.9, 12, nil, "Pull enemies toward you." },
	{ "Abyssal Bulwark", 3.2, "Freeze", "Summon crushing deep-sea pressure." },
	"Trenchlord Umi")
def("CHR_013", "Pico Flintlock", "Fire", "Mage", "Common",
	{ 860, 116, 50, 12 },
	{ "Kindling", "Burn effects you apply last 2s longer." },
	{ "Fireball", 1.35, 6, "Burn", "The classic. It explodes." },
	{ "Heat Mirage", 0, 13, nil, "Decoy that taunts then detonates." },
	{ "Meteor Call", 4.5, "Burn", "Drop a meteor on the battlefield." },
	"Pyrelord Pico")
def("CHR_014", "Anzu Palewind", "Ice", "Support", "Common",
	{ 990, 86, 66, 12 },
	{ "Cold Comfort", "Shielded allies gain +10% DEF." },
	{ "Frost Mark", 1.0, 6, "Freeze", "Mark a foe with creeping frost." },
	{ "Glacial Ward", 0, 14, nil, "Encase an ally in protective ice (absorb 250% ATK)." },
	{ "Aurora Veil", 2.7, nil, "A shimmering veil heals and shields the party." },
	"Borealis Anzu")

-- ============================= RARE (12) ==================================
def("CHR_015", "Ryouma Ashblade", "Fire", "Assassin", "Rare",
	{ 900, 145, 50, 18 },
	{ "Cinder Trail", "Dashing leaves a burning trail." },
	{ "Ash Cutter", 1.4, 6, "Burn", "A scorching crosswise slash." },
	{ "Ember Step", 1.1, 9, nil, "Dash-strike that ignites on exit." },
	{ "Crimson Requiem", 4.8, "Burn", "An iaijutsu draw that splits the horizon in flame." },
	"Hellfire Ryouma")
def("CHR_016", "Suiren Mistveil", "Water", "Mage", "Rare",
	{ 950, 140, 58, 13 },
	{ "Mist Body", "10% chance to fully evade attacks." },
	{ "Pressure Jet", 1.45, 6, nil, "A cutting jet of water." },
	{ "Mist Prison", 0.9, 12, "Freeze", "Trap a foe in a sphere of mist." },
	{ "Hundred Year Tide", 4.9, nil, "Summon a serpent of living water." },
	"Leviathan-Touched Suiren")
def("CHR_017", "Hayate Nimbus", "Wind", "Fighter", "Rare",
	{ 1000, 142, 60, 17 },
	{ "Slipstream", "+12% attack speed after a dash for 3s." },
	{ "Gale Combo", 1.4, 6, nil, "A flurry of wind-boosted blows." },
	{ "Cyclone Kick", 1.6, 10, nil, "A spinning kick that pulls enemies in." },
	{ "Skybreaker Barrage", 4.8, nil, "Aerial barrage ending in a meteor kick." },
	"Stormking Hayate")
def("CHR_018", "Tetsu Magnabrow", "Earth", "Tank", "Rare",
	{ 1600, 95, 130, 9 },
	{ "Living Ore", "Reflect 10% of melee damage taken." },
	{ "Quake Stomp", 1.3, 8, "Stun", "Stomp that staggers nearby enemies." },
	{ "Iron Resolve", 0, 16, nil, "Reduce damage taken by 40% for 5s." },
	{ "Colossus Form", 3.5, nil, "Grow giant: +50% DEF, AoE swings for 8s." },
	"Titanheart Tetsu")
def("CHR_019", "Luxia Sunmantle", "Light", "Support", "Rare",
	{ 1100, 105, 75, 13 },
	{ "Guiding Light", "Revived allies return with 50% HP instead of 30%." },
	{ "Solar Lash", 1.3, 6, nil, "A whip of condensed sunlight." },
	{ "Sanctuary", 0, 15, nil, "Zone that heals allies 80% ATK/s for 4s." },
	{ "Second Dawn", 3.0, nil, "Revive fallen allies and heal the party." },
	"Solaris Luxia")
def("CHR_020", "Zagan Murkfang", "Dark", "Fighter", "Rare",
	{ 1050, 148, 62, 15 },
	{ "Bloodthirst", "Heal 8% of damage dealt with skills." },
	{ "Umbral Claw", 1.45, 6, "Bleed", "Rending claws of shadow." },
	{ "Devour", 1.2, 11, nil, "Bite that heals for 100% of damage dealt." },
	{ "Apex Predator", 4.9, "Bleed", "Become a shadow beast and maul the target." },
	"Nightterror Zagan")
def("CHR_021", "Raiko Stormcaller", "Lightning", "Mage", "Rare",
	{ 940, 150, 55, 14 },
	{ "Conduit", "Shock spreads to one extra nearby enemy." },
	{ "Chain Lightning", 1.4, 7, "Shock", "Lightning that arcs between foes." },
	{ "Thundercloud", 1.0, 13, "Shock", "A storm cloud zaps enemies below for 5s." },
	{ "Wrath of the Sky", 5.0, "Shock", "A sustained lightning cataclysm." },
	"Tempest Sage Raiko")
def("CHR_022", "Fuyumi Glasswind", "Ice", "Assassin", "Rare",
	{ 880, 152, 48, 18 },
	{ "Cold Blood", "+20% crit chance against frozen enemies." },
	{ "Shard Fan", 1.4, 6, nil, "Throw a fan of ice shards." },
	{ "Mirror Step", 1.1, 10, "Freeze", "Leave an ice clone that shatters and freezes." },
	{ "Zero Hour", 4.8, "Freeze", "Time seems to stop as everything freezes." },
	"Absolute Zero Fuyumi")
def("CHR_023", "Daichi Rootcaller", "Earth", "Support", "Rare",
	{ 1150, 100, 80, 11 },
	{ "Deep Roots", "Allies near you gain +10% DEF." },
	{ "Thorn Volley", 1.3, 6, "Poison", "A burst of poisoned thorns." },
	{ "Regrowth", 0, 13, nil, "Heal an ally 180% ATK over 4s." },
	{ "World Tree's Gift", 2.9, nil, "Roots shield and mend the entire party." },
	"Elderwood Daichi")
def("CHR_024", "Shion Palestar", "Light", "Fighter", "Rare",
	{ 1080, 144, 64, 15 },
	{ "Starlit Fists", "Every 3rd combo finisher deals +30% damage." },
	{ "Comet Punch", 1.45, 6, nil, "A glowing straight that pierces guard." },
	{ "Meteor Drop", 1.7, 11, "Stun", "Leap and crash down like a falling star." },
	{ "Constellation Combo", 4.9, nil, "Strike the pattern of the warrior constellation." },
	"Starforged Shion")
def("CHR_025", "Nox Vesperine", "Dark", "Mage", "Rare",
	{ 930, 149, 53, 13 },
	{ "Soul Tax", "Defeated enemies grant +5 energy." },
	{ "Void Bolt", 1.45, 6, nil, "A bolt of devouring darkness." },
	{ "Gravity Well", 1.0, 13, nil, "Crushing singularity that pulls enemies in." },
	{ "Event Horizon", 5.0, nil, "Collapse a miniature black hole." },
	"Singularity Nox")
def("CHR_026", "Minato Wavebreaker", "Water", "Fighter", "Rare",
	{ 1060, 143, 63, 15 },
	{ "Riptide", "Combos slow enemy movement by 10%." },
	{ "Tide Fist", 1.4, 6, nil, "A punch carried by a crashing wave." },
	{ "Whirlpool Throw", 1.5, 11, nil, "Grab and spin a foe into others." },
	{ "Tsunami Fist", 4.8, "Freeze", "Strike with the weight of the ocean." },
	"Maelstrom Minato")

-- ============================= EPIC (10) ==================================
def("CHR_027", "Ignia Pyrelance", "Fire", "Mage", "Epic",
	{ 1000, 175, 60, 14 },
	{ "Wildfire", "Burn you apply can stack twice." },
	{ "Lance of Cinders", 1.6, 6, "Burn", "A spear of white-hot flame." },
	{ "Flame Wall", 1.1, 13, "Burn", "A wall of fire that burns those who cross." },
	{ "Phoenix Ascendant", 5.4, "Burn", "A phoenix rises and detonates over the field." },
	"Phoenix Queen Ignia")
def("CHR_028", "Gako Riversage", "Water", "Support", "Epic",
	{ 1250, 130, 85, 12 },
	{ "Flow State", "Skill cooldowns -10% for nearby allies." },
	{ "Soothing Rapids", 0, 12, nil, "Heal the most injured ally for 220% ATK." },
	{ "Crashing Surge", 1.5, 9, nil, "A wave that knocks enemies back." },
	{ "Sage's Deluge", 4.0, "Freeze", "A healing rain for allies, a flood for foes." },
	"River Spirit Gako")
def("CHR_029", "Kazeo Twinblade", "Wind", "Assassin", "Epic",
	{ 950, 185, 52, 20 },
	{ "Twin Tempest", "Skills strike twice at 60% damage each." },
	{ "Cross Gale", 1.7, 6, nil, "Scissoring slashes of wind." },
	{ "Severing Sky", 1.3, 10, "Bleed", "An airborne execution dive." },
	{ "One Thousand Cuts", 5.5, "Bleed", "Too fast to see; only the aftermath remains." },
	"Windgod Kazeo")
def("CHR_030", "Terra Oathstone", "Earth", "Tank", "Epic",
	{ 1850, 110, 150, 9 },
	{ "Oathbound", "While allies are below 30% HP, you take their damage." },
	{ "Seismic Chain", 1.4, 8, "Stun", "Chained stone fists erupt in a line." },
	{ "Sanctified Ground", 0, 15, nil, "Allies in the zone take 25% less damage." },
	{ "Atlas Burden", 4.0, "Stun", "Lift and slam a slab of the world itself." },
	"World-Bearer Terra")
def("CHR_031", "Aurelia Lightveil", "Light", "Mage", "Epic",
	{ 1020, 180, 62, 14 },
	{ "Halo", "Every 10s, gain a barrier worth 8% max HP." },
	{ "Prism Ray", 1.65, 6, nil, "A refracting beam hitting up to 3 targets." },
	{ "Consecrate", 1.2, 12, "Stun", "Holy ground that erupts after 2s." },
	{ "Heaven's Verdict", 5.4, nil, "Spears of light rain from a parted sky." },
	"Archon Aurelia")
def("CHR_032", "Vael Duskrender", "Dark", "Assassin", "Epic",
	{ 940, 188, 50, 19 },
	{ "Executioner", "+35% damage to enemies below 25% HP." },
	{ "Night Razor", 1.7, 6, "Bleed", "A scythe sweep of solid darkness." },
	{ "Death Mark", 1.0, 12, nil, "Mark a foe: your next 3 hits crit." },
	{ "Final Eclipse", 5.5, nil, "The light dies. So does the target." },
	"Reaper Sovereign Vael")
def("CHR_033", "Raijin Voltcrown", "Lightning", "Fighter", "Epic",
	{ 1100, 182, 68, 17 },
	{ "Storm Heart", "Energy gain +20%." },
	{ "Thunder God Fist", 1.7, 6, "Shock", "A fist wrapped in roaring thunder." },
	{ "Lightning Rod", 1.2, 11, "Shock", "Plant a rod that zaps nearby enemies 4s." },
	{ "Million Volt Hour", 5.4, "Shock", "An unbroken minute of lightning in five seconds." },
	"Thunder Emperor Raijin")
def("CHR_034", "Setsuna Snowlotus", "Ice", "Support", "Epic",
	{ 1230, 135, 82, 13 },
	{ "Lotus Bloom", "Cleansing an ally also heals them 80% ATK." },
	{ "Frozen Lotus", 1.4, 7, "Freeze", "A blooming flower of razor ice." },
	{ "Crystal Cocoon", 0, 14, nil, "Encase a dying ally, making them untargetable 3s." },
	{ "Eternal Garden", 3.8, "Freeze", "A frozen garden heals allies and halts enemies." },
	"Winter Empress Setsuna")
def("CHR_035", "Brom Cindergrip", "Fire", "Tank", "Epic",
	{ 1780, 115, 142, 10 },
	{ "Slag Armor", "Attackers are burned on hit." },
	{ "Molten Grapple", 1.5, 8, "Burn", "Drag a foe through molten slag." },
	{ "Furnace Roar", 0, 15, "Burn", "Taunt nearby enemies and ignite them." },
	{ "Volcanic Core", 4.0, "Burn", "Erupt, becoming a walking volcano for 6s." },
	"Magma Lord Brom")
def("CHR_036", "Tsubaki Moonblade", "Light", "Assassin", "Epic",
	{ 960, 186, 54, 19 },
	{ "Moonlit Path", "Dashes cost no stamina at night (or in dungeons)." },
	{ "Crescent Arc", 1.7, 6, nil, "A silver slash in a perfect arc." },
	{ "Lunar Veil", 1.1, 11, nil, "Become moonlight; your next hit cannot miss." },
	{ "Full Moon Severance", 5.5, nil, "One draw. One cut. One moon split in two." },
	"Moonlit Saint Tsubaki")

-- =========================== LEGENDARY (7) ================================
def("CHR_037", "Enma Hellsplitter", "Fire", "Fighter", "Legendary",
	{ 1250, 230, 80, 17 },
	{ "Hellfire Soul", "Each combo finisher adds a Burn stack; Burn heals you 30%." },
	{ "Demon Splitting Fist", 2.0, 6, "Burn", "A punch that splits stone and pride alike." },
	{ "Conflagration Step", 1.5, 10, "Burn", "Dash that detonates on arrival." },
	{ "Gates of the Inferno", 6.0, "Burn", "Open the gates. Let everything burn." },
	"Hell Sovereign Enma")
def("CHR_038", "Nerei Abysswalker", "Water", "Mage", "Legendary",
	{ 1180, 235, 75, 15 },
	{ "Deep Pressure", "Enemies near you are slowed 15%." },
	{ "Abyss Spear", 2.0, 6, nil, "A harpoon of crushing depth." },
	{ "Drowning Sphere", 1.4, 12, "Freeze", "Trap a foe in a sphere of black water." },
	{ "The Ocean Remembers", 6.0, "Freeze", "Summon the abyss itself onto land." },
	"Abyss Empress Nerei")
def("CHR_039", "Shura Galehowl", "Wind", "Assassin", "Legendary",
	{ 1080, 245, 65, 22 },
	{ "Eye of the Storm", "Perfect blocks reset Skill 1's cooldown." },
	{ "Howling Severance", 2.1, 5, "Bleed", "A slash heard before it is seen." },
	{ "Stormveil", 1.3, 10, nil, "Untargetable wind-form dash through enemies." },
	{ "Asura of the Gale", 6.2, "Bleed", "Six arms of wind, six simultaneous executions." },
	"Storm Asura Shura")
def("CHR_040", "Gaiou Earthking", "Earth", "Tank", "Legendary",
	{ 2300, 150, 190, 10 },
	{ "Immovable", "Cannot be knocked back. +20% DEF when below 50% HP." },
	{ "King's Fissure", 1.7, 8, "Stun", "Split the ground toward the foe." },
	{ "Throne of Stone", 0, 16, nil, "Allies behind you take no projectile damage 5s." },
	{ "Continental Verdict", 4.8, "Stun", "Raise a mountain range. Drop it." },
	"Terra Rex Gaiou")
def("CHR_041", "Seraphina Highlight", "Light", "Support", "Legendary",
	{ 1400, 175, 105, 14 },
	{ "Grace Eternal", "Party heals +20%. When an ally would die, they survive at 1 HP (60s CD)." },
	{ "Radiant Chains", 1.6, 7, "Stun", "Bind a foe in chains of light." },
	{ "Benediction", 0, 13, nil, "Heal the party 200% ATK and grant +10% ATK 6s." },
	{ "Choir of the Seventh Heaven", 4.5, nil, "Angelic chorus: full-party heal, shield and cleanse." },
	"Archangel Seraphina")
def("CHR_042", "Mukuro Hollowfang", "Dark", "Fighter", "Legendary",
	{ 1300, 240, 82, 18 },
	{ "Hollow Hunger", "Killing blows grant +5% ATK (stacks to 25%) until death." },
	{ "Soul Rend", 2.0, 6, "Bleed", "Tear at body and soul together." },
	{ "Hollow Howl", 1.4, 11, "Stun", "A scream from the hollow world." },
	{ "Devourer of a Hundred Souls", 6.1, "Bleed", "The mask comes off. Nothing survives." },
	"Hollow God Mukuro")
def("CHR_043", "Kirin Skyrender", "Lightning", "Mage", "Legendary",
	{ 1150, 242, 72, 16 },
	{ "Heaven's Conduit", "Ultimate costs 90 energy instead of 100." },
	{ "Skyrend Bolt", 2.05, 6, "Shock", "Lightning drawn down like a blade." },
	{ "Storm Sigil", 1.4, 12, "Shock", "A sigil that detonates in chain lightning." },
	{ "Divine Beast: Kirin", 6.1, "Shock", "Become the thunder beast of legend." },
	"True Kirin Avatar")

-- ============================= MYTHIC (4) =================================
def("CHR_044", "Okami Bloodmoon", "Dark", "Assassin", "Mythic",
	{ 1350, 300, 85, 23 },
	{ "Bloodmoon Rising", "Each Bleed tick extends your Awakening by 0.2s." },
	{ "Lunar Fang", 2.4, 5, "Bleed", "A bite of the eclipsed moon." },
	{ "Crimson Mist", 1.7, 10, "Bleed", "Become mist; enemies inside bleed." },
	{ "Howl at the Dying Moon", 7.0, "Bleed", "The moon turns red. The pack feasts." },
	"Eclipse Wolfgod Okami")
def("CHR_045", "Amaterasu Dawnflame", "Fire", "Mage", "Mythic",
	{ 1300, 305, 88, 17 },
	{ "Solar Crown", "Burn damage you deal is increased 50%." },
	{ "Sunfire Lance", 2.4, 6, "Burn", "A lance carved from the sun's surface." },
	{ "Corona Field", 1.8, 12, "Burn", "A zone of solar plasma." },
	{ "Sunrise Over the Battlefield", 7.0, "Burn", "Bring the dawn — at point-blank range." },
	"Solar Goddess Amaterasu")
def("CHR_046", "Susanoo Tidalwrath", "Water", "Fighter", "Mythic",
	{ 1500, 295, 110, 18 },
	{ "Stormtide Soul", "Heavy attacks summon a wave that hits twice." },
	{ "Sea-Cleaving Blade", 2.4, 6, nil, "A sword stroke that parts the sea." },
	{ "Maelstrom Guard", 1.6, 11, "Freeze", "A spinning water barrier that counters." },
	{ "Wrath of the Storm God", 7.0, "Freeze", "Sword, sea and storm strike as one." },
	"Stormgod Susanoo")
def("CHR_047", "Izanami Veilkeeper", "Light", "Support", "Mythic",
	{ 1650, 230, 130, 15 },
	{ "Keeper of the Veil", "Allies who die near you leave a spirit that fights 10s." },
	{ "Veil Lash", 2.0, 7, "Stun", "A whip-crack across the boundary of life." },
	{ "Spirit Gate", 0, 14, nil, "Open a gate: party-wide 300% ATK shield." },
	{ "Beyond the Veil", 5.5, nil, "Briefly drag the battlefield into the spirit world." },
	"Boundary Goddess Izanami")

-- ============================= SECRET (2) =================================
def("CHR_048", "Zero, the Forgotten", "Dark", "Fighter", "Secret",
	{ 1600, 360, 110, 20 },
	{ "Erased Existence", "Enemies cannot target you for 1s after you use any skill." },
	{ "Nameless Strike", 2.8, 5, nil, "An attack with no school, no style, no mercy." },
	{ "Memory Break", 2.0, 11, "Stun", "The target forgets how to fight: skills locked 3s." },
	{ "The Technique That Never Was", 8.0, nil, "Unrecorded. Unwitnessed. Unsurvivable." },
	"Zero, Origin Restored")
def("CHR_049", "Alice Paradoxia", "Ice", "Mage", "Secret",
	{ 1550, 365, 105, 19 },
	{ "Paradox Engine", "Your cooldowns sometimes... simply end (10% chance/s)." },
	{ "Looking-Glass Shards", 2.8, 6, "Freeze", "Mirror shards from somewhere else entirely." },
	{ "Tea Time", 0, 12, nil, "Stop time for everyone but the party for 2s." },
	{ "Wonderland Protocol", 8.0, "Freeze", "Rewrite the battlefield's rules. Briefly. Horribly." },
	"Queen of the Mirror Court")

-- ============================= DIVINE (1) =================================
def("CHR_050", "Astraea, Last Star", "Light", "Mage", "Divine",
	{ 2000, 450, 140, 21 },
	{ "Starlight Sovereign", "All allies deal +15% damage. You revive once per battle with 50% HP." },
	{ "Stellar Lance", 3.2, 5, nil, "A spear of starfire from the first night sky." },
	{ "Nova Bloom", 2.4, 10, "Stun", "A controlled supernova." },
	{ "The Last Star Falls", 10.0, "Burn", "She was the last star. Now she is the only one that matters." },
	"Astraea, Dawn of Creation")

return {
	ById = DB,
	Ordered = Ordered,
}
