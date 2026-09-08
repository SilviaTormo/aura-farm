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

local TweenService = game:GetService("TweenService")

local PoseAnimator = {}

-- poseId -> array of { motor, rx, ry, rz } (radians), composed from each
-- joint's rest pivot.
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

-- Character -> array of { motor, rest, goal }
local applied: { [Model]: { { motor: Motor6D, rest: CFrame, goal: CFrame } } } = {}
-- True rest C0 per joint, captured the first time we touch it. Posing always
-- starts FROM here, so switching poses mid-tween can never accumulate drift.
local restCache: { [Motor6D]: CFrame } = {}

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function PoseAnimator.applyPose(character: Model, poseId: string)
	PoseAnimator.stopPose(character)
	local table_ = POSE_TABLES[poseId]
	if not table_ then
		return
	end
	local record = {}
	for _, entry in table_ do
		-- R15 nests Motor6Ds inside the limbs; recurse.
		local motor = character:FindFirstChild(entry.motor, true)
		if motor and motor:IsA("Motor6D") then
			if not restCache[motor] then
				restCache[motor] = motor.C0
			end
			local rest = restCache[motor]
			local goal = rest * CFrame.Angles(entry.rx, entry.ry, entry.rz)
			TweenService:Create(motor, TWEEN_INFO, { C0 = goal }):Play()
			table.insert(record, { motor = motor, rest = rest, goal = goal })
		end
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
