--!strict
-- PartyUI.luau
-- Party management (hotkey V): current party with kick/leave, pending invite
-- with Accept/Decline, and an online-players list with Invite buttons.
-- State arrives via PartyUpdated pushes plus a "Get" refresh on open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local PartyUI = {}

local localPlayer = Players.LocalPlayer

local uiRef: any
local listFrame: ScrollingFrame
local partyState: any = nil -- { Id, LeaderUserId, Members }
local pendingInvite: { FromUserId: number, FromName: string }? = nil

local function invoke(action: string, payload: any?): (boolean, any)
	return Remotes.Function("PartyAction"):InvokeServer(action, payload)
end

local function makeRow(order: number, text: string, buttonText: string?, buttonColor: Color3?, onClick: (() -> ())?): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(0.96, 0.085)
	row.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
	row.Parent = listFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(if buttonText then 0.7 else 0.96, 0.8)
	label.Position = UDim2.fromScale(0.02, 0.1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	if buttonText and onClick then
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(0.22, 0.7)
		button.Position = UDim2.fromScale(0.75, 0.15)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = buttonColor or Color3.fromRGB(70, 130, 220)
		button.Text = buttonText
		button.Parent = row
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0.3, 0)
		buttonCorner.Parent = button
		button.Activated:Connect(onClick)
	end
	return row
end

local function makeHeader(order: number, text: string)
	local header = Instance.new("TextLabel")
	header.LayoutOrder = order
	header.Size = UDim2.fromScale(0.96, 0.055)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 220, 120)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = text
	header.Parent = listFrame
end

local function rebuild()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Section: current party
	makeHeader(nextOrder(), "YOUR PARTY")
	local inParty = partyState ~= nil and partyState.Members ~= nil
	local isLeader = inParty and partyState.LeaderUserId == localPlayer.UserId
	local memberIds: { [number]: boolean } = {}
	if inParty then
		for _, member in partyState.Members do
			memberIds[member.UserId] = true
			local crown = if member.UserId == partyState.LeaderUserId then "👑 " else ""
			if isLeader and member.UserId ~= localPlayer.UserId then
				makeRow(nextOrder(), crown .. member.Name, "Kick", Color3.fromRGB(190, 70, 70), function()
					invoke("Kick", { UserId = member.UserId })
				end)
			else
				makeRow(nextOrder(), crown .. member.Name)
			end
		end
		makeRow(nextOrder(), `{#partyState.Members}/4 members`, "Leave", Color3.fromRGB(120, 60, 70), function()
			invoke("Leave")
			partyState = nil
			rebuild()
		end)
	else
		makeRow(nextOrder(), "Not in a party — invite someone below.")
	end

	-- Section: pending invite
	if pendingInvite then
		makeHeader(nextOrder(), "INVITE")
		local invite = pendingInvite :: { FromUserId: number, FromName: string }
		makeRow(nextOrder(), `{invite.FromName} invited you`, "Accept", Color3.fromRGB(90, 190, 90), function()
			local ok, err = invoke("Accept")
			pendingInvite = nil
			if not ok then
				uiRef:Toast(tostring(err))
			end
			rebuild()
		end)
		makeRow(nextOrder(), "", "Decline", Color3.fromRGB(120, 60, 70), function()
			invoke("Decline")
			pendingInvite = nil
			rebuild()
		end)
	end

	-- Section: online players
	makeHeader(nextOrder(), "PLAYERS ONLINE")
	local listed = 0
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and not memberIds[player.UserId] then
			listed += 1
			makeRow(nextOrder(), player.DisplayName, "Invite", Color3.fromRGB(70, 130, 220), function()
				local ok, err = invoke("Invite", { UserId = player.UserId })
				uiRef:Toast(if ok then "Invite sent to " .. player.DisplayName else tostring(err))
			end)
		end
	end
	if listed == 0 then
		makeRow(nextOrder(), "No other players on this server.")
	end
end

function PartyUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "PartyScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "PARTY"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromScale(0.25, 0.15)
	listFrame.Size = UDim2.fromScale(0.5, 0.8)
	listFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
	listFrame.BorderSizePixel = 0
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.fromScale(0, 0)
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.012, 0)
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

	Remotes.Event("PartyUpdated").OnClientEvent:Connect(function(payload)
		if payload.Invite then
			pendingInvite = payload.Invite
			uiRef:Toast(`{payload.Invite.FromName} invited you to a party (press V)`)
		else
			partyState = payload.Party
		end
		if frame.Visible then
			rebuild()
		end
	end)

	return frame
end

function PartyUI.Open()
	local ok, party = Remotes.Function("PartyAction"):InvokeServer("Get")
	if ok then
		partyState = party
	end
	rebuild()
end

return PartyUI
