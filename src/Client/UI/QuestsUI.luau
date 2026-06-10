--!strict
-- QuestsUI.luau
-- Quest log: tabbed list of active quests with live objective progress and a
-- CLAIM button that lights up when every objective is complete. Progress
-- arrives via QuestProgressChanged (UIController patches the snapshot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestDatabase = require(Shared.Data.QuestDatabase)
local Remotes = require(Shared.Net.Remotes)

local QuestsUI = {}

local TABS = { "All", "Main", "Side", "Daily", "Weekly" }

local uiRef: any
local listFrame: ScrollingFrame
local activeTab = "All"

local function objectiveText(quest, progress: { number }): (string, boolean)
	local lines = {}
	local complete = true
	for index, objective in quest.Objectives do
		local current = progress[index] or 0
		if current < objective.Count then
			complete = false
		end
		local target = objective.TargetId or "any"
		table.insert(lines, `• {objective.Type} ({target}): {current}/{objective.Count}`)
	end
	return table.concat(lines, "\n"), complete
end

local function rewardText(rewards: { [string]: number }): string
	local parts = {}
	for key, amount in rewards do
		table.insert(parts, `{key} x{amount}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

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
	if not profile or not profile.Quests then
		return
	end

	local order = 0
	for questId, active in profile.Quests.Active do
		local quest = QuestDatabase.ById[questId]
		if not quest then
			continue
		end
		if activeTab ~= "All" and quest.Type ~= activeTab then
			continue
		end
		order += 1

		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.fromScale(0.96, 0.3)
		row.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
		row.Parent = listFrame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.06, 0)
		corner.Parent = row

		local objectives, complete = objectiveText(quest, active.Progress or {})

		local info = Instance.new("TextLabel")
		info.Size = UDim2.fromScale(0.72, 0.92)
		info.Position = UDim2.fromScale(0.02, 0.04)
		info.BackgroundTransparency = 1
		info.TextColor3 = Color3.new(1, 1, 1)
		info.TextScaled = true
		info.Font = Enum.Font.Gotham
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Text = `[{quest.Type}] {quest.Name}\n{objectives}\nRewards: {rewardText(quest.Rewards)}`
		info.Parent = row

		local claim = Instance.new("TextButton")
		claim.Size = UDim2.fromScale(0.2, 0.5)
		claim.Position = UDim2.fromScale(0.77, 0.25)
		claim.Font = Enum.Font.GothamBlack
		claim.TextScaled = true
		claim.Text = if complete then "CLAIM" else "IN PROGRESS"
		claim.TextColor3 = Color3.new(1, 1, 1)
		claim.BackgroundColor3 = if complete then Color3.fromRGB(90, 190, 90) else Color3.fromRGB(60, 58, 80)
		claim.AutoButtonColor = complete
		claim.Parent = row
		local claimCorner = Instance.new("UICorner")
		claimCorner.CornerRadius = UDim.new(0.3, 0)
		claimCorner.Parent = claim

		if complete then
			claim.Activated:Connect(function()
				local ok, result = Remotes.Function("QuestClaim"):InvokeServer(questId)
				if ok then
					profile.Quests.Active[questId] = nil
					profile.Quests.Completed[questId] = true
					uiRef:Toast(`Quest complete! {rewardText(result)}`)
					rebuild()
				else
					uiRef:Toast(tostring(result))
				end
			end)
		end
	end

	if order == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.fromScale(0.96, 0.2)
		empty.BackgroundTransparency = 1
		empty.Parent = listFrame
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(150, 150, 170)
		label.TextScaled = true
		label.Font = Enum.Font.Gotham
		label.Text = "No active quests — talk to NPCs in the world to find work."
		label.Parent = empty
	end
end

function QuestsUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "QuestsScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "QUEST LOG"
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
		button.Text = tab
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = Color3.fromRGB(46, 42, 70)
		button.Position = UDim2.fromScale(0.05 + (index - 1) * 0.1, 0.14)
		button.Size = UDim2.fromScale(0.09, 0.05)
		button.Parent = frame
		button.Activated:Connect(function()
			activeTab = tab
			rebuild()
		end)
	end

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromScale(0.05, 0.22)
	listFrame.Size = UDim2.fromScale(0.9, 0.72)
	listFrame.BackgroundTransparency = 1
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.fromScale(0, 0)
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = listFrame

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

	Remotes.Event("QuestProgressChanged").OnClientEvent:Connect(function()
		if frame.Visible then
			rebuild()
		end
	end)

	return frame
end

function QuestsUI.Open()
	rebuild()
end

return QuestsUI
