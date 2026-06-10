--!strict
-- ArenaService.luau
-- Physical side of PvP: when PvPService matches players, this service builds
-- an isolated arena, saves everyone's overworld position, teleports the
-- teams in, runs the round loop (countdown -> fight -> last team standing),
-- reports winners back to PvPService, and restores everyone afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PvPConfig = require(Shared.Configs.PvPConfig)
local Maid = require(Shared.Utilities.Maid)
local Remotes = require(Shared.Net.Remotes)

local ArenaService = { Name = "ArenaService" }

local services: { [string]: any }

local ARENA_ORIGIN = Vector3.new(0, 80, -8_000)
local ARENA_SPACING = 400
local ARENA_HALF_LENGTH = 40 -- spawn lines at ±this on Z
local MAX_SLOTS = 6
local ROUND_SECONDS = 90
local COUNTDOWN_SECONDS = 3

local slotUsed: { [number]: boolean } = {}

type ArenaRun = {
	Match: any,
	Base: Vector3,
	Slot: number,
	Container: Folder,
	SavedCFrames: { [Player]: CFrame },
	Maid: Maid.Maid,
	Active: boolean,
}

local runs: { [string]: ArenaRun } = {} -- matchId -> run

-- ------------------------------ ARENA BUILD ----------------------------------

local function buildArena(base: Vector3, mapId: string): Folder
	local container = Instance.new("Folder")
	container.Name = "PvPArena_" .. mapId

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(70, 2, ARENA_HALF_LENGTH * 2 + 30)
	floor.Position = base - Vector3.new(0, 1, 0)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(52, 48, 70)
	floor.Material = Enum.Material.Cobblestone
	floor.Parent = container

	-- Walls on all four sides.
	local wallSpecs = {
		{ Size = Vector3.new(70, 20, 4), Offset = Vector3.new(0, 9, ARENA_HALF_LENGTH + 17) },
		{ Size = Vector3.new(70, 20, 4), Offset = Vector3.new(0, 9, -(ARENA_HALF_LENGTH + 17)) },
		{ Size = Vector3.new(4, 20, ARENA_HALF_LENGTH * 2 + 34), Offset = Vector3.new(37, 9, 0) },
		{ Size = Vector3.new(4, 20, ARENA_HALF_LENGTH * 2 + 34), Offset = Vector3.new(-37, 9, 0) },
	}
	for index, spec in wallSpecs do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. index
		wall.Size = spec.Size
		wall.Position = base + spec.Offset
		wall.Anchored = true
		wall.Color = Color3.fromRGB(80, 70, 110)
		wall.Material = Enum.Material.Slate
		wall.Parent = container
	end

	-- Center line marker.
	local line = Instance.new("Part")
	line.Size = Vector3.new(70, 0.2, 1)
	line.Position = base + Vector3.new(0, 0.1, 0)
	line.Anchored = true
	line.CanCollide = false
	line.Color = Color3.fromRGB(255, 200, 80)
	line.Material = Enum.Material.Neon
	line.Parent = container

	container.Parent = workspace
	return container
end

-- ------------------------------ HELPERS --------------------------------------

local function allPlayers(match): { Player }
	local players = {}
	for _, player in match.TeamA do
		table.insert(players, player)
	end
	for _, player in match.TeamB do
		table.insert(players, player)
	end
	return players
end

local function announce(match, text: string)
	for _, player in allPlayers(match) do
		if player.Parent then
			Remotes.Event("NPCDialogue"):FireClient(player, "⚔ Arena", text)
		end
	end
end

local function teleportTo(player: Player, position: Vector3, lookAt: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		services.AntiCheatService:AllowTeleport(player)
		root.CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	end
end

-- Waits (up to timeout) for a player to have a living character.
local function waitForAlive(player: Player, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if not player.Parent then
			return false
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function aliveCount(team: { Player }): number
	local alive = 0
	for _, player in team do
		local humanoid = player.Parent and player.Character
			and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			alive += 1
		end
	end
	return alive
end

local function positionTeams(run: ArenaRun)
	local match = run.Match
	for index, player in match.TeamA do
		if waitForAlive(player, PvPConfig.Match.RespawnSeconds + 6) then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.Health = humanoid.MaxHealth
			local x = (index - (#match.TeamA + 1) / 2) * 8
			teleportTo(player, run.Base + Vector3.new(x, 4, -ARENA_HALF_LENGTH), run.Base)
		end
	end
	for index, player in match.TeamB do
		if waitForAlive(player, PvPConfig.Match.RespawnSeconds + 6) then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.Health = humanoid.MaxHealth
			local x = (index - (#match.TeamB + 1) / 2) * 8
			teleportTo(player, run.Base + Vector3.new(x, 4, ARENA_HALF_LENGTH), run.Base)
		end
	end
end

-- ------------------------------ ROUND LOOP ------------------------------------

local function runRounds(run: ArenaRun)
	local match = run.Match
	local roundNumber = 0
	while run.Active do
		roundNumber += 1
		positionTeams(run)
		announce(match, `Round {roundNumber} — {match.ScoreA} : {match.ScoreB}. Fight in {COUNTDOWN_SECONDS}…`)
		task.wait(COUNTDOWN_SECONDS)
		if not run.Active then
			return
		end
		announce(match, "FIGHT!")

		local roundDeadline = os.clock() + ROUND_SECONDS
		while run.Active do
			task.wait(0.5)
			local aliveA = aliveCount(match.TeamA)
			local aliveB = aliveCount(match.TeamB)
			if aliveA == 0 and aliveB == 0 then
				-- Double KO: replay the round.
				announce(match, "Double KO! Round replays.")
				break
			elseif aliveA == 0 then
				announce(match, "Round to Team B!")
				services.PvPService:ReportRoundWinner(match.Id, "B")
				break
			elseif aliveB == 0 then
				announce(match, "Round to Team A!")
				services.PvPService:ReportRoundWinner(match.Id, "A")
				break
			elseif os.clock() > roundDeadline then
				-- Timeout: side with more fighters standing takes the round.
				local winner = if aliveA >= aliveB then "A" else "B"
				announce(match, `Time! Round to Team {winner}.`)
				services.PvPService:ReportRoundWinner(match.Id, winner :: "A" | "B")
				break
			end
		end
		task.wait(2) -- ReportRoundWinner may have ended the match (MatchEnded clears Active)
	end
end

-- ------------------------------ LIFECYCLE -------------------------------------

local function onMatchStarted(match)
	local slot: number? = nil
	for index = 1, MAX_SLOTS do
		if not slotUsed[index] then
			slot = index
			break
		end
	end
	if not slot then
		-- No physical arena free; let the timeout failsafe settle the match.
		warn("[Arena] No free arena slots")
		return
	end
	slotUsed[slot :: number] = true

	local base = ARENA_ORIGIN + Vector3.new((slot :: number) * ARENA_SPACING, 0, 0)
	local run: ArenaRun = {
		Match = match,
		Base = base,
		Slot = slot :: number,
		Container = buildArena(base, PvPConfig.Modes[match.Mode].MapId),
		SavedCFrames = {},
		Maid = Maid.new(),
		Active = true,
	}
	runs[match.Id] = run

	for _, player in allPlayers(match) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			run.SavedCFrames[player] = root.CFrame
		end
	end

	run.Maid:GiveTask(task.spawn(runRounds, run))
end

local function onMatchEnded(match, winner: "A" | "B")
	local run = runs[match.Id]
	if not run then
		return
	end
	runs[match.Id] = nil
	run.Active = false
	announce(match, `Match over — Team {winner} wins {math.max(match.ScoreA, match.ScoreB)} : {math.min(match.ScoreA, match.ScoreB)}!`)

	task.delay(2.5, function()
		for _, player in allPlayers(match) do
			if player.Parent and waitForAlive(player, 8) then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
				humanoid.Health = humanoid.MaxHealth
				local saved = run.SavedCFrames[player]
				if saved then
					services.AntiCheatService:AllowTeleport(player)
					local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
					root.CFrame = saved
				end
			end
		end
		run.Maid:DoCleaning()
		run.Container:Destroy()
		slotUsed[run.Slot] = nil
	end)
end

function ArenaService:Init(registry)
	services = registry
end

function ArenaService:Start()
	services.PvPService.MatchStarted:Connect(onMatchStarted)
	services.PvPService.MatchEnded:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		for _, run in runs do
			run.SavedCFrames[player] = nil
		end
	end)
end

return ArenaService
