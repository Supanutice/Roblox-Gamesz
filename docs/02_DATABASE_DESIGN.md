# Database & Persistence Design

## 1. DataStores

| Store | Key | Value | Writer |
| --- | --- | --- | --- |
| `PlayerProfiles_v1` | `p_<userId>` | `{ Data = profile, Lock = { SessionId, Timestamp } }` | DataService only |
| `PlayerProfiles_v1_Backups` | `p_<userId>_<0..2>` | rolling snapshot ring (last 3 saves) | DataService (async) |
| `Guilds_v1` | `g_<guildId>` | GuildDoc | GuildService (UpdateAsync only) |
| `TradeLog_v1` | `<tradeGuid>` | both offers + user ids + timestamp | TradeService (append-only) |
| `Leaderboards` (OrderedDataStore) | `pvp_<seasonId>`, `level`, `bosskills` | score per userId | LeaderboardService (planned) |

## 2. Session Locking Protocol (ProfileService pattern)

```
LOAD:   UpdateAsync(key):
          if Lock exists ∧ Lock.SessionId ≠ mine ∧ age < 90 s  → REJECT (retry, then kick politely)
          else  → write my Lock, read Data
SAVE:   UpdateAsync(key):
          if Lock.SessionId ≠ mine → abort (another server owns it now)
          else  → write Data (+ release Lock on final save)
```

Guarantees: no two servers ever write one profile concurrently → no dupes via
server-hopping; crashes self-heal after the 90 s lock timeout.

## 3. Save Cadence

- Auto-save: every 120 s, only if `profile.Dirty`
- On leave: final save + lock release
- On server close: `BindToClose` blocks until every profile is flushed
- Backups: fire-and-forget ring of 3 after each successful main save

## 4. Schema Evolution

The profile template in `DataService.luau` is the schema. On load,
`TableUtil.Reconcile(data, template)` deep-fills any missing keys, so adding
fields is free. Removing/renaming fields requires a numbered migration:
bump `GameConfig.DataStoreVersion` (new store name) plus a one-time import
path from the previous store.

## 5. Profile Schema (summary)

```
Level, XP, TotalPlaySeconds, CreatedAt, LastSeenAt
Currencies        { Gold, Gems, RaidTokens, EventCurrency }       — clamped to per-currency Max
Characters        { [uid GUID]: { CharacterId, Level, XP, EvolutionStage, Ascension,
                                  SkillLevels[3], Shards, EquippedWeaponUid, Locked } }
TeamSlots         { [1..3]: uid }
Inventory         { [uid GUID]: { ItemId, Count, WeaponLevel? } }  — slot-capped (400)
Quests            { Active{ [id]: {Progress[], AcceptedAt} }, Completed{}, daily/weekly reset stamps }
Gacha             { PityCounter{bannerId}, MythicPityCounter{}, TotalPulls, LostFiftyFifty{} }
PvP               { Rating1v1, Rating3v3, Wins, Losses, SeasonId }
GuildId
Progress          { UnlockedWorlds{}, UnlockedFastTravel{}, FoundSecrets{}, BossKills{} }
BattlePass        { SeasonId, Tier, XP, PremiumOwned, ClaimedFree{}, ClaimedPremium{} }
DailyRewards      { Streak, LastClaimUnix }
Cosmetics         { Owned{}, EquippedSkin/Aura/Title }
Settings          { volumes, screen shake, damage numbers, auto-lock }
Moderation        { TradeBannedUntil, ExploitFlags }   — never replicated to clients
```

## 6. Integrity Rules

- Currency mutations only via `DataService:AddCurrency` / `SpendCurrency`
  (floor + NaN/inf rejection + max clamp; spend is check-then-debit atomic
  within the single Luau thread).
- Item grants only via `InventoryService` (validates against `ItemDatabase`,
  stack caps, slot caps; multi-consume is all-or-nothing).
- Character uids are GUIDs minted server-side; trades re-mint the uid on the
  receiving profile, killing uid-replay dupes.
- The client receives a profile *snapshot* at login and deltas afterwards; the
  snapshot strips `Moderation`.
