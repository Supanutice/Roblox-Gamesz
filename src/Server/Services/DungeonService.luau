--!strict
-- DungeonService.luau
-- Instanced 1–4 player dungeons. A glowing portal stands at every world hub;
-- the party leader triggers it to start that world's dungeon. Each run gets
-- an isolated arena far from the worlds, fights timed waves (final wave is
-- ELITE), and on victory every member receives rewards + CompleteDungeon
-- quest credit, then everyone returns to the world hub.
--
-- Fail conditions: every member dead/left the arena, or the time limit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DungeonConfig = require(Shared.Configs.DungeonConfig)
local WorldConfig = require(Shared.Configs.WorldConfig)
local Remotes = require(Shared.Net.Remotes)

local AIController = require(script.Parent.Parent.AI.AIController)

local DungeonService = { Name = "DungeonService" }

local services: { [string]: any }

-- enemyId -> enemy def (flattened from WorldConfig at Init).
local enemyDefs: { [string]: any } = {}

type Run = {
	Dungeon: DungeonConfig.DungeonDef,
	Members: { Player },
	Base: Vector3,
	Container: Folder,
	Slot: number,
	Active: boolean,
	EnemiesAlive: number,
}

local MAX_SLOTS = 8
local slotUsed: { [number]: boolean } = {}
local runOf: { [Player]: Run } = {}

local ARENA_ORIGIN = Vector3.new(0, 80, 8_000)
local ARENA_SPACING = 500
local ARENA_RADIUS = 60

-- ----------------------------- ARENA BUILD -----------------------------------

local function buildArena(base: Vector3, dungeonName: string): Folder
	local container = Instance.new("Folder")
	container.Name = "DungeonRun"

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(2, ARENA_RADIUS * 2, ARENA_RADIUS * 2)
	floor.CFrame = CFrame.new(base - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Anchored = true
	floor.Color = Color3.fromRGB(45, 40, 60)
	floor.Material = Enum.Material.Slate
	floor.Parent = container

	-- Perimeter wall so nobody falls/escapes mid-run.
	for index = 1, 16 do
		local angle = index / 16 * math.pi * 2
		local wall = Instance.new("Part")
		wall.Size = Vector3.new(4, 24, 24)
		wall.Position = base + Vector3.new(math.cos(angle) * ARENA_RADIUS, 11, math.sin(angle) * ARENA_RADIUS)
		wall.CFrame = CFrame.lookAt(wall.Position, Vector3.new(base.X, wall.Position.Y, base.Z))
		wall.Anchored = true
		wall.Color = Color3.fromRGB(70, 60, 95)
		wall.Material = Enum.Material.Slate
		wall.Parent = container
	end

	local light = Instance.new("Part")
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(6, 6, 6)
	light.Position = base + Vector3.new(0, 30, 0)
	light.Anchored = true
	light.CanCollide = false
	light.Color = Color3.fromRGB(170, 130, 255)
	light.Material = Enum.Material.Neon
	light.Name = dungeonName
	light.Parent = container
	local pointLight = Instance.new("PointLight")
	pointLight.Range = 60
	pointLight.Brightness = 2
	pointLight.Parent = light

	container.Parent = workspace
	return container
end

-- ------------------------------ RUN FLOW --------------------------------------

local function notify(run: Run, eventType: string, payload: { [string]: any })
	for _, member in run.Members do
		if member.Parent then
			Remotes.Event("DungeonEvent"):FireClient(member, eventType, payload)
		end
	end
end

local function teleportMember(player: Player, position: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		services.AntiCheatService:AllowTeleport(player)
		root.CFrame = CFrame.new(position)
	end
end

local function aliveMembersInArena(run: Run): number
	local alive = 0
	for _, member in run.Members do
		if member.Parent and member.Character then
			local humanoid = member.Character:FindFirstChildOfClass("Humanoid")
			local root = member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and root
				and (root.Position - run.Base).Magnitude < ARENA_RADIUS * 3 then
				alive += 1
			end
		end
	end
	return alive
end

local function spawnWave(run: Run, wave: DungeonConfig.Wave)
	local partyMult = DungeonConfig.PartyScaling.Base + DungeonConfig.PartyScaling.PerMember * #run.Members
	for _, group in wave.Enemies do
		local enemyDef = enemyDefs[group.Id]
		if not enemyDef then
			warn(`[Dungeon] Unknown enemy {group.Id}`)
			continue
		end
		for i = 1, group.Count do
			local model = services.SpawnerService.BuildEnemyModel(enemyDef)
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local hpMult = partyMult * (if wave.Elite then run.Dungeon.EliteMultiplier else 1)
			humanoid.MaxHealth = math.floor(humanoid.MaxHealth * hpMult)
			humanoid.Health = humanoid.MaxHealth
			if wave.Elite then
				model:SetAttribute("ATK", math.floor((model:GetAttribute("ATK") :: number) * 1.6))
				model.Name = "ELITE " .. model.Name
				local body = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if body then
					body.Color = Color3.fromRGB(255, 90, 90)
					body.Material = Enum.Material.Neon
				end
			end
			local angle = math.random() * math.pi * 2
			local distance = 15 + math.random() * (ARENA_RADIUS - 25)
			model:PivotTo(CFrame.new(run.Base + Vector3.new(math.cos(angle) * distance, 5, math.sin(angle) * distance)))
			model.Parent = run.Container

			AIController.new(model, services, {
				AggroRange = ARENA_RADIUS * 3, -- always aggro inside the arena
				AttackRange = 8,
				AttackCooldown = 2.0,
				AttackMultiplier = if wave.Elite then 1.4 else 1.0,
				RetreatHealthFraction = 0, -- dungeon enemies never retreat
				PatrolRadius = 10,
				WalkSpeed = 10,
				ChaseSpeed = 17,
			})

			run.EnemiesAlive += 1
			humanoid.Died:Once(function()
				run.EnemiesAlive -= 1
				task.delay(3, function()
					model:Destroy()
				end)
			end)
		end
	end
end

local function endRun(run: Run, victory: boolean)
	if not run.Active then
		return
	end
	run.Active = false

	local worldDef = WorldConfig.ById[run.Dungeon.WorldId]
	local hub = worldDef.FastTravelPoints[1].Position

	for _, member in run.Members do
		runOf[member] = nil
		if not member.Parent then
			continue
		end
		if victory then
			services.InventoryService:GrantRewards(member, run.Dungeon.Rewards)
			services.QuestService:ReportProgress(member, "CompleteDungeon", run.Dungeon.Id, 1)
			services.QuestService:ReportProgress(member, "CompleteDungeon", nil, 1)
			services.EconomyService:AddBattlePassXP(member, 250)
		end
		teleportMember(member, hub + Vector3.new(math.random(-6, 6), 5, math.random(-6, 6)))
	end
	notify(run, if victory then "RunCompleted" else "RunFailed",
		{ DungeonId = run.Dungeon.Id, Rewards = if victory then run.Dungeon.Rewards else nil })

	slotUsed[run.Slot] = nil
	task.delay(3, function()
		run.Container:Destroy()
	end)
end

local function runLoop(run: Run)
	local deadline = os.clock() + run.Dungeon.TimeLimitSeconds
	for waveIndex, wave in run.Dungeon.Waves do
		if not run.Active then
			return
		end
		notify(run, "WaveStarted", {
			DungeonId = run.Dungeon.Id,
			Wave = waveIndex,
			TotalWaves = #run.Dungeon.Waves,
			Elite = wave.Elite == true,
		})
		task.wait(2.5)
		spawnWave(run, wave)

		-- Wait for the wave to die (or the run to fail).
		while run.Active and run.EnemiesAlive > 0 do
			task.wait(1)
			if os.clock() > deadline then
				endRun(run, false)
				return
			end
			if aliveMembersInArena(run) == 0 then
				endRun(run, false)
				return
			end
		end
	end
	if run.Active then
		endRun(run, true)
	end
end

function DungeonService:StartRun(leader: Player, dungeonId: string): (boolean, string?)
	local dungeon = DungeonConfig.ById[dungeonId]
	if not dungeon then
		return false, "Unknown dungeon"
	end
	if not services.PartyService:IsLeader(leader) then
		return false, "Only the party leader can start"
	end
	if runOf[leader] then
		return false, "Already in a dungeon"
	end

	-- Eligible members: leveled, alive, not already in another run.
	local members: { Player } = {}
	for _, member in services.PartyService:GetMembers(leader) do
		local profile = services.DataService:GetProfile(member)
		if profile and profile.Data.Level >= dungeon.RequiredLevel and not runOf[member] then
			table.insert(members, member)
		end
	end
	if #members == 0 then
		return false, `Requires level {dungeon.RequiredLevel}`
	end

	local slot: number? = nil
	for index = 1, MAX_SLOTS do
		if not slotUsed[index] then
			slot = index
			break
		end
	end
	if not slot then
		return false, "All dungeon instances busy — try again shortly"
	end
	slotUsed[slot :: number] = true

	local base = ARENA_ORIGIN + Vector3.new((slot :: number) * ARENA_SPACING, 0, 0)
	local run: Run = {
		Dungeon = dungeon,
		Members = members,
		Base = base,
		Container = buildArena(base, dungeon.Name),
		Slot = slot :: number,
		Active = true,
		EnemiesAlive = 0,
	}
	for index, member in members do
		runOf[member] = run
		local angle = index / #members * math.pi * 2
		teleportMember(member, base + Vector3.new(math.cos(angle) * 8, 4, math.sin(angle) * 8))
	end
	notify(run, "RunStarted", { DungeonId = dungeon.Id, Name = dungeon.Name, Members = #members })
	task.spawn(runLoop, run)
	return true
end

-- ------------------------------ PORTALS ---------------------------------------

local function buildPortal(dungeon: DungeonConfig.DungeonDef)
	local worldDef = WorldConfig.ById[dungeon.WorldId]
	if not worldDef then
		return
	end
	local hub = worldDef.FastTravelPoints[1].Position

	local portal = Instance.new("Part")
	portal.Name = "DungeonPortal_" .. dungeon.Id
	portal.Size = Vector3.new(8, 11, 2)
	portal.Position = hub + Vector3.new(0, 5.5, 55)
	portal.Anchored = true
	portal.CanCollide = false
	portal.Color = Color3.fromRGB(150, 90, 255)
	portal.Material = Enum.Material.ForceField
	portal.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(16, 4)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 200
	billboard.Parent = portal
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 160, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = `⌬ {dungeon.Name}\nDungeon · Lv.{dungeon.RequiredLevel}+ · 1-4 players`
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter Dungeon"
	prompt.ObjectText = dungeon.Name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	prompt.Triggered:Connect(function(player)
		local ok, err = DungeonService:StartRun(player, dungeon.Id)
		if not ok then
			Remotes.Event("NPCDialogue"):FireClient(player, "Dungeon Portal", err or "Cannot enter")
		end
	end)
end

-- ------------------------------- LIFECYCLE ------------------------------------

function DungeonService:Init(registry)
	services = registry
	for _, worldDef in WorldConfig.Worlds do
		for _, enemy in worldDef.Enemies do
			enemyDefs[enemy.Id] = enemy
		end
	end
end

function DungeonService:Start()
	for _, dungeon in DungeonConfig.Dungeons do
		buildPortal(dungeon)
	end

	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run just drops you from the member checks; the run
		-- fails naturally when nobody alive remains in the arena.
		runOf[player] = nil
	end)
end

return DungeonService
