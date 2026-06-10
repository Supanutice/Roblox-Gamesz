--!strict
-- CombatController.luau
-- Client side of combat: instantly plays animations/sounds for responsiveness
-- (prediction), sends the REQUEST to the server, and reconciles with the
-- server's authoritative CombatStateChanged events. Also owns target lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Configs.CombatConfig)
local Remotes = require(Shared.Net.Remotes)

local CombatController = {}

local InputController, CameraController, UIController

local player = Players.LocalPlayer

-- Local prediction state (server remains authoritative).
local localCooldowns: { [string]: number } = {}
local comboIndex = 0
local lockedTarget: Model? = nil
local energy = 0

local function onLocalCooldown(key: string, duration: number): boolean
	local now = os.clock()
	if now < (localCooldowns[key] or 0) then
		return true
	end
	localCooldowns[key] = now + duration
	return false
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Animation ids per action; populated from the equipped character's rig.
-- Placeholder asset ids until animation passes land.
local ANIMATIONS = {
	M1 = { "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0" },
	Heavy = "rbxassetid://0",
	Dash = "rbxassetid://0",
	Skill1 = "rbxassetid://0",
	Skill2 = "rbxassetid://0",
	Ultimate = "rbxassetid://0",
	Block = "rbxassetid://0",
}

local animationCache: { [string]: AnimationTrack } = {}

local function playAnimation(key: string, assetId: string)
	if assetId == "rbxassetid://0" then
		return -- no animation asset yet
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local track = animationCache[key]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = assetId
		track = animator:LoadAnimation(animation)
		animationCache[key] = track
	end
	track:Play(0.05)
end

-- ------------------------------ TARGET LOCK ---------------------------------

local function findLockTarget(): Model?
	local root = getRoot()
	if not root then
		return nil
	end
	local best: Model? = nil
	local bestScore = math.huge
	local camera = workspace.CurrentCamera
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model ~= player.Character then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and humanoid.Health > 0 and targetRoot then
				local distance = (targetRoot.Position - root.Position).Magnitude
				if distance <= CombatConfig.TargetLock.MaxDistance then
					-- Prefer targets near the camera's center line.
					local _, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
					local score = distance + (if onScreen then 0 else 100)
					if score < bestScore then
						best = model
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

local function aimPosition(): Vector3
	if lockedTarget then
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			return targetRoot.Position
		end
	end
	local root = getRoot()
	if root then
		return root.Position + root.CFrame.LookVector * 12
	end
	return Vector3.zero
end

-- -------------------------------- ACTIONS -----------------------------------

local function doM1()
	if onLocalCooldown("M1", CombatConfig.M1.HitWindowSeconds) then
		return
	end
	comboIndex = (comboIndex % CombatConfig.M1.ComboLength) + 1
	playAnimation("M1_" .. comboIndex, ANIMATIONS.M1[comboIndex])
	Remotes.Event("CombatRequestM1"):FireServer(comboIndex)
end

local function doHeavy()
	if onLocalCooldown("Heavy", CombatConfig.Heavy.Cooldown) then
		return
	end
	playAnimation("Heavy", ANIMATIONS.Heavy)
	Remotes.Event("CombatRequestHeavy"):FireServer()
end

local function doDash()
	if onLocalCooldown("Dash", CombatConfig.Dash.Cooldown) then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	local moveDirection = humanoid and humanoid.MoveDirection or Vector3.zero
	local direction = if moveDirection.Magnitude > 0.1 then moveDirection else root.CFrame.LookVector
	playAnimation("Dash", ANIMATIONS.Dash)
	Remotes.Event("CombatRequestDash"):FireServer(direction)
end

local function doSkill(slot: number)
	local key = "Skill" .. slot
	-- Cooldown UI is driven by the server's SkillUsed event; local guard is
	-- just spam suppression.
	if onLocalCooldown(key, 0.5) then
		return
	end
	playAnimation(key, ANIMATIONS[key :: any] or "rbxassetid://0")
	Remotes.Event("CombatRequestSkill"):FireServer(slot, aimPosition())
end

local function doUltimate()
	if energy < CombatConfig.Energy.UltimateCost then
		UIController:Toast("Ultimate not ready")
		return
	end
	playAnimation("Ultimate", ANIMATIONS.Ultimate)
	Remotes.Event("CombatRequestUltimate"):FireServer(aimPosition())
end

-- ------------------------------- LIFECYCLE ----------------------------------

function CombatController:Init(registry)
	InputController = registry.InputController
	CameraController = registry.CameraController
	UIController = registry.UIController
end

function CombatController:Start()
	InputController.M1:Connect(doM1)
	InputController.HeavyStarted:Connect(doHeavy)
	InputController.Dash:Connect(doDash)
	InputController.Skill:Connect(doSkill)
	InputController.Ultimate:Connect(doUltimate)
	InputController.BlockChanged:Connect(function(isBlocking)
		playAnimation("Block", ANIMATIONS.Block)
		Remotes.Event("CombatRequestBlock"):FireServer(isBlocking)
	end)
	InputController.ToggleLock:Connect(function()
		lockedTarget = if lockedTarget then nil else findLockTarget()
		CameraController:SetLockTarget(lockedTarget)
	end)

	-- Drop lock when the target dies or leaves range.
	RunService.Heartbeat:Connect(function()
		if not lockedTarget then
			return
		end
		local humanoid = lockedTarget:FindFirstChildOfClass("Humanoid")
		local targetRoot = lockedTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		local root = getRoot()
		if not humanoid or humanoid.Health <= 0 or not targetRoot or not root
			or (targetRoot.Position - root.Position).Magnitude > CombatConfig.TargetLock.LoseDistance then
			lockedTarget = nil
			CameraController:SetLockTarget(nil)
		end
	end)

	-- Server reconciliation.
	Remotes.Event("CombatStateChanged").OnClientEvent:Connect(function(state, data)
		if state == "Combo" then
			comboIndex = data.Index
			energy = data.Energy
			UIController:SetEnergy(energy)
		elseif state == "SkillUsed" then
			UIController:SetSkillCooldown(data.Slot, data.CooldownEnds)
		elseif state == "Awakened" then
			UIController:ShowAwakening(data.Until)
		elseif state == "UltimateCast" then
			CameraController:PlayCinematic(data.CinematicId, data.Caster, data.Position)
		elseif state == "BossCutscene" then
			CameraController:PlayCutscene(data.CutsceneId, data.Boss)
		end
	end)
end

return CombatController
