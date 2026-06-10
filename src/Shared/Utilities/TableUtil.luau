--!strict
-- TableUtil.luau
-- Pure helpers shared by data, inventory, and config systems.

local TableUtil = {}

function TableUtil.DeepCopy<T>(source: T): T
	if typeof(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in source :: any do
		copy[key] = TableUtil.DeepCopy(value)
	end
	return copy :: any
end

-- Fills missing keys in `target` from `template` (recursive). Used by
-- DataService to reconcile old profiles against the latest schema.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any })
	for key, templateValue in template do
		local targetValue = target[key]
		if targetValue == nil then
			target[key] = TableUtil.DeepCopy(templateValue)
		elseif typeof(targetValue) == "table" and typeof(templateValue) == "table" then
			TableUtil.Reconcile(targetValue, templateValue)
		end
	end
end

function TableUtil.Count(source: { [any]: any }): number
	local count = 0
	for _ in source do
		count += 1
	end
	return count
end

function TableUtil.Keys<K, V>(source: { [K]: V }): { K }
	local keys = {}
	for key in source do
		table.insert(keys, key)
	end
	return keys
end

-- Weighted random selection. `weights` maps key -> weight (any positive number).
function TableUtil.WeightedRandom<K>(weights: { [K]: number }, rng: Random): K
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	local cursor = 0
	local lastKey: K
	for key, weight in weights do
		cursor += weight
		lastKey = key
		if roll <= cursor then
			return key
		end
	end
	return lastKey
end

return TableUtil
