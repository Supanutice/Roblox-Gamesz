--!strict
-- TradeService.luau
-- Two-phase-commit trading with anti-duplication guarantees:
--   * Offered items are revalidated against live inventory at COMMIT time
--   * Both players must re-confirm after ANY offer change
--   * Items move atomically inside one server (no cross-server trades)
--   * Every completed trade is logged for support/rollback audits

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDatabase = require(Shared.Data.ItemDatabase)
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local Remotes = require(Shared.Net.Remotes)

local TradeService = { Name = "TradeService" }

local DataService, AntiCheatService

local tradeLog: DataStore

type Offer = {
	ItemUids: { string },      -- inventory uids
	CharacterUids: { string }, -- roster uids
	Gold: number,
	Confirmed: boolean,
}

type Trade = {
	Id: string,
	PlayerA: Player,
	PlayerB: Player,
	OfferA: Offer,
	OfferB: Offer,
	State: "Negotiating" | "Committing" | "Done",
	CreatedAt: number,
}

local trades: { [string]: Trade } = {}
local playerTrade: { [Player]: Trade } = {}

local function emptyOffer(): Offer
	return { ItemUids = {}, CharacterUids = {}, Gold = 0, Confirmed = false }
end

local function offerOf(trade: Trade, player: Player): Offer
	return if trade.PlayerA == player then trade.OfferA else trade.OfferB
end

local function pushState(trade: Trade)
	local view = {
		Id = trade.Id,
		PlayerA = trade.PlayerA.UserId,
		PlayerB = trade.PlayerB.UserId,
		OfferA = trade.OfferA,
		OfferB = trade.OfferB,
		State = trade.State,
	}
	Remotes.Event("TradeUpdated"):FireClient(trade.PlayerA, view)
	Remotes.Event("TradeUpdated"):FireClient(trade.PlayerB, view)
end

-- -------------------------- VALIDATION HELPERS -----------------------------

local function canTrade(player: Player): (boolean, string?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if os.time() < profile.Data.Moderation.TradeBannedUntil then
		return false, "Trading restricted"
	end
	return true
end

-- Validates an offer against the player's CURRENT inventory/roster.
local function validateOffer(player: Player, offer: Offer): (boolean, string?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if offer.Gold < 0 or offer.Gold ~= math.floor(offer.Gold) or offer.Gold > profile.Data.Currencies.Gold then
		return false, "Invalid gold"
	end
	local seen = {}
	for _, uid in offer.ItemUids do
		if seen[uid] then
			return false, "Duplicate entry"
		end
		seen[uid] = true
		local entry = profile.Data.Inventory[uid]
		if not entry then
			return false, "Item missing"
		end
		local def = ItemDatabase.ById[entry.ItemId]
		if not def or not def.Tradeable then
			return false, "Item not tradeable"
		end
	end
	for _, uid in offer.CharacterUids do
		if seen[uid] then
			return false, "Duplicate entry"
		end
		seen[uid] = true
		local character = profile.Data.Characters[uid]
		if not character then
			return false, "Character missing"
		end
		if character.Locked then
			return false, "Character locked"
		end
		local def = CharacterDatabase.ById[character.CharacterId]
		-- Secret/Divine units are account-bound.
		if def.Rarity == "Secret" or def.Rarity == "Divine" then
			return false, "Character not tradeable"
		end
		-- Equipped team members can't be traded mid-session.
		if table.find(profile.Data.TeamSlots, uid) then
			return false, "Unequip first"
		end
	end
	return true
end

-- ------------------------------- COMMIT -------------------------------------

local function transfer(from: Player, to: Player, offer: Offer)
	local fromProfile = DataService:GetProfile(from)
	local toProfile = DataService:GetProfile(to)
	assert(fromProfile and toProfile, "profiles vanished mid-commit")

	if offer.Gold > 0 then
		assert(DataService:SpendCurrency(from, "Gold", offer.Gold), "gold vanished")
		DataService:AddCurrency(to, "Gold", offer.Gold)
	end
	for _, uid in offer.ItemUids do
		local entry = fromProfile.Data.Inventory[uid]
		fromProfile.Data.Inventory[uid] = nil
		-- Fresh uid on the receiving side prevents uid-collision dupes.
		toProfile.Data.Inventory[HttpService:GenerateGUID(false)] = entry
	end
	for _, uid in offer.CharacterUids do
		local character = fromProfile.Data.Characters[uid]
		fromProfile.Data.Characters[uid] = nil
		toProfile.Data.Characters[HttpService:GenerateGUID(false)] = character
	end
	fromProfile.Dirty = true
	toProfile.Dirty = true
end

local function commitTrade(trade: Trade): (boolean, string?)
	trade.State = "Committing"
	-- FINAL revalidation: inventory may have changed since the offer was made.
	local okA, errA = validateOffer(trade.PlayerA, trade.OfferA)
	local okB, errB = validateOffer(trade.PlayerB, trade.OfferB)
	if not okA or not okB then
		trade.State = "Negotiating"
		trade.OfferA.Confirmed = false
		trade.OfferB.Confirmed = false
		pushState(trade)
		return false, errA or errB
	end

	transfer(trade.PlayerA, trade.PlayerB, trade.OfferA)
	transfer(trade.PlayerB, trade.PlayerA, trade.OfferB)
	trade.State = "Done"
	pushState(trade)

	-- Audit log (best-effort, async).
	task.spawn(function()
		pcall(function()
			tradeLog:SetAsync(trade.Id, {
				At = os.time(),
				A = trade.PlayerA.UserId,
				B = trade.PlayerB.UserId,
				OfferA = { Items = trade.OfferA.ItemUids, Characters = trade.OfferA.CharacterUids, Gold = trade.OfferA.Gold },
				OfferB = { Items = trade.OfferB.ItemUids, Characters = trade.OfferB.CharacterUids, Gold = trade.OfferB.Gold },
			})
		end)
	end)

	trades[trade.Id] = nil
	playerTrade[trade.PlayerA] = nil
	playerTrade[trade.PlayerB] = nil
	return true
end

local function cancelTrade(trade: Trade)
	trades[trade.Id] = nil
	playerTrade[trade.PlayerA] = nil
	playerTrade[trade.PlayerB] = nil
	trade.State = "Done"
	pushState(trade)
end

-- ------------------------------- LIFECYCLE ----------------------------------

function TradeService:Init(registry)
	DataService = registry.DataService
	AntiCheatService = registry.AntiCheatService
	tradeLog = DataStoreService:GetDataStore("TradeLog_v1")
end

function TradeService:Start()
	Remotes.Function("TradeAction").OnServerInvoke = function(player, action, payload)
		if typeof(action) ~= "string" or (payload ~= nil and typeof(payload) ~= "table") then
			return false, "Invalid request"
		end
		payload = payload or {}

		if action == "Request" then
			local ok, err = canTrade(player)
			if not ok then
				return false, err
			end
			local target = typeof(payload.UserId) == "number" and Players:GetPlayerByUserId(payload.UserId)
			if not target or target == player then
				return false, "Player not found"
			end
			local targetOk = canTrade(target)
			if not targetOk then
				return false, "Partner cannot trade"
			end
			if playerTrade[player] or playerTrade[target] then
				return false, "Trade already in progress"
			end
			local trade: Trade = {
				Id = HttpService:GenerateGUID(false),
				PlayerA = player,
				PlayerB = target,
				OfferA = emptyOffer(),
				OfferB = emptyOffer(),
				State = "Negotiating",
				CreatedAt = os.time(),
			}
			trades[trade.Id] = trade
			playerTrade[player] = trade
			playerTrade[target] = trade
			pushState(trade)
			return true, trade.Id

		elseif action == "SetOffer" then
			local trade = playerTrade[player]
			if not trade or trade.State ~= "Negotiating" then
				return false, "No active trade"
			end
			local offer = offerOf(trade, player)
			offer.ItemUids = typeof(payload.ItemUids) == "table" and payload.ItemUids or {}
			offer.CharacterUids = typeof(payload.CharacterUids) == "table" and payload.CharacterUids or {}
			offer.Gold = typeof(payload.Gold) == "number" and math.max(0, math.floor(payload.Gold)) or 0
			local ok, err = validateOffer(player, offer)
			if not ok then
				offer.ItemUids, offer.CharacterUids, offer.Gold = {}, {}, 0
				return false, err
			end
			-- ANY change resets both confirmations (anti bait-and-switch).
			trade.OfferA.Confirmed = false
			trade.OfferB.Confirmed = false
			pushState(trade)
			return true

		elseif action == "Confirm" then
			local trade = playerTrade[player]
			if not trade or trade.State ~= "Negotiating" then
				return false, "No active trade"
			end
			offerOf(trade, player).Confirmed = true
			pushState(trade)
			if trade.OfferA.Confirmed and trade.OfferB.Confirmed then
				return commitTrade(trade)
			end
			return true

		elseif action == "Cancel" then
			local trade = playerTrade[player]
			if trade then
				cancelTrade(trade)
			end
			return true
		end
		return false, "Unknown action"
	end

	Players.PlayerRemoving:Connect(function(player)
		local trade = playerTrade[player]
		if trade and trade.State ~= "Done" then
			cancelTrade(trade)
		end
	end)
end

return TradeService
