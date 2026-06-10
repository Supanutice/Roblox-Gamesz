--!strict
-- EnemyModelBuilder.luau
-- Procedural pirate-saga rigs for monsters and bosses (original designs in
-- the spirit of seafaring anime — bandanas, tricorns, cutlasses, marine
-- caps, sea beasts). Replaces the single-block placeholders everywhere a
-- real mesh hasn't been provided yet:
--   * Humanoid pirates: full blocky rig + headwear + eyepatch + cutlass
--   * Quadrupeds (wolves): four-legged beast rig
--   * Serpents (kraken/leviathan-class): segmented sea-monster rig
--   * Bosses: giant pirate captains (tricorn + mantle + greatsword) or
--     giant sea beasts, picked by boss id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AppearanceData = require(Shared.Data.AppearanceData)

local EnemyModelBuilder = {}

-- ------------------------------ HELPERS --------------------------------------

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function weld(root: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

local function newRig(name: string, rootSize: Vector3, hipHeight: number): (Model, Part, Humanoid)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hipHeight
	humanoid.AutoRotate = true
	humanoid.Parent = model
	return model, root, humanoid
end

local function addEyes(model: Model, head: BasePart, root: BasePart, headOffset: CFrame, scale: number, color: Color3)
	for _, side in { -1, 1 } do
		local eye = part(model, "Eye", Vector3.new(0.2, 0.2, 0.1) * scale, color, Enum.Material.Neon)
		weld(root, eye, headOffset * CFrame.new(side * 0.28 * scale, 0.1 * scale, -0.62 * scale))
	end
end

-- ------------------------- HUMANOID PIRATE RIG -------------------------------

export type HumanoidOptions = {
	Scale: number?,
	Hat: ("Bandana" | "Tricorn" | "MarineCap")?,
	Eyepatch: boolean?,
	Cutlass: boolean?,
	Sash: boolean?,
	Horns: boolean?,
	Coat: boolean?,        -- captain's mantle (bosses)
	GiantBlade: boolean?,  -- oversized cutlass (bosses)
	Stone: boolean?,       -- golem/construct: slate material, no gear
}

function EnemyModelBuilder.BuildHumanoid(name: string, palette: AppearanceData.Palette, options: HumanoidOptions): Model
	local s = options.Scale or 1
	local model, root, humanoid = newRig(name, Vector3.new(2, 2, 1) * s, 2 * s)
	humanoid.WalkSpeed = 12

	local material = if options.Stone then Enum.Material.Slate else Enum.Material.SmoothPlastic
	local skin = if options.Stone then palette.Secondary else AppearanceData.SkinTone

	local torso = part(model, "Torso", Vector3.new(2, 2, 1) * s, palette.Primary, material)
	weld(root, torso, CFrame.new())
	local headOffset = CFrame.new(0, 1.6 * s, 0)
	local head = part(model, "Head", Vector3.new(1.2, 1.2, 1.2) * s, skin, material)
	weld(root, head, headOffset)
	for _, side in { -1, 1 } do
		local arm = part(model, "Arm", Vector3.new(0.9, 2, 0.9) * s, palette.Accent, material)
		weld(root, arm, CFrame.new(side * 1.45 * s, 0, 0))
		local leg = part(model, "Leg", Vector3.new(0.9, 2, 0.9) * s, palette.Secondary, material)
		weld(root, leg, CFrame.new(side * 0.5 * s, -2 * s, 0))
	end
	addEyes(model, head, root, headOffset, s, if options.Stone then palette.Accent else Color3.fromRGB(25, 25, 30))

	if options.Stone then
		return model -- golems/constructs wear no pirate gear
	end

	-- Headwear
	if options.Hat == "Bandana" then
		local wrap = part(model, "Bandana", Vector3.new(1.3, 0.45, 1.3) * s, palette.Accent, Enum.Material.Fabric)
		weld(root, wrap, headOffset * CFrame.new(0, 0.45 * s, 0))
		local knot = part(model, "Knot", Vector3.new(0.35, 0.7, 0.2) * s, palette.Accent, Enum.Material.Fabric)
		weld(root, knot, headOffset * CFrame.new(0, 0.2 * s, 0.72 * s) * CFrame.Angles(math.rad(20), 0, 0))
	elseif options.Hat == "Tricorn" then
		local base = part(model, "Tricorn", Vector3.new(2.1, 0.45, 2.1) * s, Color3.fromRGB(45, 35, 30))
		weld(root, base, headOffset * CFrame.new(0, 0.7 * s, 0))
		for _, angle in { 0, 120, 240 } do
			local fold = part(model, "TricornFold", Vector3.new(1.8, 0.6, 0.22) * s, Color3.fromRGB(45, 35, 30))
			weld(root, fold, headOffset * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0.8 * s, -0.95 * s))
		end
	elseif options.Hat == "MarineCap" then
		local cap = part(model, "MarineCap", Vector3.new(1.35, 0.4, 1.35) * s, Color3.fromRGB(240, 240, 240))
		weld(root, cap, headOffset * CFrame.new(0, 0.65 * s, 0))
		local brim = part(model, "CapBrim", Vector3.new(1.1, 0.12, 0.6) * s, Color3.fromRGB(40, 60, 120))
		weld(root, brim, headOffset * CFrame.new(0, 0.48 * s, -0.85 * s))
	end

	if options.Horns then
		for _, side in { -1, 1 } do
			local horn = part(model, "Horn", Vector3.new(0.25, 0.9, 0.25) * s, Color3.fromRGB(235, 225, 205))
			weld(root, horn, headOffset * CFrame.new(side * 0.45 * s, 0.75 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 18)))
		end
	end

	if options.Eyepatch then
		local patch = part(model, "Eyepatch", Vector3.new(0.34, 0.3, 0.08) * s, Color3.fromRGB(15, 15, 18))
		weld(root, patch, headOffset * CFrame.new(-0.28 * s, 0.1 * s, -0.62 * s))
		local strap = part(model, "Strap", Vector3.new(1.26, 0.1, 1.26) * s, Color3.fromRGB(15, 15, 18))
		weld(root, strap, headOffset * CFrame.new(0, 0.18 * s, 0))
	end

	if options.Sash ~= false then
		local sash = part(model, "Sash", Vector3.new(2.06, 0.5, 1.06) * s, palette.Accent, Enum.Material.Fabric)
		weld(root, sash, CFrame.new(0, -0.75 * s, 0))
	end

	if options.Coat then
		local mantle = part(model, "Mantle", Vector3.new(2.7, 0.5, 1.4) * s, palette.Secondary, Enum.Material.Fabric)
		weld(root, mantle, CFrame.new(0, 0.95 * s, 0))
		local cape = part(model, "Cape", Vector3.new(2.4, 3.2, 0.15) * s, palette.Secondary, Enum.Material.Fabric)
		weld(root, cape, CFrame.new(0, -0.4 * s, 0.65 * s))
		local trim = part(model, "Trim", Vector3.new(2.8, 0.18, 1.5) * s, palette.Accent, Enum.Material.Neon)
		weld(root, trim, CFrame.new(0, 0.72 * s, 0))
	end

	if options.Cutlass or options.GiantBlade then
		local bladeScale = if options.GiantBlade then 2.2 else 1
		local armOffset = CFrame.new(1.45 * s, -1.0 * s, 0)
		local handle = part(model, "Handle", Vector3.new(0.22, 0.7, 0.22) * s * bladeScale, Color3.fromRGB(60, 45, 35), Enum.Material.Wood)
		weld(root, handle, armOffset)
		local guard = part(model, "Guard", Vector3.new(0.5, 0.18, 0.5) * s * bladeScale, Color3.fromRGB(180, 150, 60), Enum.Material.Metal)
		weld(root, guard, armOffset * CFrame.new(0, 0.4 * s * bladeScale, 0))
		local blade = part(model, "Blade", Vector3.new(0.1, 1.8, 0.5) * s * bladeScale, Color3.fromRGB(210, 215, 225), Enum.Material.Metal)
		weld(root, blade, armOffset * CFrame.new(0, (0.4 + 1.0 * bladeScale) * s, 0.08 * s) * CFrame.Angles(math.rad(-6), 0, 0))
	end

	return model
end

-- ----------------------------- BEAST RIGS -------------------------------------

function EnemyModelBuilder.BuildQuadruped(name: string, palette: AppearanceData.Palette, scale: number?): Model
	local s = scale or 1
	local model, root, humanoid = newRig(name, Vector3.new(2.2, 1.8, 4.5) * s, 1.5 * s)
	humanoid.WalkSpeed = 16

	local body = part(model, "Body", Vector3.new(2.2, 1.8, 4.5) * s, palette.Secondary, Enum.Material.Fabric)
	weld(root, body, CFrame.new())
	local headOffset = CFrame.new(0, 0.5 * s, -2.9 * s)
	local head = part(model, "Head", Vector3.new(1.4, 1.4, 1.6) * s, palette.Secondary, Enum.Material.Fabric)
	weld(root, head, headOffset)
	local snout = part(model, "Snout", Vector3.new(0.7, 0.6, 0.8) * s, palette.Primary, Enum.Material.Fabric)
	weld(root, snout, headOffset * CFrame.new(0, -0.25 * s, -1.0 * s))
	for _, side in { -1, 1 } do
		local ear = part(model, "Ear", Vector3.new(0.4, 0.6, 0.18) * s, palette.Secondary, Enum.Material.Fabric)
		weld(root, ear, headOffset * CFrame.new(side * 0.45 * s, 0.9 * s, 0))
		for _, front in { -1.6, 1.6 } do
			local leg = part(model, "Leg", Vector3.new(0.6, 1.6, 0.6) * s, palette.Secondary, Enum.Material.Fabric)
			weld(root, leg, CFrame.new(side * 0.75 * s, -1.6 * s, front * s))
		end
	end
	local tail = part(model, "Tail", Vector3.new(0.4, 0.4, 1.6) * s, palette.Primary, Enum.Material.Fabric)
	weld(root, tail, CFrame.new(0, 0.5 * s, 2.9 * s) * CFrame.Angles(math.rad(30), 0, 0))
	addEyes(model, head, root, headOffset, s * 1.2, Color3.fromRGB(255, 80, 60))
	return model
end

function EnemyModelBuilder.BuildSerpent(name: string, palette: AppearanceData.Palette, scale: number?): Model
	local s = scale or 1
	local model, root, humanoid = newRig(name, Vector3.new(2.4, 2.4, 2.4) * s, 1.4 * s)
	humanoid.WalkSpeed = 14

	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head = part(model, "Head", Vector3.new(2.4, 2.2, 2.6) * s, palette.Primary)
	weld(root, head, headOffset)
	local jaw = part(model, "Jaw", Vector3.new(1.8, 0.6, 2.0) * s, palette.Secondary)
	weld(root, jaw, headOffset * CFrame.new(0, -1.1 * s, -0.5 * s))
	for _, side in { -1, 1 } do
		local fin = part(model, "Fin", Vector3.new(0.2, 1.6, 1.2) * s, palette.Accent, Enum.Material.Neon)
		weld(root, fin, headOffset * CFrame.new(side * 1.35 * s, 0.3 * s, 0.2 * s) * CFrame.Angles(0, 0, math.rad(side * 30)))
	end
	-- Trailing body segments arc behind and downward.
	for segment = 1, 4 do
		local size = (2.0 - segment * 0.3)
		local body = part(model, "Segment" .. segment, Vector3.new(size, size, 2.4) * s, palette.Primary)
		weld(root, body, CFrame.new(0, (0.4 - segment * 0.35) * s, (segment * 2.1) * s) * CFrame.Angles(math.rad(-segment * 7), 0, 0))
	end
	local tailFin = part(model, "TailFin", Vector3.new(0.2, 1.8, 1.4) * s, palette.Accent, Enum.Material.Neon)
	weld(root, tailFin, CFrame.new(0, -0.9 * s, 10.2 * s) * CFrame.Angles(math.rad(-25), 0, 0))
	addEyes(model, head, root, headOffset, s * 1.6, Color3.fromRGB(255, 220, 80))
	return model
end

-- ----------------------------- STYLE TABLES -----------------------------------

-- Per-enemy looks. Anything not listed: humanoid pirate with a bandana,
-- eyepatch and cutlass (the default mook of a pirate-saga world).
local ENEMY_STYLES: { [string]: { Kind: string, Options: HumanoidOptions?, Scale: number? } } = {
	EN_W1_WOLF = { Kind = "Quadruped" },
	EN_W1_GOLEM = { Kind = "Humanoid", Options = { Stone = true, Scale = 1.5 } },
	EN_W2_PUPPET = { Kind = "Humanoid", Options = { Stone = true, Hat = "Tricorn" } },
	EN_W3_HOLLOW = { Kind = "Humanoid", Options = { Hat = "Bandana", Eyepatch = true, Scale = 1.1 } },
	EN_W4_MARINE = { Kind = "Humanoid", Options = { Hat = "MarineCap", Cutlass = true } },
	EN_W4_SERPENT = { Kind = "Serpent", Scale = 1.4 },
	EN_W5_IMP = { Kind = "Humanoid", Options = { Horns = true, Cutlass = true, Scale = 0.7 } },
	EN_W5_ARCHDEMON = { Kind = "Humanoid", Options = { Horns = true, Coat = true, Cutlass = true, Scale = 1.6 } },
	EN_W6_CONSTRUCT = { Kind = "Humanoid", Options = { Stone = true, Scale = 1.4 } },
}

local DEFAULT_ENEMY: HumanoidOptions = { Hat = "Bandana", Eyepatch = true, Cutlass = true }

function EnemyModelBuilder.BuildEnemy(enemyDef: { Id: string, Name: string, Element: string }): Model
	local palette = AppearanceData.ElementPalettes[enemyDef.Element] or AppearanceData.ElementPalettes.Water
	local style = ENEMY_STYLES[enemyDef.Id]
	if style and style.Kind == "Quadruped" then
		return EnemyModelBuilder.BuildQuadruped(enemyDef.Name, palette, style.Scale)
	elseif style and style.Kind == "Serpent" then
		return EnemyModelBuilder.BuildSerpent(enemyDef.Name, palette, style.Scale)
	end
	local options = (style and style.Options) or DEFAULT_ENEMY
	return EnemyModelBuilder.BuildHumanoid(enemyDef.Name, palette, options)
end

-- Bosses: sea beasts for kraken-class ids, giant pirate lords otherwise.
local SEA_BEAST_KEYWORDS = { "KRAKEN", "LEVIATHAN", "SEAMOTHER" }

function EnemyModelBuilder.BuildBoss(bossDef: { Id: string, Name: string, Element: string }): Model
	local palette = AppearanceData.ElementPalettes[bossDef.Element] or AppearanceData.ElementPalettes.Water
	for _, keyword in SEA_BEAST_KEYWORDS do
		if string.find(bossDef.Id, keyword) then
			return EnemyModelBuilder.BuildSerpent(bossDef.Name, palette, 3.2)
		end
	end
	return EnemyModelBuilder.BuildHumanoid(bossDef.Name, palette, {
		Scale = 3.2,
		Hat = "Tricorn",
		Eyepatch = true,
		Coat = true,
		GiantBlade = true,
	})
end

return EnemyModelBuilder
