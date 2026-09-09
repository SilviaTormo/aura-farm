# TEST-REPORT — Aura Farm pilot, first live Studio execution
**Date:** 2026-09-08 · **Build:** `AuraFarmPilot.rbxl` (49.9 KB, rojo 7.7.0) · **Tester:** automated smoke test driving the real services, with the user's real avatar (FicusTus, id 621002908) as the player.

## Result: 13/13 checks PASSED, zero script errors in the session log

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | boot — Remotes folder created by server bootstrap | PASS | 0.0s |
| 2 | player_join — real avatar joined | PASS | FicusTus (621002908) |
| 3 | leaderstats — Aura + Wins created | PASS | Aura=0 Wins=0 |
| 4 | map — AuraFarmMap generated (11 children) | PASS | plaza+arena+VIP |
| 5 | crowd_npcs — NPC crowd spawned | PASS | 12 NPCs |
| 6 | spawn — SpawnLocation inside the map | PASS | — |
| 7 | character — avatar replicated | PASS | HRP present |
| 8 | pose_applied — AuraService.setActivePose (server-authoritative) | PASS | tpose, tier 1 |
| 9 | pose_motor6d — R15 Motor6D present for the animator | PASS | RightShoulder (recursive) |
| 10 | aura_ticking — crowd hype pays aura | PASS | **0 → 535 in 5s** |
| 11 | pose_stopped — pose clears | PASS | — |
| 12 | shop_spend — economy math exact | PASS | spend 500 ok, remainder = earned − 500 |
| 13 | shop_unlock — pose unlock persisted in profile | PASS | moai unlocked |

## Video + frame evidence (`evidence/`)
- **`smoke-final.mp4`** (70 s) — the green run: Studio opening the build, Play starting, the session running while the smoke test passes.
- **`smoke-live.mp4`** (30 s) — first live session right after Play was pressed.
- `smoke-run.mp4`, `smoke-run2.mp4`, `smoke-run3.mp4` — the automation debugging journey (dialogs blocking Play, window on the wrong monitor).
- **`frame-game-loaded.png`** — map loaded in viewport · **`frame-aura-farming.png`** — mid-run while aura ticks · **`frame-end.png`** — end of the green run.
- Machine-readable log: `%LOCALAPPDATA%/Roblox/logs/0.737.0.7371584_20260908T162402Z_Studio_8A10C_last.log` — all `[SMOKE]` lines + boot sequence (`[AuraFarm] started <Service>` × 13).

## What this proves (first time, with runtime evidence)
1. The place **executes**: 13 services boot in order with zero errors.
2. The code-generated **map exists and is playable** (spawn works — the avatar joined and spawned).
3. The **pose system works on a real R15 avatar** server-side (previously only mock-proven).
4. The **economy pays out**: crowd hype → aura at the designed rate (≈107/s at plaza with 12 NPCs on a tier-1 pose).
5. The **shop math is exact** and unlocks persist in the profile.
6. **No script errors** in the entire session (`FLog::CreatorError` empty).

## What this session can NOT prove (honest limits)
- **Duels and MOG payoff** need 2+ human players (the remote layer is proven by the 14/14 Luau suite; live PvP needs a human or a second client — run Test → Clients and Servers → 2 Players).
- **DataStore persistence** (Studio API access was off → expected `DataStore unavailable` warning; session-only data, by design).
- **Marketplace prompts** (all IDs are 0 = "coming soon" by design).
- **Visual quality/juice** (pose visuals, MOG FX, camera shake) — visible in the video, judged by humans.
- Studio is Spanish-locale + single-monitor capture; the video shows the whole desktop.

## How it was automated (tools now in `tools/`)
`winrect.ps1` (focus + F5 = Play), `movewin.ps1` (window to primary monitor), `clickbtn.ps1`/`clickid.ps1`/`realclick.ps1` (UI Automation dialog/ribbon control), `dumpui.ps1`/`listwins.ps1` (UI inspection), ffmpeg `gdigrab` for video. The smoke test lives in `tests/studio/SmokeTest.server.lua`, wired into the build via `default.project.json` (ServerScriptService → SmokeTest) — remove that tree entry for production builds.

## Iteration log (what the first runs caught)
1. Run 1 (11/13): `pose_motor6d` FAIL — R15 nests Motor6Ds inside limbs; assertion now recursive. `shop_spend` FAIL — crowd paid 533, not exactly 500; assertion now relative to earned aura. **Both were test-assertion bugs, not game bugs.**
2. Earlier discovery: the `Ejecutar` ribbon button is unreachable while Studio's crash-recovery dialog is up; `Players.LocalPlayer` doesn't exist in server scripts (first smoke test version error, fixed to `GetPlayers()` polling).

## Addendum: real-keystroke proof of the T-key training flow (2026-09-08)

- **A real T keystroke opens the training round end-to-end**: SendKeys T into
  the live Play viewport, then the log shows the server-side tag "open for
  FicusTus via T KEY (8s window)", followed by a judged result ~8.2s later.
  Proven on 4 separate sessions (17:00, 17:02 x2, 17:11 - the last on the
  final build).
- Round flow through the real JudgeService: "result for FicusTus: CRINGE 0.0
  vs bot 6.5 MID - LOSE (+0 aura)" (no pose locked = 0 score, correct math).
- **Defect found & fixed**: the controls hint from the previous pass was
  INVISIBLE - anchored mid-height at y=-30 (above the screen). Repositioned
  centered below the aura counter (y=86). Frames: evidence/final-1-hint.png
  (hint zone), final-2-picker.png (post-T), final-3-result.png; video
  evidence/tkey-final.mp4; tkey-run.mp4 (first proof run).
- Server evidence prints added to TrainingService: open (with source T KEY /
  PAD TOUCH), pose lock (with time-left), result (stamps + payout). These
  remain as the permanent pilot evidence channel.
- NOT proven: clicking a picker button by synthesized mouse (pixel-locating
  the GUI inside the 5120px multi-monitor capture was unreliable); pick
  coverage exists in the 14-test offline suite. Pad-touch open prints its own
  tag whenever a real avatar touches the pad.

## Addendum 2: pad-touch round + client pick proven live (2026-09-08, session 17:21)

Both remaining client paths exercised in ONE Play session (log
0.737...4CEFE_last.log), with the real avatar (FicusTus) and real physics:

- **Pad-touch round PROVEN**: a pilot LocalScript probe teleported the avatar
  onto the green pad; physics fired Touched and the server logged
  "[TRAIN] open for FicusTus via PAD TOUCH (8s window)". The pad re-opened a
  second round 31s later (debounce/cooldown expiry worked as designed).
- **Client-initiated pick PROVEN**: the probe fired TrainingPick("wave") — the
  exact remote the picker buttons fire — 1.5s into the round; the server
  accepted and logged "[TRAIN] FicusTus locked pose 'wave' at 6.5s left".
- **Judged end-to-end with the locked pose**: "[TRAIN] result for FicusTus:
  CRINGE 1.6 vs bot 6.6 MID - LOSE (+0 aura)" — a real score (1.6, from pose +
  crowd votes), not the 0.0 of an empty round. Both rounds judged and paid out
  correctly per the rules (loss = 0 aura).
- Boot integrity on the same session: [SMOKE] 13/13, zero script errors.
- Evidence: video evidence/pad-pick-proof.mp4 (42s, covers both rounds), frame
  evidence/pad-moment.png (the drop moment), plus the full [PROBE]/[TRAIN] log
  lines quoted above.
- Tooling note: the probe lives at tests/studio/ClientProbe.client.lua (pilot-
  only, like SmokeTest — BOTH are wired in default.project.json and BOTH must
  be removed for production builds).

## 2026-09-09 — Live agent-driven session (poses actually visible)
Root cause of "poses never visible": avatars are rigged with **AnimationConstraint**
(2026 Avatar Joint Upgrade) — no Motor6Ds, read-only C0, Transform does not
replicate. Server-side posing was structurally invisible. Rewired per Roblox's
migration pattern: server keeps authority (validation, aura, PoseStarted/PoseStopped
+ character attribute), new client `PoseRenderer` writes joint Transforms every
PreSimulation frame; `PoseTables` resolves AnimationConstraint, legacy Motor6D
R15 and R6 rigs. Suite grew to **21/21** (mock harness bug fixed: FireAllClients
no longer prepends the player — real Roblox passes only the payload).
Live proof (Studio 0.737 log, session 11:40Z, avatar FicusTus):
`[SMOKE] SUMMARY total=13 passed=13 failed=0`, rig inventory 15 AnimationConstraint
joints, `pose "tpose" rendering ... with 2 joints`, and — after a real P keystroke +
real wheel click — `pose "moai" rendering ... with 5 joints`
(evidence/pose_moai_live.png).

## 2026-09-09 — White-out fix (lighting)
User screenshot: avatar + map pure white. Cause: the place ships Studio default
Lighting (Brightness ~3.1, EnvironmentDiffuse/SpecularScale = 0) and no code ever
configured it — harsh direct sun blew every material to white. Fix: MapService.init
now applies a stylized late-afternoon setup (Brightness 2.2, env scales 0.65/0.45,
OutdoorAmbient, ClockTime 15.5, shadows + mild bloom) and prints
`[MapService] lighting applied`. Live session log confirms the line; frame analysis
of evidence/light_check.png: ground luma 255→~148 with green tint present
(avg RGB c6e9e4) and shadow structure visible. Suite 21/21; build 14:06.

## 2026-09-09 — Training poses now render (user report: "en el train las poses no van")
TrainingService recorded the picked pose for judging but never showed it: it never
called AuraService.setActivePose (duels did). Fix: locking a training pose now calls
setActivePose(poseId, {noPay=true}) — visual-only, so the pad can't be used as an
idle-aura farm and round losers gain nothing; the economy entry of a pose farmed
before the round is suspended while the training pose shows, and restored after
(priorPoseId). Suite test upgraded to assert the real contract (was picking an
UNLOCKED pose — the silent rejection that hid the bug): unlock -> pick -> attribute
stamped -> cleared at round end. 21/21 green.
