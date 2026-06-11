--!strict
-- RaidService.luau
-- Guild raids: an officer/leader spends one of the guild's weekly attempts
-- (validated + consumed atomically by GuildService), every online guild
-- member is teleported to the raid arena, and this week's rotation boss
-- (Voidlord / Seamother / Chronos) spawns at full BossAI choreography.
-- Victory pays boss loot (BossAI handles per-participant rewards) plus a
-- large guild XP bonus. One raid per server at a time.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuildConfig = require(Shared.Configs.GuildConfig)
local BossDatabase = require(Shared.Data.BossDatabase)
local Remotes = require(Shared.Net.Remotes)

local BossAI = require(script.Parent.Parent.AI.BossAI)

local RaidService = { Name = "RaidService" }

local services: { [string]: any }

local RAID_ORIGIN = Vector3.new(0, 80, -12_000)
local ARENA_RADIUS = 80
local RAID_TIMEOUT = 900
local GUILD_XP_PER_CLEAR = 8_000

local raidActive = false

-- ------------------------------ ARENA ------------------------------------------

local function buildArena(): Folder
	local container = Instance.new("Folder")
	container.Name = "GuildRaidArena"

	local floor = Instance.new("Part")
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(2, ARENA_RADIUS * 2, ARENA_RADIUS * 2)
	floor.CFrame = CFrame.new(RAID_ORIGIN - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Anchored = true
	floor.Color = Color3.fromRGB(38, 30, 52)
	floor.Material = Enum.Material.Basalt
	floor.Parent = container

	for index = 1, 12 do
		local angle = index / 12 * math.pi * 2
		local pillar = Instance.new("Part")
		pillar.Size = Vector3.new(5, 26, 5)
		pillar.Position = RAID_ORIGIN + Vector3.new(math.cos(angle) * (ARENA_RADIUS - 6), 12, math.sin(angle) * (ARENA_RADIUS - 6))
		pillar.Anchored = true
		pillar.Color = Color3.fromRGB(70, 55, 100)
		pillar.Material = Enum.Material.Slate
		pillar.Parent = container
		local flame = Instance.new("Part")
		flame.Size = Vector3.new(2.4, 2, 2.4)
		flame.Position = pillar.Position + Vector3.new(0, 14, 0)
		flame.Anchored = true
		flame.CanCollide = false
		flame.Color = Color3.fromRGB(170, 110, 255)
		flame.Material = Enum.Material.Neon
		flame.Parent = container
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1.8
		light.Color = Color3.fromRGB(170, 110, 255)
		light.Parent = flame
	end

	container.Parent = workspace
	return container
end

-- ------------------------------ HELPERS -----------------------------------------

local function onlineGuildMembers(guildId: string): { Player }
	local members = {}
	for _, player in Players:GetPlayers() do
		local profile = services.DataService:GetProfile(player)
		if profile and profile.Data.GuildId == guildId then
			table.insert(members, player)
		end
	end
	return members
end

local function announce(participants: { Player }, message: string)
	for _, player in participants do
		if player.Parent then
			Remotes.Event("NPCDialogue"):FireClient(player, "⚔ Guild Raid", message)
		end
	end
end

local function teleport(player: Player, position: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		services.AntiCheatService:AllowTeleport(player)
		root.CFrame = CFrame.new(position)
	end
end

-- ------------------------------ RAID FLOW ----------------------------------------

function RaidService:StartRaid(player: Player): (boolean, string?)
	if raidActive then
		return false, "A raid is already in progress on this server"
	end
	local profile = services.DataService:GetProfile(player)
	local guildId = profile and profile.Data.GuildId
	if not guildId then
		return false, "Not in a guild"
	end

	-- Headcount BEFORE consuming the weekly attempt.
	local participants = onlineGuildMembers(guildId)
	local minimum = if RunService:IsStudio() then 1 else GuildConfig.Raids.MinMembers
	if #participants < minimum then
		return false, `Need {minimum} guild members online`
	end

	local ok, err, info = services.GuildService:ConsumeRaidAttempt(player)
	if not ok or not info then
		return false, err
	end

	raidActive = true
	local arena = buildArena()
	local bossDef = BossDatabase.ById[info.BossId]

	-- Save positions and bring everyone in.
	local savedCFrames: { [Player]: CFrame } = {}
	for index, member in participants do
		local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			savedCFrames[member] = root.CFrame
		end
		local angle = index / #participants * math.pi * 2
		teleport(member, RAID_ORIGIN + Vector3.new(math.cos(angle) * 25, 4, math.sin(angle) * 25))
	end
	announce(participants, `{bossDef.Name} answers the challenge! ({#participants} raider(s))`)

	local boss = BossAI.new(info.BossId, CFrame.new(RAID_ORIGIN + Vector3.new(0, 10, 0)), services)

	local function finish(victory: boolean)
		if not raidActive then
			return
		end
		raidActive = false
		if victory then
			services.GuildService:AddGuildXP(info.GuildId, GUILD_XP_PER_CLEAR)
			announce(participants, `VICTORY! +{GUILD_XP_PER_CLEAR} guild XP. Loot has been distributed.`)
		else
			announce(participants, "The raid has failed… regroup and try again.")
			if boss.Model.Parent then
				boss.Maid:DoCleaning()
				boss.Model:Destroy()
			end
		end
		task.delay(if victory then 8 else 3, function()
			for _, member in participants do
				if member.Parent and member.Character then
					local saved = savedCFrames[member]
					if saved then
						services.AntiCheatService:AllowTeleport(member)
						local root = member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root then
							root.CFrame = saved
						end
					end
				end
			end
			arena:Destroy()
		end)
	end

	boss.Defeated:Once(function()
		finish(true)
	end)
	task.delay(RAID_TIMEOUT, function()
		finish(false) -- no-ops if already finished
	end)

	return true
end

-- ------------------------------ LIFECYCLE ----------------------------------------

function RaidService:Init(serviceRegistry)
	services = serviceRegistry
end

return RaidService
