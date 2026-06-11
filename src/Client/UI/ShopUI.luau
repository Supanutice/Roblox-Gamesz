--!strict
-- ShopUI.luau
-- Shop screen (hotkey M), three tabs:
--   Daily      — streak display + one-tap daily reward claim
--   BattlePass — 50-tier dual-track list with CLAIM buttons + XP progress
--   Cosmetics  — gem-priced rotation items (cosmetics only, never power)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)
local ProgressionConfig = require(Shared.Configs.ProgressionConfig)
local Remotes = require(Shared.Net.Remotes)

local ShopUI = {}

local TABS = { "Daily", "BattlePass", "Cosmetics" }

local uiRef: any
local contentFrame: ScrollingFrame
local activeTab = "Daily"
local shopData: any = nil

local function rewardText(rewards: { [string]: number }): string
	local parts = {}
	for key, amount in rewards do
		table.insert(parts, `{key} x{amount}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function clearContent()
	for _, child in contentFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeRow(order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(0.97, height)
	row.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
	row.Parent = contentFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = row
	return row
end

local function makeText(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

local function makeClaimButton(parent: Instance, text: string, enabled: boolean, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromScale(0.78, 0.18)
	button.Size = UDim2.fromScale(0.19, 0.64)
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.BackgroundColor3 = if enabled then Color3.fromRGB(90, 190, 90) else Color3.fromRGB(60, 58, 80)
	button.AutoButtonColor = enabled
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = button
	if enabled then
		button.Activated:Connect(onClick)
	end
	return button
end

local rebuild -- forward declaration

local function refreshData()
	local ok, data = Remotes.Function("ShopData"):InvokeServer()
	if ok then
		shopData = data
	end
end

-- ------------------------------ DAILY TAB -------------------------------------

local function buildDaily()
	local daily = shopData and shopData.Daily
	if not daily then
		return
	end
	local cycle = ProgressionConfig.DailyRewards
	local nextIndex = (daily.Streak % #cycle) + 1

	local header = makeRow(1, 0.18)
	makeText(header, `🔥 Login streak: {daily.Streak} day(s)`, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.7, 0.8),
		Color3.fromRGB(255, 220, 120))

	for index, reward in cycle do
		local row = makeRow(1 + index, 0.12)
		local marker = if index == nextIndex and daily.CanClaim then "▶ " else ""
		makeText(row, `{marker}Day {index}: {rewardText(reward)}`, UDim2.fromScale(0.03, 0.12), UDim2.fromScale(0.72, 0.76))
		if index == nextIndex then
			makeClaimButton(row, if daily.CanClaim then "CLAIM" else "CLAIMED", daily.CanClaim, function()
				local ok, result = Remotes.Function("DailyRewardClaim"):InvokeServer()
				if ok then
					uiRef:Toast("Daily reward: " .. rewardText(result))
					refreshData()
					rebuild()
				else
					uiRef:Toast(tostring(result))
				end
			end)
		end
	end
end

-- --------------------------- BATTLE PASS TAB -----------------------------------

local function buildBattlePass()
	local bp = shopData and shopData.BattlePass
	if not bp then
		return
	end
	local config = MonetizationConfig.BattlePass

	local header = makeRow(1, 0.18)
	makeText(header,
		`⭐ Season {bp.SeasonId} — Tier {bp.Tier}/{config.Tiers}   ({bp.XP}/{config.XPPerTier} XP)`
			.. (if bp.PremiumOwned then "   👑 PREMIUM" else ""),
		UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.45), Color3.fromRGB(255, 220, 120))
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromScale(0.03, 0.65)
	barBack.Size = UDim2.fromScale(0.94, 0.2)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	barBack.Parent = header
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(bp.XP / config.XPPerTier, 0, 1), 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	fill.Parent = barBack

	for tier = 1, config.Tiers do
		local unlocked = tier <= bp.Tier
		local row = makeRow(1 + tier, 0.13)
		if not unlocked then
			row.BackgroundTransparency = 0.5
		end
		makeText(row, `Tier {tier}` .. (if tier % 10 == 0 then " ★" else ""),
			UDim2.fromScale(0.02, 0.12), UDim2.fromScale(0.12, 0.76),
			if unlocked then Color3.new(1, 1, 1) else Color3.fromRGB(130, 130, 150))

		-- Free track claim.
		local freeClaimed = bp.ClaimedFree[tier] == true
		local freeButton = makeClaimButton(row,
			if freeClaimed then "✓ FREE" elseif unlocked then "FREE" else "LOCKED",
			unlocked and not freeClaimed,
			function()
				local ok, result = Remotes.Function("BattlePassClaim"):InvokeServer(tier, "Free")
				if ok then
					uiRef:Toast(`Tier {tier} (Free): {rewardText(result)}`)
					refreshData()
					rebuild()
				else
					uiRef:Toast(tostring(result))
				end
			end)
		freeButton.Position = UDim2.fromScale(0.5, 0.18)
		freeButton.Size = UDim2.fromScale(0.21, 0.64)

		-- Premium track claim.
		local premiumClaimed = bp.ClaimedPremium[tier] == true
		local premiumEnabled = unlocked and bp.PremiumOwned and not premiumClaimed
		local premiumButton = makeClaimButton(row,
			if premiumClaimed then "✓ PREM" elseif bp.PremiumOwned then "PREMIUM" else "🔒 PREM",
			premiumEnabled,
			function()
				local ok, result = Remotes.Function("BattlePassClaim"):InvokeServer(tier, "Premium")
				if ok then
					uiRef:Toast(`Tier {tier} (Premium): {rewardText(result)}`)
					refreshData()
					rebuild()
				else
					uiRef:Toast(tostring(result))
				end
			end)
		premiumButton.Position = UDim2.fromScale(0.74, 0.18)
		premiumButton.Size = UDim2.fromScale(0.23, 0.64)
		if premiumEnabled then
			premiumButton.BackgroundColor3 = Color3.fromRGB(170, 90, 240)
		end
	end
end

-- ---------------------------- COSMETICS TAB ------------------------------------

local function buildCosmetics()
	if not shopData then
		return
	end
	local header = makeRow(1, 0.14)
	makeText(header, `🛍 Rotation refreshes every {MonetizationConfig.CosmeticShop.RotationDays} days — cosmetics only, never power!`,
		UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.94, 0.7), Color3.fromRGB(170, 220, 255))

	for index, cosmeticId in shopData.Rotation do
		local owned = shopData.OwnedCosmetics[cosmeticId] == true
		local row = makeRow(1 + index, 0.14)
		makeText(row, `✨ {cosmeticId}`, UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.7, 0.7))
		makeClaimButton(row,
			if owned then "OWNED" else `BUY 💎{shopData.CosmeticPriceGems}`,
			not owned,
			function()
				local ok, err = Remotes.Function("ShopPurchase"):InvokeServer(cosmeticId)
				if ok then
					uiRef:Toast("Purchased " .. cosmeticId .. "!")
					refreshData()
					rebuild()
				else
					uiRef:Toast(tostring(err))
				end
			end)
	end
end

-- ------------------------------- SCREEN ----------------------------------------

rebuild = function()
	if not contentFrame then
		return
	end
	clearContent()
	if activeTab == "Daily" then
		buildDaily()
	elseif activeTab == "BattlePass" then
		buildBattlePass()
	else
		buildCosmetics()
	end
end

function ShopUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "ShopScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "SHOP"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	for index, tab in TABS do
		local button = Instance.new("TextButton")
		button.Text = if tab == "BattlePass" then "Battle Pass" else tab
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = Color3.fromRGB(46, 42, 70)
		button.Position = UDim2.fromScale(0.05 + (index - 1) * 0.16, 0.14)
		button.Size = UDim2.fromScale(0.15, 0.05)
		button.Parent = frame
		button.Activated:Connect(function()
			activeTab = tab
			rebuild()
		end)
	end

	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Position = UDim2.fromScale(0.05, 0.22)
	contentFrame.Size = UDim2.fromScale(0.9, 0.72)
	contentFrame.BackgroundTransparency = 1
	contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentFrame.CanvasSize = UDim2.fromScale(0, 0)
	contentFrame.ScrollBarThickness = 6
	contentFrame.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.012, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = contentFrame

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

function ShopUI.Open()
	refreshData()
	rebuild()
end

return ShopUI
