--!strict
-- SpawnerService.luau
-- Spawns world enemies and bosses from WorldConfig/BossDatabase, runs the
-- respawn loops, routes kill credit into quests/XP, and handles fast travel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Configs.WorldConfig)
local BossDatabase = require(Shared.Data.BossDatabase)
local Remotes = require(Shared.Net.Remotes)

local AIController = require(script.Parent.Parent.AI.AIController)
local BossAI = require(script.Parent.Parent.AI.BossAI)

local SpawnerService = { Name = "SpawnerService" }

local services: { [string]: any }
local activeBosses: { [string]: any } = {}

local ENEMIES_PER_TYPE = 4
local ENEMY_RESPAWN_SECONDS = 20

-- ----------------------------- ENEMY SPAWNING ------------------------------

local function buildEnemyModel(enemyDef): Model
	local enemiesFolder = ServerStorage:FindFirstChild("Enemies")
	local template = enemiesFolder and enemiesFolder:FindFirstChild(enemyDef.Id)
	local model: Model
	if template then
		model = template:Clone()
	else
		-- Placeholder rig keeps gameplay testable before art lands.
		model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 5, 2)
		root.Parent = model
		model.PrimaryPart = root
		Instance.new("Humanoid").Parent = model
	end
	model.Name = enemyDef.Name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hp = 100 + enemyDef.Level ^ 1.9 * 8
	humanoid.MaxHealth = hp
	humanoid.Health = hp
	model:SetAttribute("ATK", 8 + enemyDef.Level * 4)
	model:SetAttribute("DEF", enemyDef.Level * 2)
	model:SetAttribute("Element", enemyDef.Element)
	model:SetAttribute("EnemyId", enemyDef.Id)
	model:SetAttribute("Level", enemyDef.Level)
	return model
end

local function spawnEnemy(worldDef, enemyDef, position: Vector3)
	local model = buildEnemyModel(enemyDef)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	model.Parent = workspace

	AIController.new(model, services)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		task.delay(4, function()
			model:Destroy()
		end)
		task.delay(ENEMY_RESPAWN_SECONDS, function()
			spawnEnemy(worldDef, enemyDef, position)
		end)
	end)
end

-- Kill credit: XP + quest progress to whoever landed the killing blow.
local function onEntityDied(victim: Model, killer: Player?)
	local enemyId = victim:GetAttribute("EnemyId") :: string?
	if not enemyId or not killer then
		return
	end
	local level = victim:GetAttribute("Level") :: number? or 1
	services.DataService:AddXP(killer, 20 + level * 12)
	services.DataService:AddCurrency(killer, "Gold", 10 + level * 6)
	services.QuestService:ReportProgress(killer, "Kill", enemyId, 1)
	services.QuestService:ReportProgress(killer, "Kill", nil, 1) -- "kill anything" dailies
	services.EconomyService:AddBattlePassXP(killer, 5)
end

-- ------------------------------ BOSS LOOP ----------------------------------

local function bossSpawnLoop(worldDef, bossId: string)
	while true do
		local def = BossDatabase.ById[bossId]
		if not def then
			return
		end
		-- Spawn at the world's last fast-travel point (boss arena anchor).
		local anchor = worldDef.FastTravelPoints[#worldDef.FastTravelPoints]
		local boss = BossAI.new(bossId, CFrame.new(anchor.Position + Vector3.new(40, 6, 0)), services)
		activeBosses[bossId] = boss
		boss.Defeated:Wait()
		activeBosses[bossId] = nil
		task.wait(def.RespawnSeconds)
	end
end

-- ------------------------------ FAST TRAVEL --------------------------------

local function handleFastTravel(player: Player, worldId: unknown, pointId: unknown): (boolean, string?)
	if typeof(worldId) ~= "string" or typeof(pointId) ~= "string" then
		return false, "Invalid request"
	end
	local worldDef = WorldConfig.ById[worldId]
	if not worldDef then
		return false, "Unknown world"
	end
	local profile = services.DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if not profile.Data.Progress.UnlockedWorlds[worldId] then
		-- Check unlock requirements now (quest completion may have unlocked it).
		local req = worldDef.UnlockRequirement
		local questDone = not req.QuestId or profile.Data.Quests.Completed[req.QuestId]
		if profile.Data.Level >= req.PlayerLevel and questDone then
			profile.Data.Progress.UnlockedWorlds[worldId] = true
			profile.Dirty = true
		else
			return false, "World locked"
		end
	end
	for _, point in worldDef.FastTravelPoints do
		if point.Id == pointId then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				services.AntiCheatService:AllowTeleport(player)
				root.CFrame = CFrame.new(point.Position + Vector3.new(0, 5, 0))
				profile.Data.Progress.UnlockedFastTravel[pointId] = true
				profile.Dirty = true
				return true
			end
			return false, "No character"
		end
	end
	return false, "Unknown travel point"
end

-- ------------------------------- LIFECYCLE ---------------------------------

function SpawnerService:Init(registry)
	services = registry
end

function SpawnerService:Start()
	services.DamageService.EntityDied:Connect(onEntityDied)
	Remotes.Function("FastTravelRequest").OnServerInvoke = handleFastTravel

	-- Populate every world.
	for _, worldDef in WorldConfig.Worlds do
		for _, enemyDef in worldDef.Enemies do
			for i = 1, ENEMIES_PER_TYPE do
				local base = worldDef.FastTravelPoints[1].Position
				local offset = Vector3.new(math.random(-120, 120), 0, math.random(-120, 120))
				task.spawn(spawnEnemy, worldDef, enemyDef, base + offset)
			end
		end
		for _, bossId in worldDef.Bosses do
			task.spawn(bossSpawnLoop, worldDef, bossId)
		end
	end
end

return SpawnerService
