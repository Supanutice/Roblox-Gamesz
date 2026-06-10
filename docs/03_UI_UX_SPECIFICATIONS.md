# UI/UX Specifications

Design language: dark indigo base (#0E0C18–#1E1C2C), neon accent per context
(gold = currency/legendary, violet = summon, red = combat), Gotham family,
rounded corners (UICorner 0.08–0.3), rarity-colored UIStrokes. All screens are
scale-based (UDim2.fromScale) → identical layout on mobile and PC.
Implemented screens live in `src/Client/UI`; every screen exports
`Build(parent: ScreenGui, ui: UIController) → Frame`.

## Navigation Flow

```
            ┌────────────── HUD (always visible) ──────────────┐
            │  hotkeys / bottom dock buttons / mobile buttons  │
            ▼          ▼          ▼          ▼         ▼       ▼
        Characters  Inventory   Summon     Quests    Guild    PvP
            │                     │                            │
        Detail/Evolve         Reveal seq                 Queue → Match HUD
```
One full-screen menu at a time (UIController router). `✕` or re-pressing the
hotkey closes. Combat input is sunk while a menu is open on mobile.

## HUD (in-world)

```
┌──────────────────────────────────────────────────────────────┐
│ Quest tracker (TL)                      🪙 Gold 💎 Gems 🎟 (TR)│
│                                                              │
│                       toast messages                         │
│                                                              │
│ ████████ HP (BL)                 [1] [2] [ULT]  (BC)         │
│ ████░░░░ Energy                  mobile: Attack/Heavy/Dash   │
└──────────────────────────────────────────────────────────────┘
```
Components: HP bar (green→red), energy bar (gold, fills to ULT), 3 skill
chips with live cooldown countdowns, currency readout, toast line, boss HP
bar (top-center, appears on aggro), awakening flash overlay.

## Main Menu (first join / respawn hub)

- Logo top-center, animated parallax world art behind
- Buttons (right column): **Play**, Characters, Summon, Shop, Settings
- Bottom strip: event banner carousel (LiveOps rotation), daily reward chip
  with streak indicator

## Summon Screen (implemented: `SummonUI.luau`)

```
┌ SUMMON ────────────────────────────────── ✕ ┐
│        ◀   Reign of the Flame Emperor   ▶   │   banner art behind
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐         │
│  │card│ │card│ │card│ │card│ │card│  ×2 rows│   reveal grid (10-pull)
│  └────┘ └────┘ └────┘ └────┘ └────┘         │
│      [ Summon x1 ]   [ Summon x10 ]         │   pity meter under buttons
└─────────────────────────────────────────────┘
```
Reveal: cards fade in staggered 0.2 s; Legendary+ slow-flash 0.9 s with
rarity-color burst. Duplicate shows “+10 shards”. Pity meter: “{n}/80 —
guaranteed Legendary”.

## Inventory (implemented: `InventoryUI.luau`)

- Tabs: All / Weapon / Material / Consumable
- Grid cells: name, count, weapon level; rarity UIStroke
- Tap → detail panel (use / equip / sell) — detail panel is post-MVP

## Character Screen

```
┌ CHARACTERS ─────────────────────────────── ✕ ┐
│ ┌ roster grid (left 40%) ┐ ┌ detail (60%) ─┐ │
│ │ sortable: rarity/level │ │ 3D viewport    │ │
│ │ rarity stroke cards    │ │ stats block    │ │
│ │                        │ │ P / S1 / S2 / U│ │
│ │                        │ │ [Level][Evolve]│ │
│ └────────────────────────┘ │ [Ascend][Equip]│ │
│ Team bar: [slot1][slot2][slot3]              │ │
└──────────────────────────────────────────────┘
```

## Shop — cosmetics rotation grid (3-day timer top-right), battle pass tab
with 50-tier dual-track scroller (free row / premium row), gem bundles last.

## Quest Log — three tabs (Main / Side / Daily-Weekly); rows show objective
progress bars fed live by `QuestProgressChanged`; CLAIM button pulses when
complete.

## Guild — roster list with rank chips, MOTD banner, guild level ring,
raid attempts (n/3), war scoreboard tab.

## PvP — mode cards (1v1 Ranked / 3v3 / Guild War) with rank emblem +
rating, QUEUE button → searching overlay with widening-range hint, season
reward preview rail.

## UX Rules

1. Every server rejection surfaces as a toast with the exact server reason.
2. Buttons that cost currency always show the price on the button itself.
3. Cooldown/lock states are visually disabled, never silently ignored.
4. Mobile hit targets ≥ 9% screen width; combat buttons in thumb arc.
5. No information needed for play is locked behind hover (mobile parity).
