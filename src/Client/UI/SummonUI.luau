--!strict
-- SummonUI.luau
-- Summon screen: banner selector, x1 / x10 buttons, and the reveal sequence.
-- Reveal cadence is rarity-aware (Legendary+ gets the long flash).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BannerConfig = require(Shared.Configs.BannerConfig)
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local GameConfig = require(Shared.Configs.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local SummonUI = {}

local rarityColors: { [string]: Color3 } = {}
for _, rarity in GameConfig.Rarities do
	rarityColors[rarity.Name] = rarity.Color
end

local selectedBannerIndex = 1
local busy = false

function SummonUI.Build(parent: ScreenGui, ui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "SummonScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "SUMMON"
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local bannerLabel = Instance.new("TextLabel")
	bannerLabel.Name = "BannerName"
	bannerLabel.Font = Enum.Font.GothamBold
	bannerLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	bannerLabel.TextScaled = true
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Position = UDim2.fromScale(0.3, 0.15)
	bannerLabel.Size = UDim2.fromScale(0.4, 0.06)
	bannerLabel.Parent = frame

	local function refreshBanner()
		bannerLabel.Text = BannerConfig.Banners[selectedBannerIndex].Name
	end
	refreshBanner()

	local prev = Instance.new("TextButton")
	prev.Text = "◀"
	prev.Position = UDim2.fromScale(0.24, 0.15)
	prev.Size = UDim2.fromScale(0.04, 0.06)
	prev.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
	prev.TextColor3 = Color3.new(1, 1, 1)
	prev.TextScaled = true
	prev.Parent = frame
	prev.Activated:Connect(function()
		selectedBannerIndex = (selectedBannerIndex - 2) % #BannerConfig.Banners + 1
		refreshBanner()
	end)
	local nextButton = prev:Clone()
	nextButton.Text = "▶"
	nextButton.Position = UDim2.fromScale(0.72, 0.15)
	nextButton.Parent = frame
	nextButton.Activated:Connect(function()
		selectedBannerIndex = selectedBannerIndex % #BannerConfig.Banners + 1
		refreshBanner()
	end)

	-- Result grid
	local results = Instance.new("Frame")
	results.Name = "Results"
	results.BackgroundTransparency = 1
	results.Position = UDim2.fromScale(0.1, 0.28)
	results.Size = UDim2.fromScale(0.8, 0.45)
	results.Parent = frame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.18, 0.45)
	grid.CellPadding = UDim2.fromScale(0.02, 0.05)
	grid.Parent = results

	local function showResults(pulls)
		for _, child in results:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, pull in pulls do
			local def = CharacterDatabase.ById[pull.CharacterId]
			local card = Instance.new("Frame")
			card.BackgroundColor3 = rarityColors[pull.Rarity] or Color3.new(1, 1, 1)
			card.BackgroundTransparency = 1
			card.LayoutOrder = index
			card.Parent = results
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.08, 0)
			corner.Parent = card

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Text = def.Name .. (if pull.WasDuplicate then "\n(+10 shards)" else "")
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.fromScale(1, 0.4)
			nameLabel.Position = UDim2.fromScale(0, 0.6)
			nameLabel.TextTransparency = 1
			nameLabel.Parent = card

			-- Staggered reveal; long flash on Legendary+.
			local isBig = pull.Rarity ~= "Common" and pull.Rarity ~= "Rare" and pull.Rarity ~= "Epic"
			task.delay(index * (if isBig then 0.45 else 0.2), function()
				TweenService:Create(card, TweenInfo.new(if isBig then 0.9 else 0.3),
					{ BackgroundTransparency = 0.15 }):Play()
				TweenService:Create(nameLabel, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
			end)
		end
	end

	-- Pull buttons
	local function makePullButton(text: string, count: number, xScale: number)
		local button = Instance.new("TextButton")
		button.Text = text
		button.Font = Enum.Font.GothamBlack
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = Color3.fromRGB(120, 70, 220)
		button.Position = UDim2.fromScale(xScale, 0.82)
		button.Size = UDim2.fromScale(0.18, 0.08)
		button.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = button
		button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local banner = BannerConfig.Banners[selectedBannerIndex]
			local ok, result = Remotes.Function("SummonRequest"):InvokeServer(banner.Id, count)
			if ok then
				showResults(result)
				Remotes.Event("SummonAnimationDone"):FireServer()
			else
				ui:Toast(tostring(result))
			end
			busy = false
		end)
	end
	makePullButton("Summon x1", 1, 0.28)
	makePullButton("Summon x10", 10, 0.54)

	-- Close button
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

	return frame
end

return SummonUI
