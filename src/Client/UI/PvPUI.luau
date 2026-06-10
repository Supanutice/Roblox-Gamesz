--!strict
-- PvPUI.luau
-- PvP menu (hotkey P): mode cards with your rating + rank, queue/cancel
-- buttons, and live match-found / match-result handling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PvPConfig = require(Shared.Configs.PvPConfig)
local Remotes = require(Shared.Net.Remotes)

local PvPUI = {}

local uiRef: any
local frameRef: Frame
local queuedMode: string? = nil
local statusLabel: TextLabel

-- Modes shown as cards (GuildWar starts from the guild menu, not here).
local MODES = {
	{ Key = "Ranked1v1", Title = "1v1 RANKED", Subtitle = "Best of 3 · Elo rated" },
	{ Key = "Casual1v1", Title = "1v1 CASUAL", Subtitle = "Best of 3 · no rating" },
	{ Key = "Arena3v3", Title = "3v3 ARENA", Subtitle = "Team fights · Elo rated" },
}

local function rankFor(rating: number): string
	local rankName = PvPConfig.Ranks[1].Name
	for _, rank in PvPConfig.Ranks do
		if rating >= rank.MinRating then
			rankName = rank.Name
		end
	end
	return rankName
end

local function refreshStatus()
	if not statusLabel then
		return
	end
	local profile = uiRef:GetProfile()
	local pvp = profile and profile.PvP
	local record = if pvp then `W {pvp.Wins} / L {pvp.Losses}` else ""
	if queuedMode then
		statusLabel.Text = `🔎 Searching: {queuedMode}…   {record}`
	else
		statusLabel.Text = record
	end
end

function PvPUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "PvPScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent
	frameRef = frame

	local title = Instance.new("TextLabel")
	title.Text = "PVP ARENA"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	statusLabel = Instance.new("TextLabel")
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromScale(0.05, 0.12)
	statusLabel.Size = UDim2.fromScale(0.9, 0.045)
	statusLabel.Text = ""
	statusLabel.Parent = frame

	for index, mode in MODES do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
		card.Position = UDim2.fromScale(0.06 + (index - 1) * 0.31, 0.22)
		card.Size = UDim2.fromScale(0.28, 0.55)
		card.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.05, 0)
		corner.Parent = card

		local cardTitle = Instance.new("TextLabel")
		cardTitle.Text = mode.Title
		cardTitle.Font = Enum.Font.GothamBlack
		cardTitle.TextScaled = true
		cardTitle.TextColor3 = Color3.new(1, 1, 1)
		cardTitle.BackgroundTransparency = 1
		cardTitle.Position = UDim2.fromScale(0.05, 0.06)
		cardTitle.Size = UDim2.fromScale(0.9, 0.12)
		cardTitle.Parent = card

		local subtitle = Instance.new("TextLabel")
		subtitle.Text = mode.Subtitle
		subtitle.Font = Enum.Font.Gotham
		subtitle.TextScaled = true
		subtitle.TextColor3 = Color3.fromRGB(170, 170, 195)
		subtitle.BackgroundTransparency = 1
		subtitle.Position = UDim2.fromScale(0.05, 0.2)
		subtitle.Size = UDim2.fromScale(0.9, 0.07)
		subtitle.Parent = card

		local ratingLabel = Instance.new("TextLabel")
		ratingLabel.Name = "Rating"
		ratingLabel.Font = Enum.Font.GothamBold
		ratingLabel.TextScaled = true
		ratingLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		ratingLabel.BackgroundTransparency = 1
		ratingLabel.Position = UDim2.fromScale(0.05, 0.36)
		ratingLabel.Size = UDim2.fromScale(0.9, 0.16)
		ratingLabel.Parent = card

		local queueButton = Instance.new("TextButton")
		queueButton.Name = "Queue"
		queueButton.Font = Enum.Font.GothamBlack
		queueButton.TextScaled = true
		queueButton.TextColor3 = Color3.new(1, 1, 1)
		queueButton.BackgroundColor3 = Color3.fromRGB(120, 70, 220)
		queueButton.Position = UDim2.fromScale(0.15, 0.72)
		queueButton.Size = UDim2.fromScale(0.7, 0.16)
		queueButton.Text = "QUEUE"
		queueButton.Parent = card
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0.25, 0)
		buttonCorner.Parent = queueButton

		local function refreshCard()
			local profile = uiRef:GetProfile()
			local pvp = profile and profile.PvP
			if pvp then
				local rating = if mode.Key == "Arena3v3" then pvp.Rating3v3 else pvp.Rating1v1
				ratingLabel.Text = if PvPConfig.Modes[mode.Key].Ranked
					then `{rankFor(rating)}\n{rating} RP`
					else "Unrated"
			end
			queueButton.Text = if queuedMode == mode.Key then "CANCEL" else "QUEUE"
			queueButton.BackgroundColor3 = if queuedMode == mode.Key
				then Color3.fromRGB(190, 70, 70)
				else Color3.fromRGB(120, 70, 220)
		end
		queueButton.Activated:Connect(function()
			if queuedMode == mode.Key then
				Remotes.Function("PvPLeaveQueue"):InvokeServer()
				queuedMode = nil
			else
				if queuedMode then
					Remotes.Function("PvPLeaveQueue"):InvokeServer()
					queuedMode = nil
				end
				local ok, err = Remotes.Function("PvPJoinQueue"):InvokeServer(mode.Key)
				if ok then
					queuedMode = mode.Key
				else
					uiRef:Toast(tostring(err))
				end
			end
			refreshCard()
			refreshStatus()
		end)

		-- Refresh when the screen opens (PvPUI.Open walks these).
		card.Name = "ModeCard_" .. mode.Key
		PvPUI["_refresh_" .. mode.Key] = refreshCard
		refreshCard()
	end

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

	Remotes.Event("PvPMatchFound").OnClientEvent:Connect(function(info)
		queuedMode = nil
		uiRef:Toast(`⚔ Match found — {info.Mode}! Teleporting to the arena…`)
		if frame.Visible then
			ui:CloseScreen()
		end
	end)

	Remotes.Event("PvPMatchEnded").OnClientEvent:Connect(function(result)
		local profile = uiRef:GetProfile()
		if profile and profile.PvP then
			if result.Won then
				profile.PvP.Wins += 1
			else
				profile.PvP.Losses += 1
			end
		end
		uiRef:Toast(if result.Won
			then `🏆 Victory! {result.Rank} · {result.NewRating} RP`
			else `Defeat. {result.Rank} · {result.NewRating} RP`)
	end)

	return frame
end

function PvPUI.Open()
	for _, mode in MODES do
		local refresh = PvPUI["_refresh_" .. mode.Key]
		if refresh then
			refresh()
		end
	end
	refreshStatus()
end

return PvPUI
