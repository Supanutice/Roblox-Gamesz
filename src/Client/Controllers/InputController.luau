--!strict
-- InputController.luau
-- Single owner of raw input. Maps PC keys / mouse and mobile touch buttons
-- onto named ACTION signals that CombatController and UIController consume.
-- Nothing else in the client reads UserInputService directly.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Utilities.Signal)

local InputController = {
	-- Combat
	M1 = Signal.new(),
	HeavyStarted = Signal.new(),
	Dash = Signal.new(),
	Skill = Signal.new(),        -- (slot: number)
	Ultimate = Signal.new(),
	BlockChanged = Signal.new(), -- (isBlocking: boolean)
	ToggleLock = Signal.new(),
	-- UI
	OpenMenu = Signal.new(),     -- (screenName: string)
}

local KEYBINDS: { [Enum.KeyCode]: () -> () } = {}

local function bindKey(keyCode: Enum.KeyCode, fn: () -> ())
	KEYBINDS[keyCode] = fn
end

function InputController:Init()
	bindKey(Enum.KeyCode.Q, function()
		self.Dash:Fire()
	end)
	bindKey(Enum.KeyCode.One, function()
		self.Skill:Fire(1)
	end)
	bindKey(Enum.KeyCode.Two, function()
		self.Skill:Fire(2)
	end)
	bindKey(Enum.KeyCode.R, function()
		self.Ultimate:Fire()
	end)
	bindKey(Enum.KeyCode.Tab, function()
		self.ToggleLock:Fire()
	end)
	-- Menus
	bindKey(Enum.KeyCode.C, function()
		self.OpenMenu:Fire("Characters")
	end)
	bindKey(Enum.KeyCode.B, function()
		self.OpenMenu:Fire("Inventory")
	end)
	bindKey(Enum.KeyCode.K, function()
		self.OpenMenu:Fire("Summon")
	end)
	bindKey(Enum.KeyCode.L, function()
		self.OpenMenu:Fire("Quests")
	end)
	bindKey(Enum.KeyCode.G, function()
		self.OpenMenu:Fire("Guild")
	end)
	bindKey(Enum.KeyCode.P, function()
		self.OpenMenu:Fire("PvP")
	end)
	bindKey(Enum.KeyCode.V, function()
		self.OpenMenu:Fire("Party")
	end)
	bindKey(Enum.KeyCode.M, function()
		self.OpenMenu:Fire("Shop")
	end)
end

function InputController:Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.M1:Fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self.HeavyStarted:Fire()
		elseif input.KeyCode == Enum.KeyCode.F then
			self.BlockChanged:Fire(true)
		else
			local handler = KEYBINDS[input.KeyCode]
			if handler then
				handler()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			self.BlockChanged:Fire(false)
		end
	end)

	-- Mobile: on-screen combat buttons via ContextActionService (auto-creates
	-- touch buttons positioned for thumb reach).
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local actions: { [string]: { fn: () -> (), title: string } } = {
			AW3_M1 = { title = "Attack", fn = function() self.M1:Fire() end },
			AW3_Heavy = { title = "Heavy", fn = function() self.HeavyStarted:Fire() end },
			AW3_Dash = { title = "Dash", fn = function() self.Dash:Fire() end },
			AW3_Skill1 = { title = "S1", fn = function() self.Skill:Fire(1) end },
			AW3_Skill2 = { title = "S2", fn = function() self.Skill:Fire(2) end },
			AW3_Ult = { title = "ULT", fn = function() self.Ultimate:Fire() end },
		}
		for name, action in actions do
			ContextActionService:BindAction(name, function(_, state)
				if state == Enum.UserInputState.Begin then
					action.fn()
				end
				return Enum.ContextActionResult.Sink
			end, true)
			ContextActionService:SetTitle(name, action.title)
		end
		-- Block is hold-to-block on mobile.
		ContextActionService:BindAction("AW3_Block", function(_, state)
			if state == Enum.UserInputState.Begin then
				self.BlockChanged:Fire(true)
			elseif state == Enum.UserInputState.End then
				self.BlockChanged:Fire(false)
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("AW3_Block", "Block")
	end
end

return InputController
