--!strict
-- VFXController.luau
-- Renders server combat events: damage numbers, status effect particles,
-- boss telegraphs. Pure presentation — destroying this module changes
-- nothing about gameplay outcomes. Booted by Controllers/EffectsController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatusEffectData = require(Shared.Data.StatusEffectData)
local Remotes = require(Shared.Net.Remotes)

local VFXController = {}

local ELEMENT_COLORS: { [string]: Color3 } = {
	Fire = Color3.fromRGB(255, 110, 50),
	Water = Color3.fromRGB(70, 160, 255),
	Wind = Color3.fromRGB(150, 255, 180),
	Earth = Color3.fromRGB(190, 140, 80),
	Light = Color3.fromRGB(255, 245, 170),
	Dark = Color3.fromRGB(150, 80, 220),
	Lightning = Color3.fromRGB(255, 240, 90),
	Ice = Color3.fromRGB(170, 230, 255),
}

-- --------------------------- DAMAGE NUMBERS ---------------------------------

function VFXController.ShowDamageNumber(target: Model, amount: number, isCrit: boolean, element: string)
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 1.4)
	billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = root
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = ELEMENT_COLORS[element] or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = (if isCrit then "✦ " else "") .. tostring(amount)
	label.Parent = billboard
	if isCrit then
		label.TextColor3 = Color3.fromRGB(255, 80, 80)
		billboard.Size = UDim2.fromScale(6, 2)
	end

	TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = billboard.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(billboard, 0.9)
end

-- --------------------------- STATUS PARTICLES --------------------------------

local activeStatusVFX: { [Model]: { [string]: Instance } } = {}

function VFXController.ShowStatusEffect(target: Model, effectId: string, duration: number)
	local def = StatusEffectData.Effects[effectId]
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not root then
		return
	end
	activeStatusVFX[target] = activeStatusVFX[target] or {}
	if activeStatusVFX[target][effectId] then
		Debris:AddItem(activeStatusVFX[target][effectId], 0) -- replace
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Status_" .. effectId
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Size = NumberSequence.new(0.5)
	local colorMap: { [string]: Color3 } = {
		Burn = ELEMENT_COLORS.Fire,
		Freeze = ELEMENT_COLORS.Ice,
		Shock = ELEMENT_COLORS.Lightning,
		Poison = Color3.fromRGB(140, 220, 80),
		Bleed = Color3.fromRGB(220, 40, 60),
		Stun = Color3.fromRGB(255, 235, 130),
	}
	emitter.Color = ColorSequence.new(colorMap[effectId] or Color3.new(1, 1, 1))
	emitter.Parent = root
	activeStatusVFX[target][effectId] = emitter
	Debris:AddItem(emitter, duration)
end

-- ---------------------------- BOSS TELEGRAPHS --------------------------------

function VFXController.ShowTelegraph(data: { Boss: Model, Shape: string, Radius: number?, Position: Vector3?, Duration: number })
	local position: Vector3
	if data.Shape == "Circle" then
		local root = data.Boss and data.Boss:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		position = root.Position
	else
		position = data.Position or Vector3.zero
	end

	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(255, 60, 60)
	disc.Transparency = 0.6
	local radius = data.Radius or 8
	disc.Size = Vector3.new(0.2, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = workspace
	TweenService:Create(disc, TweenInfo.new(data.Duration), { Transparency = 0.2 }):Play()
	Debris:AddItem(disc, data.Duration)
end

-- ------------------------------- WIRING --------------------------------------

function VFXController.Boot()
	Remotes.Event("CombatHitConfirmed").OnClientEvent:Connect(function(target, damage, isCrit, element)
		if typeof(target) == "Instance" and target:IsA("Model") then
			VFXController.ShowDamageNumber(target, damage, isCrit, element)
		end
	end)
	Remotes.Event("StatusEffectApplied").OnClientEvent:Connect(function(target, effectId, duration)
		if typeof(target) == "Instance" and target:IsA("Model") then
			VFXController.ShowStatusEffect(target, effectId, duration)
		end
	end)
	Remotes.Event("CombatStateChanged").OnClientEvent:Connect(function(state, data)
		if state == "BossTelegraph" then
			VFXController.ShowTelegraph(data)
		end
	end)
end

return VFXController
