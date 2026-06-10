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

-- Signature overrides. Theme "Pirate" swaps headwear to seafarer gear and
-- adds a sash; used across the Grand Ocean roster.
local Overrides: { [string]: { Hat: string?, Prop: string?, Theme: string? } } = {
	-- The pirate crew (Water / sea-flavored heroes).
	CHR_002 = { Theme = "Pirate", Hat = "StrawHat" },   -- Mira Tidesong
	CHR_012 = { Theme = "Pirate", Hat = "Bandana" },    -- Umi Coralguard
	CHR_016 = { Theme = "Pirate", Hat = "TricornHat" }, -- Suiren Mistveil
	CHR_026 = { Theme = "Pirate", Hat = "StrawHat" },   -- Minato Wavebreaker
	CHR_038 = { Theme = "Pirate", Hat = "TricornHat" }, -- Nerei Abysswalker
	CHR_046 = { Theme = "Pirate", Hat = "CaptainCoat" },-- Susanoo Tidalwrath

	-- A few signature non-pirate looks.
	CHR_037 = { Hat = "OniHorns" },                     -- Enma Hellsplitter
	CHR_044 = { Hat = "WolfEars" },                     -- Okami Bloodmoon
	CHR_050 = { Hat = "StarCrown" },                    -- Astraea, Last Star
}

return {
	ElementPalettes = ElementPalettes,
	ClassLooks = ClassLooks,
	Overrides = Overrides,
	SkinTone = Color3.fromRGB(255, 215, 180),
}
