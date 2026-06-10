--!strict
-- Remotes.luau
-- Typed remote registry. The server CREATES every remote at boot; the client
-- WAITS for them. No system ever calls Instance.new("RemoteEvent") elsewhere,
-- which makes the entire network surface auditable in one file (anti-cheat
-- reviews start here).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- name -> "Event" | "Function"
local DEFINITIONS: { [string]: string } = {
	-- Combat (client -> server requests; server validates everything)
	CombatRequestM1 = "Event",          -- (comboIndex: number)
	CombatRequestHeavy = "Event",       -- ()
	CombatRequestDash = "Event",        -- (direction: Vector3)
	CombatRequestSkill = "Event",       -- (skillSlot: number, aimPosition: Vector3)
	CombatRequestBlock = "Event",       -- (isBlocking: boolean)
	CombatRequestUltimate = "Event",    -- (aimPosition: Vector3)
	CombatHitConfirmed = "Event",       -- server -> client: (targetId, damage, isCrit, element)
	CombatStateChanged = "Event",       -- server -> client: (state: string, data: {})
	StatusEffectApplied = "Event",      -- server -> client: (targetId, effectId, duration)

	-- Data replication
	ProfileLoaded = "Event",            -- server -> client: (profileSnapshot)
	CurrencyChanged = "Event",          -- server -> client: (currency: string, newAmount: number)
	InventoryChanged = "Event",         -- server -> client: (delta)
	CharacterRosterChanged = "Event",   -- server -> client: (rosterDelta)

	-- Gacha
	SummonRequest = "Function",         -- (bannerId: string, count: 1 | 10) -> { results }
	SummonAnimationDone = "Event",      -- client -> server: ack to release input lock

	-- Characters
	EquipCharacter = "Function",        -- (characterUid: string, teamSlot: number) -> ok, err
	LevelUpCharacter = "Function",      -- (characterUid: string) -> ok, err
	EvolveCharacter = "Function",       -- (characterUid: string) -> ok, err
	AscendCharacter = "Function",       -- (characterUid: string) -> ok, err

	-- Quests
	QuestAccept = "Function",           -- (questId: string) -> ok, err
	QuestClaim = "Function",            -- (questId: string) -> ok, rewards | err
	QuestProgressChanged = "Event",     -- server -> client

	-- PvP
	PvPJoinQueue = "Function",          -- (mode: string) -> ok, err
	PvPLeaveQueue = "Function",         -- () -> ok
	PvPMatchFound = "Event",            -- server -> client: (matchInfo)
	PvPMatchEnded = "Event",            -- server -> client: (result)

	-- Guild
	GuildAction = "Function",           -- (action: string, payload: {}) -> ok, result | err
	GuildEvent = "Event",               -- server -> client: (eventType, payload)

	-- Trading
	TradeAction = "Function",           -- (action: string, payload: {}) -> ok, result | err
	TradeUpdated = "Event",             -- server -> client: (tradeState)

	-- World / travel
	FastTravelRequest = "Function",     -- (worldId: string, pointId: string) -> ok, err
	NPCDialogue = "Event",              -- server -> client: (npcName: string, line: string)

	-- Shop / monetization (cosmetics only)
	ShopPurchase = "Function",          -- (productId: string) -> ok, err
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server-only: create every remote up front so the client never races.
function Remotes.InitServer()
	assert(RunService:IsServer(), "Remotes.InitServer must run on the server")
	local folder = getFolder()
	for name, kind in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(if kind == "Event" then "RemoteEvent" else "RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Event(name: string): RemoteEvent
	assert(DEFINITIONS[name] == "Event", `Unknown RemoteEvent "{name}"`)
	if RunService:IsServer() then
		return getFolder():FindFirstChild(name) :: RemoteEvent
	end
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	assert(DEFINITIONS[name] == "Function", `Unknown RemoteFunction "{name}"`)
	if RunService:IsServer() then
		return getFolder():FindFirstChild(name) :: RemoteFunction
	end
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
