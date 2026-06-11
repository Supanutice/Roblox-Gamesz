--!strict
-- WorldBuilderService.luau
-- Procedurally builds PLACEHOLDER geometry for all six worlds so the game is
-- fully walkable/playable before real art lands. v2 "map upgrade":
--   * themed islands with beach rims and raised hills
--   * village hubs: houses behind each NPC, central fountain, lamp posts on
--     the safe-zone ring, market crates
--   * per-world decoration sets (palms, bamboo, spirit lanterns, docks &
--     ship mast, obsidian spikes & lava pools, sky crystals & clouds)
--   * a global ocean — falling in teleports you back to the nearest hub
--   * world lighting/atmosphere
-- All scatter uses per-world seeded Random so every server builds the
-- identical map. Real art under Workspace/Worlds/<Id> takes precedence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Configs.WorldConfig)
local Remotes = require(Shared.Net.Remotes)

local WorldBuilderService = { Name = "WorldBuilderService" }

local services: { [string]: any }

local OCEAN_LEVEL = -8

-- Visual theme per world (placeholder palette).
local THEMES: { [string]: { Ground: Color3, Accent: Color3, Material: Enum.Material } } = {
	W1_BEGINNER_ISLAND = { Ground = Color3.fromRGB(120, 180, 90), Accent = Color3.fromRGB(240, 220, 160), Material = Enum.Material.Grass },
	W2_SHINOBI_NATION = { Ground = Color3.fromRGB(70, 110, 70), Accent = Color3.fromRGB(180, 60, 60), Material = Enum.Material.Grass },
	W3_SOUL_EMPIRE = { Ground = Color3.fromRGB(150, 150, 165), Accent = Color3.fromRGB(120, 200, 220), Material = Enum.Material.Slate },
	W4_GRAND_OCEAN = { Ground = Color3.fromRGB(220, 205, 160), Accent = Color3.fromRGB(60, 130, 200), Material = Enum.Material.Sand },
	W5_DEMON_REALM = { Ground = Color3.fromRGB(60, 40, 45), Accent = Color3.fromRGB(230, 90, 40), Material = Enum.Material.Basalt },
	W6_CELESTIAL_KINGDOM = { Ground = Color3.fromRGB(235, 235, 245), Accent = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Marble },
}

-- ------------------------------ PART HELPERS ----------------------------------

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function makeWedge(props: { [string]: any }): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	for key, value in props do
		(wedge :: any)[key] = value
	end
	return wedge
end

local function addLabel(parent: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(14, 3)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.MaxDistance = 220
	billboard.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = billboard
end

-- One-shot-per-player Touched guard.
local function onPlayerTouch(part: BasePart, cooldown: number, handler: (player: Player) -> ())
	local lastTouch: { [Player]: number } = {}
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastTouch[player] or 0) < cooldown then
			return
		end
		lastTouch[player] = now
		handler(player)
	end)
end

-- --------------------------- DECORATION BUILDERS ------------------------------

local function palmTree(container: Folder, position: Vector3, rng: Random)
	local height = rng:NextNumber(9, 14)
	local trunk = makePart({
		Size = Vector3.new(1, height, 1), Position = position + Vector3.new(0, height / 2, 0),
		Color = Color3.fromRGB(125, 90, 60), Material = Enum.Material.Wood, Parent = container,
	})
	trunk.CFrame *= CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8)))
	for index = 1, 5 do
		local angle = index / 5 * math.pi * 2
		makePart({
			Size = Vector3.new(5, 0.3, 1.6),
			CFrame = CFrame.new(position + Vector3.new(0, height, 0))
				* CFrame.Angles(0, angle, math.rad(-18)) * CFrame.new(2.4, 0, 0),
			Color = Color3.fromRGB(80, 160, 70), Material = Enum.Material.Grass, Parent = container,
		})
	end
end

local function bambooStalk(container: Folder, position: Vector3, rng: Random)
	local height = rng:NextNumber(11, 17)
	makePart({
		Size = Vector3.new(0.7, height, 0.7), Position = position + Vector3.new(0, height / 2, 0),
		Color = Color3.fromRGB(130, 190, 90), Material = Enum.Material.SmoothPlastic, Parent = container,
	})
end

local function spiritLantern(container: Folder, position: Vector3, _rng: Random)
	makePart({
		Size = Vector3.new(0.6, 5, 0.6), Position = position + Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(90, 90, 105), Material = Enum.Material.Slate, Parent = container,
	})
	makePart({
		Size = Vector3.new(1.4, 1.4, 1.4), Position = position + Vector3.new(0, 5.7, 0),
		Color = Color3.fromRGB(140, 220, 240), Material = Enum.Material.Neon,
		Transparency = 0.2, Parent = container,
	})
end

local function obsidianSpike(container: Folder, position: Vector3, rng: Random)
	local height = rng:NextNumber(6, 16)
	local spike = makePart({
		Size = Vector3.new(2.4, height, 2.4), Position = position + Vector3.new(0, height / 2, 0),
		Color = Color3.fromRGB(28, 22, 30), Material = Enum.Material.Basalt, Parent = container,
	})
	spike.CFrame *= CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-14, 14)))
end

local function lavaPool(container: Folder, position: Vector3, rng: Random)
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, rng:NextNumber(8, 16), rng:NextNumber(8, 16)),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon,
		CanCollide = false, Parent = container,
	})
end

local function skyCrystal(container: Folder, position: Vector3, rng: Random)
	makePart({
		Size = Vector3.new(2, rng:NextNumber(4, 8), 2),
		CFrame = CFrame.new(position + Vector3.new(0, rng:NextNumber(6, 14), 0))
			* CFrame.Angles(math.rad(rng:NextNumber(-30, 30)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-30, 30))),
		Color = Color3.fromRGB(180, 220, 255), Material = Enum.Material.Neon,
		Transparency = 0.25, CanCollide = false, Parent = container,
	})
end

local function rock(container: Folder, position: Vector3, rng: Random, color: Color3)
	local size = rng:NextNumber(2, 5)
	local boulder = makePart({
		Size = Vector3.new(size, size * 0.8, size), Position = position + Vector3.new(0, size * 0.3, 0),
		Color = color, Material = Enum.Material.Slate, Parent = container,
	})
	boulder.CFrame *= CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-10, 10)))
end

local function lampPost(container: Folder, position: Vector3, accent: Color3)
	makePart({
		Size = Vector3.new(0.5, 7, 0.5), Position = position + Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(50, 45, 55), Material = Enum.Material.Metal, Parent = container,
	})
	local lamp = makePart({
		Size = Vector3.new(1.1, 1.1, 1.1), Position = position + Vector3.new(0, 7.4, 0),
		Color = accent, Material = Enum.Material.Neon, Parent = container,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.4
	light.Color = accent
	light.Parent = lamp
end

local function house(container: Folder, position: Vector3, facing: Vector3, theme, rng: Random)
	local base = CFrame.lookAt(position, position + facing)
	local wallColor = theme.Ground:Lerp(Color3.fromRGB(200, 180, 150), 0.55)
	local body = makePart({
		Size = Vector3.new(11, 8, 9), CFrame = base * CFrame.new(0, 4, 0),
		Color = wallColor, Material = Enum.Material.WoodPlanks, Parent = container,
	})
	makeWedge({
		Size = Vector3.new(11, 4, 4.5), CFrame = base * CFrame.new(0, 10, -2.25),
		Color = theme.Accent, Material = Enum.Material.Slate, Parent = container,
	})
	makeWedge({
		Size = Vector3.new(11, 4, 4.5), CFrame = base * CFrame.new(0, 10, 2.25) * CFrame.Angles(0, math.rad(180), 0),
		Color = theme.Accent, Material = Enum.Material.Slate, Parent = container,
	})
	makePart({ -- door
		Size = Vector3.new(2.4, 4.5, 0.4), CFrame = base * CFrame.new(rng:NextNumber(-2, 2), 2.25, -4.55),
		Color = Color3.fromRGB(80, 55, 35), Material = Enum.Material.Wood, Parent = container,
	})
	makePart({ -- window
		Size = Vector3.new(2, 2, 0.3), CFrame = base * CFrame.new(3.2, 4.5, -4.55),
		Color = Color3.fromRGB(255, 235, 160), Material = Enum.Material.Neon, Transparency = 0.3, Parent = container,
	})
	return body
end

local function fountain(container: Folder, position: Vector3, accent: Color3)
	makePart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(160, 160, 170), Material = Enum.Material.Cobblestone, Parent = container,
	})
	makePart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 10, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 160, 230), Material = Enum.Material.Glass, Transparency = 0.3, Parent = container,
	})
	makePart({
		Size = Vector3.new(1.4, 5, 1.4), Position = position + Vector3.new(0, 4.5, 0),
		Color = Color3.fromRGB(160, 160, 170), Material = Enum.Material.Cobblestone, Parent = container,
	})
	makePart({
		Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 7.5, 0),
		Color = accent, Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, Parent = container,
	})
end

local function crates(container: Folder, position: Vector3, rng: Random)
	for i = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(2, 3.2)
		makePart({
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-3, 3), size / 2, rng:NextNumber(-3, 3)))
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
			Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks, Parent = container,
		})
	end
end

-- Pirate dock with a ship mast — W4's signature piece.
local function dock(container: Folder, hub: Vector3, theme)
	local start = hub + Vector3.new(0, 0, -200) -- island edge
	for plank = 0, 7 do
		makePart({
			Size = Vector3.new(12, 1, 10),
			Position = start + Vector3.new(0, 0.5, -plank * 10),
			Color = Color3.fromRGB(140, 105, 70), Material = Enum.Material.WoodPlanks, Parent = container,
		})
		for _, side in { -1, 1 } do
			makePart({
				Size = Vector3.new(1, 8, 1),
				Position = start + Vector3.new(side * 5.5, -2, -plank * 10),
				Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.Wood, Parent = container,
			})
		end
	end
	-- Mast + sail at the dock's end.
	local mastBase = start + Vector3.new(0, 0, -78)
	makePart({
		Size = Vector3.new(1.4, 26, 1.4), Position = mastBase + Vector3.new(0, 14, 0),
		Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.Wood, Parent = container,
	})
	makePart({
		Size = Vector3.new(14, 10, 0.3), Position = mastBase + Vector3.new(0, 18, 1),
		Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.Fabric, Parent = container,
	})
	makePart({ -- flag
		Size = Vector3.new(4, 2.4, 0.2), Position = mastBase + Vector3.new(2.4, 26, 0),
		Color = theme.Accent, Material = Enum.Material.Fabric, Parent = container,
	})
end

-- Red gate arch — W2's signature piece (generic arch, original design).
local function archGate(container: Folder, position: Vector3, facing: Vector3)
	local base = CFrame.lookAt(position, position + facing)
	local red = Color3.fromRGB(190, 60, 55)
	for _, side in { -1, 1 } do
		makePart({
			Size = Vector3.new(1.6, 14, 1.6), CFrame = base * CFrame.new(side * 6, 7, 0),
			Color = red, Material = Enum.Material.SmoothPlastic, Parent = container,
		})
	end
	makePart({
		Size = Vector3.new(17, 1.4, 2.2), CFrame = base * CFrame.new(0, 14.2, 0),
		Color = red, Material = Enum.Material.SmoothPlastic, Parent = container,
	})
	makePart({
		Size = Vector3.new(13, 1.1, 1.8), CFrame = base * CFrame.new(0, 11.8, 0),
		Color = red, Material = Enum.Material.SmoothPlastic, Parent = container,
	})
end

local function marbleColumn(container: Folder, position: Vector3, rng: Random)
	local height = rng:NextNumber(12, 18)
	makePart({
		Size = Vector3.new(2.2, height, 2.2), Position = position + Vector3.new(0, height / 2, 0),
		Color = Color3.fromRGB(240, 238, 230), Material = Enum.Material.Marble, Parent = container,
	})
	makePart({
		Size = Vector3.new(3.2, 1, 3.2), Position = position + Vector3.new(0, height + 0.5, 0),
		Color = Color3.fromRGB(240, 238, 230), Material = Enum.Material.Marble, Parent = container,
	})
end

local function cloud(container: Folder, position: Vector3, rng: Random)
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(30, 60), rng:NextNumber(30, 60)),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.45, CanCollide = false, Parent = container,
	})
end

-- --------------------------- WORLD DECORATION ---------------------------------

-- Scatter ring between the plaza and the island edge, avoiding bridges-ish.
local function scatterPosition(rng: Random, hub: Vector3, minRadius: number, maxRadius: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(minRadius, maxRadius)
	return hub + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function decorateWorld(worldIndex: number, worldDef: WorldConfig.WorldDef, container: Folder, theme)
	local rng = Random.new(worldIndex * 7919)
	local hub = worldDef.FastTravelPoints[1].Position

	-- Village core: fountain + lamp ring + market crates + houses behind NPCs.
	-- (Fountain sits off-center so it never overlaps the spawn pad.)
	fountain(container, hub + Vector3.new(-18, 0, -18), theme.Accent)
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		lampPost(container, hub + Vector3.new(math.cos(angle) * 56, 0, math.sin(angle) * 56), theme.Accent)
	end
	crates(container, hub + Vector3.new(14, 0, 14), rng)
	for index = 1, #worldDef.NPCs do
		local angle = math.rad(120 + index * 35) -- matches NPCService placement
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		house(container, hub + direction * 42, -direction, theme, rng)
	end

	-- Raised hills give the flat island a silhouette.
	for _ = 1, 3 do
		local position = scatterPosition(rng, hub, 110, 175)
		local radius = rng:NextNumber(18, 34)
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(rng:NextNumber(6, 14), radius * 2, radius * 2),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = theme.Ground, Material = theme.Material, Parent = container,
		})
	end

	-- Beach rim around the island.
	makePart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 470, 470),
		CFrame = CFrame.new(hub - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(225, 210, 165), Material = Enum.Material.Sand, Parent = container,
	})

	-- Per-world signature decoration sets.
	local id = worldDef.Id
	if id == "W1_BEGINNER_ISLAND" then
		for _ = 1, 18 do
			palmTree(container, scatterPosition(rng, hub, 75, 190), rng)
		end
		for _ = 1, 8 do
			rock(container, scatterPosition(rng, hub, 80, 190), rng, Color3.fromRGB(140, 135, 125))
		end
	elseif id == "W2_SHINOBI_NATION" then
		archGate(container, hub + Vector3.new(0, 0, 64), Vector3.new(0, 0, -1))
		for _ = 1, 26 do
			bambooStalk(container, scatterPosition(rng, hub, 75, 190), rng)
		end
		for _ = 1, 6 do
			spiritLantern(container, scatterPosition(rng, hub, 70, 150), rng)
		end
	elseif id == "W3_SOUL_EMPIRE" then
		for _ = 1, 14 do
			spiritLantern(container, scatterPosition(rng, hub, 70, 185), rng)
		end
		for _ = 1, 8 do
			rock(container, scatterPosition(rng, hub, 80, 185), rng, Color3.fromRGB(110, 110, 130))
		end
	elseif id == "W4_GRAND_OCEAN" then
		dock(container, hub, theme)
		for _ = 1, 14 do
			palmTree(container, scatterPosition(rng, hub, 75, 185), rng)
		end
		for _ = 1, 5 do
			crates(container, scatterPosition(rng, hub, 70, 140), rng)
		end
	elseif id == "W5_DEMON_REALM" then
		for _ = 1, 16 do
			obsidianSpike(container, scatterPosition(rng, hub, 75, 190), rng)
		end
		for _ = 1, 7 do
			lavaPool(container, scatterPosition(rng, hub, 85, 185), rng)
		end
	elseif id == "W6_CELESTIAL_KINGDOM" then
		for _ = 1, 10 do
			marbleColumn(container, scatterPosition(rng, hub, 75, 175), rng)
		end
		for _ = 1, 12 do
			skyCrystal(container, scatterPosition(rng, hub, 70, 190), rng)
		end
		for _ = 1, 8 do
			cloud(container, scatterPosition(rng, hub, 90, 260) - Vector3.new(0, rng:NextNumber(25, 55), 0), rng)
		end
	end
end

-- ------------------------------ WORLD BUILD -----------------------------------

local function buildWorld(worldIndex: number, worldDef: WorldConfig.WorldDef, worldsFolder: Folder)
	local theme = THEMES[worldDef.Id] or THEMES.W1_BEGINNER_ISLAND
	local container = Instance.new("Folder")
	container.Name = worldDef.Id
	container.Parent = worldsFolder

	local hub = worldDef.FastTravelPoints[1].Position

	-- Main island under the hub (covers the 90-160 stud enemy spawn ring).
	makePart({
		Name = "MainIsland",
		Size = Vector3.new(420, 8, 420),
		Position = hub - Vector3.new(0, 5, 0),
		Color = theme.Ground,
		Material = theme.Material,
		Parent = container,
	})

	-- Hub plaza.
	local plaza = makePart({
		Name = "HubPlaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 44, 44),
		CFrame = CFrame.new(hub - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(165, 155, 145),
		Material = Enum.Material.Cobblestone,
		Parent = container,
	})
	addLabel(plaza, worldDef.Name, theme.Accent)

	-- Visible safe-zone boundary (matches SafeZones.Radius = 60).
	makePart({
		Name = "SafeZoneRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 120, 120),
		CFrame = CFrame.new(hub - Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 255, 180),
		Material = Enum.Material.Neon,
		Transparency = 0.82,
		CanCollide = false,
		CanQuery = false,
		Parent = container,
	})

	-- Island + glowing pad per fast-travel point; touching unlocks it and
	-- counts toward "Reach" quest objectives.
	for index, point in worldDef.FastTravelPoints do
		if index > 1 then
			makePart({
				Name = "Island_" .. point.Id,
				Size = Vector3.new(90, 8, 90),
				Position = point.Position - Vector3.new(0, 5, 0),
				Color = theme.Ground,
				Material = theme.Material,
				Parent = container,
			})
			-- Simple bridge back to the hub so everything is walkable.
			local toHub = hub - point.Position
			local flat = Vector3.new(toHub.X, 0, toHub.Z)
			local length = flat.Magnitude
			if length > 1 then
				local midpoint = (point.Position + hub) / 2
				local bridge = makePart({
					Name = "Bridge_" .. point.Id,
					Size = Vector3.new(10, 2, length),
					Color = theme.Accent,
					Material = Enum.Material.WoodPlanks,
					Parent = container,
				})
				bridge.CFrame = CFrame.lookAt(midpoint - Vector3.new(0, 1, 0), hub - Vector3.new(0, 1, 0))
				-- Rope-post rails so bridges read as bridges.
				for postIndex = 0, math.floor(length / 24) do
					for _, side in { -1, 1 } do
						makePart({
							Size = Vector3.new(0.6, 3.4, 0.6),
							CFrame = bridge.CFrame * CFrame.new(side * 4.6, 2.2, length / 2 - postIndex * 24),
							Color = Color3.fromRGB(110, 80, 55),
							Material = Enum.Material.Wood,
							Parent = container,
						})
					end
				end
			end
		end
		local pad = makePart({
			Name = "FastTravel_" .. point.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 12, 12),
			CFrame = CFrame.new(point.Position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
			Parent = container,
		})
		addLabel(pad, "◈ " .. point.Name, Color3.fromRGB(160, 230, 255))
		onPlayerTouch(pad, 3, function(player)
			local profile = services.DataService:GetProfile(player)
			if not profile then
				return
			end
			if not profile.Data.Progress.UnlockedFastTravel[point.Id] then
				profile.Data.Progress.UnlockedFastTravel[point.Id] = true
				profile.Dirty = true
			end
			services.QuestService:ReportProgress(player, "Reach", point.Id, 1)
		end)
	end

	-- Secret chests at deterministic offsets around the hub.
	for index, secret in worldDef.Secrets do
		local angle = index * 2.3996 -- golden-angle spread
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (140 + index * 12)
		local chest = makePart({
			Name = "Secret_" .. secret.Id,
			Size = Vector3.new(3, 3, 3),
			Position = hub + offset + Vector3.new(0, 2.5, 0),
			Color = Color3.fromRGB(255, 200, 80),
			Material = Enum.Material.Metal,
			Parent = container,
		})
		addLabel(chest, "✦", Color3.fromRGB(255, 220, 120))
		onPlayerTouch(chest, 5, function(player)
			local profile = services.DataService:GetProfile(player)
			if not profile or profile.Data.Progress.FoundSecrets[secret.Id] then
				return
			end
			profile.Data.Progress.FoundSecrets[secret.Id] = true
			profile.Dirty = true
			services.InventoryService:GrantRewards(player, secret.Reward)
			Remotes.Event("NPCDialogue"):FireClient(player, "Secret found!", secret.Hint)
		end)
	end

	-- Boss arena: ringed floor, pillars with fire bowls, entrance banners.
	local lastPoint = worldDef.FastTravelPoints[#worldDef.FastTravelPoints]
	local arenaCenter = lastPoint.Position + Vector3.new(40, 0, 0)
	makePart({
		Name = "BossArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 120, 120),
		CFrame = CFrame.new(arenaCenter - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = theme.Ground:Lerp(Color3.new(0, 0, 0), 0.3),
		Material = Enum.Material.Cobblestone,
		Parent = container,
	})
	for pillarIndex = 1, 8 do
		local angle = pillarIndex / 8 * math.pi * 2
		local pillarPosition = arenaCenter + Vector3.new(math.cos(angle) * 55, 9, math.sin(angle) * 55)
		makePart({
			Name = "ArenaPillar" .. pillarIndex,
			Size = Vector3.new(4, 18, 4),
			Position = pillarPosition,
			Color = theme.Accent,
			Material = theme.Material,
			Parent = container,
		})
		local flame = makePart({
			Size = Vector3.new(2, 1.6, 2),
			Position = pillarPosition + Vector3.new(0, 9.8, 0),
			Color = Color3.fromRGB(255, 140, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = container,
		})
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Parent = flame
	end

	decorateWorld(worldIndex, worldDef, container, theme)
end

-- --------------------------- GLOBAL ENVIRONMENT --------------------------------

local function buildOcean(worldsFolder: Folder)
	local ocean = makePart({
		Name = "Ocean",
		Size = Vector3.new(13_000, 6, 3_400),
		Position = Vector3.new(5_000, OCEAN_LEVEL, 150),
		Color = Color3.fromRGB(35, 95, 160),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Parent = worldsFolder,
	})
	-- Falling into the sea returns you to the nearest world hub.
	onPlayerTouch(ocean, 4, function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local nearest = WorldConfig.Worlds[1].FastTravelPoints[1].Position
		local nearestDistance = math.huge
		for _, worldDef in WorldConfig.Worlds do
			local hub = worldDef.FastTravelPoints[1].Position
			local distance = (Vector3.new(hub.X, 0, hub.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = hub, distance
			end
		end
		services.AntiCheatService:AllowTeleport(player)
		root.CFrame = CFrame.new(nearest + Vector3.new(0, 5, 0))
		Remotes.Event("NPCDialogue"):FireClient(player, "The Sea", "The current washed you back ashore…")
	end)
end

local function configureLighting()
	Lighting.ClockTime = 14.3
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.4
		atmosphere.Color = Color3.fromRGB(199, 209, 222)
		atmosphere.Decay = Color3.fromRGB(110, 130, 160)
		atmosphere.Haze = 1.6
		atmosphere.Glare = 0.3
		atmosphere.Parent = Lighting
	end
end

-- ------------------------------- LIFECYCLE -------------------------------------

function WorldBuilderService:Init(registry)
	services = registry

	local worldsFolder = workspace:FindFirstChild("Worlds") :: Folder?
	if not worldsFolder then
		worldsFolder = Instance.new("Folder")
		worldsFolder.Name = "Worlds"
		worldsFolder.Parent = workspace
	end

	configureLighting()
	buildOcean(worldsFolder :: Folder)

	for worldIndex, worldDef in WorldConfig.Worlds do
		-- Real art under Workspace/Worlds/<Id> takes precedence; the builder
		-- only fills in worlds that don't exist yet.
		if not (worldsFolder :: Folder):FindFirstChild(worldDef.Id) then
			buildWorld(worldIndex, worldDef, worldsFolder :: Folder)
		end
	end

	-- Player spawn at the World 1 hub.
	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Size = Vector3.new(12, 1, 12)
		spawnLocation.Position = WorldConfig.Worlds[1].FastTravelPoints[1].Position + Vector3.new(0, 1, 0)
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Color = Color3.fromRGB(255, 255, 255)
		spawnLocation.Material = Enum.Material.Neon
		spawnLocation.Parent = workspace
	end
end

return WorldBuilderService
