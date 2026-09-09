--!strict
-- PoseTables (shared): the procedural pose definitions, in R15 joint space,
-- plus the per-rig joint resolver. The SERVER validates pose ids against
-- Config; the CLIENT renderer (PoseRenderer.client) reads the angle entries
-- here and writes joint Transforms every frame.
--
-- Why client-side: since Roblox's 2026 Avatar Joint Upgrade, avatar rigs use
-- AnimationConstraint instead of Motor6D. AnimationConstraint.Transform does
-- NOT replicate from the server and C0 is read-only — a server-side poser is
-- invisible to everyone. So the server keeps authority (which player holds
-- which pose, aura, validation) and broadcasts PoseStarted/PoseStopped; every
-- client renders those states locally. This is Roblox's documented migration
-- pattern for procedural posing.

export type PoseEntry = {
	motor: string, -- canonical R15 joint name
	rx: number,
	ry: number,
	rz: number,
}

export type PoseTable = { PoseEntry }

local PoseTables = {}

-- poseId -> array of { motor, rx, ry, rz } (radians), rotations from each
-- joint's rest orientation. Angles are in R15 joint space.
PoseTables.TABLES = {
	tpose = {
		-- Straight out to the sides, slightly back so arms don't z-fight.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-85) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(85) },
	} :: PoseTable,
	wave = {
		-- Right arm up overhead, wiggling (the signature pose).
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-165) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(10) },
		{ motor = "Neck", rx = math.rad(-8), ry = 0, rz = 0 },
	} :: PoseTable,
	moai = {
		-- Arms crossed in front, stone face: shoulders forward + across, head down.
		{ motor = "RightShoulder", rx = math.rad(-70), ry = 0, rz = math.rad(-20) },
		{ motor = "LeftShoulder", rx = math.rad(-70), ry = 0, rz = math.rad(20) },
		{ motor = "RightElbow", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-12), ry = 0, rz = 0 },
	} :: PoseTable,
	kata = {
		-- Power-up crouch: arms pulled down-back, torso leaning forward.
		{ motor = "RightShoulder", rx = math.rad(15), ry = 0, rz = math.rad(-25) },
		{ motor = "LeftShoulder", rx = math.rad(15), ry = 0, rz = math.rad(25) },
		{ motor = "RightElbow", rx = math.rad(-110), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-110), ry = 0, rz = 0 },
		{ motor = "Root", rx = math.rad(15), ry = 0, rz = 0 },
	} :: PoseTable,
	modelwalk = {
		-- Runway: chest out, one arm swinging high, chin up.
		{ motor = "RightShoulder", rx = math.rad(-40), ry = 0, rz = math.rad(-12) },
		{ motor = "LeftShoulder", rx = math.rad(15), ry = 0, rz = math.rad(15) },
		{ motor = "RightElbow", rx = math.rad(-25), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(6), ry = 0, rz = 0 },
	} :: PoseTable,
	sigma = {
		-- Final form: both arms straight up (V), head tilted back.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-175) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(175) },
		{ motor = "Neck", rx = math.rad(12), ry = 0, rz = 0 },
	} :: PoseTable,
	zombie = {
		-- Both arms straight out forward, head drooping. The 2008 classic.
		{ motor = "RightShoulder", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "RightElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-10), ry = 0, rz = 0 },
	} :: PoseTable,
	salute = {
		-- Right hand snaps to the brow; left arm stays disciplined at the side.
		{ motor = "RightShoulder", rx = math.rad(-75), ry = math.rad(20), rz = math.rad(-95) },
		{ motor = "RightElbow", rx = math.rad(-125), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(5) },
		{ motor = "Neck", rx = math.rad(-4), ry = 0, rz = 0 },
	} :: PoseTable,
	dab = {
		-- Head into the bent right elbow, left arm flung out straight.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-160) },
		{ motor = "RightElbow", rx = math.rad(-115), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(95) },
		{ motor = "LeftElbow", rx = math.rad(-105), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(15), ry = math.rad(-20), rz = 0 },
	} :: PoseTable,
	flex = {
		-- Double biceps: arms out to the sides, forearms cranked up.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-80) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(80) },
		{ motor = "RightElbow", rx = math.rad(-95), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-95), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-6), ry = 0, rz = 0 },
	} :: PoseTable,
	sigmalean = {
		-- Gravity-defying backwards lean, arms relaxed, chin up.
		{ motor = "RightShoulder", rx = math.rad(-15), ry = 0, rz = math.rad(-30) },
		{ motor = "LeftShoulder", rx = math.rad(-15), ry = 0, rz = math.rad(30) },
		{ motor = "RightElbow", rx = math.rad(-20), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-20), ry = 0, rz = 0 },
		{ motor = "Root", rx = math.rad(-22), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(18), ry = 0, rz = 0 },
	} :: PoseTable,
	-- ── Originals with render effects (PoseTables.FX) ──
	phantom = {
		-- Drifting spirit: arms half-raised angling inward, head bowed.
		{ motor = "RightShoulder", rx = math.rad(-30), ry = 0, rz = math.rad(-35) },
		{ motor = "LeftShoulder", rx = math.rad(-30), ry = 0, rz = math.rad(35) },
		{ motor = "RightElbow", rx = math.rad(-45), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-45), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-18), ry = 0, rz = 0 },
	} :: PoseTable,
	ascension = {
		-- Levitating: arms spread wide and lifted, chest open, face to the sky.
		{ motor = "RightShoulder", rx = math.rad(-20), ry = 0, rz = math.rad(-110) },
		{ motor = "LeftShoulder", rx = math.rad(-20), ry = 0, rz = math.rad(110) },
		{ motor = "RightElbow", rx = math.rad(-8), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-8), ry = 0, rz = 0 },
		{ motor = "Root", rx = math.rad(-6), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(22), ry = 0, rz = 0 },
	} :: PoseTable,
	mogpose = {
		-- THE MOG, wearable: arms crossed high over the chest, chin down,
		-- judging everyone. The duel-ending moment, held on demand.
		{ motor = "RightShoulder", rx = math.rad(-80), ry = math.rad(25), rz = math.rad(-30) },
		{ motor = "LeftShoulder", rx = math.rad(-80), ry = math.rad(-25), rz = math.rad(30) },
		{ motor = "RightElbow", rx = math.rad(-115), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-115), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-15), ry = 0, rz = 0 },
	} :: PoseTable,
}

-- ── Per-pose render effects ─────────────────────────────────────
-- Driven by the client renderer. A held pose gets a colored point light +
-- rising aura orbs; a one-shot burst marks the lock (the signature moment).
export type FxSpec = {
	auraColor: Color3,
	lightBrightness: number?,
	lightRange: number?,
	orbRate: number?, -- continuous aura orbs per second while held
	burstCount: number?, -- one-shot particles when the pose locks
	burstSpeed: NumberRange?,
}

local FX: { [string]: FxSpec } = {
	phantom = {
		auraColor = Color3.fromRGB(170, 120, 255),
		lightBrightness = 0.6,
		lightRange = 7,
		orbRate = 4,
	},
	ascension = {
		auraColor = Color3.fromRGB(255, 245, 200),
		lightBrightness = 1.4,
		lightRange = 12,
		orbRate = 10,
		burstCount = 40,
		burstSpeed = NumberRange.new(4, 8),
	},
	mogpose = {
		auraColor = Color3.fromRGB(255, 120, 60),
		lightBrightness = 2.2,
		lightRange = 16,
		orbRate = 14,
		burstCount = 70,
		burstSpeed = NumberRange.new(10, 18),
	},
}
PoseTables.FX = FX

function PoseTables.getFx(poseId: string): FxSpec?
	return FX[poseId]
end

function PoseTables.get(poseId: string): PoseTable?
	return PoseTables.TABLES[poseId]
end

-- ── Rig resolution ──────────────────────────────────────────────
-- Joint classes/names across rig generations (all resolve on a real avatar):
--   Avatar Joint Upgrade (2026): AnimationConstraint, R15 names.
--   Legacy Motor6D R15: Motor6D, R15 names, nested inside limbs.
--   Legacy Motor6D R6: Motor6D, "Right Shoulder" (space), "RootJoint", no elbows.
-- R6 shoulder pivots yaw the local frame (right +90deg, left -90deg), so the
-- same angles would swing arms forward/back instead of out to the sides:
--   right shoulder: R6(rx, ry, rz) = R15(-rz, ry, rx)
--   left shoulder:  R6(rx, ry, rz) = R15(rz, ry, -rx)
local R6_ALIAS: { [string]: { motor: string, side: string? } } = {
	RightShoulder = { motor = "Right Shoulder", side = "right" },
	LeftShoulder = { motor = "Left Shoulder", side = "left" },
	Root = { motor = "RootJoint" },
}

export type ResolvedJoint = {
	joint: Instance, -- AnimationConstraint or Motor6D
	rx: number,
	ry: number,
	rz: number,
}

local function isPosable(joint: Instance): boolean
	return joint:IsA("AnimationConstraint") or joint:IsA("Motor6D")
end

-- Finds a joint by R15 name (AnimationConstraint on current rigs, Motor6D on
-- legacy ones), then retries under the R6 alias with angles transformed into
-- R6 joint space. Elbow entries resolve to nothing on R6 (R6 has no elbow
-- joints) — expected, not an error. A non-posable instance that merely shares
-- the joint's name is skipped.
function PoseTables.resolveJoint(character: Instance, entry: PoseEntry): ResolvedJoint?
	local joint = character:FindFirstChild(entry.motor, true)
	if joint and isPosable(joint) then
		return { joint = joint, rx = entry.rx, ry = entry.ry, rz = entry.rz }
	end
	local alias = R6_ALIAS[entry.motor]
	if not alias then
		return nil
	end
	local r6 = character:FindFirstChild(alias.motor, true)
	if not r6 or not isPosable(r6) then
		return nil
	end
	if alias.side == "right" then
		return { joint = r6, rx = -entry.rz, ry = entry.ry, rz = entry.rx }
	elseif alias.side == "left" then
		return { joint = r6, rx = entry.rz, ry = entry.ry, rz = -entry.rx }
	end
	return { joint = r6, rx = entry.rx, ry = entry.ry, rz = entry.rz }
end

return PoseTables
