--!strict
-- CombatConfig.luau
-- Every combat timing/tuning value. The SERVER enforces these numbers;
-- the client merely animates to them.

return {
	M1 = {
		ComboLength = 4,
		BaseDamageMultiplier = 0.45,      -- of ATK per hit
		FinisherMultiplier = 1.0,         -- 4th hit
		HitWindowSeconds = 0.45,          -- min time between M1 requests (server check)
		ComboResetSeconds = 1.4,          -- idle time before combo resets
		Range = 9,                        -- studs, server-validated
		KnockbackFinisher = 38,           -- studs/s impulse on 4th hit
	},

	Heavy = {
		DamageMultiplier = 1.4,
		Cooldown = 4.0,
		ChargeSeconds = 0.55,
		Range = 11,
		GuardBreak = true,                -- heavies pierce normal block
		Knockback = 55,
	},

	Dash = {
		Cooldown = 1.6,
		Distance = 22,
		DurationSeconds = 0.25,
		IFrameSeconds = 0.20,             -- invulnerability during dash
	},

	AirCombo = {
		LaunchMultiplier = 0.8,           -- launcher hit (heavy while combo >= 3)
		LaunchVelocity = 60,
		MaxAirHits = 3,
		AirHitMultiplier = 0.5,
	},

	Block = {
		DamageReduction = 0.65,           -- normal block absorbs 65%
		PerfectWindowSeconds = 0.18,      -- block started within this window of the hit
		PerfectReduction = 1.0,           -- perfect block absorbs 100%
		PerfectCounterWindow = 0.8,       -- after perfect block, counter is enabled
		CounterMultiplier = 2.0,
		StaminaCostPerHit = 8,
	},

	TargetLock = {
		MaxDistance = 80,
		LoseDistance = 100,
	},

	Energy = {
		Max = 100,
		PerM1Hit = 4,
		PerSkillHit = 8,
		PerDamageTakenPercent = 0.15,     -- energy per 1% max HP lost
		UltimateCost = 100,
	},

	Awakening = {
		DurationSeconds = 20,
		StatBonus = 0.35,                 -- +35% ATK/SPD while awakened
		RequiredUltimates = 2,            -- ultimates cast this life to unlock
	},

	-- Server-side movement sanity bounds (AntiCheatService)
	Movement = {
		MaxHorizontalSpeed = 34,          -- sprint + buffer; dash handled separately
		MaxDashSpeed = 95,
		TeleportToleranceStuds = 60,      -- per heartbeat-window check
	},

	Stamina = {
		Max = 100,
		RegenPerSecond = 12,
		DashCost = 20,
	},
}
