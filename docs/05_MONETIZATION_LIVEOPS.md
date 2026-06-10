# Monetization & Live Operations

## 1. Monetization Principles

**Hard rule: no power for Robux.** Enforced in code review — anything in
`MonetizationConfig.luau` granting stats, characters, or progression speed
(beyond the also-free battle pass) is rejected.

| Product | What it is | Why it's fair |
| --- | --- | --- |
| Gem bundles | Premium currency | Every gem source also exists free (quests, events, dailies, PvP) |
| Premium Battle Pass | Cosmetic track + bonus currencies | All gameplay-relevant rewards mirrored on the free track |
| Character skins | Visual recolors/outfits | Zero stats |
| Mount skins | Visual | Zero stats |
| Ultimate VFX recolors | Visual | Zero stats |
| Auras / Emotes / Titles | Visual/social | Zero stats |

Gacha fairness: published rates (in-game rates page mirrors
`BannerConfig.Rates`), soft pity at 50, hard pity at 80, Mythic pity at 400,
guaranteed featured after a lost 50/50, every-10-pull Rare minimum. Secret and
Divine units are tradeable-never, so there is no real-money secondary market
pressure.

## 2. Battle Pass (per 56-day season)

- 50 tiers × 1000 XP; XP from quests (100/claim), kills (5), bosses, events.
- Free track: ~2000 gems, evolution materials, 10 summon tickets.
- Premium (800 R$): seasonal skin set, mount skin, ultimate VFX, ~3000 gems.
- Season flip is automatic: `LiveOpsService:GetCurrentSeason()` derives from
  epoch time; profiles reconcile on login (tier reset, premium re-verified).

## 3. Event Calendar (LiveOpsService — all servers agree via os.time())

| Cadence | Event | Effect |
| --- | --- | --- |
| Daily 18:00 UTC, 1 h | Double Gold Hour | 2× gold drops |
| Weekly Sat–Sun | Raid Weekend | 2× raid tokens |
| Monthly 1st–3rd | Solstice Festival | Event boss spawns, EventCurrency drops, event banner |
| Per season (56 d) | Season flip | Battle pass reset, PvP soft reset (rating → midpoint of rating & 1000), season rewards by final rank |

## 4. Cosmetic Shop Rotation

3-day deterministic rotation (`Random.new(windowIndex)`) — every server shows
the same shop without coordination. Categories rotate across skins, auras,
VFX, emotes, titles.

## 5. Live Service Plan

**Weekly:** balance pass (config-only hotfixes — all tuning lives in
Shared/Configs), bug triage, raid rotation.
**Monthly:** 2–4 new characters (one `def(...)` + rig + animations), one event,
cosmetic drops.
**Per season (8 weeks):** new banner pair, battle pass, ranked reset, one
major feature (dungeon, raid tier, or world expansion).

## 6. Future Expansion (the next 100 characters)

- CHR_051–CHR_150 reserved; database loader is order-independent so packs
  ship as additional `def(...)` blocks.
- Each season introduces ~12 characters: 4 Common/Rare (pool depth),
  5 Epic/Legendary, 2 Mythic, 1 Secret/Divine (yearly Divine cadence: 2).
- New elements ship as wheel extensions in `Formulas.ELEMENT_ADVANTAGE` plus
  a StatusEffectData entry when paired with a new status.
- World 7 (“Voidsea Frontier”, Lv 500 cap raise to 600) is the year-2 anchor;
  `WorldConfig` requires only a new `WorldDef` + geometry.

## 7. KPIs to instrument (AnalyticsService, post-MVP)

D1/D7/D30 retention, summons per DAU, pity distribution (verify published
rates), session length, world progression funnel (each `Q_W#_BOSS`
completion), PvP queue time p50/p95, ARPDAU split by product, exploit-flag
rate per 1k sessions.
