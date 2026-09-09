--!strict
-- AuraFarmShared: shared constants for the pilot.

export type Pose = {
	id: string,
	name: string,
	tier: number, -- 1 Common .. 4 SIGMA
	rate: number, -- aura multiplier
	cooldown: number, -- seconds
	cost: number, -- aura cost (0 = free)
	description: string,
}

export type PoseWheel = { Pose }

return {
	GAME_NAME = "AURA FARM",
	VERSION = "0.6.1", -- bumped every pass; Hud shows it (stale-place detector)

	-- Aura economy
	STARTING_AURA = 0,
	DUEL_STEAL_FRACTION = 0.15, -- winner steals 15% of loser's aura
	DUEL_STEAL_CAP = 2500, -- cap on a single steal
	DUEL_NEWBIE_PROTECT = 100, -- players below this aura can't be robbed below 0
	MOGGED_DEBUFF_SECONDS = 60,

	-- Crowd / hype
	HYPE_RADIUS = 34, -- studs: NPCs inside this radius can see your pose
	ATTENTION_DECAY_SECONDS = 6, -- same pose in the same spot = crowd gets bored
	AURA_TICK_SECONDS = 1,

	-- Duel
	DUEL_ROUNDS = 5, -- best of 5
	DUEL_ROUND_SECONDS = 6,
	DUEL_CHALLENGE_COOLDOWN = 30, -- seconds between challenges issued by a player

	-- NPC rivals: duels you can fight solo (no second player needed).
	-- maxTier: strongest pose the bot may pick each round (rarer poses need aura).
	-- bounty: bonus aura paid to you when you win.
	NPC_RIVALS = {
		{ name = "NPC_Tomas", displayName = "Tomás el Faker", maxTier = 1, bounty = 100 },
		{ name = "NPC_Luna", displayName = "Luna Hype", maxTier = 3, bounty = 400 },
		{ name = "NPC_Giga", displayName = "GIGACHAD 🗿", maxTier = 4, bounty = 1200 },
	},
	NPC_DUEL_RESULT_SECONDS = 6, -- showdown pause before cleanup/teleport back

	-- Judge timing bonus: locking a pose very close to the round end scores extra.
	DUEL_TIMING_WINDOW = 1.5, -- seconds before round end that count as "on the beat"
	TIMING_BONUS_POINTS = 1.5, -- max bonus points for perfect timing

	-- Monetization (M3): replace the 0s with real IDs from the Creator Dashboard.
	-- With id = 0 the purchase prompt is skipped and the item shows as "coming soon".
	GAMEPASSES = {
		DoubleAura = 0,
		VipPlaza = 0,
		SigmaPosePack = 0,
		GoldenDripBundle = 0,
	},
	DEV_PRODUCTS = {
		MogShield = 0,
		CooldownRefill = 0,
		PartyMode = 0,
	},
	PASS_AURA_MULTIPLIER = 2, -- DoubleAura gamepass
	DRIP_AURA_MULTIPLIER = 1.5, -- GoldenDripBundle
	MOG_SHIELD_SECONDS = 3600,
	PARTY_MODE_SECONDS = 600,
	PASS_INFO = {
		{ key = "DoubleAura", name = "2x Aura ⚡", description = "Double aura from every pose." },
		{ key = "VipPlaza", name = "VIP Plaza 👑", description = "Access the rooftop VIP spot." },
		{ key = "SigmaPosePack", name = "Sigma Pose Pack 🗿", description = "Unlock the SIGMA pose instantly." },
		{ key = "GoldenDripBundle", name = "Golden Drip ✨", description = "Golden chain: +50% aura rate." },
	},

	-- Judge stamps
	STAMP_FIRE = "FIRE", -- 10/10
	STAMP_MID = "MID",
	STAMP_CRINGE = "CRINGE",

	POSES = {
		{
			id = "tpose",
			name = "T-Pose",
			tier = 1,
			rate = 1,
			cooldown = 0,
			cost = 0,
			description = "The classic. Default dominance.",
		} :: Pose,
		{
			id = "wave",
			name = "Wave ✌️",
			tier = 1,
			rate = 1,
			cooldown = 1,
			cost = 0,
			description = "Friendly. Suspiciously friendly.",
		} :: Pose,
		{
			id = "zombie",
			name = "Zombie 🧟",
			tier = 1,
			rate = 1,
			cooldown = 0,
			cost = 0,
			description = "Classic 2008 arms-out walk. Braaains.",
		} :: Pose,
		{
			id = "moai",
			name = "🗿 Moai Stance",
			tier = 2,
			rate = 2,
			cooldown = 2,
			cost = 500,
			description = "Absolute sigma silence.",
		} :: Pose,
		{
			id = "salute",
			name = "Salute 🫡",
			tier = 2,
			rate = 2,
			cooldown = 2,
			cost = 750,
			description = "O7. Respect the grind.",
		} :: Pose,
		{
			id = "kata",
			name = "Kata Power-Up",
			tier = 3,
			rate = 3.5,
			cooldown = 4,
			cost = 2000,
			description = "Charging your final form.",
		} :: Pose,
		{
			id = "modelwalk",
			name = "Model Walk",
			tier = 3,
			rate = 3.5,
			cooldown = 4,
			cost = 2000,
			description = "Runway energy.",
		} :: Pose,
		{
			id = "dab",
			name = "The Dab 🕺",
			tier = 3,
			rate = 3.5,
			cooldown = 4,
			cost = 2500,
			description = "Insert victory music here.",
		} :: Pose,
		{
			id = "flex",
			name = "Double Biceps 💪",
			tier = 3,
			rate = 3.5,
			cooldown = 4,
			cost = 2500,
			description = "Never skipped the gym. Once.",
		} :: Pose,
		{
			id = "sigma",
			name = "SIGMA Final Form",
			tier = 4,
			rate = 6,
			cooldown = 8,
			cost = 10000,
			description = "The aura speaks for itself.",
		} :: Pose,
		{
			id = "sigmalean",
			name = "SIGMA Lean 🕴️",
			tier = 4,
			rate = 6,
			cooldown = 8,
			cost = 15000,
			description = "Defies gravity. And haters.",
		} :: Pose,
	} :: PoseWheel,

	-- Placeholder animation ids (Studio-owned placeholder; replace in M2).
	-- 0 means "no animation, freeze in current pose".
	POSE_ANIMATIONS = {
		tpose = "0",
		wave = "0",
		zombie = "0",
		moai = "0",
		salute = "0",
		kata = "0",
		modelwalk = "0",
		dab = "0",
		flex = "0",
		sigma = "0",
		sigmalean = "0",
	},
}

-- Pose angle tables live in PoseTables (shared) — poses are procedural
-- joint rotations, rendered client-side (see DESIGN.md §5: real animations
-- replace these in M2).
