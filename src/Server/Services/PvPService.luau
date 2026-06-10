--!strict
-- PvPService.luau
-- Queue -> matchmake -> arena -> result -> Elo. Rating-band matchmaking with
-- a widening search window. Ranked modes apply stat normalization so PvP
-- stays skill-forward (anti pay-to-win pillar).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PvPConfig = require(Shared.Configs.PvPConfig)
local Formulas = require(Shared.Utilities.Formulas)
local Remotes = require(Shared.Net.Remotes)

local PvPService = { Name = "PvPService" }

local DataService, QuestService

type QueueEntry = {
	Player: Player,
	Mode: string,
	Rating: number,
	QueuedAt: number,
}

type Match = {
	Id: string,
	Mode: string,
	TeamA: { Player },
	TeamB: { Player },
	ScoreA: number,
	ScoreB: number,
	RoundsToWin: number,
	StartedAt: number,
}

local queues: { [string]: { QueueEntry } } = {}
local activeMatches: { [string]: Match } = {}
local playerMatch: { [Player]: Match } = {}

-- ------------------------------- RANKS -------------------------------------

function PvPService:GetRankName(rating: number): string
	local rankName = PvPConfig.Ranks[1].Name
	for _, rank in PvPConfig.Ranks do
		if rating >= rank.MinRating then
			rankName = rank.Name
		end
	end
	return rankName
end

-- ------------------------------ QUEUEING ------------------------------------

local function ratingFor(player: Player, mode: string): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return PvPConfig.Matchmaking.StartingRating
	end
	return if mode == "Arena3v3" then profile.Data.PvP.Rating3v3 else profile.Data.PvP.Rating1v1
end

function PvPService:JoinQueue(player: Player, mode: string): (boolean, string?)
	if not PvPConfig.Modes[mode] then
		return false, "Unknown mode"
	end
	if playerMatch[player] then
		return false, "Already in a match"
	end
	queues[mode] = queues[mode] or {}
	for _, entry in queues[mode] do
		if entry.Player == player then
			return false, "Already queued"
		end
	end
	table.insert(queues[mode], {
		Player = player,
		Mode = mode,
		Rating = ratingFor(player, mode),
		QueuedAt = os.clock(),
	})
	return true
end

function PvPService:LeaveQueue(player: Player)
	for _, queue in queues do
		for index, entry in queue do
			if entry.Player == player then
				table.remove(queue, index)
				break
			end
		end
	end
end

-- ----------------------------- MATCHMAKING ----------------------------------

local function searchRange(entry: QueueEntry): number
	local waited = os.clock() - entry.QueuedAt
	return math.min(
		PvPConfig.Matchmaking.InitialRatingRange + waited * PvPConfig.Matchmaking.RangeGrowthPerSecond,
		PvPConfig.Matchmaking.MaxRatingRange)
end

local function tryMatch(mode: string)
	local queue = queues[mode]
	if not queue then
		return
	end
	local teamSize = PvPConfig.Modes[mode].TeamSize
	local needed = teamSize * 2
	if #queue < needed then
		return
	end
	-- Sort by rating; greedy adjacent grouping keeps matches fair.
	table.sort(queue, function(a, b)
		return a.Rating < b.Rating
	end)
	for startIndex = 1, #queue - needed + 1 do
		local group = {}
		for i = startIndex, startIndex + needed - 1 do
			table.insert(group, queue[i])
		end
		local spread = group[#group].Rating - group[1].Rating
		local allowed = math.huge
		for _, entry in group do
			allowed = math.min(allowed, searchRange(entry))
		end
		if spread <= allowed then
			-- Alternate assignment balances average rating between teams.
			local teamA, teamB = {}, {}
			for index, entry in group do
				table.insert(if index % 2 == 1 then teamA else teamB, entry.Player)
			end
			for _, entry in group do
				PvPService:LeaveQueue(entry.Player)
			end
			PvPService:StartMatch(mode, teamA, teamB)
			return
		end
	end
end

-- ------------------------------- MATCHES ------------------------------------

function PvPService:StartMatch(mode: string, teamA: { Player }, teamB: { Player })
	local match: Match = {
		Id = game:GetService("HttpService"):GenerateGUID(false),
		Mode = mode,
		TeamA = teamA,
		TeamB = teamB,
		ScoreA = 0,
		ScoreB = 0,
		RoundsToWin = math.ceil(PvPConfig.Match.BestOf / 2),
		StartedAt = os.clock(),
	}
	activeMatches[match.Id] = match
	for _, player in teamA do
		playerMatch[player] = match
	end
	for _, player in teamB do
		playerMatch[player] = match
	end

	local info = {
		MatchId = match.Id,
		Mode = mode,
		MapId = PvPConfig.Modes[mode].MapId,
		TeamA = teamA,
		TeamB = teamB,
		Duration = PvPConfig.Match.DurationSeconds,
	}
	for _, player in teamA do
		Remotes.Event("PvPMatchFound"):FireClient(player, info)
	end
	for _, player in teamB do
		Remotes.Event("PvPMatchFound"):FireClient(player, info)
	end
	-- Arena teleport/round flow is handled by the arena map scripts, which
	-- call ReportRoundWinner below. Timeout failsafe:
	task.delay(PvPConfig.Match.DurationSeconds * PvPConfig.Match.BestOf + 60, function()
		if activeMatches[match.Id] then
			self:EndMatch(match, if match.ScoreA >= match.ScoreB then "A" else "B")
		end
	end)
end

function PvPService:ReportRoundWinner(matchId: string, team: "A" | "B")
	local match = activeMatches[matchId]
	if not match then
		return
	end
	if team == "A" then
		match.ScoreA += 1
	else
		match.ScoreB += 1
	end
	if match.ScoreA >= match.RoundsToWin then
		self:EndMatch(match, "A")
	elseif match.ScoreB >= match.RoundsToWin then
		self:EndMatch(match, "B")
	end
end

function PvPService:EndMatch(match: Match, winner: "A" | "B")
	activeMatches[match.Id] = nil
	local winners = if winner == "A" then match.TeamA else match.TeamB
	local losers = if winner == "A" then match.TeamB else match.TeamA
	local ranked = PvPConfig.Modes[match.Mode].Ranked
	local ratingKey = if match.Mode == "Arena3v3" then "Rating3v3" else "Rating1v1"

	for index, winnerPlayer in winners do
		playerMatch[winnerPlayer] = nil
		local profile = DataService:GetProfile(winnerPlayer)
		if profile then
			profile.Data.PvP.Wins += 1
			if ranked then
				local opposite = losers[math.min(index, #losers)]
				local loserProfile = opposite and DataService:GetProfile(opposite)
				if loserProfile then
					local delta = Formulas.EloChange(profile.Data.PvP[ratingKey], loserProfile.Data.PvP[ratingKey])
					profile.Data.PvP[ratingKey] += delta
				end
			end
			profile.Dirty = true
			QuestService:ReportProgress(winnerPlayer, "WinPvP", nil, 1)
			Remotes.Event("PvPMatchEnded"):FireClient(winnerPlayer,
				{ Won = true, NewRating = profile.Data.PvP[ratingKey], Rank = self:GetRankName(profile.Data.PvP[ratingKey]) })
		end
	end
	for index, loserPlayer in losers do
		playerMatch[loserPlayer] = nil
		local profile = DataService:GetProfile(loserPlayer)
		if profile then
			profile.Data.PvP.Losses += 1
			if ranked then
				local opposite = winners[math.min(index, #winners)]
				local winnerProfile = opposite and DataService:GetProfile(opposite)
				if winnerProfile then
					local _, loserDelta = Formulas.EloChange(winnerProfile.Data.PvP[ratingKey], profile.Data.PvP[ratingKey])
					profile.Data.PvP[ratingKey] = math.max(0, profile.Data.PvP[ratingKey] + loserDelta)
				end
			end
			profile.Dirty = true
			Remotes.Event("PvPMatchEnded"):FireClient(loserPlayer,
				{ Won = false, NewRating = profile.Data.PvP[ratingKey], Rank = self:GetRankName(profile.Data.PvP[ratingKey]) })
		end
	end
end

-- ------------------------------- LIFECYCLE ----------------------------------

function PvPService:Init(registry)
	DataService = registry.DataService
	QuestService = registry.QuestService
end

function PvPService:Start()
	Remotes.Function("PvPJoinQueue").OnServerInvoke = function(player, mode)
		if typeof(mode) ~= "string" then
			return false, "Invalid"
		end
		return self:JoinQueue(player, mode)
	end
	Remotes.Function("PvPLeaveQueue").OnServerInvoke = function(player)
		self:LeaveQueue(player)
		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		self:LeaveQueue(player)
		local match = playerMatch[player]
		if match then
			-- Leaver forfeits the match for their team.
			local onTeamA = table.find(match.TeamA, player) ~= nil
			self:EndMatch(match, if onTeamA then "B" else "A")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(PvPConfig.Matchmaking.QueueTickSeconds)
			for mode in PvPConfig.Modes do
				tryMatch(mode)
			end
		end
	end)
end

return PvPService
