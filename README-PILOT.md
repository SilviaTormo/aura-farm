# 🧪 AURA FARM — Pilot Playtest Guide

Everything you need to get the pilot build running in Roblox Studio and run
your first 6–10 person playtest. Full design: see `DESIGN.md`.

## 1. Play the pilot (≈2 min)

**You only need Roblox Studio** (free, from roblox.com/create). The game is
already built in this folder:

1. Double-click **`AuraFarmPilot.rbxl`** (or in Studio: File → Open From File).
2. Press **Play** (F5).
3. Pose with `P` / `Q` to stop, farm aura, open the shop with `B`.

To test duels solo: **Test tab → "Clients and Servers" → set to 2 Players →
Start**. Two windows join the same server — challenge yourself to a duel.

Enable **"Studio Access to API Services"** (Game Settings → Security) if you
want aura to persist + leaderboards to work between sessions.

## 2. Rebuilding after code changes

The `.rbxl` is built from the Luau sources in `src/` with
[Rojo](https://github.com/rojo-rbx/rojo). The tool is already downloaded into
`tools/` — you don't need to install anything:

- **Double-click `build.bat`** → rebuilds `AuraFarmPilot.rbxl` → re-open it in
  Studio. That's it.

Or from a terminal in this folder:

```bash
./tools/rojo/rojo.exe build default.project.json -o AuraFarmPilot.rbxl
```

Source layout:

- `src/server` → `ServerScriptService/AuraFarmServer`
- `src/shared` → `ReplicatedStorage/AuraFarmShared`
- `src/client` → `StarterPlayer/StarterPlayerScripts/AuraFarmClient`

(Advanced: `rojo serve` + the Rojo Studio plugin gives live-sync while you
iterate — only needed once you're doing heavy code work.)

## 3. What's in the pilot build

| Feature | Status |
|---|---|
| Plaza + arena + judges (code-built map) | ✅ |
| Pose with `P` (PC) / POSE button (mobile) | ✅ |
| NPC crowd hype + attention decay + aura ticks | ✅ |
| Pose shop (`B` / SHOP button) — aura currency | ✅ |
| Duels: invite → arena → best-of-5 → judge stamps | ✅ |
| Judge timing bonus (lock on the beat for +points) | ✅ |
| MOG moment: skull confetti, aura orbs, camera shake | ✅ |
| MOGGED billboard debuff on the loser | ✅ |
| Server-side poses (everyone sees your pose) | ✅ |
| Spot multipliers: stage 2x, arena 1.5x, VIP rooftop 2.5x | ✅ |
| Robux gamepasses + dev products (full wiring) | ✅ needs IDs in `Config.lua` |
| Clip prompts (CaptureService) after MOGs | ✅ |
| Aura persistence (DataStore) + all-time + weekly boards | ✅ |
| Real animation ASSETS (procedural Motor6D poses now) | ⏳ M2 polish |

## 4. Tester checklist (print for playtesters)

1. Join the game. **Without reading anything**, try to figure out how to farm
   aura. (This tests onboarding — tell the moderator how long it took.)
2. Pose until you have ≥ 500 aura, then open the shop (`B`) and buy 🗿 Moai.
3. Challenge someone: walk near them → `MOG` (duel) → they accept → arena.
4. During each round, pick a pose **before** the timer ends.
5. Watch the judges stamp 🔥/mid/💀. Best of 5. Winner steals 15% aura.
6. If you lose: enjoy your head exploding 💀.
7. Check the leaderboard boards near spawn.

## 5. Moderator script (the person running the test)

- Min 0–5: silence. Observe who poses spontaneously.
- Min 5: announce in chat: "First MOG battle in the arena, now."
- Min 10: "Everyone check the top-aura board."
- Min 15: "Shop's open — what's the first thing you'd buy with Robux?"
- After: run the 5-question survey from `DESIGN.md` §9.

## 6. Success bar

- ≥ 60% of testers dueled at least once.
- ≥ 40% bought a pose with aura.
- ≥ 7/10 average "I'd play again tomorrow".
- At least one tester clips the MOG moment and shares it.

## 7. Known pilot limitations

- Poses are procedural Motor6D transforms (visible to everyone, but stylized
  freezes — swap in real animation assets in M2 via `Config.POSE_ANIMATIONS`).
- NPC crowd has full bodies with procedural walk/cheer animation, but no
  faces/accessories yet.
- Robux purchases are fully wired but inert until you paste real IDs into
  `GAMEPASSES` / `DEV_PRODUCTS` in `src/shared/Config.lua` (id = 0 shows
  "coming soon"). After creating the passes/products in the Creator Dashboard,
  paste the IDs and the shop prompts go live.
- Clip prompts call `CaptureService:PromptCapture` (beta) — verify it's enabled
  for your place; failures are silently caught.
