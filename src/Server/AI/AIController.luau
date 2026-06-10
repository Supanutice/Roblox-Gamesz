--!strict
-- AIController.luau
-- State-machine AI for regular enemies: Patrol -> Aggro -> Chase -> Attack
-- -> Retreat. One controller instance per spawned enemy model. All enemies
-- in a server tick on a single shared heartbeat accumulator (perf budget:
-- AI ticks at 5 Hz, not 60 Hz).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maid = require(Shared.Utilities.Maid)
local SafeZones = require(Shared.Utilities.SafeZones)

local AIController = {}
AIController.__index = AIController

local function inSafeZone(position: Vector3): boolean
	return SafeZones.Contains(position)
end

export type AIConfig = {
	AggroRange: number,
	AttackRange: number,
	AttackCooldown: number,
	AttackMultiplier: number,
	RetreatHealthFraction: number, -- retreat below this HP fraction
	PatrolRadius: number,
	WalkSpeed: number,
	ChaseSpeed: number,
}

local DEFAULT_CONFIG: AIConfig = {
	AggroRange = 40,
	AttackRange = 8,
	AttackCooldown = 2.0,
	AttackMultiplier = 1.0,
	RetreatHealthFraction = 0.15,
	PatrolRadius = 25,
	WalkSpeed = 8,
	ChaseSpeed = 16,
}

local TICK_INTERVAL = 0.2

function AIController.new(model: Model, services: { [string]: any }, config: AIConfig?)
	local self = setmetatable({}, AIController)
	self.Model = model
	self.Humanoid = model:WaitForChild("Humanoid") :: Humanoid
	self.Root = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Services = services
	self.Config = config or DEFAULT_CONFIG
	self.State = "Patrol"
	self.SpawnPosition = self.Root.Position
	self.Target = nil :: Model?
	self.LastAttackAt = 0
	self.Maid = Maid.new()
	self._accumulator = 0

	services.CombatService:RegisterEntity(model)

	self.Maid:GiveTask(RunService.Heartbeat:Connect(function(dt)
		self._accumulator += dt
		if self._accumulator >= TICK_INTERVAL then
			self._accumulator = 0
			self:Tick()
		end
	end))
	self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))
	return self
end

-- ----------------------------- PERCEPTION ----------------------------------

function AIController:FindTarget(): Model?
	local closest: Model? = nil
	local closestDistance = self.Config.AggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not inSafeZone(root.Position) then
			local distance = (root.Position - self.Root.Position).Magnitude
			if distance < closestDistance then
				closest = character
				closestDistance = distance
			end
		end
	end
	return closest
end

function AIController:TargetAlive(): boolean
	if not self.Target or not self.Target.Parent then
		return false
	end
	local humanoid = self.Target:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- ------------------------------ STATES --------------------------------------

function AIController:Tick()
	local healthFraction = self.Humanoid.Health / self.Humanoid.MaxHealth
	if self.State ~= "Retreat" and healthFraction <= self.Config.RetreatHealthFraction then
		self.State = "Retreat"
	end

	if self.State == "Patrol" then
		self:TickPatrol()
	elseif self.State == "Chase" then
		self:TickChase()
	elseif self.State == "Attack" then
		self:TickAttack()
	elseif self.State == "Retreat" then
		self:TickRetreat()
	end
end

function AIController:TickPatrol()
	self.Humanoid.WalkSpeed = self.Config.WalkSpeed
	local target = self:FindTarget()
	if target then
		self.Target = target
		self.State = "Chase"
		return
	end
	-- Wander around spawn.
	if math.random() < 0.15 then
		local offset = Vector3.new(
			math.random(-self.Config.PatrolRadius, self.Config.PatrolRadius), 0,
			math.random(-self.Config.PatrolRadius, self.Config.PatrolRadius))
		self.Humanoid:MoveTo(self.SpawnPosition + offset)
	end
end

function AIController:TickChase()
	if not self:TargetAlive() then
		self.Target = nil
		self.State = "Patrol"
		return
	end
	local targetRoot = (self.Target :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	-- Target reached the village safe zone: break off immediately.
	if inSafeZone(targetRoot.Position) then
		self.Target = nil
		self.State = "Patrol"
		self.Humanoid:MoveTo(self.SpawnPosition)
		return
	end
	local distance = (targetRoot.Position - self.Root.Position).Magnitude
	-- De-aggro leash: don't chase across the world.
	if distance > self.Config.AggroRange * 2 then
		self.Target = nil
		self.State = "Patrol"
		self.Humanoid:MoveTo(self.SpawnPosition)
		return
	end
	if distance <= self.Config.AttackRange then
		self.State = "Attack"
		return
	end
	self.Humanoid.WalkSpeed = self.Config.ChaseSpeed
	self.Humanoid:MoveTo(targetRoot.Position)
end

function AIController:TickAttack()
	if not self:TargetAlive() then
		self.Target = nil
		self.State = "Patrol"
		return
	end
	local targetRoot = (self.Target :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	if inSafeZone(targetRoot.Position) then
		self.Target = nil
		self.State = "Patrol"
		self.Humanoid:MoveTo(self.SpawnPosition)
		return
	end
	local distance = (targetRoot.Position - self.Root.Position).Magnitude
	if distance > self.Config.AttackRange * 1.5 then
		self.State = "Chase"
		return
	end
	-- Face the target.
	self.Root.CFrame = CFrame.lookAt(self.Root.Position,
		Vector3.new(targetRoot.Position.X, self.Root.Position.Y, targetRoot.Position.Z))

	if os.clock() - self.LastAttackAt >= self.Config.AttackCooldown then
		self.LastAttackAt = os.clock()
		self.Services.DamageService:ApplyDamage({
			Attacker = self.Model,
			Victim = self.Target,
			SkillMultiplier = self.Config.AttackMultiplier,
		})
	end
end

function AIController:TickRetreat()
	-- Flee toward spawn; recover there.
	self.Humanoid.WalkSpeed = self.Config.ChaseSpeed
	self.Humanoid:MoveTo(self.SpawnPosition)
	if (self.Root.Position - self.SpawnPosition).Magnitude < 8 then
		self.Humanoid.Health = math.min(self.Humanoid.MaxHealth, self.Humanoid.Health + self.Humanoid.MaxHealth * 0.05)
		if self.Humanoid.Health / self.Humanoid.MaxHealth > 0.5 then
			self.State = "Patrol"
		end
	end
end

function AIController:Destroy()
	self.Maid:DoCleaning()
end

return AIController
