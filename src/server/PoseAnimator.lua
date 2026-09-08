--!strict
-- PoseAnimator (server): applies procedural Motor6D poses to a character so
-- EVERY client sees the pose (the pilot's client-only freeze only showed it
-- locally). Restores original C0s when the pose stops. Real Animation assets
-- can later replace the procedural tables without changing call sites.
--
-- v2: poses are written as an ABSOLUTE C0 offset from the joint's rest pivot
-- (motor.C0 = restC0 * CFrame.Angles(...)), not multiplied onto the current
-- C0. The old relative version double-applied on re-pose and its Z angles
-- were sign-flipped, so both arms rotated INTO the torso: poses were
-- invisible (limbs clipping through the body). Angles now match real arm
-- rotation about the shoulder pivot: negative Z raises the RIGHT arm out to
-- its side, positive Z raises the LEFT arm.
--
-- v3: RIG-AWARE. The tables speak R15 (RightShoulder/LeftShoulder/Root/…).
-- R6 rigs name those motors differently ("Right Shoulder" with a space,
-- "RootJoint") and have NO elbows; worse, R6 shoulder C0s carry a built-in
-- 90-degree yaw, so the same (rx, rz) would swing arms forward/back instead
-- of out to the sides. Each entry now resolves per rig, with derived R6
-- angle transforms. A pose that matches ZERO joints warns instead of
-- failing silently (that silence shipped once and read as "the player
-- doesn't do the pose").

local TweenService = game:GetService("TweenService")

local PoseAnimator = {}

-- poseId -> array of { motor, rx, ry, rz } (radians), composed from each
-- joint's rest pivot. Angles are in R15 joint space.
local POSE_TABLES: { [string]: { { motor: string, rx: number, ry: number, rz: number, ry2: number? } } } = {
	tpose = {
		-- Straight out to the sides, slightly back so arms don't z-fight.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-85) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(85), ry2 = math.rad(95) },
	},
	wave = {
		-- Right arm up overhead, wiggling (the signature pose).
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-165) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(10) },
		{ motor = "Neck", rx = math.rad(-8), ry = 0, rz = 0 },
	},
	moai = {
		-- Arms crossed in front, stone face: shoulders forward + across, head down.
		{ motor = "RightShoulder", rx = math.rad(-70), ry = 0, rz = math.rad(-20) },
		{ motor = "LeftShoulder", rx = math.rad(-70), ry = 0, rz = math.rad(20) },
		{ motor = "RightElbow", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-12), ry = 0, rz = 0 },
	},
	kata = {
		-- Power-up crouch: arms pulled down-back, torso leaning forward.
		{ motor = "RightShoulder", rx = math.rad(15), ry = 0, rz = math.rad(-25) },
		{ motor = "LeftShoulder", rx = math.rad(15), ry = 0, rz = math.rad(25) },
		{ motor = "RightElbow", rx = math.rad(-110), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-110), ry = 0, rz = 0 },
		{ motor = "Root", rx = math.rad(15), ry = 0, rz = 0 },
	},
	modelwalk = {
		-- Runway: chest out, one arm swinging high, chin up.
		{ motor = "RightShoulder", rx = math.rad(-40), ry = 0, rz = math.rad(-12) },
		{ motor = "LeftShoulder", rx = math.rad(15), ry = 0, rz = math.rad(15) },
		{ motor = "RightElbow", rx = math.rad(-25), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(6), ry = 0, rz = 0 },
	},
	sigma = {
		-- Final form: both arms straight up (V), head tilted back.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-175) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(175) },
		{ motor = "Neck", rx = math.rad(12), ry = 0, rz = 0 },
	},
	zombie = {
		-- Both arms straight out forward, head drooping. The 2008 classic.
		{ motor = "RightShoulder", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = math.rad(-90), ry = 0, rz = 0 },
		{ motor = "RightElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-15), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-10), ry = 0, rz = 0 },
	},
	salute = {
		-- Right hand snaps to the brow; left arm stays disciplined at the side.
		{ motor = "RightShoulder", rx = math.rad(-75), ry = math.rad(20), rz = math.rad(-95) },
		{ motor = "RightElbow", rx = math.rad(-125), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(5) },
		{ motor = "Neck", rx = math.rad(-4), ry = 0, rz = 0 },
	},
	dab = {
		-- Head into the bent right elbow, left arm flung out straight.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-160) },
		{ motor = "RightElbow", rx = math.rad(-115), ry = 0, rz = 0 },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(95) },
		{ motor = "LeftElbow", rx = math.rad(-105), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(15), ry = math.rad(-20), rz = 0 },
	},
	flex = {
		-- Double biceps: arms out to the sides, forearms cranked up.
		{ motor = "RightShoulder", rx = 0, ry = 0, rz = math.rad(-80) },
		{ motor = "LeftShoulder", rx = 0, ry = 0, rz = math.rad(80) },
		{ motor = "RightElbow", rx = math.rad(-95), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-95), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(-6), ry = 0, rz = 0 },
	},
	sigmalean = {
		-- Gravity-defying backwards lean, arms relaxed, chin up.
		{ motor = "RightShoulder", rx = math.rad(-15), ry = 0, rz = math.rad(-30) },
		{ motor = "LeftShoulder", rx = math.rad(-15), ry = 0, rz = math.rad(30) },
		{ motor = "RightElbow", rx = math.rad(-20), ry = 0, rz = 0 },
		{ motor = "LeftElbow", rx = math.rad(-20), ry = 0, rz = 0 },
		{ motor = "Root", rx = math.rad(-22), ry = 0, rz = 0 },
		{ motor = "Neck", rx = math.rad(18), ry = 0, rz = 0 },
	},
}

-- ── R6 support ──────────────────────────────────────────────────
-- Derived mapping from R15 joint space. R6 shoulder pivots yaw the local
-- frame (right +90deg, left -90deg), so:
--   right shoulder: R6(rx, ry, rz) = R15(-rz, ry, rx)
--   left shoulder:  R6(rx, ry, rz) = R15(rz, ry, -rx)
-- Neck / RootJoint have no such yaw: angles pass through unchanged.
local R6_ALIAS: { [string]: { motor: string, side: string? } } = {
	RightShoulder = { motor = "Right Shoulder", side = "right" },
	LeftShoulder = { motor = "Left Shoulder", side = "left" },
	Root = { motor = "RootJoint" },
}

-- Transforms one POSE_TABLES entry into R6 joint space (radians).
local function toR6(entry): (string, number, number, number)
	local alias = R6_ALIAS[entry.motor]
	local name = alias and alias.motor or entry.motor
	if alias and alias.side == "right" then
		return name, -entry.rz, entry.ry, entry.rx
	elseif alias and alias.side == "left" then
		return name, entry.rz, entry.ry, -entry.rx
	end
	return name, entry.rx, entry.ry, entry.rz
end

-- Character -> array of { motor, rest, goal }
local applied: { [Model]: { { motor: Motor6D, rest: CFrame, goal: CFrame } } } = {}
-- True rest C0 per joint, captured the first time we touch it. Posing always
-- starts FROM here, so switching poses mid-tween can never accumulate drift.
local restCache: { [Motor6D]: CFrame } = {}
-- One visibility warning per character: zero matched joints = invisible pose.
local warnedRig: { [Model]: boolean } = {}

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function PoseAnimator.applyPose(character: Model, poseId: string)
	PoseAnimator.stopPose(character)
	local table_ = POSE_TABLES[poseId]
	if not table_ then
		return
	end
	local record = {}
	local matched = 0
	local firstTried = table_[1] and table_[1].motor or "?"
	for _, entry in table_ do
		-- Rig-aware resolution: try the R15 motor name first (R15 nests
		-- Motor6Ds inside the limbs, hence recursive search), then the R6
		-- alias with transformed angles. Elbow entries resolve to nothing
		-- on R6 by design (R6 has no elbow joints).
		local name, rx, ry, rz = entry.motor, entry.rx, entry.ry, entry.rz
		local motor = character:FindFirstChild(name, true)
		if not motor and R6_ALIAS[name] then
			name, rx, ry, rz = toR6(entry)
			motor = character:FindFirstChild(name, true)
		end
		if motor and motor:IsA("Motor6D") then
			matched += 1
			if not restCache[motor] then
				restCache[motor] = motor.C0
			end
			local rest = restCache[motor]
			local goal = rest * CFrame.Angles(rx, ry, rz)
			TweenService:Create(motor, TWEEN_INFO, { C0 = goal }):Play()
			table.insert(record, { motor = motor, rest = rest, goal = goal })
		end
	end
	-- A pose that matched ZERO joints is invisible by definition. Warn once
	-- per character instead of failing silently.
	if matched == 0 and not warnedRig[character] then
		warnedRig[character] = true
		local detail = ""
		if typeof(character) == "Instance" then -- mock characters in tests have no GetDescendants
			local motors = {}
			for _, d in character:GetDescendants() do
				if d:IsA("Motor6D") then
					table.insert(motors, d.Name)
				end
			end
			local probe = character:FindFirstChild(firstTried, true)
			detail = (" Motor6Ds present: %s%s"):format(
				#motors > 0 and table.concat(motors, ", ") or "NONE",
				probe and ("; " .. firstTried .. " is a " .. probe.ClassName .. ", not a Motor6D") or "")
		end
		warn(("[PoseAnimator] pose %q matched 0 joints on %s.%s"):format(poseId, character.Name, detail))
	end
	applied[character] = record
end

function PoseAnimator.stopPose(character: Model)
	local record = applied[character]
	if not record then
		return
	end
	applied[character] = nil
	for _, entry in record do
		if entry.motor.Parent then
			-- Back to the exact rest C0 captured at apply time (kill any
			-- mid-flight tween state).
			TweenService:Create(entry.motor, TWEEN_INFO, { C0 = entry.rest }):Play()
		end
	end
end

function PoseAnimator.bindPlayer(character: Model)
	-- Auto-restore if the character is removed (respawn etc.).
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			PoseAnimator.stopPose(character)
		end
	end)
end

return PoseAnimator
