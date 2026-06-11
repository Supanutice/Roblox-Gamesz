--!strict
-- AppearanceService.luau
-- Morphs a player's avatar into their equipped hero: element color palette
-- on the body, class/signature headwear, and a weapon prop — all built from
-- parts (no uploaded meshes needed). If a real rig exists under
-- ReplicatedStorage/Characters/<CHR_id>, designers can later swap this for
-- full model replacement; until then every hero is visually distinct.
-- Re-applied automatically on respawn and whenever the team changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AppearanceData = require(Shared.Data.AppearanceData)

local AppearanceService = { Name = "AppearanceService" }

local ACCESSORY_TAG = "AW3_Appearance"

-- ------------------------------ PART HELPERS ---------------------------------

local function prop(parent: Model, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.Name = ACCESSORY_TAG
	part.Parent = parent
	return part
end

local function weldTo(part: Part, anchor: BasePart, offset: CFrame)
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

local function limb(character: Model, r15Name: string, r6Name: string): BasePart?
	return (character:FindFirstChild(r15Name) or character:FindFirstChild(r6Name)) :: BasePart?
end

local function wedgeProp(parent: Model, size: Vector3, color: Color3): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Size = size
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.Massless = true
	wedge.Name = ACCESSORY_TAG
	wedge.Parent = parent
	return wedge
end

local function weldWedge(wedge: WedgePart, anchor: BasePart, offset: CFrame)
	wedge.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = wedge
	weld.Parent = wedge
end

-- ------------------------------ ANIME HAIR -----------------------------------

local HAIRS: { [string]: (character: Model, head: BasePart, color: Color3) -> () } = {}

local function hairCap(character: Model, head: BasePart, color: Color3)
	local cap = prop(character, Vector3.new(1.34, 0.62, 1.34), color)
	weldTo(cap, head, CFrame.new(0, 0.42, 0))
	-- Front bangs.
	local bangs = prop(character, Vector3.new(1.3, 0.42, 0.26), color)
	weldTo(bangs, head, CFrame.new(0, 0.34, -0.58) * CFrame.Angles(math.rad(-12), 0, 0))
end

HAIRS.SpikyShort = function(character, head, color)
	hairCap(character, head, color)
	for index = 1, 5 do
		local angle = (index - 3) * 0.5
		local spike = wedgeProp(character, Vector3.new(0.34, 0.72, 0.5), color)
		weldWedge(spike, head,
			CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.82, -0.28) * CFrame.Angles(math.rad(-25), 0, 0))
	end
end

HAIRS.SpikyWild = function(character, head, color)
	hairCap(character, head, color)
	-- Shonen-protagonist spikes: a ring plus a tall center crest.
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		local spike = wedgeProp(character, Vector3.new(0.4, 1.05, 0.62), color)
		weldWedge(spike, head,
			CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.92, -0.34) * CFrame.Angles(math.rad(-32), 0, 0))
	end
	local crest = wedgeProp(character, Vector3.new(0.46, 1.25, 0.72), color)
	weldWedge(crest, head, CFrame.new(0, 1.15, 0.05) * CFrame.Angles(math.rad(-14), 0, 0))
end

HAIRS.LongStraight = function(character, head, color)
	hairCap(character, head, color)
	local back = prop(character, Vector3.new(1.3, 2.3, 0.32), color)
	weldTo(back, head, CFrame.new(0, -0.55, 0.62) * CFrame.Angles(math.rad(4), 0, 0))
	for _, side in { -1, 1 } do
		local panel = prop(character, Vector3.new(0.3, 1.7, 0.6), color)
		weldTo(panel, head, CFrame.new(side * 0.68, -0.3, 0.1))
	end
end

HAIRS.Ponytail = function(character, head, color)
	hairCap(character, head, color)
	local band = prop(character, Vector3.new(0.34, 0.22, 0.34), Color3.fromRGB(60, 50, 55))
	weldTo(band, head, CFrame.new(0, 0.62, 0.62))
	for segment = 1, 3 do
		local size = 0.52 - segment * 0.1
		local tail = prop(character, Vector3.new(size, 0.85, size), color)
		weldTo(tail, head,
			CFrame.new(0, 0.62 - segment * 0.62, 0.72 + segment * 0.16) * CFrame.Angles(math.rad(12), 0, 0))
	end
end

HAIRS.TwinTails = function(character, head, color)
	hairCap(character, head, color)
	for _, side in { -1, 1 } do
		for segment = 1, 3 do
			local size = 0.42 - segment * 0.08
			local tail = prop(character, Vector3.new(size, 0.8, size), color)
			weldTo(tail, head,
				CFrame.new(side * 0.74, 0.45 - segment * 0.58, 0.18)
					* CFrame.Angles(0, 0, math.rad(side * 8)))
		end
	end
end

HAIRS.SlickBack = function(character, head, color)
	hairCap(character, head, color)
	local back = wedgeProp(character, Vector3.new(1.3, 0.62, 1.0), color)
	weldWedge(back, head, CFrame.new(0, 0.74, 0.24) * CFrame.Angles(math.rad(180), math.rad(180), 0))
end

-- ------------------------------ ANIME FACE -----------------------------------

local function buildFace(character: Model, head: BasePart, palette: AppearanceData.Palette)
	-- Replace the default Roblox face decal with a drawn anime face.
	local oldFace = head:FindFirstChild("face")
	if oldFace then
		oldFace:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = ACCESSORY_TAG
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(120, 120)
	gui.LightInfluence = 1
	gui.Parent = head

	for _, side in { -1, 1 } do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(0.5 + side * 0.19, 0.5)
		eye.Size = UDim2.fromScale(0.17, 0.3)
		eye.BackgroundColor3 = Color3.fromRGB(35, 32, 42)
		eye.BorderSizePixel = 0
		eye.Parent = gui
		local eyeCorner = Instance.new("UICorner")
		eyeCorner.CornerRadius = UDim.new(0.5, 0)
		eyeCorner.Parent = eye

		local iris = Instance.new("Frame")
		iris.AnchorPoint = Vector2.new(0.5, 0.5)
		iris.Position = UDim2.fromScale(0.5, 0.42)
		iris.Size = UDim2.fromScale(0.62, 0.5)
		iris.BackgroundColor3 = palette.Accent
		iris.BorderSizePixel = 0
		iris.Parent = eye
		local irisCorner = Instance.new("UICorner")
		irisCorner.CornerRadius = UDim.new(0.5, 0)
		irisCorner.Parent = iris

		local sparkle = Instance.new("Frame")
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = UDim2.fromScale(0.32, 0.26)
		sparkle.Size = UDim2.fromScale(0.3, 0.24)
		sparkle.BackgroundColor3 = Color3.new(1, 1, 1)
		sparkle.BorderSizePixel = 0
		sparkle.Parent = eye
		local sparkleCorner = Instance.new("UICorner")
		sparkleCorner.CornerRadius = UDim.new(0.5, 0)
		sparkleCorner.Parent = sparkle

		local brow = Instance.new("Frame")
		brow.AnchorPoint = Vector2.new(0.5, 0.5)
		brow.Position = UDim2.fromScale(0.5 + side * 0.19, 0.27)
		brow.Size = UDim2.fromScale(0.2, 0.035)
		brow.BackgroundColor3 = Color3.fromRGB(45, 40, 50)
		brow.BorderSizePixel = 0
		brow.Rotation = side * -8
		brow.Parent = gui
	end

	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.78)
	mouth.Size = UDim2.fromScale(0.12, 0.03)
	mouth.BackgroundColor3 = Color3.fromRGB(120, 70, 70)
	mouth.BorderSizePixel = 0
	mouth.Parent = gui
end

-- ------------------------------ RARITY AURA -----------------------------------

local GameConfig = require(Shared.Configs.GameConfig)
local RARITY_TIER: { [string]: number } = {}
for tier, rarity in GameConfig.Rarities do
	RARITY_TIER[rarity.Name] = tier
end

local function buildAura(character: Model, palette: AppearanceData.Palette, rarity: string)
	local tier = RARITY_TIER[rarity] or 1
	if tier < 3 then
		return -- auras start at Epic
	end
	local torso = limb(character, "UpperTorso", "Torso")
	if not torso then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = ACCESSORY_TAG
	emitter.Color = ColorSequence.new(palette.Accent)
	emitter.Rate = (tier - 2) * 4
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(0.6, 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.28)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.8
	emitter.Parent = torso

	if tier >= 5 then -- Mythic+ glow
		local light = Instance.new("PointLight")
		light.Name = ACCESSORY_TAG
		light.Color = palette.Accent
		light.Range = 11
		light.Brightness = 1.1
		light.Parent = torso
	end
end

-- ------------------------------ HAT BUILDERS ---------------------------------

local HATS: { [string]: (character: Model, head: BasePart, palette: AppearanceData.Palette) -> () } = {}

HATS.StrawHat = function(character, head, palette)
	-- Original wide-brim straw hat (genre staple, our own design).
	local straw = Color3.fromRGB(235, 200, 120)
	local brim = prop(character, Vector3.new(0.3, 3.4, 3.4), straw)
	brim.Shape = Enum.PartType.Cylinder
	weldTo(brim, head, CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local crown = prop(character, Vector3.new(0.65, 1.7, 1.7), straw)
	crown.Shape = Enum.PartType.Cylinder
	weldTo(crown, head, CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local band = prop(character, Vector3.new(0.3, 1.75, 1.75), palette.Accent)
	band.Shape = Enum.PartType.Cylinder
	weldTo(band, head, CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)))
end

HATS.TricornHat = function(character, head, palette)
	local base = prop(character, Vector3.new(2.4, 0.5, 2.4), Color3.fromRGB(45, 35, 30))
	weldTo(base, head, CFrame.new(0, 0.75, 0))
	for _, angle in { 0, 120, 240 } do
		local fold = prop(character, Vector3.new(2.1, 0.7, 0.25), Color3.fromRGB(45, 35, 30))
		weldTo(fold, head, CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0.85, -1.05))
	end
	local trim = prop(character, Vector3.new(0.2, 1.3, 1.3), palette.Accent, Enum.Material.Neon)
	trim.Shape = Enum.PartType.Cylinder
	weldTo(trim, head, CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)))
end

HATS.Bandana = function(character, head, palette)
	local wrap = prop(character, Vector3.new(1.35, 0.5, 1.35), palette.Primary)
	weldTo(wrap, head, CFrame.new(0, 0.45, 0))
	local knot = prop(character, Vector3.new(0.4, 0.8, 0.25), palette.Primary)
	weldTo(knot, head, CFrame.new(0, 0.25, 0.75) * CFrame.Angles(math.rad(25), 0, 0))
end

HATS.Headband = function(character, head, palette)
	local band = prop(character, Vector3.new(1.3, 0.28, 1.3), palette.Accent, Enum.Material.Fabric)
	weldTo(band, head, CFrame.new(0, 0.32, 0))
	local tail = prop(character, Vector3.new(0.25, 1.1, 0.1), palette.Accent, Enum.Material.Fabric)
	weldTo(tail, head, CFrame.new(0.35, -0.1, 0.7) * CFrame.Angles(math.rad(15), 0, math.rad(10)))
end

HATS.Helmet = function(character, head, palette)
	local dome = prop(character, Vector3.new(1.5, 0.8, 1.5), palette.Secondary, Enum.Material.Metal)
	weldTo(dome, head, CFrame.new(0, 0.55, 0))
	local crest = prop(character, Vector3.new(0.2, 0.5, 1.6), palette.Accent, Enum.Material.Neon)
	weldTo(crest, head, CFrame.new(0, 1.0, 0))
end

HATS.MageHat = function(character, head, palette)
	local brim = prop(character, Vector3.new(0.25, 2.6, 2.6), palette.Secondary, Enum.Material.Fabric)
	brim.Shape = Enum.PartType.Cylinder
	weldTo(brim, head, CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	-- Stacked, shrinking cylinders fake a cone.
	for tier = 1, 3 do
		local size = 1.5 - tier * 0.4
		local cone = prop(character, Vector3.new(0.55, size, size), palette.Secondary, Enum.Material.Fabric)
		cone.Shape = Enum.PartType.Cylinder
		weldTo(cone, head, CFrame.new(0, 0.6 + tier * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)))
	end
end

HATS.Halo = function(character, head, palette)
	local ring = prop(character, Vector3.new(0.15, 1.6, 1.6), palette.Accent, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.25
	weldTo(ring, head, CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
end

HATS.OniHorns = function(character, head, palette)
	for _, side in { -1, 1 } do
		local horn = prop(character, Vector3.new(0.3, 1.1, 0.3), Color3.fromRGB(240, 230, 215))
		weldTo(horn, head, CFrame.new(side * 0.5, 0.85, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)))
	end
end

HATS.WolfEars = function(character, head, palette)
	for _, side in { -1, 1 } do
		local ear = prop(character, Vector3.new(0.45, 0.7, 0.2), palette.Secondary, Enum.Material.Fabric)
		weldTo(ear, head, CFrame.new(side * 0.45, 0.85, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)))
	end
end

HATS.StarCrown = function(character, head, palette)
	local ring = prop(character, Vector3.new(0.25, 1.5, 1.5), Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	weldTo(ring, head, CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)))
	for _, angle in { 0, 90, 180, 270 } do
		local spike = prop(character, Vector3.new(0.18, 0.6, 0.18), Color3.fromRGB(255, 240, 160), Enum.Material.Neon)
		weldTo(spike, head, CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 1.05, -0.7))
	end
end

HATS.CaptainCoat = function(character, head, palette)
	-- Captain's shoulder mantle + tricorn.
	HATS.TricornHat(character, head, palette)
	local torso = limb(character, "UpperTorso", "Torso")
	if torso then
		local mantle = prop(character, Vector3.new(2.6, 0.45, 1.4), palette.Secondary, Enum.Material.Fabric)
		weldTo(mantle, torso, CFrame.new(0, 0.95, 0))
		local trim = prop(character, Vector3.new(2.7, 0.15, 1.5), palette.Accent, Enum.Material.Neon)
		weldTo(trim, torso, CFrame.new(0, 0.72, 0))
	end
end

-- ------------------------------ PROP BUILDERS --------------------------------

local PROPS: { [string]: (character: Model, palette: AppearanceData.Palette) -> () } = {}

PROPS.Dagger = function(character, palette)
	local arm = limb(character, "RightHand", "Right Arm")
	if not arm then
		return
	end
	local handle = prop(character, Vector3.new(0.25, 0.7, 0.25), Color3.fromRGB(60, 45, 35))
	weldTo(handle, arm, CFrame.new(0, -1.0, 0))
	local blade = prop(character, Vector3.new(0.12, 1.2, 0.45), palette.Accent, Enum.Material.Metal)
	weldTo(blade, arm, CFrame.new(0, -1.9, 0))
end

PROPS.Shield = function(character, palette)
	local arm = limb(character, "LeftLowerArm", "Left Arm")
	if not arm then
		return
	end
	local plate = prop(character, Vector3.new(0.3, 2.2, 1.6), palette.Secondary, Enum.Material.Metal)
	weldTo(plate, arm, CFrame.new(-0.6, -0.2, 0))
	local emblem = prop(character, Vector3.new(0.15, 0.7, 0.7), palette.Accent, Enum.Material.Neon)
	weldTo(emblem, arm, CFrame.new(-0.78, -0.2, 0))
end

PROPS.Staff = function(character, palette)
	local arm = limb(character, "RightHand", "Right Arm")
	if not arm then
		return
	end
	local shaft = prop(character, Vector3.new(0.25, 5.2, 0.25), Color3.fromRGB(85, 60, 40), Enum.Material.Wood)
	weldTo(shaft, arm, CFrame.new(0, -1.0, 0))
	local orb = prop(character, Vector3.new(0.8, 0.8, 0.8), palette.Accent, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	weldTo(orb, arm, CFrame.new(0, 1.9, 0))
end

PROPS.Tome = function(character, palette)
	local arm = limb(character, "LeftHand", "Left Arm")
	if not arm then
		return
	end
	local book = prop(character, Vector3.new(0.9, 0.25, 1.1), palette.Secondary, Enum.Material.Fabric)
	weldTo(book, arm, CFrame.new(0, -1.05, -0.3))
	local rune = prop(character, Vector3.new(0.4, 0.27, 0.5), palette.Accent, Enum.Material.Neon)
	weldTo(rune, arm, CFrame.new(0, -1.05, -0.3))
end

PROPS.FistWraps = function(character, palette)
	for _, name in { { "RightHand", "Right Arm" }, { "LeftHand", "Left Arm" } } do
		local arm = limb(character, name[1], name[2])
		if arm then
			local wrap = prop(character, Vector3.new(1.1, 0.5, 1.1), palette.Accent, Enum.Material.Fabric)
			weldTo(wrap, arm, CFrame.new(0, -0.7, 0))
		end
	end
end

-- ------------------------------ MORPH CORE ------------------------------------

local function clearAppearance(character: Model)
	for _, child in character:GetDescendants() do
		if child.Name == ACCESSORY_TAG
			or child:IsA("Accessory") or child:IsA("Shirt")
			or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
end

local BODY_GROUPS = {
	Primary = { "Torso", "UpperTorso", "LowerTorso" },
	Secondary = { "Left Leg", "Right Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
	Accent = { "Left Arm", "Right Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" },
}

function AppearanceService:ApplyAppearance(player: Player, character: Model, characterDef: any?)
	if not character.Parent then
		return
	end
	clearAppearance(character)
	if not characterDef then
		return -- no hero equipped: leave the bare avatar
	end

	local palette = AppearanceData.ElementPalettes[characterDef.Element]
		or AppearanceData.ElementPalettes.Fire
	local look = AppearanceData.ClassLooks[characterDef.Class] or AppearanceData.ClassLooks.Fighter
	local override = AppearanceData.Overrides[characterDef.Id]
	local hatId = (override and override.Hat) or look.Hat
	local propId = (override and override.Prop) or look.Prop

	-- Body palette.
	for group, names in BODY_GROUPS do
		for _, name in names do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = (palette :: any)[group]
				part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.Color = AppearanceData.SkinTone
		-- Anime face: big eyes with element-colored irises + highlights.
		buildFace(character, head, palette)
		-- Anime hair: signature style/color, or class/element defaults.
		-- (Skipped under full helmets to avoid clipping.)
		if hatId ~= "Helmet" then
			local hairId = (override and override.Hair) or AppearanceData.ClassHair[characterDef.Class] or "SpikyShort"
			local hairColor = (override and override.HairColor)
				or AppearanceData.HairColorByElement[characterDef.Element]
				or Color3.fromRGB(60, 50, 55)
			local hairBuilder = HAIRS[hairId]
			if hairBuilder then
				hairBuilder(character, head, hairColor)
			end
		end
	end

	-- Element aura particles + glow for high-rarity heroes.
	buildAura(character, palette, characterDef.Rarity)

	-- Pirate theme extra: waist sash for the Grand Ocean crew.
	if override and override.Theme == "Pirate" then
		local torso = limb(character, "LowerTorso", "Torso")
		if torso then
			local sash = prop(character, Vector3.new(2.05, 0.5, 1.05), palette.Accent, Enum.Material.Fabric)
			weldTo(sash, torso, CFrame.new(0, if torso.Name == "Torso" then -0.8 else 0, 0))
		end
	end

	-- Headwear + weapon prop.
	if head and head:IsA("BasePart") then
		local hatBuilder = HATS[hatId]
		if hatBuilder then
			hatBuilder(character, head, palette)
		end
	end
	local propBuilder = PROPS[propId]
	if propBuilder then
		propBuilder(character, palette)
	end
end

function AppearanceService:Init() end

return AppearanceService
