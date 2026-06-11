--!strict
-- GuildService.luau
-- Guild creation, membership, ranks, leveling, chat relay, raids, wars.
-- Guild documents live in their own DataStore keyed by guild id and are
-- synchronized across servers via MessagingService; per-player membership
-- is the GuildId field on the player profile.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuildConfig = require(Shared.Configs.GuildConfig)
local Remotes = require(Shared.Net.Remotes)

local GuildService = { Name = "GuildService" }

local DataService
local registry: { [string]: any }

local guildStore: DataStore
-- Server-local cache of guild docs this server's players belong to.
local guildCache: { [string]: any } = {}
-- Pending guild invites (in-server): invitee -> info.
local guildInvites: { [Player]: { GuildId: string, GuildName: string, ExpiresAt: number } } = {}

type GuildDoc = {
	Id: string,
	Name: string,
	CreatedAt: number,
	LeaderUserId: number,
	-- userId(string) -> { Rank: string, JoinedAt: number, Contribution: number }
	Members: { [string]: { Rank: string, JoinedAt: number, Contribution: number } },
	Level: number,
	XP: number,
	MOTD: string,
	RaidAttemptsThisWeek: number,
	WeekStamp: number,
	WarScore: number,
}

-- ----------------------------- PERSISTENCE ---------------------------------

local function loadGuild(guildId: string): GuildDoc?
	if guildCache[guildId] then
		return guildCache[guildId]
	end
	local ok, doc = pcall(function()
		return guildStore:GetAsync("g_" .. guildId)
	end)
	if ok and doc then
		guildCache[guildId] = doc
	end
	return ok and doc or nil
end

-- All mutations go through UpdateAsync so concurrent servers can't clobber.
local function mutateGuild(guildId: string, mutator: (GuildDoc) -> boolean): (boolean, GuildDoc?)
	local result: GuildDoc? = nil
	local ok = pcall(function()
		guildStore:UpdateAsync("g_" .. guildId, function(doc: any)
			if not doc then
				return nil
			end
			if mutator(doc) then
				result = doc
				return doc
			end
			return nil -- mutation rejected; no write
		end)
	end)
	if result then
		guildCache[guildId] = result
		-- Tell other servers to refresh their cache.
		pcall(function()
			MessagingService:PublishAsync("GuildUpdated", guildId)
		end)
	end
	return ok and result ~= nil, result
end

-- ------------------------------ PERMISSIONS --------------------------------

local function hasPermission(doc: GuildDoc, userId: number, permission: string): boolean
	local member = doc.Members[tostring(userId)]
	if not member then
		return false
	end
	local permissions = GuildConfig.Permissions[member.Rank]
	return permissions ~= nil and table.find(permissions, permission) ~= nil
end

-- -------------------------------- ACTIONS ----------------------------------

function GuildService:CreateGuild(player: Player, name: string): (boolean, any)
	if typeof(name) ~= "string" then
		return false, "Invalid name"
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if #name < GuildConfig.NameMinLength or #name > GuildConfig.NameMaxLength then
		return false, "Name must be 3-20 characters"
	end
	-- Filter the name (moderation requirement).
	local filtered
	local ok = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or filtered ~= name then
		return false, "Name not allowed"
	end

	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if profile.Data.GuildId then
		return false, "Already in a guild"
	end
	if not DataService:SpendCurrency(player, "Gems", GuildConfig.CreateCostGems) then
		return false, "Not enough Gems"
	end

	local guildId = HttpService:GenerateGUID(false)
	local doc: GuildDoc = {
		Id = guildId,
		Name = name,
		CreatedAt = os.time(),
		LeaderUserId = player.UserId,
		Members = { [tostring(player.UserId)] = { Rank = "Leader", JoinedAt = os.time(), Contribution = 0 } },
		Level = 1,
		XP = 0,
		MOTD = "Welcome to " .. name .. "!",
		RaidAttemptsThisWeek = 0,
		WeekStamp = math.floor(os.time() / 604800),
		WarScore = 0,
	}
	local saved = pcall(function()
		guildStore:SetAsync("g_" .. guildId, doc)
	end)
	if not saved then
		DataService:AddCurrency(player, "Gems", GuildConfig.CreateCostGems) -- refund
		return false, "Save failed, try again"
	end
	guildCache[guildId] = doc
	profile.Data.GuildId = guildId
	profile.Dirty = true
	return true, doc
end

function GuildService:JoinGuild(player: Player, guildId: string): (boolean, any)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if profile.Data.GuildId then
		return false, "Already in a guild"
	end
	local ok, doc = mutateGuild(guildId, function(doc)
		local count = 0
		for _ in doc.Members do
			count += 1
		end
		if count >= GuildConfig.MaxMembers then
			return false
		end
		doc.Members[tostring(player.UserId)] = { Rank = "Member", JoinedAt = os.time(), Contribution = 0 }
		return true
	end)
	if not ok then
		return false, "Guild full or unavailable"
	end
	profile.Data.GuildId = guildId
	profile.Dirty = true
	return true, doc
end

function GuildService:LeaveGuild(player: Player): (boolean, string?)
	local profile = DataService:GetProfile(player)
	local guildId = profile and profile.Data.GuildId
	if not guildId then
		return false, "Not in a guild"
	end
	mutateGuild(guildId, function(doc)
		if doc.LeaderUserId == player.UserId then
			-- Leader leaving promotes the oldest officer/member, or disbands.
			local successorId: string? = nil
			local oldest = math.huge
			for userId, member in doc.Members do
				if userId ~= tostring(player.UserId) and member.JoinedAt < oldest then
					oldest = member.JoinedAt
					successorId = userId
				end
			end
			if successorId then
				doc.LeaderUserId = tonumber(successorId) :: number
				doc.Members[successorId].Rank = "Leader"
			end
		end
		doc.Members[tostring(player.UserId)] = nil
		return true
	end)
	profile.Data.GuildId = nil
	profile.Dirty = true
	return true
end

function GuildService:KickMember(player: Player, targetUserId: number): (boolean, string?)
	local profile = DataService:GetProfile(player)
	local guildId = profile and profile.Data.GuildId
	if not guildId then
		return false, "Not in a guild"
	end
	local ok = mutateGuild(guildId, function(doc)
		if not hasPermission(doc, player.UserId, "Kick") then
			return false
		end
		local target = doc.Members[tostring(targetUserId)]
		if not target or target.Rank == "Leader" then
			return false
		end
		doc.Members[tostring(targetUserId)] = nil
		return true
	end)
	return ok, if ok then nil else "Not permitted"
end

function GuildService:AddGuildXP(guildId: string, amount: number)
	mutateGuild(guildId, function(doc)
		doc.XP += amount
		local needed = math.floor(GuildConfig.Leveling.XPPerLevelBase * doc.Level ^ 1.6)
		while doc.Level < GuildConfig.Leveling.MaxLevel and doc.XP >= needed do
			doc.XP -= needed
			doc.Level += 1
			needed = math.floor(GuildConfig.Leveling.XPPerLevelBase * doc.Level ^ 1.6)
		end
		return true
	end)
end

function GuildService:GetGuild(guildId: string)
	return loadGuild(guildId)
end

-- Atomically validates permission + weekly attempts, consumes one attempt,
-- and returns this week's rotation boss. Called by RaidService.
function GuildService:ConsumeRaidAttempt(player: Player): (boolean, string?, { GuildId: string, BossId: string }?)
	local profile = DataService:GetProfile(player)
	local guildId = profile and profile.Data.GuildId
	if not guildId then
		return false, "Not in a guild"
	end
	local week = math.floor(os.time() / 604_800)
	local bossId = GuildConfig.Raids.BossRotation[(week % #GuildConfig.Raids.BossRotation) + 1]
	local denyReason = "No permission"
	local ok = mutateGuild(guildId, function(doc)
		if not hasPermission(doc, player.UserId, "StartRaid") then
			denyReason = "Only leaders/officers can start raids"
			return false
		end
		if doc.WeekStamp ~= week then
			doc.WeekStamp = week
			doc.RaidAttemptsThisWeek = 0
		end
		if doc.RaidAttemptsThisWeek >= GuildConfig.Raids.WeeklyAttempts then
			denyReason = "No raid attempts left this week"
			return false
		end
		doc.RaidAttemptsThisWeek += 1
		return true
	end)
	if not ok then
		return false, denyReason
	end
	return true, nil, { GuildId = guildId, BossId = bossId }
end

-- ------------------------------- LIFECYCLE ----------------------------------

function GuildService:Init(serviceRegistry)
	registry = serviceRegistry
	DataService = serviceRegistry.DataService
	guildStore = DataStoreService:GetDataStore("Guilds_v1")
end

function GuildService:Start()
	pcall(function()
		MessagingService:SubscribeAsync("GuildUpdated", function(message)
			guildCache[message.Data] = nil -- force re-read on next access
		end)
	end)

	Remotes.Function("GuildAction").OnServerInvoke = function(player, action, payload)
		if typeof(action) ~= "string" or (payload ~= nil and typeof(payload) ~= "table") then
			return false, "Invalid request"
		end
		payload = payload or {}
		if action == "Create" then
			return self:CreateGuild(player, payload.Name)
		elseif action == "Join" then
			if typeof(payload.GuildId) ~= "string" then
				return false, "Invalid"
			end
			return self:JoinGuild(player, payload.GuildId)
		elseif action == "Leave" then
			return self:LeaveGuild(player)
		elseif action == "Kick" then
			if typeof(payload.UserId) ~= "number" then
				return false, "Invalid"
			end
			return self:KickMember(player, payload.UserId)
		elseif action == "Get" then
			local profile = DataService:GetProfile(player)
			local guildId = profile and profile.Data.GuildId
			return true, if guildId then loadGuild(guildId) else nil
		elseif action == "SetMOTD" then
			local profile = DataService:GetProfile(player)
			local guildId = profile and profile.Data.GuildId
			if not guildId or typeof(payload.MOTD) ~= "string" or #payload.MOTD > 200 then
				return false, "Invalid"
			end
			local ok = mutateGuild(guildId, function(doc)
				if not hasPermission(doc, player.UserId, "EditMOTD") then
					return false
				end
				doc.MOTD = payload.MOTD
				return true
			end)
			return ok
		elseif action == "Invite" then
			if typeof(payload.UserId) ~= "number" then
				return false, "Invalid"
			end
			local profile = DataService:GetProfile(player)
			local guildId = profile and profile.Data.GuildId
			if not guildId then
				return false, "Not in a guild"
			end
			local doc = loadGuild(guildId)
			if not doc or not hasPermission(doc, player.UserId, "Invite") then
				return false, "No invite permission"
			end
			local target = Players:GetPlayerByUserId(payload.UserId)
			if not target or target == player then
				return false, "Player not found"
			end
			local targetProfile = DataService:GetProfile(target)
			if not targetProfile or targetProfile.Data.GuildId then
				return false, "Player already has a guild"
			end
			guildInvites[target] = { GuildId = guildId, GuildName = doc.Name, ExpiresAt = os.clock() + 120 }
			Remotes.Event("GuildEvent"):FireClient(target, "Invite",
				{ GuildName = doc.Name, From = player.DisplayName })
			return true
		elseif action == "AcceptInvite" then
			local invite = guildInvites[player]
			guildInvites[player] = nil
			if not invite or os.clock() > invite.ExpiresAt then
				return false, "Invite expired"
			end
			return self:JoinGuild(player, invite.GuildId)
		elseif action == "StartRaid" then
			if registry.RaidService then
				return registry.RaidService:StartRaid(player)
			end
			return false, "Raids unavailable"
		end
		return false, "Unknown action"
	end

	Players.PlayerRemoving:Connect(function(player)
		guildInvites[player] = nil
	end)
end

return GuildService
