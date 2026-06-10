--!strict
-- UIController.luau
-- Screen router + HUD owner. Screens are modules in Client/UI that expose
-- Build(parent) -> Frame and optional Open/Close hooks. Only one full-screen
-- menu is open at a time; the HUD is always alive underneath.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local UIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InputController

local screenGui: ScreenGui
local hud: { [string]: any } = {}
local screens: { [string]: any } = {}
local openScreen: string? = nil

-- Local mirror of profile data for UI rendering (server remains the truth).
local profileSnapshot: any = nil

-- ------------------------------- HUD ----------------------------------------

local function buildHUD()
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "HUD"
	hudFrame.BackgroundTransparency = 1
	hudFrame.Size = UDim2.fromScale(1, 1)
	hudFrame.Parent = screenGui

	-- Health bar (bottom-left)
	local healthBack = Instance.new("Frame")
	healthBack.Name = "HealthBack"
	healthBack.AnchorPoint = Vector2.new(0, 1)
	healthBack.Position = UDim2.new(0.02, 0, 0.95, 0)
	healthBack.Size = UDim2.fromScale(0.24, 0.025)
	healthBack.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	healthBack.Parent = hudFrame
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	healthFill.Parent = healthBack
	hud.HealthFill = healthFill

	-- Energy / ultimate bar (under health)
	local energyBack = healthBack:Clone()
	energyBack.Name = "EnergyBack"
	energyBack.Position = UDim2.new(0.02, 0, 0.985, 0)
	energyBack.Parent = hudFrame
	local energyFill = energyBack:FindFirstChild("Fill") :: Frame
	energyFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	energyFill.Size = UDim2.fromScale(0, 1)
	hud.EnergyFill = energyFill

	-- Currency readout (top-right)
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "Currencies"
	currencyLabel.AnchorPoint = Vector2.new(1, 0)
	currencyLabel.Position = UDim2.new(0.99, 0, 0.02, 0)
	currencyLabel.Size = UDim2.fromScale(0.3, 0.04)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.TextColor3 = Color3.new(1, 1, 1)
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Right
	currencyLabel.TextScaled = true
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.Text = ""
	currencyLabel.Parent = hudFrame
	hud.CurrencyLabel = currencyLabel

	-- Skill cooldown indicators (bottom-center)
	hud.SkillButtons = {}
	for slot = 1, 3 do
		local button = Instance.new("TextLabel")
		button.Name = "Skill" .. slot
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.46 + slot * 0.05, 0, 0.97, 0)
		button.Size = UDim2.fromScale(0.04, 0.07)
		button.SizeConstraint = Enum.SizeConstraint.RelativeXX
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Text = if slot == 3 then "ULT" else tostring(slot)
		button.Parent = hudFrame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = button
		hud.SkillButtons[slot] = button
	end

	-- Toast message area
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.12)
	toast.Size = UDim2.fromScale(0.4, 0.05)
	toast.BackgroundTransparency = 1
	toast.TextColor3 = Color3.fromRGB(255, 230, 150)
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.TextTransparency = 1
	toast.Text = ""
	toast.Parent = hudFrame
	hud.Toast = toast
end

local function refreshCurrencies()
	if not profileSnapshot or not hud.CurrencyLabel then
		return
	end
	local c = profileSnapshot.Currencies
	hud.CurrencyLabel.Text = `🪙 {c.Gold}   💎 {c.Gems}   🎟 {c.RaidTokens}`
end

-- ----------------------------- PUBLIC API ------------------------------------

function UIController:Toast(message: string)
	local toast = hud.Toast :: TextLabel
	toast.Text = message
	toast.TextTransparency = 0
	TweenService:Create(toast, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }):Play()
end

function UIController:SetEnergy(energy: number)
	local CombatConfig = require(Shared.Configs.CombatConfig)
	if hud.EnergyFill then
		hud.EnergyFill.Size = UDim2.fromScale(math.clamp(energy / CombatConfig.Energy.Max, 0, 1), 1)
	end
end

function UIController:SetSkillCooldown(slot: number, cooldownEnds: number)
	local button = hud.SkillButtons and hud.SkillButtons[slot]
	if not button then
		return
	end
	task.spawn(function()
		while os.clock() < cooldownEnds do
			button.Text = string.format("%.0f", cooldownEnds - os.clock())
			button.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
			task.wait(0.25)
		end
		button.Text = if slot == 3 then "ULT" else tostring(slot)
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
	end)
end

function UIController:ShowAwakening(untilTime: number)
	self:Toast("⚡ AWAKENED ⚡")
end

function UIController:GetProfile(): any
	return profileSnapshot
end

function UIController:OpenScreen(name: string)
	if openScreen == name then
		self:CloseScreen()
		return
	end
	self:CloseScreen()
	local screen = screens[name]
	if not screen then
		-- Lazy-load the screen module from Client/UI.
		local uiFolder = script.Parent.Parent:WaitForChild("UI")
		local module = uiFolder:FindFirstChild(name .. "UI")
		if not module then
			self:Toast(name .. " screen coming soon")
			return
		end
		screen = require(module)
		screen.Frame = screen.Build(screenGui, self)
		screens[name] = screen
	end
	screen.Frame.Visible = true
	if screen.Open then
		screen.Open(self)
	end
	openScreen = name
end

function UIController:CloseScreen()
	if openScreen and screens[openScreen] then
		local screen = screens[openScreen]
		screen.Frame.Visible = false
		if screen.Close then
			screen.Close(self)
		end
	end
	openScreen = nil
end

-- ------------------------------- LIFECYCLE -----------------------------------

function UIController:Init(registry)
	InputController = registry.InputController
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AnimeWarriorsUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	buildHUD()
end

function UIController:Start()
	InputController.OpenMenu:Connect(function(name)
		self:OpenScreen(name)
	end)

	Remotes.Event("ProfileLoaded").OnClientEvent:Connect(function(snapshot)
		profileSnapshot = snapshot
		refreshCurrencies()
	end)
	Remotes.Event("CurrencyChanged").OnClientEvent:Connect(function(currency, amount)
		if profileSnapshot then
			profileSnapshot.Currencies[currency] = amount
			refreshCurrencies()
		end
	end)
	Remotes.Event("NPCDialogue").OnClientEvent:Connect(function(npcName, line)
		self:Toast(`{npcName}: {line}`)
	end)
	Remotes.Event("QuestProgressChanged").OnClientEvent:Connect(function(questId, progress)
		if profileSnapshot and profileSnapshot.Quests then
			local active = profileSnapshot.Quests.Active[questId]
			if active then
				active.Progress = progress
			else
				profileSnapshot.Quests.Active[questId] = { Progress = progress, AcceptedAt = os.time() }
			end
		end
	end)

	-- Health bar follows the live humanoid.
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function update()
			if hud.HealthFill then
				hud.HealthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
			end
		end
		humanoid.HealthChanged:Connect(update)
		update()
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return UIController
