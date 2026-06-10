--!strict
-- QuestService.luau
-- Accept/track/claim for Main, Side, Daily, Weekly quests. Progress is
-- reported by OTHER systems via ReportProgress (kill feeds, summons,
-- dungeon clears) — the client can never claim progress directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestDatabase = require(Shared.Data.QuestDatabase)
local Remotes = require(Shared.Net.Remotes)

local QuestService = { Name = "QuestService" }

local DataService, InventoryService, EconomyService

local SECONDS_PER_DAY = 86_400
local SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY

-- ============================== RESET LOGIC ================================

local function resetPeriodicQuests(profile)
	local quests = profile.Data.Quests
	local now = os.time()
	local today = math.floor(now / SECONDS_PER_DAY)
	local thisWeek = math.floor(now / SECONDS_PER_WEEK)

	if math.floor(quests.LastDailyReset / SECONDS_PER_DAY) < today then
		quests.LastDailyReset = now
		for questId, def in QuestDatabase.ById do
			if def.Type == "Daily" then
				quests.Active[questId] = nil
				quests.Completed[questId] = nil
			end
		end
	end
	if math.floor(quests.LastWeeklyReset / SECONDS_PER_WEEK) < thisWeek then
		quests.LastWeeklyReset = now
		for questId, def in QuestDatabase.ById do
			if def.Type == "Weekly" then
				quests.Active[questId] = nil
				quests.Completed[questId] = nil
			end
		end
	end
end

-- ================================ ACTIONS ==================================

function QuestService:AcceptQuest(player: Player, questId: string): (boolean, string?)
	local def = QuestDatabase.ById[questId]
	if not def then
		return false, "Unknown quest"
	end
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	resetPeriodicQuests(profile)
	local quests = profile.Data.Quests
	if quests.Active[questId] then
		return false, "Already active"
	end
	if quests.Completed[questId] and (def.Type == "Main" or def.Type == "Side") then
		return false, "Already completed"
	end
	if profile.Data.Level < def.RequiredLevel then
		return false, `Requires level {def.RequiredLevel}`
	end
	if def.PrerequisiteQuest and not quests.Completed[def.PrerequisiteQuest] then
		return false, "Prerequisite not completed"
	end

	local progress = table.create(#def.Objectives, 0)
	quests.Active[questId] = { Progress = progress, AcceptedAt = os.time() }
	profile.Dirty = true
	Remotes.Event("QuestProgressChanged"):FireClient(player, questId, progress)
	return true
end

-- Called by combat/gacha/dungeon systems whenever something countable happens.
function QuestService:ReportProgress(player: Player, objectiveType: string, targetId: string?, amount: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local changed = false
	for questId, active in profile.Data.Quests.Active do
		local def = QuestDatabase.ById[questId]
		if not def then
			continue
		end
		for index, objective in def.Objectives do
			if objective.Type ~= objectiveType then
				continue
			end
			-- Objectives without a TargetId count anything of that type.
			if objective.TargetId and objective.TargetId ~= targetId then
				continue
			end
			local current = active.Progress[index] or 0
			if current < objective.Count then
				active.Progress[index] = math.min(objective.Count, current + amount)
				changed = true
				Remotes.Event("QuestProgressChanged"):FireClient(player, questId, active.Progress)
			end
		end
	end
	if changed then
		profile.Dirty = true
	end
end

function QuestService:ClaimQuest(player: Player, questId: string): (boolean, any)
	local def = QuestDatabase.ById[questId]
	local profile = DataService:GetProfile(player)
	if not def or not profile then
		return false, "Invalid"
	end
	local active = profile.Data.Quests.Active[questId]
	if not active then
		return false, "Not active"
	end
	for index, objective in def.Objectives do
		if (active.Progress[index] or 0) < objective.Count then
			return false, "Objectives incomplete"
		end
	end

	profile.Data.Quests.Active[questId] = nil
	profile.Data.Quests.Completed[questId] = true
	profile.Dirty = true

	InventoryService:GrantRewards(player, def.Rewards)
	EconomyService:AddBattlePassXP(player, 100) -- every quest feeds the pass
	return true, def.Rewards
end

-- ================================ LIFECYCLE ================================

function QuestService:Init(registry)
	DataService = registry.DataService
	InventoryService = registry.InventoryService
	EconomyService = registry.EconomyService
end

function QuestService:Start()
	Remotes.Function("QuestAccept").OnServerInvoke = function(player, questId)
		if typeof(questId) ~= "string" then
			return false, "Invalid"
		end
		return self:AcceptQuest(player, questId)
	end
	Remotes.Function("QuestClaim").OnServerInvoke = function(player, questId)
		if typeof(questId) ~= "string" then
			return false, "Invalid"
		end
		return self:ClaimQuest(player, questId)
	end

	-- Auto-accept dailies/weeklies on login so players never miss them.
	DataService.ProfileLoaded:Connect(function(player, profile)
		resetPeriodicQuests(profile)
		for questId, def in QuestDatabase.ById do
			if (def.Type == "Daily" or def.Type == "Weekly")
				and profile.Data.Level >= def.RequiredLevel
				and not profile.Data.Quests.Active[questId]
				and not profile.Data.Quests.Completed[questId] then
				local progress = table.create(#def.Objectives, 0)
				profile.Data.Quests.Active[questId] = { Progress = progress, AcceptedAt = os.time() }
			end
		end
	end)
end

return QuestService
