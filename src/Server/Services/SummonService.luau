--!strict
-- SummonService.luau
-- Gacha engine: single/10-pull, soft pity, hard pity, Mythic long pity,
-- featured 50/50 with guarantee after a loss. ALL randomness is server-side
-- with a per-server Random instance; rates are validated at boot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BannerConfig = require(Shared.Configs.BannerConfig)
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local TableUtil = require(Shared.Utilities.TableUtil)
local Remotes = require(Shared.Net.Remotes)

local SummonService = { Name = "SummonService" }

local DataService, CharacterService, QuestService

local rng = Random.new()

-- rarity -> { characterId } pools, built once at boot.
local pools: { [string]: { string } } = {}
local bannersById: { [string]: BannerConfig.Banner } = {}

local LEGENDARY_PLUS = { Legendary = true, Mythic = true, Secret = true, Divine = true }
local MYTHIC_PLUS = { Mythic = true, Secret = true, Divine = true }

-- ============================== ROLL LOGIC =================================

local function rollRarity(pityCount: number, mythicPityCount: number): string
	-- Mythic hard pity overrides everything.
	if mythicPityCount + 1 >= BannerConfig.Pity.MythicHardPity then
		return "Mythic"
	end
	-- Hard pity: force Legendary+.
	local forceLegendary = pityCount + 1 >= BannerConfig.Pity.HardPity

	-- Soft pity: shift weight into Legendary from Common/Rare.
	local rates = table.clone(BannerConfig.Rates)
	local pastSoft = pityCount + 1 - BannerConfig.Pity.SoftPityStart
	if pastSoft > 0 then
		local bonus = math.min(pastSoft * BannerConfig.Pity.SoftPityBonusPerPull, rates.Common + rates.Rare)
		local fromCommon = math.min(bonus, rates.Common)
		rates.Common -= fromCommon
		rates.Rare -= (bonus - fromCommon)
		rates.Legendary += bonus
	end

	if forceLegendary then
		rates.Common, rates.Rare, rates.Epic = 0, 0, 0
	end

	return TableUtil.WeightedRandom(rates, rng)
end

local function pickCharacter(rarity: string, banner: BannerConfig.Banner, gacha): string
	local pool = pools[rarity]
	assert(pool and #pool > 0, "Empty pool for rarity " .. rarity)

	-- Featured 50/50 applies to Legendary+ pulls on rate-up banners.
	if LEGENDARY_PLUS[rarity] and #banner.FeaturedCharacterIds > 0 then
		local featuredInRarity = {}
		for _, id in banner.FeaturedCharacterIds do
			if CharacterDatabase.ById[id].Rarity == rarity then
				table.insert(featuredInRarity, id)
			end
		end
		if #featuredInRarity > 0 then
			local guaranteed = gacha.LostFiftyFifty[banner.Id]
			local featuredShare = banner.RateUpMultiplier / (banner.RateUpMultiplier + 1)
			if guaranteed or rng:NextNumber() < featuredShare then
				gacha.LostFiftyFifty[banner.Id] = nil
				return featuredInRarity[rng:NextInteger(1, #featuredInRarity)]
			else
				gacha.LostFiftyFifty[banner.Id] = true
			end
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

export type PullResult = {
	CharacterId: string,
	Rarity: string,
	WasDuplicate: boolean,
	PityAtPull: number,
}

function SummonService:Summon(player: Player, bannerId: string, count: number): (boolean, { PullResult } | string)
	local banner = bannersById[bannerId]
	if not banner then
		return false, "Unknown banner"
	end
	if count ~= 1 and count ~= 10 then
		return false, "Invalid count"
	end
	local now = os.time()
	if (banner.StartsAtUnix and now < banner.StartsAtUnix) or (banner.EndsAtUnix and now > banner.EndsAtUnix) then
		return false, "Banner not active"
	end
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end

	local cost = if count == 1 then banner.CostSingle else banner.CostMulti
	if not DataService:SpendCurrency(player, banner.CostCurrency, cost) then
		return false, "Not enough " .. banner.CostCurrency
	end

	local gacha = profile.Data.Gacha
	gacha.PityCounter[bannerId] = gacha.PityCounter[bannerId] or 0
	gacha.MythicPityCounter[bannerId] = gacha.MythicPityCounter[bannerId] or 0

	local results: { PullResult } = {}
	local gotRarePlus = false

	for i = 1, count do
		local rarity = rollRarity(gacha.PityCounter[bannerId], gacha.MythicPityCounter[bannerId])

		-- 10-pull guarantee: last slot upgrades to Rare if nothing Rare+ yet.
		if count == 10 and i == 10 and not gotRarePlus and rarity == "Common"
			and BannerConfig.Multi.GuaranteedRareMinimum then
			rarity = "Rare"
		end
		if rarity ~= "Common" then
			gotRarePlus = true
		end

		-- Pity bookkeeping.
		gacha.PityCounter[bannerId] = if LEGENDARY_PLUS[rarity] then 0 else gacha.PityCounter[bannerId] + 1
		gacha.MythicPityCounter[bannerId] = if MYTHIC_PLUS[rarity] then 0 else gacha.MythicPityCounter[bannerId] + 1
		gacha.TotalPulls += 1

		local characterId = pickCharacter(rarity, banner, gacha)
		local _, wasDuplicate = CharacterService:GrantCharacter(player, characterId)
		table.insert(results, {
			CharacterId = characterId,
			Rarity = rarity,
			WasDuplicate = wasDuplicate,
			PityAtPull = gacha.PityCounter[bannerId],
		})
	end

	profile.Dirty = true
	if QuestService then
		QuestService:ReportProgress(player, "Summon", nil, count)
	end
	return true, results
end

-- ================================ LIFECYCLE ================================

function SummonService:Init(registry)
	DataService = registry.DataService
	CharacterService = registry.CharacterService
	QuestService = registry.QuestService

	-- Build rarity pools.
	for _, def in CharacterDatabase.Ordered do
		pools[def.Rarity] = pools[def.Rarity] or {}
		table.insert(pools[def.Rarity], def.Id)
	end

	-- Validate rates sum to 100 (catches config typos before players do).
	local sum = 0
	for _, rate in BannerConfig.Rates do
		sum += rate
	end
	assert(math.abs(sum - 100) < 1e-6, `Banner rates sum to {sum}, expected 100`)

	for _, banner in BannerConfig.Banners do
		bannersById[banner.Id] = banner
	end
end

function SummonService:Start()
	local inFlight: { [Player]: boolean } = {}
	Remotes.Function("SummonRequest").OnServerInvoke = function(player, bannerId, count)
		if typeof(bannerId) ~= "string" or typeof(count) ~= "number" then
			return false, "Invalid request"
		end
		-- Re-entrancy guard: one summon transaction at a time per player.
		if inFlight[player] then
			return false, "Summon in progress"
		end
		inFlight[player] = true
		local ok, result = self:Summon(player, bannerId, count)
		inFlight[player] = nil
		return ok, result
	end
end

return SummonService
