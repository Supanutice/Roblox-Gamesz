--!strict
-- EffectsController.luau
-- Thin controller that boots the Effects/VFXController module through the
-- standard client lifecycle (the loader only scans Controllers/).

local VFXController = require(script.Parent.Parent.Effects.VFXController)

local EffectsController = {}

function EffectsController:Init() end

function EffectsController:Start()
	VFXController.Boot()
end

return EffectsController
