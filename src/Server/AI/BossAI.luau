--!strict
-- BossAI.luau
-- Phase-driven boss controller executing AttackPattern sequences from
-- BossDatabase. Handles phase transitions, enrage, cutscene triggers and
-- loot distribution to every participant who dealt damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossDatabase = require(Shared.Data.BossDatabase)
local Maid = require(Shared.Utilities.Maid)
local Signal = require(Shared.Utilities.Signal)
local Remotes = require(Shared.Net.Remotes)

local BossAI = {}
BossAI.__index = BossAI

-- Generic ability executors. Specific bosses reference these by id in their
-- AttackPattern; unknown ids fall back to MELEE_SWING so new patterns never
-- crash a live raid.
local ABILITIES: { [string]: (self: any) -> () } = {}

local function ability(id: string, fn: (self: any) -> ())
	ABILITIES[id] = fn
end

-- Default: heavy frontal swing.
ability("MELEE_SWING", function(self)
	local targets = self.Services.HitboxService:SweepFront(self.Root, 18, 14, self.Model)
	for _, target in targets do
		self.Services.DamageService:ApplyDamage({
			Attacker = self.Model, Victim = target.Model,
			SkillMultiplier = 1.0 * self.Phase.DamageMultiplier, Knockback = 40,
		})
	end
end)

-- Telegraphed AoE slam around the boss.
ability("AOE_SLAM", function(self)
	Remotes.Event("CombatStateChanged"):FireAllClients("BossTelegraph",
		{ Boss = self.Model, Shape = "Circle", Radius = 25, Duration = 1.5 })
	task.wait(1.5)
	local targets = self.Services.HitboxService:SweepSphere(self.Root.Position, 25, self.Model)
	for _, target in targets do
		self.Services.DamageService:ApplyDamage({
			Attacker = self.Model, Victim = target.Model,
			SkillMultiplier = 1.6 * self.Phase.DamageMultiplier,
			StatusEffect = "Stun", Knockback = 60,
		})
	end
end)

-- Ranged barrage at random players.
ability("PROJECTILE_BARRAGE", function(self)
	for i = 1, 5 do
		local players = Players:GetPlayers()
		if #players == 0 then
			return
		end
		local target = players[math.random(#players)].Character
		local root = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Remotes.Event("CombatStateChanged"):FireAllClients("BossTelegraph",
				{ Boss = self.Model, Shape = "Point", Position = root.Position, Duration = 0.8 })
			local struckPosition = root.Position
			task.delay(0.8, function()
				local targets = self.Services.HitboxService:SweepSphere(struckPosition, 8, self.Model)
				for _, hit in targets do
					self.Services.DamageService:ApplyDamage({
						Attacker = self.Model, Victim = hit.Model,
						SkillMultiplier = 0.8 * self.Phase.DamageMultiplier,
					})
				end
			end)
		end
		task.wait(0.4)
	end
end)

-- All database pattern ids map onto the three generic executors until each
-- boss receives bespoke choreography. Designers extend with ability(...) here.
setmetatable(ABILITIES, { __index = function(_, patternId)
	if string.find(patternId, "SLAM") or string.find(patternId, "CRASH") or string.find(patternId, "QUAKE") then
		return ABILITIES.AOE_SLAM
	elseif string.find(patternId, "BEAM") or string.find(patternId, "RAIN") or string.find(patternId, "VOLLEY")
		or string.find(patternId, "BARRAGE") or string.find(patternId, "STARFALL") then
		return ABILITIES.PROJECTILE_BARRAGE
	end
	return ABILITIES.MELEE_SWING
end })

-- ================================= CLASS ===================================

function BossAI.new(bossId: string, spawnCFrame: CFrame, services: { [string]: any })
	local def = BossDatabase.ById[bossId]
	assert(def, "Unknown boss " .. bossId)

	local self = setmetatable({}, BossAI)
	self.Def = def
	self.Services = services
	self.Maid = Maid.new()
	self.Defeated = Signal.new() -- (participants: { Player })
	self.DamageByPlayer = {} :: { [Player]: number }
	self.SpawnedAt = os.clock()
	self.Enraged = false

	-- Build the model (asset cloned from ServerStorage/Bosses if present;
	-- placeholder rig otherwise so logic is testable without art).
	local serverStorage = game:GetService("ServerStorage")
	local bossesFolder = serverStorage:FindFirstChild("Bosses")
	local template = bossesFolder and bossesFolder:FindFirstChild(bossId)
	local model: Model
	if template then
		model = template:Clone()
	else
		model = Instance.new("Model")
		model.Name = def.Name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(8, 12, 8)
		root.Anchored = false
		root.Parent = model
		model.PrimaryPart = root
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = def.BaseHealth
	humanoid.Health = def.BaseHealth
	model:SetAttribute("ATK", def.BaseAttack)
	model:SetAttribute("DEF", def.BaseDefense)
	model:SetAttribute("Element", def.Element)
	model:SetAttribute("IsBoss", true)
	model:PivotTo(spawnCFrame)
	model.Parent = workspace

	self.Model = model
	self.Humanoid = humanoid
	self.Root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	self.Phase = def.Phases[1]
	self.PhaseIndex = 1

	services.CombatService:RegisterEntity(model)

	-- Track damage credit for loot eligibility.
	self.Maid:GiveTask(services.DamageService.DamageDealt:Connect(function(attacker, victim, amount)
		if victim == model then
			local player = Players:GetPlayerFromCharacter(attacker)
			if player then
				self.DamageByPlayer[player] = (self.DamageByPlayer[player] or 0) + amount
			end
		end
	end))

	self.Maid:GiveTask(humanoid.Died:Connect(function()
		self:OnDefeated()
	end))

	-- Intro cutscene for everyone nearby.
	Remotes.Event("CombatStateChanged"):FireAllClients("BossCutscene",
		{ CutsceneId = def.IntroCutsceneId, Boss = model })

	-- Main behavior loop.
	self.Maid:GiveTask(task.spawn(function()
		task.wait(3) -- intro grace
		self:RunPatternLoop()
	end))

	return self
end

function BossAI:RunPatternLoop()
	while self.Humanoid.Health > 0 and self.Model.Parent do
		-- Phase check: pick the deepest phase whose threshold we've crossed.
		local fraction = self.Humanoid.Health / self.Humanoid.MaxHealth
		for index = #self.Def.Phases, 1, -1 do
			local phase = self.Def.Phases[index]
			if fraction <= phase.HealthThreshold and index > self.PhaseIndex then
				self.PhaseIndex = index
				self.Phase = phase
				Remotes.Event("CombatStateChanged"):FireAllClients("BossPhase",
					{ Boss = self.Model, PhaseName = phase.Name, PhaseIndex = index })
				break
			end
		end

		-- Enrage timer.
		if not self.Enraged and os.clock() - self.SpawnedAt > self.Def.EnrageSeconds then
			self.Enraged = true
			Remotes.Event("CombatStateChanged"):FireAllClients("BossEnrage", { Boss = self.Model })
		end
		local enrageMult = if self.Enraged then 2 else 1

		for _, patternId in self.Phase.AttackPattern do
			if self.Humanoid.Health <= 0 or not self.Model.Parent then
				return
			end
			-- Chase nearest player between abilities.
			local nearest: BasePart? = nil
			local nearestDistance = math.huge
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local distance = (root.Position - self.Root.Position).Magnitude
					if distance < nearestDistance then
						nearest, nearestDistance = root, distance
					end
				end
			end
			if nearest and nearestDistance > 15 then
				self.Humanoid.WalkSpeed = 14 * self.Phase.SpeedMultiplier * enrageMult
				self.Humanoid:MoveTo(nearest.Position)
				task.wait(1)
			end

			local executor = ABILITIES[patternId]
			task.spawn(executor, self)
			task.wait(2.5 / (self.Phase.SpeedMultiplier * enrageMult))
		end
	end
end

function BossAI:OnDefeated()
	local participants: { Player } = {}
	for player in self.DamageByPlayer do
		if player.Parent then
			table.insert(participants, player)
		end
	end

	Remotes.Event("CombatStateChanged"):FireAllClients("BossCutscene",
		{ CutsceneId = self.Def.DefeatCutsceneId, Boss = self.Model })

	-- Loot: guaranteed rewards + independent table rolls, per participant.
	for _, player in participants do
		self.Services.InventoryService:GrantRewards(player, self.Def.GuaranteedRewards)
		for _, entry in self.Def.LootTable do
			if math.random() < entry.Chance then
				self.Services.InventoryService:AddItem(player, entry.ItemId, math.random(entry.Min, entry.Max))
			end
		end
		self.Services.QuestService:ReportProgress(player, "DefeatBoss", self.Def.Id, 1)
		local profile = self.Services.DataService:GetProfile(player)
		if profile then
			profile.Data.Progress.BossKills[self.Def.Id] = (profile.Data.Progress.BossKills[self.Def.Id] or 0) + 1
			profile.Dirty = true
		end
	end

	self.Defeated:Fire(participants)
	task.delay(8, function()
		self.Maid:DoCleaning()
		self.Model:Destroy()
	end)
end

return BossAI
