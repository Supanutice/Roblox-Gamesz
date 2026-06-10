--!strict
-- WorldBuilderService.luau
-- Procedurally builds PLACEHOLDER geometry for all six worlds so the game is
-- fully walkable/playable before real art lands: themed islands, fast-travel
-- pads, secret chests, boss arenas and the spawn point. Geometry is built in
-- Init (before SpawnerService:Start spawns enemies) so nothing falls into
-- the void. Replace any island by placing real art under
-- Workspace/Worlds/<WorldId> — the builder skips worlds that already exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Configs.WorldConfig)
local Remotes = require(Shared.Net.Remotes)

local WorldBuilderService = { Name = "WorldBuilderService" }

local services: { [string]: any }

-- Visual theme per world (placeholder palette).
local THEMES: { [string]: { Ground: Color3, Accent: Color3, Material: Enum.Material } } = {
	W1_BEGINNER_ISLAND = { Ground = Color3.fromRGB(120, 180, 90), Accent = Color3.fromRGB(240, 220, 160), Material = Enum.Material.Grass },
	W2_SHINOBI_NATION = { Ground = Color3.fromRGB(70, 110, 70), Accent = Color3.fromRGB(180, 60, 60), Material = Enum.Material.Grass },
	W3_SOUL_EMPIRE = { Ground = Color3.fromRGB(150, 150, 165), Accent = Color3.fromRGB(120, 200, 220), Material = Enum.Material.Slate },
	W4_GRAND_OCEAN = { Ground = Color3.fromRGB(220, 205, 160), Accent = Color3.fromRGB(60, 130, 200), Material = Enum.Material.Sand },
	W5_DEMON_REALM = { Ground = Color3.fromRGB(60, 40, 45), Accent = Color3.fromRGB(230, 90, 40), Material = Enum.Material.Basalt },
	W6_CELESTIAL_KINGDOM = { Ground = Color3.fromRGB(235, 235, 245), Accent = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Marble },
}

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
		local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
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

local function buildWorld(worldDef: WorldConfig.WorldDef, worldsFolder: Folder)
	local theme = THEMES[worldDef.Id] or THEMES.W1_BEGINNER_ISLAND
	local container = Instance.new("Folder")
	container.Name = worldDef.Id
	container.Parent = worldsFolder

	local hub = worldDef.FastTravelPoints[1].Position

	-- Main island under the hub (covers the ±120 enemy spawn scatter).
	makePart({
		Name = "MainIsland",
		Size = Vector3.new(420, 8, 420),
		Position = hub - Vector3.new(0, 5, 0),
		Color = theme.Ground,
		Material = theme.Material,
		Parent = container,
	})

	-- Hub plaza marker.
	local plaza = makePart({
		Name = "HubPlaza",
		Size = Vector3.new(40, 1, 40),
		Position = hub - Vector3.new(0, 0.5, 0),
		Color = theme.Accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = container,
	})
	addLabel(plaza, worldDef.Name, theme.Accent)

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

	-- Boss arena ring at the SpawnerService boss anchor (last FT point + 40 X).
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
		makePart({
			Name = "ArenaPillar" .. pillarIndex,
			Size = Vector3.new(4, 18, 4),
			Position = arenaCenter + Vector3.new(math.cos(angle) * 55, 9, math.sin(angle) * 55),
			Color = theme.Accent,
			Material = theme.Material,
			Parent = container,
		})
	end
end

function WorldBuilderService:Init(registry)
	services = registry

	local worldsFolder = workspace:FindFirstChild("Worlds") :: Folder?
	if not worldsFolder then
		worldsFolder = Instance.new("Folder")
		worldsFolder.Name = "Worlds"
		worldsFolder.Parent = workspace
	end

	for _, worldDef in WorldConfig.Worlds do
		-- Real art under Workspace/Worlds/<Id> takes precedence; the builder
		-- only fills in worlds that don't exist yet.
		if not (worldsFolder :: Folder):FindFirstChild(worldDef.Id) then
			buildWorld(worldDef, worldsFolder :: Folder)
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
