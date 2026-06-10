--!strict
-- Main.client.luau
-- Client bootstrap mirroring the server's two-phase service loader:
-- controllers Init(registry) then Start().

local controllersFolder = script.Parent:WaitForChild("Controllers")

type Controller = {
	Init: ((self: any, registry: { [string]: any }) -> ())?,
	Start: ((self: any) -> ())?,
}

local registry: { [string]: Controller } = {}

for _, child in controllersFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, controller = pcall(require, child)
		if ok then
			registry[child.Name] = controller :: Controller
		else
			warn(`[ClientBoot] Failed to require {child.Name}: {controller}`)
		end
	end
end

local names = {}
for name in registry do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local controller = registry[name]
	if controller.Init then
		local ok, err = pcall(function()
			controller:Init(registry)
		end)
		if not ok then
			warn(`[ClientBoot] {name}:Init failed: {err}`)
		end
	end
end

for _, name in names do
	local controller = registry[name]
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(function()
				controller:Start()
			end)
			if not ok then
				warn(`[ClientBoot] {name}:Start failed: {err}`)
			end
		end)
	end
end

print("[ClientBoot] Anime Warriors III client started")
