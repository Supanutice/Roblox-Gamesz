--!strict
-- AppearanceData.luau
-- Visual identity for every hero, built procedurally from parts until real
-- meshes land. Element decides the color palette, class decides the default
-- headwear + weapon prop, and per-character overrides give signature looks
-- (the Grand Ocean crew gets the pirate theme — original designs inspired
-- by the genre, never copies of licensed characters).

export type Palette = {
	Primary: Color3,   -- torso
	Secondary: Color3, -- legs
	Accent: Color3,    -- arms / trims / weapon glow
}

local ElementPalettes: { [string]: Palette } = {
	Fire = { Primary = Color3.fromRGB(190, 60, 40), Secondary = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 150, 60) },
	Water = { Primary = Color3.fromRGB(45, 105, 190), Secondary = Color3.fromRGB(30, 50, 80), Accent = Color3.fromRGB(120, 200, 255) },
	Wind = { Primary = Color3.fromRGB(85, 170, 120), Secondary = Color3.fromRGB(45, 80, 60), Accent = Color3.fromRGB(180, 255, 200) },
	Earth = { Primary = Color3.fromRGB(140, 100, 60), Secondary = Color3.fromRGB(80, 60, 40), Accent = Color3.fromRGB(220, 180, 120) },
	Light = { Primary = Color3.fromRGB(235, 225, 190), Secondary = Color3.fromRGB(180, 160, 120), Accent = Color3.fromRGB(255, 240, 150) },
	Dark = { Primary = Color3.fromRGB(60, 50, 80), Secondary = Color3.fromRGB(35, 30, 50), Accent = Color3.fromRGB(170, 110, 255) },
	Lightning = { Primary = Color3.fromRGB(200, 180, 60), Secondary = Color3.fromRGB(70, 65, 40), Accent = Color3.fromRGB(255, 245, 120) },
	Ice = { Primary = Color3.fromRGB(150, 200, 230), Secondary = Color3.fromRGB(70, 100, 130), Accent = Color3.fromRGB(220, 245, 255) },
}

-- Default headwear + weapon prop per class. Builders live in
-- AppearanceService; these are just ids.
local ClassLooks: { [string]: { Hat: string, Prop: string } } = {
	Fighter = { Hat = "Headband", Prop = "FistWraps" },
	Assassin = { Hat = "Bandana", Prop = "Dagger" },
	Tank = { Hat = "Helmet", Prop = "Shield" },
	Mage = { Hat = "MageHat", Prop = "Staff" },
	Support = { Hat = "Halo", Prop = "Tome" },
}

-- Anime hair: default style per class; per-character overrides below.
local ClassHair: { [string]: string } = {
	Fighter = "SpikyWild",
	Assassin = "SpikyShort",
	Tank = "SlickBack",
	Mage = "LongStraight",
	Support = "Ponytail",
}

-- Default anime hair color per element (overridable per character).
local HairColorByElement: { [string]: Color3 } = {
	Fire = Color3.fromRGB(205, 65, 45),
	Water = Color3.fromRGB(45, 80, 170),
	Wind = Color3.fromRGB(80, 170, 100),
	Earth = Color3.fromRGB(125, 85, 50),
	Light = Color3.fromRGB(245, 222, 145),
	Dark = Color3.fromRGB(48, 38, 62),
	Lightning = Color3.fromRGB(250, 212, 90),
	Ice = Color3.fromRGB(195, 222, 240),
}

-- Signature overrides. Theme "Pirate" swaps headwear to seafarer gear and
-- adds a sash; Hair/HairColor give marquee heroes cover-art identities.
local Overrides: { [string]: { Hat: string?, Prop: string?, Theme: string?, Hair: string?, HairColor: Color3? } } = {
	-- The pirate crew (Water / sea-flavored heroes).
	CHR_002 = { Theme = "Pirate", Hat = "StrawHat", Hair = "LongStraight", HairColor = Color3.fromRGB(70, 130, 200) },
	CHR_012 = { Theme = "Pirate", Hat = "Bandana" },
	CHR_016 = { Theme = "Pirate", Hat = "TricornHat", Hair = "LongStraight" },
	CHR_026 = { Theme = "Pirate", Hat = "StrawHat", Hair = "SpikyWild" },
	CHR_038 = { Theme = "Pirate", Hat = "TricornHat", Hair = "LongStraight", HairColor = Color3.fromRGB(30, 45, 90) },
	CHR_046 = { Theme = "Pirate", Hat = "CaptainCoat", Hair = "SpikyWild", HairColor = Color3.fromRGB(40, 60, 120) },

	-- Heroines with signature hairstyles.
	CHR_005 = { Hair = "TwinTails", HairColor = Color3.fromRGB(250, 230, 160) },  -- Sera Dawnlight
	CHR_008 = { Hair = "LongStraight", HairColor = Color3.fromRGB(225, 240, 250) }, -- Yuki Frostpetal
	CHR_010 = { Hair = "Ponytail", HairColor = Color3.fromRGB(120, 190, 120) },   -- Hana Bloomweaver
	CHR_014 = { Hair = "TwinTails" },                                              -- Anzu Palewind
	CHR_019 = { Hair = "LongStraight", HairColor = Color3.fromRGB(255, 235, 170) },-- Luxia Sunmantle
	CHR_022 = { Hair = "Ponytail", HairColor = Color3.fromRGB(205, 228, 245) },   -- Fuyumi Glasswind
	CHR_027 = { Hair = "LongStraight", HairColor = Color3.fromRGB(230, 80, 50) }, -- Ignia Pyrelance
	CHR_031 = { Hair = "TwinTails", HairColor = Color3.fromRGB(255, 240, 190) },  -- Aurelia Lightveil
	CHR_034 = { Hair = "LongStraight", HairColor = Color3.fromRGB(235, 245, 255) },-- Setsuna Snowlotus
	CHR_036 = { Hair = "Ponytail", HairColor = Color3.fromRGB(240, 240, 250) },   -- Tsubaki Moonblade
	CHR_041 = { Hair = "LongStraight", HairColor = Color3.fromRGB(255, 245, 210) },-- Seraphina
	CHR_045 = { Hair = "LongStraight", HairColor = Color3.fromRGB(255, 120, 60) },-- Amaterasu
	CHR_047 = { Hair = "LongStraight", HairColor = Color3.fromRGB(235, 230, 245) },-- Izanami
	CHR_049 = { Hair = "TwinTails", HairColor = Color3.fromRGB(240, 235, 255) },  -- Alice Paradoxia

	-- A few signature non-pirate looks.
	CHR_001 = { Hair = "SpikyWild", HairColor = Color3.fromRGB(220, 70, 40) },    -- Kaito (cover hero)
	CHR_037 = { Hat = "OniHorns", Hair = "SpikyWild", HairColor = Color3.fromRGB(180, 40, 40) }, -- Enma
	CHR_042 = { Hair = "SpikyWild", HairColor = Color3.fromRGB(240, 240, 245) },  -- Mukuro (white-haired)
	CHR_044 = { Hat = "WolfEars", Hair = "SpikyWild", HairColor = Color3.fromRGB(90, 85, 100) }, -- Okami
	CHR_048 = { Hair = "SlickBack", HairColor = Color3.fromRGB(20, 20, 26) },     -- Zero
	CHR_050 = { Hat = "StarCrown", Hair = "LongStraight", HairColor = Color3.fromRGB(255, 250, 225) }, -- Astraea
}

return {
	ElementPalettes = ElementPalettes,
	ClassLooks = ClassLooks,
	ClassHair = ClassHair,
	HairColorByElement = HairColorByElement,
	Overrides = Overrides,
	SkinTone = Color3.fromRGB(255, 215, 180),
}
