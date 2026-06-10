--!strict
-- NPCService.luau
-- Spawns every NPC defined in WorldConfig as an interactable character
-- (ProximityPrompt). Talking to an NPC:
--   1) counts toward "Talk" quest objectives,
--   2) auto-claims any of their completed quests,
--   3) auto-accepts their next available quest,
--   4) sends a dialogue line to the player.
-- Placeholder rigs are used until real NPC models are placed under
-- ServerStorage/NPCs/<NpcId>.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Configs.WorldConfig)
local QuestDatabase = require(Shared.Data.QuestDatabase)
local Remotes = require(Shared.Net.Remotes)

local NPCService = { Name = "NPCService" }

local services: { [string]: any }

-- Dialogue flavor per role; quest lines override these.
local ROLE_DIALOGUE: { [string]: string } = {
	QuestGiver = "The road ahead is dangerous. Are you prepared?",
	WeaponShop = "Finest blades this side of the realm. Take a look!",
	ItemShop = "Potions, tonics, trinkets — everything an adventurer needs.",
	ConsumableShop = "Hot meals! Nothing restores the spirit like good food.",
	Trainer = "Again! A warrior's body remembers what the mind forgets.",
	BountyBoard = "Plenty of bounties today. Pick your prey.",
	FastTravelUnlock = "Answer well, and the path shall open.",
	MountShop = "She's fast, she's loyal, and she only bites strangers.",
	TradePost = "Everything has a price. Most people just don't know theirs.",
}

-- quest giver npcId -> ordered quest ids (built at Init from QuestDatabase).
local questsByGiver: { [string]: { string } } = {}

local function buildPlaceholderNPC(npc: { Id: string, Name: string, Role: string }): Model
	local model = Instance.new("Model")
	model.Name = npc.Name

	local torso = Instance.new("Part")
	torso.Name = "Body"
	torso.Size = Vector3.new(2.5, 5, 1.5)
	torso.Anchored = true
	torso.Color = Color3.fromRGB(90, 120, 200)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Parent = model
	model.PrimaryPart = torso

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.Anchored = true
	head.Color = Color3.fromRGB(255, 220, 180)
	head.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 120
	billboard.Parent = torso
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 170)
	label.TextStrokeTransparency = 0.4
	label.Text = `{npc.Name}\n[{npc.Role}]`
	label.Parent = billboard

	return model
end

local function onTalk(player: Player, npc: { Id: string, Name: string, Role: string })
	-- 1) Talk objectives.
	services.QuestService:ReportProgress(player, "Talk", npc.Id, 1)

	local profile = services.DataService:GetProfile(player)
	if not profile then
		return
	end
	local dialogue = ROLE_DIALOGUE[npc.Role] or "..."

	-- 2) Claim any of this NPC's quests the player has finished.
	for _, questId in questsByGiver[npc.Id] or {} do
		if profile.Data.Quests.Active[questId] then
			local ok, rewards = services.QuestService:ClaimQuest(player, questId)
			if ok then
				local quest = QuestDatabase.ById[questId]
				dialogue = `Outstanding work on "{quest.Name}"! Take this — you've earned it.`
				break
			end
		end
	end

	-- 3) Offer/auto-accept the next available quest in their chain.
	for _, questId in questsByGiver[npc.Id] or {} do
		local quests = profile.Data.Quests
		if not quests.Active[questId] and not quests.Completed[questId] then
			local ok = services.QuestService:AcceptQuest(player, questId)
			if ok then
				local quest = QuestDatabase.ById[questId]
				dialogue = `{quest.Description} (Quest accepted: "{quest.Name}")`
				break
			end
		end
	end

	-- 4) Speak.
	Remotes.Event("NPCDialogue"):FireClient(player, npc.Name, dialogue)
end

local function spawnNPC(npc: { Id: string, Name: string, Role: string }, position: Vector3, facing: Vector3)
	local npcFolder = ServerStorage:FindFirstChild("NPCs")
	local template = npcFolder and npcFolder:FindFirstChild(npc.Id)
	local model = if template then template:Clone() else buildPlaceholderNPC(npc)

	-- Position: torso 2.5 above ground, head above torso.
	model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 2.5, 0), position + facing))
	local head = model:FindFirstChild("Head") :: BasePart?
	local body = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) :: BasePart
	if head and not template then
		head.CFrame = body.CFrame * CFrame.new(0, 3.3, 0)
	end
	model.Parent = workspace:FindFirstChild("NPCs") or workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = npc.Name
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		onTalk(player, npc)
	end)
end

function NPCService:Init(registry)
	services = registry

	-- Index quest chains by giver, preserving database declaration order via
	-- prerequisite depth (prereq-less quests first).
	for questId, quest in QuestDatabase.ById do
		if quest.GiverNPC then
			questsByGiver[quest.GiverNPC] = questsByGiver[quest.GiverNPC] or {}
			table.insert(questsByGiver[quest.GiverNPC], questId)
		end
	end
	local function chainDepth(questId: string): number
		local depth, current = 0, QuestDatabase.ById[questId]
		while current and current.PrerequisiteQuest do
			depth += 1
			current = QuestDatabase.ById[current.PrerequisiteQuest]
		end
		return depth
	end
	for _, questIds in questsByGiver do
		table.sort(questIds, function(a, b)
			local depthA, depthB = chainDepth(a), chainDepth(b)
			return if depthA == depthB then a < b else depthA < depthB
		end)
	end

	if not workspace:FindFirstChild("NPCs") then
		local folder = Instance.new("Folder")
		folder.Name = "NPCs"
		folder.Parent = workspace
	end
end

function NPCService:Start()
	-- Stand NPCs in a gentle arc around each world's hub plaza.
	for _, worldDef in WorldConfig.Worlds do
		local hub = worldDef.FastTravelPoints[1].Position
		for index, npc in worldDef.NPCs do
			local angle = math.rad(120 + index * 35)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 24
			spawnNPC(npc, hub + offset, -offset)
		end
	end
end

return NPCService
