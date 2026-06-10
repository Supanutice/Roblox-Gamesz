# Development Roadmap

Team assumption: 1 lead engineer, 1 gameplay engineer, 2 artists/animators,
1 designer (can compress with contractors; expand timeline solo ~2.5×).

## Phase 1 — MVP (Weeks 1–8)  →  Closed Alpha

**Goal: one full loop — fight, quest, summon, progress — in World 1.**

- [x] Architecture: boot loaders, DI registry, Remotes contract, Signal/Maid
- [x] DataService (session lock, autosave, backups, reconcile)
- [x] Combat core: M1 combo, heavy, dash, block/perfect block, hitboxes,
      damage formula, 6 status effects, energy/ultimate, awakening
- [x] CharacterService: roster, team, level/evolve/ascend; 50-character DB
- [x] SummonService: rates, soft/hard/Mythic pity, 50/50, 10-pull guarantee
- [x] QuestService + World 1 quest line; daily/weekly auto-grant
- [x] Enemy AI + Kraken Spawn boss; spawner/respawn loops
- [x] HUD, Summon, Inventory screens; damage numbers; telegraphs
- [x] AntiCheat v1 (movement, damage ceiling, remote budget, ledger)
- [x] Procedural placeholder geometry for all 6 worlds (islands, bridges,
      fast-travel pads, secret chests, boss arenas, spawn) — WorldBuilderService
- [x] Interactable NPCs with dialogue + quest accept/claim — NPCService
- [x] Characters screen (equip / level / evolve / ascend) + Quest Log screen
- [ ] World 1 geometry + placeholder rigs replaced with real art
- [ ] First playtest: 20-player server soak, save-integrity pass

**Exit criteria:** 30 min of content, zero data-loss reports across 100
sessions, stable 60 FPS on a mid-range phone.

## Phase 2 — Beta (Weeks 9–18)  →  Open Beta

- Worlds 2–3 (geometry, quests live in DB already), Shadow Shogun + Hollow
  Monarch choreography (bespoke BossAI abilities)
- PvP ranked 1v1 + arena maps; spectate-safe match flow (service shipped;
  needs arena maps + round scripts calling `ReportRoundWinner`)
- Guilds v1 (create/join/ranks/MOTD shipped; add guild chat channel + raids)
- Trading v1 (shipped; add UI + 2FA-style confirm screen)
- Character/Quest/Shop/Guild/PvP UI screens
- Animation pass: per-class M1 sets, 50 ultimates (batched by class skeleton)
- Cutscene system for boss intros (CameraController hooks shipped)
- Analytics + crash reporting; load test at 2k CCU

## Phase 3 — Launch (Weeks 19–26)

- Worlds 4–6 + Leviathan / Demon King / Arbiter full choreography
- Raid bosses (Voidlord, Seamother, Chronos) + guild raid scheduler
- Battle pass season 1, cosmetic shop catalog (30+ items)
- Limited banner #1 with launch Mythic (Susanoo rate-up)
- Marketing beats: trailer, creator codes, launch event (Solstice)
- LiveOps dashboard: kill-switch flags for banners/events/trading

## Phase 4 — Live Service (Week 27+)

- 8-week season cadence (see 05_MONETIZATION_LIVEOPS.md §5)
- Season 2: 3v3 arena ranked, dungeon system (instanced, 4-player)
- Season 3: guild wars (48 h territory), mounts + mount skins
- Season 4: world 7 + level cap 600, second Divine
- Continuous: monthly character drops toward the 100-character expansion pool

## Risk Register

| Risk | Mitigation |
| --- | --- |
| DataStore throttling at scale | Dirty-flag saves, 120 s cadence, backup ring is async best-effort |
| Combat feel on mobile | Prediction-first client (animations before server ack); 0.45 s M1 window tuned for touch |
| Gacha compliance scrutiny | Published rates = config truth; pity audit via analytics |
| Exploit arms race | Single remote surface, behavioral ledger, trade audit log enables rollbacks |
| Content drought post-launch | Data-driven content: characters/quests/bosses ship without code changes |
