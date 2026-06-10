--!strict
-- InventoryUI.luau
-- Scrolling item grid with category tabs, fed by the profile snapshot and
-- live InventoryChanged deltas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDatabase = require(Shared.Data.ItemDatabase)
local GameConfig = require(Shared.Configs.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local InventoryUI = {}

local rarityColors: { [string]: Color3 } = {}
for _, rarity in GameConfig.Rarities do
	rarityColors[rarity.Name] = rarity.Color
end

local CATEGORIES = { "All", "Weapon", "Material", "Consumable" }

local activeCategory = "All"
local listFrame: ScrollingFrame
local uiRef: any

local function rebuild()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local profile = uiRef:GetProfile()
	if not profile then
		return
	end
	local order = 0
	for uid, entry in profile.Inventory do
		local def = ItemDatabase.ById[entry.ItemId]
		if not def or (activeCategory ~= "All" and def.Category ~= activeCategory) then
			continue
		end
		order += 1
		local cell = Instance.new("Frame")
		cell.LayoutOrder = order
		cell.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
		cell.Parent = listFrame
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarityColors[def.Rarity] or Color3.new(1, 1, 1)
		stroke.Thickness = 2
		stroke.Parent = cell
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.Gotham
		label.Text = `{def.Name}\nx{entry.Count}` .. (if entry.WeaponLevel then `  Lv.{entry.WeaponLevel}` else "")
		label.Parent = cell
	end
end

function InventoryUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "InventoryScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "INVENTORY"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	-- Category tabs
	for index, category in CATEGORIES do
		local tab = Instance.new("TextButton")
		tab.Text = category
		tab.Font = Enum.Font.GothamBold
		tab.TextScaled = true
		tab.TextColor3 = Color3.new(1, 1, 1)
		tab.BackgroundColor3 = Color3.fromRGB(46, 42, 70)
		tab.Position = UDim2.fromScale(0.05 + (index - 1) * 0.12, 0.14)
		tab.Size = UDim2.fromScale(0.11, 0.05)
		tab.Parent = frame
		tab.Activated:Connect(function()
			activeCategory = category
			rebuild()
		end)
	end

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromScale(0.05, 0.22)
	listFrame.Size = UDim2.fromScale(0.9, 0.72)
	listFrame.BackgroundTransparency = 1
	listFrame.CanvasSize = UDim2.fromScale(0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = frame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.15, 0.22)
	grid.CellPadding = UDim2.fromScale(0.012, 0.02)
	grid.Parent = listFrame

	local close = Instance.new("TextButton")
	close.Text = "✕"
	close.Position = UDim2.fromScale(0.94, 0.03)
	close.Size = UDim2.fromScale(0.04, 0.06)
	close.BackgroundColor3 = Color3.fromRGB(60, 30, 36)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextScaled = true
	close.Parent = frame
	close.Activated:Connect(function()
		ui:CloseScreen()
	end)

	Remotes.Event("InventoryChanged").OnClientEvent:Connect(function()
		if frame.Visible then
			rebuild()
		end
	end)

	return frame
end

function InventoryUI.Open()
	rebuild()
end

return InventoryUI
