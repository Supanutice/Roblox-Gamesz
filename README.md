# Anime Warriors III

An Anime Action RPG for Roblox — open world, multiplayer (PvE + PvP), gacha character
collection, dungeon raids, boss battles, and guilds. Built in Luau with a modular,
event-driven, service-oriented architecture. Targets 60 FPS on Mobile + PC.

## Repository Layout

```
Roblox-Gamesz/
├── default.project.json        # Rojo project mapping
├── docs/                       # Design & technical documentation
│   ├── 01_GAME_DESIGN_DOCUMENT.md
│   ├── 02_TECHNICAL_DESIGN_DOCUMENT.md
│   ├── 03_DATABASE_STRUCTURE.md
│   ├── 04_UI_UX_SPECIFICATIONS.md
│   ├── 05_DEVELOPMENT_ROADMAP.md
│   └── 06_LIVE_SERVICE_PLAN.md
└── src/
    ├── Server/                 # → ServerScriptService.Server
    │   ├── Main.server.luau    # Server bootstrap (service loader)
    │   ├── Services/           # Singleton game services (Data, Combat, Gacha…)
    │   ├── Managers/           # Per-entity runtime managers (Boss, Enemy)
    │   └── Modules/            # Server-only helpers (Hitbox, SessionLock)
    ├── Client/                 # → StarterPlayer.StarterPlayerScripts.Client
    │   ├── Main.client.luau    # Client bootstrap (controller loader)
    │   ├── Controllers/        # Input, Combat, Camera, UI controllers
    │   ├── UI/                 # Screen modules (Summon, Inventory…)
    │   └── Effects/            # VFX / SFX playback
    └── Shared/                 # → ReplicatedStorage.Shared
        ├── Configs/            # Tunable game constants (balance lives here)
        ├── Data/               # Static databases (Characters, Bosses, Quests)
        ├── Net/                # Remote event/function definitions
        └── Utilities/          # Signal, Maid, TableUtil, Formulas
```

## Getting Started

1. Install [Rojo](https://rojo.space) 7.x.
2. `rojo serve` in the repo root, then connect from Roblox Studio with the Rojo plugin.
3. Press Play — `Main.server.luau` boots all services, `Main.client.luau` boots all
   controllers. Boot order and dependency injection are described in
   `docs/02_TECHNICAL_DESIGN_DOCUMENT.md`.

## Architecture at a Glance

- **OOP + Modules** — every system is a ModuleScript class or singleton service.
- **Dependency Injection** — services receive a registry table at `:Init()`; no
  service `require`s another service directly, which keeps the graph acyclic.
- **Event-Driven** — cross-system communication goes through `Signal` objects and
  the typed remote definitions in `Shared/Net/Remotes.luau`.
- **Server-Authoritative** — the client *requests* actions; the server validates
  cooldowns, ranges, energy, and ownership before applying any state change.

## Documentation Index

| Doc | Contents |
| --- | --- |
| 01 Game Design | Core loop, characters, combat, worlds, bosses, gacha, progression, PvP, economy, monetization |
| 02 Technical Design | Architecture, boot flow, networking, security, performance budget |
| 03 Database Structure | Player data schema, save system, DataStore strategy, leaderboards |
| 04 UI/UX | Wireframes, layouts, navigation flow for every screen |
| 05 Roadmap | MVP scope, milestone plan, team estimates |
| 06 Live Service | Seasons, events, expansion plan (100 future characters) |
