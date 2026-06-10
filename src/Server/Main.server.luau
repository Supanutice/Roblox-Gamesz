--!strict
-- Main.server.luau
-- Server bootstrap. Two-phase startup:
--   1) Init(registry)  — every service receives the service registry. No
--      service may touch another service's API yet, only store references.
--   2) Start()         — all services exist; cross-service calls are legal.
-- This is the dependency-injection seam: services never require() each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

-- Create every remote before any client can ask for them.
Remotes.InitServer()

local servicesFolder = script.Parent:WaitForChild("Services")

type Service = {
	Name: string?,
	Init: ((self: any, registry: { [string]: any }) -> ())?,
	Start: ((self: any) -> ())?,
}

local registry: { [string]: Service } = {}

-- Phase 0: require everything.
for _, child in servicesFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, service = pcall(require, child)
		if ok then
			registry[child.Name] = service :: Service
		else
			warn(`[Boot] Failed to require {child.Name}: {service}`)
		end
	end
end

-- Phase 1: Init (deterministic order for reproducible boots).
local names = {}
for name in registry do
	table.insert(names, name)
end
table.sort(names)

-- DataService must init first: everything depends on profiles existing.
local PRIORITY = { DataService = 1, AntiCheatService = 2 }
table.sort(names, function(a, b)
	return (PRIORITY[a] or 100) < (PRIORITY[b] or 100) or ((PRIORITY[a] or 100) == (PRIORITY[b] or 100) and a < b)
end)

for _, name in names do
	local service = registry[name]
	if service.Init then
		local ok, err = pcall(function()
			service:Init(registry)
		end)
		if not ok then
			warn(`[Boot] {name}:Init failed: {err}`)
		end
	end
end

-- Phase 2: Start.
for _, name in names do
	local service = registry[name]
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(function()
				service:Start()
			end)
			if not ok then
				warn(`[Boot] {name}:Start failed: {err}`)
			end
		end)
	end
end

print("[Boot] Anime Warriors III server started —", #names, "services online")
