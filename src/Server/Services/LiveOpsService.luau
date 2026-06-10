--!strict
-- LiveOpsService.luau
-- Seasons, scheduled events (daily/weekly/monthly), event boss spawning and
-- the cosmetic shop rotation. Schedules are computed from os.time() so every
-- server agrees without coordination.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Configs.MonetizationConfig)

local LiveOpsService = { Name = "LiveOpsService" }

local services: { [string]: any }

local SECONDS_PER_DAY = 86_400

-- Season 0 epoch: first season starts at this UTC timestamp.
local SEASON_EPOCH = 1_767_225_600 -- 2026-01-01 00:00:00 UTC

local EVENTS = {
	-- Daily event: 2x gold hour at 18:00 UTC.
	{ Id = "DOUBLE_GOLD_HOUR", Cadence = "Daily", StartHourUTC = 18, DurationHours = 1 },
	-- Weekly event: Saturday raid-token weekend.
	{ Id = "RAID_WEEKEND", Cadence = "Weekly", StartDayOfWeek = 6, DurationHours = 48 },
	-- Monthly event: Solstice boss for the first 3 days of each month.
	{ Id = "SOLSTICE_FESTIVAL", Cadence = "Monthly", StartDayOfMonth = 1, DurationHours = 72, BossId = "BOSS_EVENT_SOLSTICE" },
}

-- ------------------------------ SEASONS -------------------------------------

function LiveOpsService:GetCurrentSeason(): number
	local elapsed = os.time() - SEASON_EPOCH
	return math.max(0, math.floor(elapsed / (MonetizationConfig.BattlePass.SeasonLengthDays * SECONDS_PER_DAY)))
end

-- Player-facing season state; resets battle pass + PvP rating soft-reset
-- when a profile from a previous season loads.
local function reconcileSeason(player: Player, profile)
	local season = LiveOpsService:GetCurrentSeason()
	if profile.Data.BattlePass.SeasonId ~= season then
		profile.Data.BattlePass.SeasonId = season
		profile.Data.BattlePass.Tier = 0
		profile.Data.BattlePass.XP = 0
		profile.Data.BattlePass.ClaimedFree = {}
		profile.Data.BattlePass.ClaimedPremium = {}
		profile.Data.BattlePass.PremiumOwned = false -- re-verified by EconomyService
	end
	if profile.Data.PvP.SeasonId ~= season then
		-- Soft reset toward 1000: keeps ladder fresh, respects skill.
		profile.Data.PvP.SeasonId = season
		profile.Data.PvP.Rating1v1 = math.floor((profile.Data.PvP.Rating1v1 + 1000) / 2)
		profile.Data.PvP.Rating3v3 = math.floor((profile.Data.PvP.Rating3v3 + 1000) / 2)
	end
	profile.Dirty = true
end

-- ------------------------------ EVENTS --------------------------------------

function LiveOpsService:IsEventActive(eventId: string): boolean
	local now = os.time()
	local date = os.date("!*t", now)
	for _, event in EVENTS do
		if event.Id ~= eventId then
			continue
		end
		if event.Cadence == "Daily" then
			local start = (event.StartHourUTC :: number)
			return date.hour >= start and date.hour < start + event.DurationHours
		elseif event.Cadence == "Weekly" then
			-- os.date wday: 1=Sunday … 7=Saturday
			local dayStart = event.StartDayOfWeek :: number
			local hoursIntoWeek = ((date.wday - 1) * 24) + date.hour
			local eventStartHours = dayStart * 24
			return hoursIntoWeek >= eventStartHours and hoursIntoWeek < eventStartHours + event.DurationHours
		elseif event.Cadence == "Monthly" then
			local dayStart = event.StartDayOfMonth :: number
			local hoursIntoMonth = ((date.day - 1) * 24) + date.hour
			local eventStartHours = (dayStart - 1) * 24
			return hoursIntoMonth >= eventStartHours and hoursIntoMonth < eventStartHours + event.DurationHours
		end
	end
	return false
end

-- Multipliers other services consult (SpawnerService gold drops, etc).
function LiveOpsService:GetGoldMultiplier(): number
	return if self:IsEventActive("DOUBLE_GOLD_HOUR") then 2 else 1
end

function LiveOpsService:GetRaidTokenMultiplier(): number
	return if self:IsEventActive("RAID_WEEKEND") then 2 else 1
end

-- Cosmetic shop rotation: deterministic pseudo-random pick per rotation
-- window so all servers show identical shops.
function LiveOpsService:GetShopRotation(): { string }
	local window = math.floor(os.time() / (MonetizationConfig.CosmeticShop.RotationDays * SECONDS_PER_DAY))
	local rotationRng = Random.new(window)
	local catalog = MonetizationConfig.CosmeticShop.Categories
	local rotation = {}
	for i = 1, 4 do
		local category = catalog[rotationRng:NextInteger(1, #catalog)]
		table.insert(rotation, `{category}_SEASONAL_{window % 8 + 1}`)
	end
	return rotation
end

-- ------------------------------ LIFECYCLE ------------------------------------

function LiveOpsService:Init(registry)
	services = registry
end

function LiveOpsService:Start()
	services.DataService.ProfileLoaded:Connect(reconcileSeason)

	-- Event boss spawner: checks every 5 minutes whether the monthly event
	-- boss should exist on this server.
	task.spawn(function()
		local BossAI = require(script.Parent.Parent.AI.BossAI)
		local activeEventBoss: any = nil
		while true do
			task.wait(300)
			local solsticeActive = self:IsEventActive("SOLSTICE_FESTIVAL")
			if solsticeActive and not activeEventBoss then
				activeEventBoss = BossAI.new("BOSS_EVENT_SOLSTICE", CFrame.new(0, 50, 300), services)
				activeEventBoss.Defeated:Once(function()
					task.delay(1800, function()
						activeEventBoss = nil
					end)
				end)
			end
		end
	end)
end

return LiveOpsService
