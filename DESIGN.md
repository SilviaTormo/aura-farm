# AURA FARM: Pose Battles 💀🗿

> Stand in a meme plaza, strike poses to farm AURA from a hype-hungry NPC crowd,
> mog rivals in judge-scored pose-off duels, flex drip, and clip your wins for the feed.

Status: **PILOT v0.1** — playable vertical slice for a small closed playtest.

---

## 1. The fantasy

You are a nobody in a plaza full of people who all want attention. You pose.
The crowd goes 🔥. Your AURA number goes up. Someone walks up, stares at you,
and challenges you to a pose-off. Three judges watch. The crowd screams.
You hit the pose at the perfect beat… **STAMP: 🔥 10/10.** Your rival gets
💀 CRINGE. Their head explodes. Your aura number eats theirs.

That is the whole game. Everything else exists to make that moment repeat.

## 2. Why this can make money (reality check)

- The "aura farming" genre is hot on Roblox (Aura Ascension, Aura Farm Game,
  Need More Aura…), but none of them own the **crowd-hype + judged duel** fantasy.
- Monetization = flex + convenience, never raw score:
  - **Gamepasses**: 2x Aura, VIP plaza, Sigma Pose Pack, Golden Drip Bundle.
  - **Dev products**: Mog Shield (1h), Cooldown Refill, server-wide **Party Mode**
    (2x for everyone, 10 min — social whale spend).
- Revenue math to keep in mind: 30% marketplace fee on passes/products,
  DevEx ≈ $0.0038 per Robux (with a 42% boost for spend from age-verified 18+ US
  players), and **Creator Rewards** daily engagement payouts reward DAU/time —
  a pose-battle social loop is very good at generating exactly that.
- **Sharing flywheel**: Roblox's CaptureService (Video Captures API) + Roblox
  Moments feed. We prompt "Clip that! 💀" after judge verdicts and head-explosion
  moments. Clips are the discovery engine; the game must be *watchable*.

## 3. Core loop (v1 pilot)

```
      ┌────────────── pose ──────────────┐
      ▼                                  │
 [farm aura from crowd] ──▶ [buy pose/drip] ──▶ [challenge rival]
      ▲                                                   │
      └────── [steal 15% of their aura] ◀── [JUDGED MOG] ◀─┘
```

- **Pose** (key `P`, or the on-screen action button on mobile): open the pose
  wheel → hold a pose → NPCs inside your hype radius turn to you, cheer
  (🔥💀🗿 particles) and grant aura ticks.
  `aura rate = pose tier × crowd count × drip multiplier × spot multiplier`.
- **Crowd**: NPCs wander the plaza with **attention decay** (they get bored of
  your pose) → forces you to rotate poses and spots. Rare **influencer NPCs**
  migrate toward whoever is currently #1 on the server.
- **Duels ("MOG ⚔️")**: challenge a player → both teleport to the arena →
  30-second judged pose-off (see §4) → winner steals **15% of the loser's
  current aura** (capped, newbie-protected), loser wears a **"MOGGED 💀"**
  billboard debuff for 60 s. Rate-limited so one player can't spam-challenge.
  - **Solo mode (pilot)**: 3 NPC rivals (Tomás el Faker, Luna Hype, GIGACHAD)
    stand by the arena and can be MOG'd with no second player — same judged
    best-of-5, the bot picks its pose at the buzzer limited by its tier, and
    the winner takes the rival's **bounty** (100/400/1200 aura) instead of a
    steal. Live PvP rides the exact same judge loop.

## 4. ⚖️ Judge System (the duel's scoring & feedback layer)

The judges are the heart of the duel. Server-authoritative, never client-side.

- **3 NPC judges** sit at the arena (meme talent-show style). After each pose
  round they slam a stamp:
  - 🔥 **FIRE** — big score (10/10): pose tier high, timing tight, crowd voted for you.
  - 😐 **mid** — okay score (5–7/10).
  - 💀 **CRINGE** — bad score (0–3/10): wrong pose, timed out, crowd ignored you.
- **Round scoring** (server computes): `score = pose tier + timing bonus + crowd vote share`,
  with a small random jitter so upsets happen. Best-of-5 rounds wins the duel.
- **Live markers over both fighters**: floating round scores (+aura XP numbers),
  and a **hype meter** per player fed by judge stamps + crowd votes.
- **Round win hitmarkers**: when you out-pose your rival that round, a "clink"
  hitmarker + your hype meter surges.
- **Final MOG moment** (winner announcement — the clip-worthy payoff):
  - Loser's **head explodes**: 💀 decal burst + confetti particles, head briefly
    swaps to a skull prop, camera shake, bass-drop sting.
  - **Aura XP orbs** visibly stream from the loser to the winner (the 15% steal,
    made physical).
  - **"MOGGED 💀" stamp** slams onto the loser's screen; winner gets a golden
    banner + the judges do a reaction pose.
- All verdicts are computed on the server (`JudgeService`); clients only render.

## 5. Poses & drip

| Tier | Example poses | Aura rate | Cost (Aura) |
|---|---|---|---|
| Common | T-pose, wave, ✌️ lean | 1x | free |
| Rare | 🗿 stance, kata power-up | 2x | 500 |
| Epic | model walk, flip-flex | 3.5x | 2,000 |
| Mythic "SIGMA" | final-form charge, gravity-defying lean | 6x | 10,000 |

- Drip (chains, shades, capes with glow trails) multiplies aura rate and is
  bought with a mix of Aura and Robux.
- Poses are animations (`Animate`-replacement custom keyframes in v0.1 we use
  placeholder anims — see TODOs in code).
- v0.1 ships **procedural poses**: PoseAnimator v2 writes each pose as an
  absolute Motor6D C0 offset from the joint's rest pivot (shoulders, elbows,
  neck, root) and tweens to it, so every client sees the stance. Real
  Animation assets later replace the tables without touching call sites.

## 6. Map (floor796 energy, original art)

One dense plaza, everything walkable in ~20 s:

- **Fountain spawn** (center) — everyone sees everyone.
- **Graffiti walls** — original meme-style decals (no copyrighted characters).
- **Skate ramp**, **food truck**, **secret rooftop** (VIP gamepass area).
- **Duel arena** with the 3-judge panel + crowd stands — slightly raised, so
  duels are visible (and clip-worthy) from the whole plaza.
- Chunky low-poly props, bright flat colors, constantly milling NPC crowd.

**IP caution**: original meme-style faces/props only; Roblox-licensed audio
from the Creator Store only. No copyrighted characters, no copyrighted music.

## 7. Scoreboards

- Global **All-time top aura** + **Weekly top aura** (OrderedDataStore).
- **Top moggers** (duel wins) board at the arena.
- Player-list `leaderstats` shows Aura + Wins for at-a-glance flexing.

## 8. 🧪 Pilot scope (v0.1) — what the playtest build contains

IN:
- Plaza blockout (simple colored parts, no fancy art yet).
- Aura farming with 3 placeholder poses + NPC crowd (attention decay).
- Pose shop (Aura currency) with the tier table above.
- Duels with the full Judge System: stamps, hype meters, head explosion, orbs.
- Aura persistence (DataStore) + all-time leaderboard.
- Mobile action buttons (pose wheel + duel button).

OUT (post-pilot):
- Robux monetization (passes/products exist as stubs, not live products yet).
- Roblox Moments clip prompts (service stubbed, wired in M5).
- Crew wars (v2), trading, seasonal passes, multiple maps.

## 9. 🧪 Playtest protocol (how the first 10 people test it)

1. **Session**: 30–45 min, one server, 6–10 players, 1 moderator (you).
2. **Onboarding check**: can a fresh player figure out posing in < 60 s with
   zero explanation? (If not, we fix the HUD before anything else.)
3. **Scripted beats**:
   - Minute 0–5: free farm. Watch: does anyone pose spontaneously?
   - Minute 5: moderator announces "first MOG battle, arena, now" → first duel.
   - Minute 10: everyone checks the leaderboard.
   - Minute 15: shop opens — does anyone grind toward a paid pose?
4. **Survey after (5 questions max)**:
   1. What moment made you laugh/scream? (the clip moment)
   2. Was the duel verdict fair? (judge system tuning)
   3. What pose did you buy and why?
   4. Would you clip & share the MOG moment? where?
   5. Rate "I want to play again tomorrow" 1–10.
5. **Metrics to read from the dashboard after**: avg session time, % players
   who dueled, % who bought a pose with aura, peak CCU.
6. **Success bar for pilot**: ≥ 60% of testers dueled at least once, ≥ 40%
   bought a pose, ≥ 7/10 "play again", and at least one tester shared a clip.

## 10. Milestones

- **M1 (this pilot)**: playable vertical slice — everything in §8.
- **M2**: juice pass — real animations, VFX, audio, meme decals.
- **M3**: monetization live (passes + products real IDs), clip prompts.
- **M4**: soft-launch polish — onboarding, thumbnails, icons, weekly boards.
- **M5 (v2)**: crew wars, more maps, seasonal events.

## 11. Tech notes

- Rojo project in `aura-farm/` (`default.project.json`), sync with Rojo into a
  Studio place created from the official **Baseplate** template.
- Server-authoritative aura + judge scoring (`src/server`), clients only render
  (`src/client`), shared config in `src/shared`.
- DataStore persistence with session locking in `DataService`; the pilot build
  falls back gracefully in Studio (API access off) so testing still works.
- Remotes live under `ReplicatedStorage/Remotes` (see `src/shared/Remotes.lua`).
