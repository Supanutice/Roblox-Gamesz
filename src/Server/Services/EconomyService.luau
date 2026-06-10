--!strict
-- EconomyService.luau
-- Daily/weekly rewards, Robux product processing (gems + cosmetics only),
-- and the battle pass XP track. No power is ever sold here.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared.Configs.ProgressionConfig)
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)
local Remotes = require(Shared.Net.Remotes)

local EconomyService = { Name = "EconomyService" }

local DataService, InventoryService

local SECONDS_PER_DAY = 86_400

-- --------------------------- DAILY REWARDS --------------------------------

local function utcDayNumber(unix: number): number
	return math.floor(unix / SECONDS_PER_DAY)
end

function EconomyService:TryClaimDailyReward(player: Player): (boolean, { [string]: number }?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, nil
	end
	local daily = profile.Data.DailyRewards
	local today = utcDayNumber(os.time())
	local lastDay = utcDayNumber(daily.LastClaimUnix)
	if today == lastDay then
		return false, nil -- already claimed
	end
	-- Missing a day resets the streak.
	daily.Streak = if today == lastDay + 1 then daily.Streak + 1 else 1
	daily.LastClaimUnix = os.time()

	local cycle = ProgressionConfig.DailyRewards
	local reward = cycle[((daily.Streak - 1) % #cycle) + 1]
	InventoryService:GrantRewards(player, reward)
	profile.Dirty = true
	return true, reward
end

-- --------------------------- BATTLE PASS ----------------------------------

function EconomyService:AddBattlePassXP(player: Player, amount: number)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end
	local bp = profile.Data.BattlePass
	local config = MonetizationConfig.BattlePass
	bp.XP += math.floor(amount)
	while bp.Tier < config.Tiers and bp.XP >= config.XPPerTier do
		bp.XP -= config.XPPerTier
		bp.Tier += 1
	end
	profile.Dirty = true
end

-- ------------------------ ROBUX PURCHASES ----------------------------------

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService:GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for key, product in MonetizationConfig.Products do
		if product.ProductId == receiptInfo.ProductId and product.ProductId ~= 0 then
			DataService:AddCurrency(player, "Gems", product.Gems)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	warn(`[EconomyService] Unknown product {receiptInfo.ProductId}`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function EconomyService:Init(registry)
	DataService = registry.DataService
	InventoryService = registry.InventoryService
end

function EconomyService:Start()
	MarketplaceService.ProcessReceipt = processReceipt

	Remotes.Function("ShopPurchase").OnServerInvoke = function(player, productId)
		if typeof(productId) ~= "string" then
			return false, "Invalid request"
		end
		-- Cosmetic shop purchases with Gems (Robux products go through
		-- MarketplaceService, not this path).
		local ok, err = self:PurchaseCosmetic(player, productId)
		return ok, err
	end

	-- Premium battle pass detection.
	Players.PlayerAdded:Connect(function(player)
		local profile = DataService:WaitForProfile(player)
		if not profile then
			return
		end
		local passId = MonetizationConfig.GamePasses.BATTLE_PASS_PREMIUM.PassId
		if passId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				profile.Data.BattlePass.PremiumOwned = true
				profile.Dirty = true
			end
		end
	end)
end

function EconomyService:PurchaseCosmetic(player: Player, cosmeticId: string): (boolean, string?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	if profile.Data.Cosmetics.Owned[cosmeticId] then
		return false, "Already owned"
	end
	-- Cosmetic catalog prices resolve through LiveOpsService rotation;
	-- flat fallback price keeps the path safe if rotation data is missing.
	local price = 250
	if not DataService:SpendCurrency(player, "Gems", price) then
		return false, "Not enough Gems"
	end
	profile.Data.Cosmetics.Owned[cosmeticId] = true
	profile.Dirty = true
	return true
end

return EconomyService
