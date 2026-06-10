--!strict
-- HitboxService.luau
-- Server-authoritative spatial hit detection. Clients NEVER report "I hit X";
-- they request an attack and the server sweeps geometry itself.
-- Uses OverlapParams spatial queries — cheap, deterministic, exploit-proof.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maid = require(Shared.Utilities.Maid)

local HitboxService = { Name = "HitboxService" }

export type HitTarget = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
}

local function extractTarget(part: BasePart, ignoreModel: Model?): HitTarget?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model or model == ignoreModel then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return { Model = model, Humanoid = humanoid, RootPart = root :: BasePart }
end

local function dedupe(parts: { BasePart }, ignoreModel: Model?): { HitTarget }
	local seen: { [Model]: boolean } = {}
	local targets: { HitTarget } = {}
	for _, part in parts do
		local target = extractTarget(part, ignoreModel)
		if target and not seen[target.Model] then
			seen[target.Model] = true
			table.insert(targets, target)
		end
	end
	return targets
end

-- Box sweep in front of the attacker (melee M1 / heavy).
function HitboxService:SweepFront(attackerRoot: BasePart, range: number, width: number, ignoreModel: Model?): { HitTarget }
	local cframe = attackerRoot.CFrame * CFrame.new(0, 0, -range / 2)
	local size = Vector3.new(width, 6, range)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if ignoreModel then
		params.FilterDescendantsInstances = { ignoreModel }
	end
	local parts = workspace:GetPartBoundsInBox(cframe, size, params)
	return dedupe(parts :: { BasePart }, ignoreModel)
end

-- Sphere burst around a point (AoE skills, ultimates, boss slams).
function HitboxService:SweepSphere(position: Vector3, radius: number, ignoreModel: Model?): { HitTarget }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if ignoreModel then
		params.FilterDescendantsInstances = { ignoreModel }
	end
	local parts = workspace:GetPartBoundsInRadius(position, radius, params)
	return dedupe(parts :: { BasePart }, ignoreModel)
end

-- Moving hitbox attached to a projectile/dash for `duration` seconds.
-- onHit is called at most once per target.
function HitboxService:AttachMoving(part: BasePart, duration: number, ignoreModel: Model?, onHit: (HitTarget) -> ())
	local maid = Maid.new()
	local hitModels: { [Model]: boolean } = {}
	maid:GiveTask(game:GetService("RunService").Heartbeat:Connect(function()
		local targets = self:SweepSphere(part.Position, math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2 + 1, ignoreModel)
		for _, target in targets do
			if not hitModels[target.Model] then
				hitModels[target.Model] = true
				onHit(target)
			end
		end
	end))
	task.delay(duration, function()
		maid:DoCleaning()
	end)
	return maid
end

-- Server-side reach validation: was the victim plausibly in range when the
-- attacker's request arrived? Generous tolerance covers latency.
function HitboxService:ValidateReach(attackerRoot: BasePart, victimRoot: BasePart, maxRange: number): boolean
	local LATENCY_TOLERANCE = 6 -- studs
	return (attackerRoot.Position - victimRoot.Position).Magnitude <= maxRange + LATENCY_TOLERANCE
end

return HitboxService
