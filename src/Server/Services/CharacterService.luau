--!strict
-- CharacterService.luau
-- Owns the player's hero roster: granting, equipping, leveling, evolution,
-- ascension, and pushing computed stats onto the live character model.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local GameConfig = require(Shared.Configs.GameConfig)
local ProgressionConfig = require(Shared.Configs.ProgressionConfig)
local Formulas = require(Shared.Utilities.Formulas)
local TableUtil = require(Shared.Utilities.TableUtil)
local Remotes = require(Shared.Net.Remotes)

local CharacterService = { Name = "CharacterService" }

local DataService, InventoryService, AppearanceService

local RARITY_MULT: { [string]: number } = {}
local RARITY_MAX_EVO: { [string]: number } = {}
for _, rarity in GameConfig.Rarities do
	RARITY_MULT[rarity.Name] = rarity.StatMult
	RARITY_MAX_EVO[rarity.Name] = rarity.MaxEvolution
end

-- ============================== ACQUISITION ================================

-- Grants a character; duplicates convert to ascension shards automatically.
function CharacterService:GrantCharacter(player: Player, characterId: string): (string?, boolean)
	local def = CharacterDatabase.ById[characterId]
	assert(def, "Unknown character " .. characterId)
	local profile = DataService:GetProfile(player)
	if not profile then
		return nil, false
	end

	-- Duplicate? Convert to shards on the FIRST owned copy.
	for uid, owned in profile.Data.Characters do
		if owned.CharacterId == characterId then
			owned.Shards += 10
			profile.Dirty = true
			Remotes.Event("CharacterRosterChanged"):FireClient(player, { ShardsAdded = { Uid = uid, Amount = 10 } })
			return uid, true -- wasDuplicate
		end
	end

	if TableUtil.Count(profile.Data.Characters) >= GameConfig.Limits.MaxCharactersOwned then
		return nil, false
	end

	local uid = HttpService:GenerateGUID(false)
	profile.Data.Characters[uid] = {
		CharacterId = characterId,
		Level = 1,
		XP = 0,
		EvolutionStage = 1,
		Ascension = 0,
		SkillLevels = { 1, 1, 1 },
		Shards = 0,
		EquippedWeaponUid = nil,
		ObtainedAt = os.time(),
		Locked = false,
	}
	profile.Dirty = true
	Remotes.Event("CharacterRosterChanged"):FireClient(player, { Granted = { Uid = uid, CharacterId = characterId } })
	return uid, false
end

-- ================================ EQUIPPING ================================

function CharacterService:EquipCharacter(player: Player, uid: string, teamSlot: number): (boolean, string?)
	if typeof(uid) ~= "string" or typeof(teamSlot) ~= "number" then
		return false, "Invalid request"
	end
	if teamSlot < 1 or teamSlot > GameConfig.Team.MaxEquipped or teamSlot ~= math.floor(teamSlot) then
		return false, "Invalid slot"
	end
	local profile = DataService:GetProfile(player)
	if not profile or not profile.Data.Characters[uid] then
		return false, "Not owned"
	end
	-- A character can occupy only one slot.
	for slot, equippedUid in profile.Data.TeamSlots do
		if equippedUid == uid and slot ~= teamSlot then
			profile.Data.TeamSlots[slot] = nil
		end
	end
	profile.Data.TeamSlots[teamSlot] = uid
	profile.Dirty = true
	if player.Character then
		self:ApplyStatsToCharacter(player, player.Character)
	end
	return true
end

-- The team's slot-1 character drives the player's skills and stats.
function CharacterService:GetActiveCharacterDef(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return nil
	end
	local uid = profile.Data.TeamSlots[1]
	local instance = uid and profile.Data.Characters[uid]
	if not instance then
		return nil
	end
	return { Uid = uid, Instance = instance, Def = CharacterDatabase.ById[instance.CharacterId] }
end

-- Writes computed stats as model attributes; DamageService reads them.
function CharacterService:ApplyStatsToCharacter(player: Player, characterModel: Model)
	local active = self:GetActiveCharacterDef(player)
	local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if not active then
		-- No team yet (fresh account): unarmed baseline.
		characterModel:SetAttribute("ATK", 10)
		characterModel:SetAttribute("DEF", 0)
		characterModel:SetAttribute("Element", "Fire")
		if AppearanceService then
			AppearanceService:ApplyAppearance(player, characterModel, nil)
		end
		return
	end

	local def, inst = active.Def, active.Instance
	local mult = RARITY_MULT[def.Rarity] or 1
	local hp = Formulas.ComputeStat(def.BaseStats.HP, inst.Level, mult, inst.EvolutionStage, inst.Ascension)
	local atk = Formulas.ComputeStat(def.BaseStats.ATK, inst.Level, mult, inst.EvolutionStage, inst.Ascension)
	local defStat = Formulas.ComputeStat(def.BaseStats.DEF, inst.Level, mult, inst.EvolutionStage, inst.Ascension)

	-- Weapon bonus.
	local profile = DataService:GetProfile(player)
	if profile and inst.EquippedWeaponUid then
		local weapon = profile.Data.Inventory[inst.EquippedWeaponUid]
		if weapon then
			local ItemDatabase = require(Shared.Data.ItemDatabase)
			local weaponDef = ItemDatabase.ById[weapon.ItemId]
			if weaponDef and weaponDef.WeaponStats then
				atk += math.floor(weaponDef.WeaponStats.ATK * (1 + (weapon.WeaponLevel or 1) * 0.03))
			end
		end
	end

	humanoid.MaxHealth = hp
	humanoid.Health = hp
	characterModel:SetAttribute("ATK", atk)
	characterModel:SetAttribute("DEF", defStat)
	characterModel:SetAttribute("Element", def.Element)
	characterModel:SetAttribute("Class", def.Class)
	characterModel:SetAttribute("BaseWalkSpeed", 16 + def.BaseStats.SPD * 0.25)
	humanoid.WalkSpeed = 16 + def.BaseStats.SPD * 0.25

	-- Visual morph into the equipped hero (palette, headwear, weapon prop).
	if AppearanceService then
		AppearanceService:ApplyAppearance(player, characterModel, def)
	end
end

-- ============================== PROGRESSION ================================

function CharacterService:LevelUpCharacter(player: Player, uid: string): (boolean, string?)
	local profile = DataService:GetProfile(player)
	local inst = profile and profile.Data.Characters[uid]
	if not inst then
		return false, "Not owned"
	end
	if inst.Level >= ProgressionConfig.LevelCap then
		return false, "Max level"
	end
	local cost = math.floor(ProgressionConfig.Character.LevelUpGoldCostBase * inst.Level ^ 1.4)
	if not DataService:SpendCurrency(player, "Gold", cost) then
		return false, "Not enough Gold"
	end
	inst.Level += 1
	profile.Dirty = true
	if player.Character then
		self:ApplyStatsToCharacter(player, player.Character)
	end
	return true
end

function CharacterService:EvolveCharacter(player: Player, uid: string): (boolean, string?)
	local profile = DataService:GetProfile(player)
	local inst = profile and profile.Data.Characters[uid]
	if not inst then
		return false, "Not owned"
	end
	local def = CharacterDatabase.ById[inst.CharacterId]
	local maxEvo = RARITY_MAX_EVO[def.Rarity] or 2
	local nextStage = inst.EvolutionStage + 1
	if nextStage > maxEvo then
		return false, "Final form reached"
	end
	local requirement = ProgressionConfig.Evolution.Stages[nextStage]
	if not requirement then
		return false, "No evolution data"
	end
	if inst.Level < requirement.RequiredLevel then
		return false, `Requires level {requirement.RequiredLevel}`
	end
	if not InventoryService:ConsumeItems(player, requirement.Materials) then
		return false, "Missing materials"
	end
	if not DataService:SpendCurrency(player, "Gold", requirement.Gold) then
		return false, "Not enough Gold"
	end
	inst.EvolutionStage = nextStage
	profile.Dirty = true
	Remotes.Event("CharacterRosterChanged"):FireClient(player, { Evolved = { Uid = uid, Stage = nextStage } })
	if player.Character then
		self:ApplyStatsToCharacter(player, player.Character)
	end
	return true
end

function CharacterService:AscendCharacter(player: Player, uid: string): (boolean, string?)
	local profile = DataService:GetProfile(player)
	local inst = profile and profile.Data.Characters[uid]
	if not inst then
		return false, "Not owned"
	end
	if inst.Ascension >= ProgressionConfig.Ascension.MaxStars then
		return false, "Max ascension"
	end
	local shardsNeeded = ProgressionConfig.Ascension.ShardsPerStar[inst.Ascension + 1]
	if inst.Shards < shardsNeeded then
		return false, `Need {shardsNeeded} shards`
	end
	inst.Shards -= shardsNeeded
	inst.Ascension += 1
	profile.Dirty = true
	Remotes.Event("CharacterRosterChanged"):FireClient(player, { Ascended = { Uid = uid, Stars = inst.Ascension } })
	if player.Character then
		self:ApplyStatsToCharacter(player, player.Character)
	end
	return true
end

-- ================================ LIFECYCLE ================================

function CharacterService:Init(registry)
	DataService = registry.DataService
	InventoryService = registry.InventoryService
	AppearanceService = registry.AppearanceService
end

function CharacterService:Start()
	Remotes.Function("EquipCharacter").OnServerInvoke = function(player, uid, slot)
		return self:EquipCharacter(player, uid, slot)
	end
	Remotes.Function("LevelUpCharacter").OnServerInvoke = function(player, uid)
		if typeof(uid) ~= "string" then
			return false, "Invalid"
		end
		return self:LevelUpCharacter(player, uid)
	end
	Remotes.Function("EvolveCharacter").OnServerInvoke = function(player, uid)
		if typeof(uid) ~= "string" then
			return false, "Invalid"
		end
		return self:EvolveCharacter(player, uid)
	end
	Remotes.Function("AscendCharacter").OnServerInvoke = function(player, uid)
		if typeof(uid) ~= "string" then
			return false, "Invalid"
		end
		return self:AscendCharacter(player, uid)
	end

	-- Starter character for brand-new accounts.
	DataService.ProfileLoaded:Connect(function(player, profile)
		if TableUtil.Count(profile.Data.Characters) == 0 then
			local uid = self:GrantCharacter(player, "CHR_001")
			if uid then
				profile.Data.TeamSlots[1] = uid
			end
		end
	end)
end

return CharacterService
