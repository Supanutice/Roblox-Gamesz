--!strict
-- DataService.luau
-- Secure player persistence following the ProfileService pattern:
--   * Session locking via UpdateAsync (no two servers own one profile)
--   * Auto-save every GameConfig.Server.AutoSaveIntervalSeconds
--   * Reconciliation of old profiles against the latest template
--   * Ordered backup snapshots (last 3 saves) for support restores
-- ALL writes to player data flow through this service's mutation API so
-- AntiCheatService can audit a single choke point.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local TableUtil = require(Shared.Utilities.TableUtil)
local Signal = require(Shared.Utilities.Signal)
local Remotes = require(Shared.Net.Remotes)

local STORE_NAME = "PlayerProfiles_v" .. GameConfig.DataStoreVersion
local BACKUP_STORE_NAME = STORE_NAME .. "_Backups"
local LOCK_TIMEOUT = GameConfig.Server.ProfileSessionLockTimeoutSeconds

-- ============================ PROFILE TEMPLATE =============================

local PROFILE_TEMPLATE = {
	SchemaVersion = 1,
	CreatedAt = 0,
	LastSeenAt = 0,
	TotalPlaySeconds = 0,

	Level = 1,
	XP = 0,

	Currencies = {
		Gold = GameConfig.Currencies.Gold.StartingAmount,
		Gems = GameConfig.Currencies.Gems.StartingAmount,
		RaidTokens = 0,
		EventCurrency = 0,
	},

	-- Owned characters: uid -> instance data. uid is a GUID minted on acquire.
	Characters = {} :: { [string]: {
		CharacterId: string, -- CharacterDatabase id
		Level: number,
		XP: number,
		EvolutionStage: number,
		Ascension: number,
		SkillLevels: { number }, -- [1]=Skill1 [2]=Skill2 [3]=Ultimate
		Shards: number,
		EquippedWeaponUid: string?,
		ObtainedAt: number,
		Locked: boolean, -- protects from accidental trade/sell
	} },
	TeamSlots = {} :: { string }, -- up to 3 character uids

	Inventory = {} :: { [string]: {
		ItemId: string,
		Count: number,
		WeaponLevel: number?, -- weapons only
	} },

	Quests = {
		Active = {} :: { [string]: { Progress: { number }, AcceptedAt: number } },
		Completed = {} :: { [string]: boolean },
		LastDailyReset = 0,
		LastWeeklyReset = 0,
	},

	Gacha = {
		PityCounter = {} :: { [string]: number },       -- bannerId -> pulls since Legendary+
		MythicPityCounter = {} :: { [string]: number }, -- bannerId -> pulls since Mythic+
		TotalPulls = 0,
		LostFiftyFifty = {} :: { [string]: boolean },   -- guaranteed-featured tracking
	},

	PvP = {
		Rating1v1 = 1000,
		Rating3v3 = 1000,
		Wins = 0,
		Losses = 0,
		SeasonId = 0,
	},

	GuildId = nil :: string?,

	Progress = {
		UnlockedWorlds = { W1_BEGINNER_ISLAND = true } :: { [string]: boolean },
		UnlockedFastTravel = {} :: { [string]: boolean },
		FoundSecrets = {} :: { [string]: boolean },
		BossKills = {} :: { [string]: number },
	},

	BattlePass = {
		SeasonId = 0,
		Tier = 0,
		XP = 0,
		PremiumOwned = false,
		ClaimedFree = {} :: { [number]: boolean },
		ClaimedPremium = {} :: { [number]: boolean },
	},

	DailyRewards = { Streak = 0, LastClaimUnix = 0 },

	Cosmetics = {
		Owned = {} :: { [string]: boolean },
		EquippedSkin = nil :: string?,
		EquippedAura = nil :: string?,
		EquippedTitle = nil :: string?,
	},

	Settings = {
		MusicVolume = 0.7,
		SFXVolume = 1.0,
		ScreenShake = true,
		DamageNumbers = true,
		AutoLockTarget = true,
	},

	Moderation = {
		TradeBannedUntil = 0,
		ExploitFlags = 0,
	},
}

-- ================================ SERVICE ==================================

export type Profile = {
	Data: typeof(PROFILE_TEMPLATE),
	UserId: number,
	SessionId: string,
	Dirty: boolean,
}

local DataService = {
	Name = "DataService",
	ProfileLoaded = Signal.new(), -- (player, profile)
	ProfileReleasing = Signal.new(), -- (player, profile)
}

local profiles: { [Player]: Profile } = {}
local store: DataStore
local backupStore: DataStore
local registry: { [string]: any }

local function jobSessionId(): string
	return game.JobId ~= "" and game.JobId or "studio"
end

-- ----------------------------- LOAD / LOCK --------------------------------

local function loadProfile(player: Player): Profile?
	local key = "p_" .. player.UserId
	local sessionId = jobSessionId() .. "/" .. os.time()
	local loadedData: any = nil
	local lockRejected = false

	for attempt = 1, 5 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored: any)
				stored = stored or { Data = nil, Lock = nil }
				local lock = stored.Lock
				if lock and lock.SessionId ~= sessionId and (os.time() - lock.Timestamp) < LOCK_TIMEOUT then
					-- Another live server owns this profile. Do not steal.
					lockRejected = true
					return nil -- abort write
				end
				stored.Lock = { SessionId = sessionId, Timestamp = os.time() }
				loadedData = stored.Data
				lockRejected = false
				return stored
			end)
		end)
		if ok and not lockRejected then
			break
		end
		if lockRejected then
			-- Old server may be mid-shutdown; wait for its lock to clear.
			task.wait(5)
		else
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {err}`)
			task.wait(2 ^ attempt)
		end
	end

	if lockRejected then
		player:Kick("Your data is still saving from another server. Please rejoin in a minute.")
		return nil
	end

	local data = loadedData or TableUtil.DeepCopy(PROFILE_TEMPLATE)
	TableUtil.Reconcile(data, PROFILE_TEMPLATE)
	if data.CreatedAt == 0 then
		data.CreatedAt = os.time()
	end
	data.LastSeenAt = os.time()

	return {
		Data = data,
		UserId = player.UserId,
		SessionId = sessionId,
		Dirty = false,
	}
end

local function saveProfile(profile: Profile, releaseLock: boolean)
	local key = "p_" .. profile.UserId
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored: any)
				stored = stored or {}
				-- Only the lock owner may write.
				if stored.Lock and stored.Lock.SessionId ~= profile.SessionId then
					return nil
				end
				stored.Data = profile.Data
				stored.Lock = if releaseLock then nil else { SessionId = profile.SessionId, Timestamp = os.time() }
				return stored
			end)
		end)
		if ok then
			profile.Dirty = false
			break
		end
		warn(`[DataService] Save attempt {attempt} failed for {profile.UserId}: {err}`)
		task.wait(2 ^ attempt)
	end

	-- Rolling backup (best effort, never blocks the main save).
	task.spawn(function()
		pcall(function()
			backupStore:SetAsync(key .. "_" .. (os.time() % 3), { Data = profile.Data, SavedAt = os.time() })
		end)
	end)
end

-- ------------------------------ PUBLIC API ---------------------------------

function DataService:GetProfile(player: Player): Profile?
	return profiles[player]
end

-- Yields until the player's profile is loaded (or they leave).
function DataService:WaitForProfile(player: Player): Profile?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService:GetCurrency(player: Player, currency: string): number
	local profile = profiles[player]
	return profile and profile.Data.Currencies[currency] or 0
end

function DataService:AddCurrency(player: Player, currency: string, amount: number): boolean
	assert(amount >= 0 and amount == amount and amount ~= math.huge, "invalid amount")
	local profile = profiles[player]
	local config = GameConfig.Currencies[currency]
	if not profile or not config then
		return false
	end
	local balance = profile.Data.Currencies[currency] or 0
	profile.Data.Currencies[currency] = math.min(balance + math.floor(amount), config.MaxAmount)
	profile.Dirty = true
	Remotes.Event("CurrencyChanged"):FireClient(player, currency, profile.Data.Currencies[currency])
	return true
end

-- Atomic spend: returns false (and changes nothing) if balance insufficient.
function DataService:SpendCurrency(player: Player, currency: string, amount: number): boolean
	assert(amount >= 0 and amount == amount and amount ~= math.huge, "invalid amount")
	local profile = profiles[player]
	if not profile then
		return false
	end
	amount = math.floor(amount)
	local balance = profile.Data.Currencies[currency] or 0
	if balance < amount then
		return false
	end
	profile.Data.Currencies[currency] = balance - amount
	profile.Dirty = true
	Remotes.Event("CurrencyChanged"):FireClient(player, currency, profile.Data.Currencies[currency])
	return true
end

function DataService:AddXP(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local Formulas = require(Shared.Utilities.Formulas)
	local ProgressionConfig = require(Shared.Configs.ProgressionConfig)
	profile.Data.XP += math.floor(amount)
	while profile.Data.Level < ProgressionConfig.LevelCap
		and profile.Data.XP >= Formulas.XPForLevel(profile.Data.Level) do
		profile.Data.XP -= Formulas.XPForLevel(profile.Data.Level)
		profile.Data.Level += 1
	end
	profile.Dirty = true
end

-- ------------------------------- LIFECYCLE ---------------------------------

local function onPlayerAdded(player: Player)
	local profile = loadProfile(player)
	if not profile then
		return
	end
	if not player.Parent then
		-- Player left during the (yielding) load; release immediately.
		saveProfile(profile, true)
		return
	end
	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	-- Snapshot for the client (UI state). Never send Moderation.
	local snapshot = TableUtil.DeepCopy(profile.Data)
	snapshot.Moderation = nil
	Remotes.Event("ProfileLoaded"):FireClient(player, snapshot)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	profile.Data.LastSeenAt = os.time()
	DataService.ProfileReleasing:Fire(player, profile)
	saveProfile(profile, true)
end

function DataService:Init(serviceRegistry)
	registry = serviceRegistry
	store = DataStoreService:GetDataStore(STORE_NAME)
	backupStore = DataStoreService:GetDataStore(BACKUP_STORE_NAME)
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Auto-save loop.
	task.spawn(function()
		while true do
			task.wait(GameConfig.Server.AutoSaveIntervalSeconds)
			for _, profile in profiles do
				if profile.Dirty then
					task.spawn(saveProfile, profile, false)
				end
			end
		end
	end)

	-- Playtime tracker.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, profile in profiles do
				profile.Data.TotalPlaySeconds += 60
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local saving = 0
		for player, profile in profiles do
			saving += 1
			task.spawn(function()
				saveProfile(profile, true)
				saving -= 1
			end)
		end
		while saving > 0 do
			task.wait(0.1)
		end
	end)
end

return DataService
