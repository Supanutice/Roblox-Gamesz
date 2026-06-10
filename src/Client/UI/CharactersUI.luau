--!strict
-- CharactersUI.luau
-- Roster grid (left) + detail panel (right): stats, skills, and the four
-- progression actions — Equip, Level Up, Evolve, Ascend. All actions go
-- through server RemoteFunctions; the local snapshot is patched on success.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterDatabase = require(Shared.Data.CharacterDatabase)
local GameConfig = require(Shared.Configs.GameConfig)
local ProgressionConfig = require(Shared.Configs.ProgressionConfig)
local Remotes = require(Shared.Net.Remotes)

local CharactersUI = {}

local rarityColors: { [string]: Color3 } = {}
for _, rarity in GameConfig.Rarities do
	rarityColors[rarity.Name] = rarity.Color
end

local uiRef: any
local rosterFrame: ScrollingFrame
local detailFrame: Frame
local selectedUid: string? = nil

local function makeButton(parent: Instance, text: string, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = color
	button.Position = position
	button.Size = UDim2.fromScale(0.46, 0.085)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button
	return button
end

local refreshDetail -- forward declaration

local function rebuildRoster()
	if not rosterFrame then
		return
	end
	for _, child in rosterFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local profile = uiRef:GetProfile()
	if not profile then
		return
	end
	-- Sort: equipped first, then rarity tier desc, then level desc.
	local rarityTier: { [string]: number } = {}
	for tier, rarity in GameConfig.Rarities do
		rarityTier[rarity.Name] = tier
	end
	local entries = {}
	for uid, inst in profile.Characters do
		table.insert(entries, { Uid = uid, Inst = inst, Def = CharacterDatabase.ById[inst.CharacterId] })
	end
	local equippedSet = {}
	for _, uid in profile.TeamSlots do
		equippedSet[uid] = true
	end
	table.sort(entries, function(a, b)
		if (equippedSet[a.Uid] or false) ~= (equippedSet[b.Uid] or false) then
			return equippedSet[a.Uid] == true
		end
		local tierA, tierB = rarityTier[a.Def.Rarity] or 0, rarityTier[b.Def.Rarity] or 0
		if tierA ~= tierB then
			return tierA > tierB
		end
		return a.Inst.Level > b.Inst.Level
	end)

	for order, entry in entries do
		local card = Instance.new("TextButton")
		card.LayoutOrder = order
		card.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
		card.Font = Enum.Font.GothamBold
		card.TextScaled = true
		card.TextColor3 = Color3.new(1, 1, 1)
		card.Text = `{entry.Def.Name}\nLv.{entry.Inst.Level}` .. (if equippedSet[entry.Uid] then "  ★" else "")
		card.Parent = rosterFrame
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarityColors[entry.Def.Rarity] or Color3.new(1, 1, 1)
		stroke.Thickness = if selectedUid == entry.Uid then 4 else 2
		stroke.Parent = card
		card.Activated:Connect(function()
			selectedUid = entry.Uid
			rebuildRoster()
			refreshDetail()
		end)
	end
end

refreshDetail = function()
	if not detailFrame then
		return
	end
	for _, child in detailFrame:GetChildren() do
		child:Destroy()
	end
	local profile = uiRef:GetProfile()
	local inst = profile and selectedUid and profile.Characters[selectedUid]
	if not inst then
		local hint = Instance.new("TextLabel")
		hint.Size = UDim2.fromScale(1, 0.2)
		hint.Position = UDim2.fromScale(0, 0.4)
		hint.BackgroundTransparency = 1
		hint.TextColor3 = Color3.fromRGB(160, 160, 180)
		hint.TextScaled = true
		hint.Font = Enum.Font.Gotham
		hint.Text = "Select a character"
		hint.Parent = detailFrame
		return
	end
	local def = CharacterDatabase.ById[inst.CharacterId]

	local info = Instance.new("TextLabel")
	info.Size = UDim2.fromScale(1, 0.5)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.new(1, 1, 1)
	info.TextScaled = true
	info.Font = Enum.Font.Gotham
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextYAlignment = Enum.TextYAlignment.Top
	info.Text = table.concat({
		def.Name .. "  (" .. def.Rarity .. ")",
		`{def.Element} {def.Class}  ·  Lv.{inst.Level}  ·  Evo {inst.EvolutionStage}  ·  ✦{inst.Ascension}  ·  Shards {inst.Shards}`,
		"",
		`Passive — {def.Passive.Name}: {def.Passive.Description}`,
		`S1 — {def.Skill1.Name} (x{def.Skill1.Multiplier}, {def.Skill1.Cooldown}s)`,
		`S2 — {def.Skill2.Name} (x{def.Skill2.Multiplier}, {def.Skill2.Cooldown}s)`,
		`ULT — {def.Ultimate.Name} (x{def.Ultimate.Multiplier})`,
		"",
		`Final form: {def.EvolutionName}`,
	}, "\n")
	info.Parent = detailFrame

	local uid = selectedUid :: string
	local levelCost = math.floor(ProgressionConfig.Character.LevelUpGoldCostBase * inst.Level ^ 1.4)

	local equipButton = makeButton(detailFrame, "Equip (Slot 1)", UDim2.fromScale(0.02, 0.56), Color3.fromRGB(70, 130, 220))
	equipButton.Activated:Connect(function()
		local ok, err = Remotes.Function("EquipCharacter"):InvokeServer(uid, 1)
		if ok then
			profile.TeamSlots[1] = uid
			uiRef:Toast("Equipped " .. def.Name)
			rebuildRoster()
		else
			uiRef:Toast(tostring(err))
		end
	end)

	local levelButton = makeButton(detailFrame, `Level Up (🪙{levelCost})`, UDim2.fromScale(0.52, 0.56), Color3.fromRGB(90, 180, 90))
	levelButton.Activated:Connect(function()
		local ok, err = Remotes.Function("LevelUpCharacter"):InvokeServer(uid)
		if ok then
			inst.Level += 1
			rebuildRoster()
			refreshDetail()
		else
			uiRef:Toast(tostring(err))
		end
	end)

	local evolveButton = makeButton(detailFrame, "Evolve", UDim2.fromScale(0.02, 0.68), Color3.fromRGB(170, 90, 240))
	evolveButton.Activated:Connect(function()
		local ok, err = Remotes.Function("EvolveCharacter"):InvokeServer(uid)
		if ok then
			inst.EvolutionStage += 1
			uiRef:Toast(def.Name .. " evolved!")
			refreshDetail()
		else
			uiRef:Toast(tostring(err))
		end
	end)

	local shardsNeeded = ProgressionConfig.Ascension.ShardsPerStar[inst.Ascension + 1]
	local ascendButton = makeButton(detailFrame,
		if shardsNeeded then `Ascend ({inst.Shards}/{shardsNeeded})` else "Max Ascension",
		UDim2.fromScale(0.52, 0.68), Color3.fromRGB(230, 160, 60))
	ascendButton.Activated:Connect(function()
		local ok, err = Remotes.Function("AscendCharacter"):InvokeServer(uid)
		if ok then
			inst.Ascension += 1
			inst.Shards -= shardsNeeded or 0
			uiRef:Toast(def.Name .. " ascended! ✦" .. inst.Ascension)
			refreshDetail()
		else
			uiRef:Toast(tostring(err))
		end
	end)
end

function CharactersUI.Build(parent: ScreenGui, ui): Frame
	uiRef = ui
	local frame = Instance.new("Frame")
	frame.Name = "CharactersScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 15, 26)
	frame.Visible = false
	frame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "CHARACTERS"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.3, 0.07)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	rosterFrame = Instance.new("ScrollingFrame")
	rosterFrame.Position = UDim2.fromScale(0.04, 0.15)
	rosterFrame.Size = UDim2.fromScale(0.4, 0.8)
	rosterFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
	rosterFrame.BorderSizePixel = 0
	rosterFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rosterFrame.CanvasSize = UDim2.fromScale(0, 0)
	rosterFrame.ScrollBarThickness = 6
	rosterFrame.Parent = frame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.3, 0.3)
	grid.CellPadding = UDim2.fromScale(0.025, 0.03)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = rosterFrame

	detailFrame = Instance.new("Frame")
	detailFrame.Position = UDim2.fromScale(0.47, 0.15)
	detailFrame.Size = UDim2.fromScale(0.49, 0.8)
	detailFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
	detailFrame.BorderSizePixel = 0
	detailFrame.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.03, 0)
	padding.Parent = detailFrame

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

	Remotes.Event("CharacterRosterChanged").OnClientEvent:Connect(function(delta)
		local profile = uiRef:GetProfile()
		if profile and delta.Granted then
			profile.Characters[delta.Granted.Uid] = profile.Characters[delta.Granted.Uid] or {
				CharacterId = delta.Granted.CharacterId,
				Level = 1, XP = 0, EvolutionStage = 1, Ascension = 0,
				SkillLevels = { 1, 1, 1 }, Shards = 0, Locked = false,
				ObtainedAt = os.time(),
			}
		elseif profile and delta.ShardsAdded then
			local inst = profile.Characters[delta.ShardsAdded.Uid]
			if inst then
				inst.Shards += delta.ShardsAdded.Amount
			end
		end
		if frame.Visible then
			rebuildRoster()
			refreshDetail()
		end
	end)

	return frame
end

function CharactersUI.Open()
	rebuildRoster()
	refreshDetail()
end

return CharactersUI
