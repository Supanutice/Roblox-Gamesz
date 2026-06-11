--!strict
-- GuildUI.luau
-- Guild screen (hotkey G). No guild: create form + pending invite accept.
-- In a guild: header (name/level/XP), editable MOTD (with permission),
-- member roster with kick controls, online-player invite list, and the
-- weekly Guild Raid panel (rotation boss + attempts left + START RAID).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuildConfig = require(Shared.Configs.GuildConfig)
local BossDatabase = require(Shared.Data.BossDatabase)
local Remotes = require(Shared.Net.Remotes)

local GuildUI = {}

local localPlayer = Players.LocalPlayer

local uiRef: any
local listFrame: ScrollingFrame
local guildDoc: any = nil
local pendingInvite: { GuildName: string, From: string }? = nil

local function invoke(action: string, payload: any?): (boolean, any)
	return Remotes.Function("GuildAction"):InvokeServer(action, payload)
end

-- ------------------------------ ROW HELPERS ------------------------------------

local function makeRow(order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(0.97, height)
	row.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
	row.Parent = listFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
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

local function makeButton(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = size
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = color
	button.Text = text
	button.Parent = parent
	button.Activated:Connect(onClick)
	return button
end

local function makeHeader(order: number, text: string)
	local header = Instance.new("TextLabel")
	header.LayoutOrder = order
	header.Size = UDim2.fromScale(0.97, 0.05)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 220, 120)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = text
	header.Parent = listFrame
end

local rebuild -- forward declaration

local function refresh()
	local ok, doc = invoke("Get")
	guildDoc = if ok then doc else nil
	rebuild()
end

-- ------------------------------ NO-GUILD VIEW ----------------------------------

local function buildNoGuild()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	if pendingInvite then
		makeHeader(nextOrder(), "INVITATION")
		local invite = pendingInvite :: { GuildName: string, From: string }
		local row = makeRow(nextOrder(), 0.12)
		makeText(row, `{invite.From} invited you to "{invite.GuildName}"`,
			UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.6, 0.7))
		makeButton(row, "ACCEPT", UDim2.fromScale(0.66, 0.2), UDim2.fromScale(0.15, 0.6),
			Color3.fromRGB(90, 190, 90), function()
				local ok, err = invoke("AcceptInvite")
				pendingInvite = nil
				if ok then
					uiRef:Toast("Welcome to the guild!")
					refresh()
				else
					uiRef:Toast(tostring(err))
					rebuild()
				end
			end)
		makeButton(row, "DECLINE", UDim2.fromScale(0.82, 0.2), UDim2.fromScale(0.15, 0.6),
			Color3.fromRGB(120, 60, 70), function()
				pendingInvite = nil
				rebuild()
			end)
	end

	makeHeader(nextOrder(), "CREATE A GUILD")
	local row = makeRow(nextOrder(), 0.16)
	local nameBox = Instance.new("TextBox")
	nameBox.Position = UDim2.fromScale(0.03, 0.25)
	nameBox.Size = UDim2.fromScale(0.55, 0.5)
	nameBox.Font = Enum.Font.Gotham
	nameBox.TextScaled = true
	nameBox.TextColor3 = Color3.new(1, 1, 1)
	nameBox.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	nameBox.PlaceholderText = "Guild name (3-20 characters)…"
	nameBox.Text = ""
	nameBox.ClearTextOnFocus = false
	nameBox.Parent = row
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0.2, 0)
	boxCorner.Parent = nameBox
	makeButton(row, `CREATE 💎{GuildConfig.CreateCostGems}`, UDim2.fromScale(0.62, 0.25), UDim2.fromScale(0.34, 0.5),
		Color3.fromRGB(120, 70, 220), function()
			local ok, result = invoke("Create", { Name = nameBox.Text })
			if ok then
				uiRef:Toast("Guild founded!")
				refresh()
			else
				uiRef:Toast(tostring(result))
			end
		end)

	local hint = makeRow(nextOrder(), 0.1)
	hint.BackgroundTransparency = 0.5
	makeText(hint, "…or ask a guild officer to invite you (they use the list in their guild screen).",
		UDim2.fromScale(0.03, 0.2), UDim2.fromScale(0.94, 0.6), Color3.fromRGB(165, 160, 190))
end

-- ------------------------------ GUILD VIEW --------------------------------------

local function buildGuild()
	local doc = guildDoc
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local myEntry = doc.Members[tostring(localPlayer.UserId)]
	local myRank = if myEntry then myEntry.Rank else "Member"
	local myPermissions = GuildConfig.Permissions[myRank] or {}
	local function can(permission: string): boolean
		return table.find(myPermissions, permission) ~= nil
	end

	-- Header: name, level, XP bar.
	local header = makeRow(nextOrder(), 0.16)
	makeText(header, `🏰 {doc.Name}   ·   Level {doc.Level}   ·   Your rank: {myRank}`,
		UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.42), Color3.fromRGB(255, 220, 120))
	local xpNeeded = math.floor(GuildConfig.Leveling.XPPerLevelBase * doc.Level ^ 1.6)
	makeText(header, `XP {doc.XP} / {xpNeeded}`, UDim2.fromScale(0.03, 0.52), UDim2.fromScale(0.3, 0.3),
		Color3.fromRGB(165, 160, 190))
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromScale(0.34, 0.58)
	barBack.Size = UDim2.fromScale(0.62, 0.18)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	barBack.Parent = header
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(doc.XP / xpNeeded, 0, 1), 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	fill.Parent = barBack

	-- MOTD.
	makeHeader(nextOrder(), "MESSAGE OF THE DAY")
	local motdRow = makeRow(nextOrder(), 0.13)
	if can("EditMOTD") then
		local motdBox = Instance.new("TextBox")
		motdBox.Position = UDim2.fromScale(0.03, 0.2)
		motdBox.Size = UDim2.fromScale(0.72, 0.6)
		motdBox.Font = Enum.Font.Gotham
		motdBox.TextScaled = true
		motdBox.TextColor3 = Color3.new(1, 1, 1)
		motdBox.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
		motdBox.Text = doc.MOTD
		motdBox.ClearTextOnFocus = false
		motdBox.Parent = motdRow
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0.2, 0)
		boxCorner.Parent = motdBox
		makeButton(motdRow, "SAVE", UDim2.fromScale(0.78, 0.2), UDim2.fromScale(0.19, 0.6),
			Color3.fromRGB(70, 130, 220), function()
				local ok, err = invoke("SetMOTD", { MOTD = motdBox.Text })
				uiRef:Toast(if ok then "MOTD updated" else tostring(err))
			end)
	else
		makeText(motdRow, `📜 {doc.MOTD}`, UDim2.fromScale(0.03, 0.2), UDim2.fromScale(0.94, 0.6))
	end

	-- Weekly raid panel.
	makeHeader(nextOrder(), "GUILD RAID — THIS WEEK")
	local week = math.floor(os.time() / 604_800)
	local bossId = GuildConfig.Raids.BossRotation[(week % #GuildConfig.Raids.BossRotation) + 1]
	local bossDef = BossDatabase.ById[bossId]
	local used = if doc.WeekStamp == week then doc.RaidAttemptsThisWeek else 0
	local left = GuildConfig.Raids.WeeklyAttempts - used
	local raidRow = makeRow(nextOrder(), 0.16)
	makeText(raidRow, `☠ {bossDef.Name}  (Lv.{bossDef.Level} {bossDef.Element})\nAttempts left: {left}/{GuildConfig.Raids.WeeklyAttempts}`,
		UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.6, 0.8))
	makeButton(raidRow,
		if left > 0 then "⚔ START RAID" else "NO ATTEMPTS",
		UDim2.fromScale(0.66, 0.22), UDim2.fromScale(0.31, 0.56),
		if left > 0 and can("StartRaid") then Color3.fromRGB(170, 90, 240) else Color3.fromRGB(60, 58, 80),
		function()
			local ok, err = invoke("StartRaid")
			if ok then
				uiRef:Toast("The raid begins — brace yourselves!")
				uiRef:CloseScreen()
			else
				uiRef:Toast(tostring(err))
			end
		end)

	-- Members.
	local memberCount = 0
	for _ in doc.Members do
		memberCount += 1
	end
	makeHeader(nextOrder(), `MEMBERS ({memberCount}/{GuildConfig.MaxMembers})`)
	for userIdKey, member in doc.Members do
		local userId = tonumber(userIdKey) :: number
		local row = makeRow(nextOrder(), 0.09)
		local crown = if userId == doc.LeaderUserId then "👑 " else ""
		local nameLabel = makeText(row, `{crown}[{member.Rank}]  …`, UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.7, 0.7))
		task.spawn(function()
			local ok, username = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if nameLabel.Parent then
				nameLabel.Text = `{crown}[{member.Rank}]  {if ok then username else userIdKey}`
			end
		end)
		if can("Kick") and userId ~= localPlayer.UserId and userId ~= doc.LeaderUserId then
			makeButton(row, "KICK", UDim2.fromScale(0.8, 0.18), UDim2.fromScale(0.17, 0.64),
				Color3.fromRGB(190, 70, 70), function()
					local ok, err = invoke("Kick", { UserId = userId })
					uiRef:Toast(if ok then "Member removed" else tostring(err))
					refresh()
				end)
		end
	end

	-- Invite online players.
	if can("Invite") then
		makeHeader(nextOrder(), "INVITE PLAYERS")
		local listed = 0
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer and not doc.Members[tostring(player.UserId)] then
				listed += 1
				local row = makeRow(nextOrder(), 0.09)
				makeText(row, player.DisplayName, UDim2.fromScale(0.03, 0.15), UDim2.fromScale(0.7, 0.7))
				makeButton(row, "INVITE", UDim2.fromScale(0.8, 0.18), UDim2.fromScale(0.17, 0.64),
					Color3.fromRGB(70, 130, 220), function()
						local ok, err = invoke("Invite", { UserId = player.UserId })
						uiRef:Toast(if ok then "Invite sent!" else tostring(err))
					end)
			end
		end
		if listed == 0 then
			local row = makeRow(nextOrder(), 0.08)
			row.BackgroundTransparency = 0.5
			makeText(row, "No eligible players on this server.", UDim2.fromScale(0.03, 0.2),
				UDim2.fromScale(0.9, 0.6), Color3.fromRGB(165, 160, 190))
		end
	end

	-- Leave.
	local leaveRow = makeRow(nextOrder(), 0.1)
	leaveRow.BackgroundTransparency = 1
	makeButton(leaveRow, "LEAVE GUILD", UDim2.fromScale(0.35, 0.15), UDim2.fromScale(0.3, 0.7),
		Color3.fromRGB(120, 60, 70), function()
			local ok, err = invoke("Leave")
			uiRef:Toast(if ok then "You left the guild." else tostring(err))
			refresh()
		end)
end

-- ------------------------------- SCREEN -----------------------------------------

rebuild = function()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if guildDoc then
		buildGuild()
	else
		buildNoGuild()
	end
end

function GuildUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "GuildScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "GUILD"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromScale(0.12, 0.15)
	listFrame.Size = UDim2.fromScale(0.76, 0.8)
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

	Remotes.Event("GuildEvent").OnClientEvent:Connect(function(eventType, payload)
		if eventType == "Invite" then
			pendingInvite = payload
			uiRef:Toast(`🏰 {payload.From} invited you to "{payload.GuildName}" (press G)`)
			if frame.Visible then
				rebuild()
			end
		end
	end)

	return frame
end

function GuildUI.Open()
	refresh()
end

return GuildUI
