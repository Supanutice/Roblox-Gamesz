--!strict
-- AntiCheatService.luau
-- Defense in depth:
--   1) The architecture itself: clients only REQUEST actions; every number
--      (damage, currency, items, cooldowns) is computed server-side.
--   2) This service: behavioral detection for what replication physics still
--      lets clients control — movement (speed/teleport/fly) — plus damage
--      ceilings, remote-spam throttling, and an escalation ledger.
-- Philosophy: flag and accumulate evidence; kick on strong signals; never
-- punish on a single noisy sample (lag happens).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Configs.CombatConfig)

local AntiCheatService = { Name = "AntiCheatService" }

local DataService

type Tracker = {
	LastPosition: Vector3?,
	LastSampleAt: number,
	SpeedStrikes: number,
	BurstAllowedUntil: number,  -- dash windows whitelisted by CombatService
	TeleportAllowed: boolean,   -- one-shot pass set by FastTravel/arena TP
	RemoteCalls: number,        -- rolling per-window remote counter
	Flags: { [string]: number },
	FlagScore: number,
}

local trackers: { [Player]: Tracker } = {}

local SAMPLE_INTERVAL = 0.5
local SPEED_STRIKES_BEFORE_RUBBERBAND = 3
local FLAG_SCORE_KICK_THRESHOLD = 25
local REMOTE_CALLS_PER_WINDOW = 60 -- per SAMPLE_INTERVAL across all combat remotes

local FLAG_WEIGHTS: { [string]: number } = {
	M1RateLimit = 1,
	BadSkillSlot = 3,
	UltimateNoEnergy = 3,
	SpeedHack = 5,
	Teleport = 5,
	RemoteSpam = 2,
	DamageCeiling = 8,
}

-- ------------------------------ PUBLIC API ----------------------------------

-- Combat systems call this when a client request fails validation in a way
-- that legitimate clients never produce.
function AntiCheatService:Flag(player: Player, reason: string)
	local tracker = trackers[player]
	if not tracker then
		return
	end
	tracker.Flags[reason] = (tracker.Flags[reason] or 0) + 1
	tracker.FlagScore += FLAG_WEIGHTS[reason] or 1

	if tracker.FlagScore >= FLAG_SCORE_KICK_THRESHOLD then
		local profile = DataService and DataService:GetProfile(player)
		if profile then
			profile.Data.Moderation.ExploitFlags += 1
			profile.Dirty = true
		end
		warn(`[AntiCheat] Kicking {player.Name}: score {tracker.FlagScore}`, tracker.Flags)
		player:Kick("Disconnected: irregular client behavior detected.")
	end
end

-- CombatService whitelists short bursts of high speed (dashes, knockback).
function AntiCheatService:AllowBurst(player: Player, duration: number)
	local tracker = trackers[player]
	if tracker then
		tracker.BurstAllowedUntil = math.max(tracker.BurstAllowedUntil, os.clock() + duration)
	end
end

-- SpawnerService/PvPService whitelist legitimate server-side teleports.
function AntiCheatService:AllowTeleport(player: Player)
	local tracker = trackers[player]
	if tracker then
		tracker.TeleportAllowed = true
	end
end

-- DamageService routes all outgoing damage through here. The ceiling is a
-- tripwire for stat-injection exploits, not a balance lever.
function AntiCheatService:ClampDamage(attacker: Model, damage: number): number
	local atk = attacker:GetAttribute("ATK") :: number? or 10
	-- Max conceivable multiplier: Divine ultimate (10x) * awakening * crit *
	-- element * variance ≈ 30x ATK. Anything beyond 50x is an exploit.
	local ceiling = atk * 50
	if damage > ceiling then
		local player = Players:GetPlayerFromCharacter(attacker)
		if player then
			self:Flag(player, "DamageCeiling")
		end
		return math.floor(ceiling)
	end
	return damage
end

-- Combat remote handlers call this first; returns false when throttled.
function AntiCheatService:CheckRemoteBudget(player: Player): boolean
	local tracker = trackers[player]
	if not tracker then
		return false
	end
	tracker.RemoteCalls += 1
	if tracker.RemoteCalls > REMOTE_CALLS_PER_WINDOW then
		self:Flag(player, "RemoteSpam")
		return false
	end
	return true
end

-- ---------------------------- MOVEMENT WATCH --------------------------------

local function sample(player: Player, tracker: Tracker)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		tracker.LastPosition = nil
		return
	end
	local now = os.clock()
	local dt = now - tracker.LastSampleAt
	tracker.LastSampleAt = now
	tracker.RemoteCalls = 0 -- window reset

	local position = root.Position
	if tracker.LastPosition and dt > 0 then
		local delta = position - tracker.LastPosition
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local speed = horizontal / dt

		if horizontal > CombatConfig.Movement.TeleportToleranceStuds then
			if tracker.TeleportAllowed then
				tracker.TeleportAllowed = false
			else
				AntiCheatService:Flag(player, "Teleport")
				root.CFrame = CFrame.new(tracker.LastPosition) -- rubber-band
				tracker.LastPosition = nil
				return
			end
		elseif speed > CombatConfig.Movement.MaxHorizontalSpeed then
			local inBurst = now < tracker.BurstAllowedUntil and speed <= CombatConfig.Movement.MaxDashSpeed
			if not inBurst then
				tracker.SpeedStrikes += 1
				if tracker.SpeedStrikes >= SPEED_STRIKES_BEFORE_RUBBERBAND then
					tracker.SpeedStrikes = 0
					AntiCheatService:Flag(player, "SpeedHack")
					root.CFrame = CFrame.new(tracker.LastPosition)
					tracker.LastPosition = nil
					return
				end
			end
		else
			tracker.SpeedStrikes = math.max(0, tracker.SpeedStrikes - 1)
		end
	end
	tracker.LastPosition = position
end

-- ------------------------------- LIFECYCLE ----------------------------------

function AntiCheatService:Init(registry)
	DataService = registry.DataService
end

function AntiCheatService:Start()
	Players.PlayerAdded:Connect(function(player)
		trackers[player] = {
			LastPosition = nil,
			LastSampleAt = os.clock(),
			SpeedStrikes = 0,
			BurstAllowedUntil = 0,
			TeleportAllowed = false,
			RemoteCalls = 0,
			Flags = {},
			FlagScore = 0,
		}
		-- Respawn = legitimate position jump.
		player.CharacterAdded:Connect(function()
			local tracker = trackers[player]
			if tracker then
				tracker.LastPosition = nil
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SAMPLE_INTERVAL)
			for player, tracker in trackers do
				sample(player, tracker)
			end
		end
	end)

	-- Flag scores decay so laggy-but-honest players recover.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, tracker in trackers do
				tracker.FlagScore = math.max(0, tracker.FlagScore - 2)
			end
		end
	end)
end

return AntiCheatService
