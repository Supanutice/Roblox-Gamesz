# Anime Warriors III — Master Architecture & Technical Design

## 1. Pillars

| Pillar | Consequence in code |
| --- | --- |
| Server-authoritative everything | Clients send *requests*; `Remotes.luau` is the entire attack surface |
| 60 FPS on mobile | Single tick loops (no per-entity threads), 5 Hz AI, 0.25 s status ticks, StreamingEnabled |
| Modular & DI | Services never `require` each other; the boot loader injects a registry |
| Anti pay-to-win | `MonetizationConfig.luau` is cosmetics-only by code-review rule; ranked PvP normalizes stats |
| Live-service ready | Configs/databases are pure data; new content ships without touching service code |

## 2. Boot Flow

```
SERVER                                      CLIENT
Main.server.luau                            Main.client.luau
 ├─ Remotes.InitServer()  (create remotes)   ├─ require all Controllers
 ├─ require all Services                     ├─ Controller:Init(registry)  (no cross-calls)
 ├─ Service:Init(registry) (DataService 1st) └─ Controller:Start()         (wire signals/remotes)
 └─ Service:Start()        (cross-calls OK)
```

Two-phase startup guarantees every module exists before any module talks to
another. `Init` stores references; `Start` subscribes and runs.

## 3. Runtime Instance Tree

```
ReplicatedStorage
├─ Shared                  (Rojo: src/Shared)
│  ├─ Configs              GameConfig, CombatConfig, BannerConfig, ProgressionConfig,
│  │                       WorldConfig, PvPConfig, GuildConfig, MonetizationConfig
│  ├─ Data                 CharacterDatabase (50 heroes), BossDatabase, QuestDatabase,
│  │                       ItemDatabase, StatusEffectData
│  ├─ Net                  Remotes.luau (typed registry; server creates, client waits)
│  └─ Utilities            Signal, Maid, TableUtil, Formulas
├─ Remotes                 (created at runtime by Remotes.InitServer)
├─ Assets                  (meshes, sounds — art drop zone)
├─ Characters              (hero rigs, keyed by CHR_xxx)
└─ Effects                 (particle templates, keyed by VFX_xxx)

ServerScriptService
└─ Server                  (Rojo: src/Server)
   ├─ Main.server.luau
   ├─ Services             DataService, InventoryService, EconomyService, CombatService,
   │                       DamageService, HitboxService, StatusEffectService,
   │                       CharacterService, SummonService, QuestService, SpawnerService,
   │                       PvPService, GuildService, TradeService, AntiCheatService,
   │                       LiveOpsService
   ├─ Managers             (reserved: per-dungeon instance managers)
   ├─ Modules              (reserved: server-only helpers)
   └─ AI                   AIController (enemies), BossAI (phase bosses)

ServerStorage
├─ Enemies/<EN_id>         enemy rig templates (placeholder rigs auto-built if absent)
└─ Bosses/<BOSS_id>        boss rig templates

StarterPlayer/StarterPlayerScripts
└─ Client                  (Rojo: src/Client)
   ├─ Main.client.luau
   ├─ Controllers          InputController, CombatController, CameraController,
   │                       UIController, EffectsController
   ├─ UI                   SummonUI, InventoryUI (+ CharacterUI, ShopUI, QuestUI,
   │                       GuildUI, PvPUI — same Build(parent, ui) contract)
   └─ Effects              VFXController

Workspace (StreamingEnabled)
└─ Worlds/<W#_id>          world geometry; logic layer = WorldConfig.luau
```

## 4. Networking Contract

All remotes are declared once in `src/Shared/Net/Remotes.luau`. Rules:

1. **Client → Server** remotes carry *intentions* (`CombatRequestSkill(slot, aim)`),
   never *outcomes* (no damage values, no item ids being granted).
2. **Server → Client** remotes carry *facts* the client renders
   (`CombatHitConfirmed`, `CurrencyChanged`).
3. RemoteFunctions return `(ok: boolean, payloadOrError)` — every handler
   type-checks its arguments before touching state.
4. Adding a remote requires adding it to `DEFINITIONS`; security review diffs
   exactly one file.

## 5. Damage Pipeline (the one true path)

```
Client input ─▶ CombatRequest* remote
  ─▶ CombatService: validate state/cooldown/energy/rate ── reject → AntiCheat:Flag
  ─▶ HitboxService: server-side spatial sweep (box / sphere / moving)
  ─▶ DamageService.ApplyDamage:
        i-frames → block/perfect-block → Formulas.ComputeDamage
        (ATK · skill mult · skill level · DEF mitigation · element wheel ·
         crit · variance) → AntiCheat:ClampDamage → Humanoid:TakeDamage
  ─▶ side effects: StatusEffectService:Apply, knockback, energy gain,
        CombatHitConfirmed (damage numbers), EntityDied signal
  ─▶ EntityDied → SpawnerService kill credit → XP/Gold/quests/battle-pass
```

## 6. Performance Budget (20-player server, 60 FPS)

| System | Cost ceiling |
| --- | --- |
| Status effects | 1 loop @ 4 Hz over active entities |
| Enemy AI | 1 heartbeat accumulator per enemy, logic @ 5 Hz; ~100 enemies max |
| AntiCheat movement | 20 players @ 2 Hz position sampling |
| Matchmaking | queue scan @ 0.5 Hz |
| Auto-save | staggered, 1 profile write / player / 2 min |
| Client VFX | Debris-managed, ≤ 0.9 s damage numbers, particle emitters auto-expire |

## 7. Security Model (Anti-Cheat layers)

1. **Architecture** — no client-trusted numbers anywhere (see §4, §5).
2. **Validation** — every remote handler type-checks args, checks cooldowns
   server-side, validates range with latency tolerance, re-validates trades at
   commit time, re-entrancy-guards summons.
3. **Behavioral** — `AntiCheatService`: speed/teleport detection with
   dash-burst and fast-travel whitelists, rubber-banding, damage ceilings,
   remote-rate budgets, weighted flag ledger with decay → kick at threshold.
4. **Audit** — trade log DataStore, exploit flag counter on profiles,
   single-choke-point currency mutations.

## 8. Data Models (canonical shapes)

Player profile: see `PROFILE_TEMPLATE` in `DataService.luau` — the template IS
the schema; `TableUtil.Reconcile` migrates old profiles forward automatically.

Guild document (`Guilds_v1` store): see `GuildDoc` type in `GuildService.luau`;
all writes go through `UpdateAsync` mutators, cross-server cache invalidation
via MessagingService.

Static content: `CharacterDef`, `BossDef`, `QuestDef`, `ItemDef`,
`StatusEffectDef`, `WorldDef`, `Banner` — all exported Luau types living next
to their data.

## 9. Extension Playbook

| Want to add… | Touch |
| --- | --- |
| A character | `CharacterDatabase.luau` (one `def(...)` call) + rig in ReplicatedStorage/Characters |
| A banner | `BannerConfig.luau` |
| A quest | `QuestDatabase.luau` (+ WorldConfig quest list) |
| A boss | `BossDatabase.luau` (+ ability choreography in `BossAI.luau` if bespoke) |
| A status effect | `StatusEffectData.luau` (+ VFX color in VFXController) |
| A world | `WorldConfig.luau` + geometry under Workspace/Worlds |
| A UI screen | one module in `Client/UI` exposing `Build(parent, ui)` |
