--!strict
-- InventoryService.luau
-- Authoritative item storage: weapons, materials, consumables, cosmetics.
-- Every grant/consume validates against ItemDatabase and profile limits.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDatabase = require(Shared.Data.ItemDatabase)
local GameConfig = require(Shared.Configs.GameConfig)
local TableUtil = require(Shared.Utilities.TableUtil)
local Remotes = require(Shared.Net.Remotes)

local InventoryService = { Name = "InventoryService" }

local DataService

local function notifyClient(player: Player, delta: { [string]: any })
	Remotes.Event("InventoryChanged"):FireClient(player, delta)
end

-- Finds an existing stack with room, or nil.
local function findStack(inventory, itemId: string, def): (string?, any)
	for uid, entry in inventory do
		if entry.ItemId == itemId and def.Stackable and entry.Count < def.MaxStack then
			return uid, entry
		end
	end
	return nil, nil
end

function InventoryService:GetCount(player: Player, itemId: string): number
	local profile = DataService:GetProfile(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, entry in profile.Data.Inventory do
		if entry.ItemId == itemId then
			total += entry.Count
		end
	end
	return total
end

function InventoryService:AddItem(player: Player, itemId: string, count: number): (boolean, string?)
	local def = ItemDatabase.ById[itemId]
	if not def then
		return false, "Unknown item: " .. itemId
	end
	if count <= 0 or count ~= math.floor(count) then
		return false, "Invalid count"
	end
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	local inventory = profile.Data.Inventory

	local remaining = count
	while remaining > 0 do
		local stackUid, stack = findStack(inventory, itemId, def)
		if stack then
			local space = def.MaxStack - stack.Count
			local toAdd = math.min(space, remaining)
			stack.Count += toAdd
			remaining -= toAdd
		else
			if TableUtil.Count(inventory) >= GameConfig.Limits.MaxInventorySlots then
				return false, "Inventory full"
			end
			local uid = HttpService:GenerateGUID(false)
			inventory[uid] = {
				ItemId = itemId,
				Count = math.min(remaining, def.MaxStack),
				WeaponLevel = if def.Category == "Weapon" then 1 else nil,
			}
			remaining -= inventory[uid].Count
		end
	end

	profile.Dirty = true
	notifyClient(player, { Added = { ItemId = itemId, Count = count } })
	return true
end

-- Atomic multi-consume: either all materials are removed, or none are.
function InventoryService:ConsumeItems(player: Player, costs: { [string]: number }): (boolean, string?)
	local profile = DataService:GetProfile(player)
	if not profile then
		return false, "No profile"
	end
	for itemId, needed in costs do
		if self:GetCount(player, itemId) < needed then
			return false, "Missing " .. itemId
		end
	end
	local inventory = profile.Data.Inventory
	for itemId, needed in costs do
		local remaining = needed
		for uid, entry in inventory do
			if remaining <= 0 then
				break
			end
			if entry.ItemId == itemId then
				local take = math.min(entry.Count, remaining)
				entry.Count -= take
				remaining -= take
				if entry.Count <= 0 then
					inventory[uid] = nil
				end
			end
		end
	end
	profile.Dirty = true
	notifyClient(player, { Consumed = costs })
	return true
end

-- Grants from loot tables / quest rewards. Mixed currency + item map.
function InventoryService:GrantRewards(player: Player, rewards: { [string]: number })
	for key, amount in rewards do
		if key == "XP" then
			DataService:AddXP(player, amount)
		elseif GameConfig.Currencies[key] then
			DataService:AddCurrency(player, key, amount)
		elseif ItemDatabase.ById[key] then
			self:AddItem(player, key, amount)
		else
			warn(`[InventoryService] Unknown reward key "{key}"`)
		end
	end
end

function InventoryService:Init(registry)
	DataService = registry.DataService
end

return InventoryService
