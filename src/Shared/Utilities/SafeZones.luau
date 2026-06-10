--!strict
-- SafeZones.luau
-- Shared definition of no-combat zones (the hub plaza of every world).
-- Consumed by AIController (regular enemies) and BossAI (boss targeting).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Configs.WorldConfig)

local SafeZones = {
	Radius = 60,
}

local hubs: { Vector3 } = {}
for _, worldDef in WorldConfig.Worlds do
	table.insert(hubs, worldDef.FastTravelPoints[1].Position)
end

function SafeZones.Contains(position: Vector3): boolean
	for _, hub in hubs do
		local flat = position - hub
		if Vector3.new(flat.X, 0, flat.Z).Magnitude <= SafeZones.Radius then
			return true
		end
	end
	return false
end

return SafeZones
