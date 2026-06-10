# World Design — Six Launch Worlds

Logical definitions (NPCs, enemies, bosses, quests, travel, secrets) live in
`src/Shared/Configs/WorldConfig.luau`; this document is the level-design brief
for the geometry under `Workspace/Worlds/<Id>`. All worlds use
StreamingEnabled; each world's origin is offset 2,000 studs on X so streaming
naturally unloads distant worlds.

Progression gates: each world unlocks via its predecessor's boss quest +
player level (enforced server-side in `SpawnerService.handleFastTravel`).

---

## World 1 — Beginner Island (Lv 1–25) · origin X=0
**Theme:** sunny coastal village, cherry trees, broken shrine cliffs.
**Layout:** Hamato Village hub (spawn, shops, dojo) → east coast road
(bandits) → Broken Shore (wolves, Tide Golems) → Watcher's Peak switchbacks →
boss cove arena. One looping main road; everything visible from the peak.
**NPCs:** Elder Hamato (main quests), Sensei Roku (tutorial/trainer), Smith
Daigo (weapons), Merchant Yui (items + first-summon quest).
**Enemies:** Cove Bandit (3), Shorefang Wolf (6), Tide Golem (12), Rogue
Disciple (18). **Boss:** Kraken Spawn — tutorial boss, telegraph training.
**Secrets:** waterfall cave chest (100 gems); four-shrine bow puzzle (5k gold).
**Reward arc:** completes onboarding — first summon, first evolution shards,
first boss kill → unlocks World 2.

## World 2 — Shinobi Nation (Lv 25–70) · origin X=2000
**Theme:** hidden-village valley: paper lanterns, bamboo, rooftop paths.
**Layout:** Hidden Gate checkpoint → village tiers (vertical design, rooftop
traversal) → Whisper Forest (genin/puppets) → cursed shrine (Oni-masked) →
Kage Tower summit arena.
**NPCs:** Lady Shirayuki (kage, main quests), Toolsmith Genba, Chef Tonkatsu
(consumables), Spymaster Kuro (bounty board = repeatable side kills).
**Enemies:** Renegade Genin (28), Cursed Puppet (38), Shadow Jonin (52),
Oni-Masked Assassin (64). **Boss:** Shadow Shogun — clone mechanic teaches
target identification; perfect-block counter window showcase.
**Secrets:** dojo-floor forbidden scroll (skill scrolls); midnight fox shrine.

## World 3 — Soul Empire (Lv 70–140) · origin X=4000
**Theme:** monochrome spirit city, floating lanterns, rivers of souls.
**Layout:** Spirit Court plaza → twin soul-river crossing (Soulbound Knights
patrol bridges) → Hollow Rift wasteland (arena). Gatekeeper Wol riddle gate
shortcuts the wasteland for clever players.
**Enemies:** Hollow Wraith (75), Fallen Reaper (95), Soulbound Knight (120).
**Boss:** Hollow Monarch — add-management fight (heal-on-add-death punishes
ignoring mechanics); first DPS-race phase.

## World 4 — Grand Ocean (Lv 140–230) · origin X=6000
**Theme:** pirate archipelago; fights on ship decks and island chains.
**Layout:** Freeport Haven (trade post — Broker Quill anchors the player
economy) → reef route (pirates) → marine fortress → Skull Isle → open-sea
Leviathan arena (ship-deck platforms, water = DoT hazard).
**Enemies:** Reef Pirate (150), Iron Marine (180), Abyss Serpent (215).
**Boss:** The Leviathan — environmental boss: deck positioning, breach
prediction, maelstrom ring rotation.

## World 5 — Demon Realm (Lv 230–350) · origin X=8000
**Theme:** obsidian wastes, lava rivers, the Last Bastion fortress.
**Layout:** Bastion hub (siege ambience, NPC defenders) → ember fields (imp
swarms — AoE skill showcase) → Pit (fiends) → Obsidian Approach (archdemon
gauntlet) → throne arena.
**Enemies:** Ember Imp (240), Pit Fiend (290), Archdemon Sentinel (330).
**Boss:** Demon King Balgaroth — twin-guard shield phase (coordinated DPS),
270° breath cone with positional safe spot. Drops the first Divine Ember.

## World 6 — Celestial Kingdom (Lv 350–500) · origin X=10000
**Theme:** floating islands above the clouds, dawn palette, star machinery.
**Layout:** Gate of Dawn → island chain traversal (air-dash gaps) → Astral
Foundry (constructs) → void-corrupted outskirts → Infinity Spire (vertical
climb) → Arbiter sanctum.
**Enemies:** Fallen Seraph (370), Astral Construct (420), Voidborn Herald (480).
**Boss:** The Celestial Arbiter — endgame skill check: body-block mechanic,
gravity inversion (aerial combat), 60-second World Erasure DPS wall with
rotating safe tiles. Pinnacle loot: Starfall Edge, Divine Embers.

---

## Shared World Systems
- **Fast travel:** unlock by touching the waypoint once; travel via map UI
  (server-validated, AntiCheat teleport-whitelisted).
- **Dungeons:** each world ships one 4-player instanced dungeon post-MVP
  (reserved `Managers/` layer); daily quest hook already counts clears.
- **Raids:** guild raid bosses (Voidlord, Seamother, Chronos) rotate weekly —
  see `GuildConfig.Raids` and `BossDatabase`.
- **Density budget:** ≤ 16 active enemies per world region (4 types × 4
  spawns) to hold the 60 FPS server budget with 20 players.
