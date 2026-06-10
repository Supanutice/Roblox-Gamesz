--!strict
-- PartyService.luau
-- In-server parties (max 4): invite -> accept flow, leader promotion on
-- leave, kicks, and a state push to every member on any change. Dungeons
-- (and later raids) consume parties via GetMembers().

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Configs.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local PartyService = { Name = "PartyService" }

type Party = {
	Id: string,
	Leader: Player,
	Members: { Player },
}

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { Party: Party, From: Player, ExpiresAt: number } } = {}

local INVITE_TTL = 60

-- ------------------------------ STATE PUSH ----------------------------------

local function partyView(party: Party)
	local members = {}
	for _, member in party.Members do
		table.insert(members, { UserId = member.UserId, Name = member.DisplayName })
	end
	return { Id = party.Id, LeaderUserId = party.Leader.UserId, Members = members }
end

local function pushParty(party: Party)
	local view = partyView(party)
	for _, member in party.Members do
		Remotes.Event("PartyUpdated"):FireClient(member, { Party = view })
	end
end

-- ------------------------------- ACTIONS -------------------------------------

local function createParty(leader: Player): Party
	local party: Party = {
		Id = HttpService:GenerateGUID(false),
		Leader = leader,
		Members = { leader },
	}
	partyOf[leader] = party
	return party
end

local function removeMember(party: Party, player: Player)
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	partyOf[player] = nil
	Remotes.Event("PartyUpdated"):FireClient(player, { Party = nil })

	if #party.Members == 0 then
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	pushParty(party)
end

function PartyService:Invite(player: Player, targetUserId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "Player not found"
	end
	if partyOf[target] then
		return false, "Already in a party"
	end
	local party = partyOf[player]
	if party and party.Leader ~= player then
		return false, "Only the leader can invite"
	end
	if not party then
		party = createParty(player)
		pushParty(party)
	end
	if #party.Members >= GameConfig.Limits.MaxPartySize then
		return false, "Party full"
	end
	invites[target] = { Party = party, From = player, ExpiresAt = os.clock() + INVITE_TTL }
	Remotes.Event("PartyUpdated"):FireClient(target, {
		Invite = { FromUserId = player.UserId, FromName = player.DisplayName },
	})
	return true
end

function PartyService:Accept(player: Player): (boolean, string?)
	local invite = invites[player]
	invites[player] = nil
	if not invite or os.clock() > invite.ExpiresAt then
		return false, "Invite expired"
	end
	if partyOf[player] then
		return false, "Already in a party"
	end
	local party = invite.Party
	-- Party may have dissolved or filled while the invite sat.
	if #party.Members == 0 or partyOf[party.Leader] ~= party then
		return false, "Party no longer exists"
	end
	if #party.Members >= GameConfig.Limits.MaxPartySize then
		return false, "Party full"
	end
	table.insert(party.Members, player)
	partyOf[player] = party
	pushParty(party)
	return true
end

function PartyService:Leave(player: Player): (boolean, string?)
	local party = partyOf[player]
	if not party then
		return false, "Not in a party"
	end
	removeMember(party, player)
	return true
end

function PartyService:Kick(player: Player, targetUserId: number): (boolean, string?)
	local party = partyOf[player]
	if not party or party.Leader ~= player then
		return false, "Only the leader can kick"
	end
	for _, member in party.Members do
		if member.UserId == targetUserId and member ~= player then
			removeMember(party, member)
			return true
		end
	end
	return false, "Member not found"
end

-- The party a player acts with: their party's members, or just themselves.
function PartyService:GetMembers(player: Player): { Player }
	local party = partyOf[player]
	if party then
		return table.clone(party.Members)
	end
	return { player }
end

function PartyService:IsLeader(player: Player): boolean
	local party = partyOf[player]
	return party == nil or party.Leader == player
end

-- ------------------------------- LIFECYCLE -----------------------------------

function PartyService:Init() end

function PartyService:Start()
	Remotes.Function("PartyAction").OnServerInvoke = function(player, action, payload)
		if typeof(action) ~= "string" or (payload ~= nil and typeof(payload) ~= "table") then
			return false, "Invalid request"
		end
		payload = payload or {}
		if action == "Invite" then
			if typeof(payload.UserId) ~= "number" then
				return false, "Invalid"
			end
			return self:Invite(player, payload.UserId)
		elseif action == "Accept" then
			return self:Accept(player)
		elseif action == "Decline" then
			invites[player] = nil
			return true
		elseif action == "Leave" then
			return self:Leave(player)
		elseif action == "Kick" then
			if typeof(payload.UserId) ~= "number" then
				return false, "Invalid"
			end
			return self:Kick(player, payload.UserId)
		elseif action == "Get" then
			local party = partyOf[player]
			return true, if party then partyView(party) else nil
		end
		return false, "Unknown action"
	end

	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local party = partyOf[player]
		if party then
			removeMember(party, player)
		end
	end)
end

return PartyService
