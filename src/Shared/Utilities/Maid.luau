--!strict
-- Maid.luau
-- Tracks connections, instances, and cleanup callbacks so transient systems
-- (hitboxes, status effects, UI screens) can never leak.

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { any } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(task_: any): any
	table.insert(self._tasks, task_)
	return task_
end

local function cleanupTask(task_: any)
	local taskType = typeof(task_)
	if taskType == "RBXScriptConnection" then
		task_:Disconnect()
	elseif taskType == "Instance" then
		task_:Destroy()
	elseif taskType == "function" then
		task_()
	elseif taskType == "thread" then
		task.cancel(task_)
	elseif taskType == "table" then
		if task_.Disconnect then
			task_:Disconnect()
		elseif task_.Destroy then
			task_:Destroy()
		end
	end
end

function Maid:DoCleaning()
	local tasks = self._tasks
	self._tasks = {}
	for _, task_ in tasks do
		cleanupTask(task_)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
