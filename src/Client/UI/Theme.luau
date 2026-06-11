--!strict
-- Theme.luau
-- Central art direction for every UI screen: dark-indigo backdrop with depth
-- gradient, gold/violet neon accents, glowing title underlines, pill buttons
-- with hover highlights, styled panels and scrollbars, and an open "pop"
-- animation. UIController calls Theme.PolishScreen(frame) once after a
-- screen's Build — the polisher restyles the existing structure and keeps
-- watching for rows/buttons created later (list rebuilds), so individual
-- screens never need theme code of their own.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(17, 15, 30),
	BackgroundDeep = Color3.fromRGB(9, 8, 17),
	Panel = Color3.fromRGB(31, 28, 48),
	PanelLight = Color3.fromRGB(46, 42, 72),
	Gold = Color3.fromRGB(255, 205, 95),
	Violet = Color3.fromRGB(150, 95, 255),
	Cyan = Color3.fromRGB(120, 220, 255),
	Success = Color3.fromRGB(95, 200, 110),
	Danger = Color3.fromRGB(225, 85, 85),
	TextDim = Color3.fromRGB(165, 160, 190),
}

local POLISHED = "AW3_Polished"

-- ------------------------------ HELPERS ---------------------------------------

local function ensureCorner(instance: Instance, radius: number)
	if not instance:FindFirstChildOfClass("UICorner") then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(radius, 0)
		corner.Parent = instance
	end
end

local function ensureStroke(instance: Instance, color: Color3, transparency: number): UIStroke
	local stroke = instance:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Transparency = transparency
		stroke.Thickness = 1.4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = instance
	end
	return stroke :: UIStroke
end

local function ensureGradient(instance: Instance, rotation: number, bright: number, dim: number)
	if not instance:FindFirstChildOfClass("UIGradient") then
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Color = ColorSequence.new(
			Color3.new(bright, bright, bright),
			Color3.new(dim, dim, dim))
		gradient.Parent = instance
	end
end

-- ----------------------------- ELEMENT RULES -----------------------------------

local function polishButton(button: TextButton)
	if button:GetAttribute(POLISHED) then
		return
	end
	button:SetAttribute(POLISHED, true)
	ensureCorner(button, 0.22)
	ensureGradient(button, 90, 1, 0.78)

	local isClose = button.Text == "✕"
	if isClose then
		button.BackgroundColor3 = Theme.Colors.Panel
		button.TextColor3 = Theme.Colors.Danger
	end
	local stroke = ensureStroke(button, if isClose then Theme.Colors.Danger else Theme.Colors.Gold, 0.78)
	local restingTransparency = stroke.Transparency

	button.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = restingTransparency }):Play()
	end)
end

local function polishPanel(panel: Frame)
	if panel:GetAttribute(POLISHED) or panel.BackgroundTransparency >= 1 then
		return
	end
	panel:SetAttribute(POLISHED, true)
	ensureCorner(panel, 0.08)
	ensureStroke(panel, Theme.Colors.Violet, 0.86)
	ensureGradient(panel, 90, 1, 0.88)
end

local function polishScroller(scroller: ScrollingFrame)
	if scroller:GetAttribute(POLISHED) then
		return
	end
	scroller:SetAttribute(POLISHED, true)
	scroller.ScrollBarImageColor3 = Theme.Colors.Violet
	scroller.ScrollBarImageTransparency = 0.25
	scroller.ScrollBarThickness = 5
end

local function polishTitle(root: Frame, title: TextLabel)
	if title:GetAttribute(POLISHED) then
		return
	end
	title:SetAttribute(POLISHED, true)
	-- Gold-to-white sheen across the headline text.
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Theme.Colors.Gold, Color3.fromRGB(255, 255, 255))
	gradient.Parent = title
	-- Glowing underline beneath the title.
	local underline = Instance.new("Frame")
	underline.Name = "TitleUnderline"
	underline:SetAttribute(POLISHED, true)
	underline.AnchorPoint = Vector2.new(0, 0)
	underline.Position = UDim2.fromScale(title.Position.X.Scale, title.Position.Y.Scale + title.Size.Y.Scale + 0.008)
	underline.Size = UDim2.fromScale(0.16, 0.006)
	underline.BackgroundColor3 = Theme.Colors.Gold
	underline.BorderSizePixel = 0
	underline.Parent = root
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = underline
end

-- ------------------------------ SCREEN CHROME ----------------------------------

local function applyElementRules(root: Frame, instance: Instance)
	if instance:IsA("TextButton") then
		polishButton(instance)
	elseif instance:IsA("ScrollingFrame") then
		polishScroller(instance)
	elseif instance:IsA("Frame") and instance ~= root then
		polishPanel(instance)
	elseif instance:IsA("TextLabel")
		and instance.Parent == root
		and instance.Font == Enum.Font.GothamBlack
		and instance.Position.Y.Scale < 0.1 then
		polishTitle(root, instance)
	end
end

-- One-time chrome + ongoing element styling for a screen frame.
function Theme.PolishScreen(root: Frame)
	if root:GetAttribute(POLISHED) then
		return
	end
	root:SetAttribute(POLISHED, true)

	-- Backdrop: unified base color + vertical depth gradient.
	root.BackgroundColor3 = Theme.Colors.Background
	ensureGradient(root, 90, 1, 0.55)

	-- Header tint band behind the title area.
	local band = Instance.new("Frame")
	band.Name = "HeaderBand"
	band:SetAttribute(POLISHED, true)
	band.Size = UDim2.fromScale(1, 0.12)
	band.BackgroundColor3 = Theme.Colors.Violet
	band.BackgroundTransparency = 0.92
	band.BorderSizePixel = 0
	band.ZIndex = 0
	band.Parent = root
	local bandFade = Instance.new("UIGradient")
	bandFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	bandFade.Parent = band

	-- Thin neon frame lines top & bottom.
	for _, y in { 0, 0.996 } do
		local line = Instance.new("Frame")
		line:SetAttribute(POLISHED, true)
		line.Size = UDim2.fromScale(1, 0.004)
		line.Position = UDim2.fromScale(0, y)
		line.BackgroundColor3 = Theme.Colors.Violet
		line.BackgroundTransparency = 0.35
		line.BorderSizePixel = 0
		line.Parent = root
		local lineFade = Instance.new("UIGradient")
		lineFade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		lineFade.Parent = line
	end

	-- Open-animation rig.
	local scale = Instance.new("UIScale")
	scale.Name = "OpenScale"
	scale.Parent = root

	-- Style everything that exists now…
	for _, descendant in root:GetDescendants() do
		applyElementRules(root, descendant)
	end
	-- …and everything list rebuilds create later.
	root.DescendantAdded:Connect(function(descendant)
		task.defer(applyElementRules, root, descendant)
	end)
end

-- Pop animation when a screen opens.
function Theme.AnimateOpen(root: Frame)
	local scale = root:FindFirstChild("OpenScale")
	if scale and scale:IsA("UIScale") then
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }):Play()
	end
end

return Theme
