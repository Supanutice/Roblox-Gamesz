--!strict
-- CameraController.luau
-- Target-lock orbit camera, screen shake, ultimate cinematics, and boss
-- cutscenes. Falls back to default Roblox camera when idle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maid = require(Shared.Utilities.Maid)

local CameraController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local lockTarget: Model? = nil
local lockMaid = Maid.new()
local shakeIntensity = 0

-- ------------------------------- LOCK-ON ------------------------------------

function CameraController:SetLockTarget(target: Model?)
	lockTarget = target
	lockMaid:DoCleaning()
	if not target then
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	lockMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetRoot = lockTarget and lockTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not targetRoot then
			return
		end
		-- Over-the-shoulder framing: behind the player, looking at the target.
		local back = (root.Position - targetRoot.Position).Unit
		local desired = CFrame.lookAt(
			root.Position + back * 10 + Vector3.new(0, 5, 0) + root.CFrame.RightVector * 2,
			targetRoot.Position + Vector3.new(0, 2, 0))
		camera.CFrame = camera.CFrame:Lerp(desired, math.min(1, dt * 10))
	end))
end

-- ----------------------------- SCREEN SHAKE ----------------------------------

function CameraController:Shake(intensity: number, duration: number)
	shakeIntensity = math.max(shakeIntensity, intensity)
	task.delay(duration, function()
		shakeIntensity = math.max(0, shakeIntensity - intensity)
	end)
end

-- ------------------------------ CINEMATICS -----------------------------------

-- Ultimate finisher camera: a quick dolly arc around the caster, then snap
-- back. CinematicId selects per-character framing once bespoke sequences
-- exist; the generic arc keeps every ultimate cinematic from day one.
function CameraController:PlayCinematic(cinematicId: string, caster: Model, focusPosition: Vector3)
	local root = caster:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Only fully take the camera when WE cast it; others get shake only.
	if caster ~= player.Character then
		self:Shake(0.6, 0.8)
		return
	end
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local startCFrame = CFrame.lookAt(root.Position + root.CFrame.RightVector * 8 + Vector3.new(0, 3, 0), root.Position)
	local endCFrame = CFrame.lookAt(focusPosition + Vector3.new(0, 14, 16), focusPosition)
	camera.CFrame = startCFrame
	local tween = TweenService:Create(camera, TweenInfo.new(1.1, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
		{ CFrame = endCFrame })
	tween:Play()
	tween.Completed:Once(function()
		self:Shake(1.2, 0.5)
		task.wait(0.8)
		camera.CameraType = previousType
		if lockTarget then
			self:SetLockTarget(lockTarget) -- re-engage lock rig
		end
	end)
end

-- Boss intro/defeat cutscene: orbit the boss for 3 seconds.
function CameraController:PlayCutscene(cutsceneId: string, boss: Model)
	local root = boss and boss:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local angle = elapsed * 0.8
		local radius = math.max(root.Size.Magnitude * 1.5, 25)
		camera.CFrame = CFrame.lookAt(
			root.Position + Vector3.new(math.cos(angle) * radius, radius * 0.4, math.sin(angle) * radius),
			root.Position)
		if elapsed >= 3 then
			connection:Disconnect()
			camera.CameraType = previousType
		end
	end)
end

-- ------------------------------- LIFECYCLE -----------------------------------

function CameraController:Init() end

function CameraController:Start()
	-- Shake applicator rides on top of whatever camera mode is active.
	RunService.RenderStepped:Connect(function()
		if shakeIntensity > 0.01 then
			local offset = Vector3.new(
				(math.random() - 0.5) * shakeIntensity,
				(math.random() - 0.5) * shakeIntensity,
				0)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			shakeIntensity *= 0.92
		end
	end)
end

return CameraController
