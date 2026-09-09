--!strict
-- PoseRenderer.client.lua: renders every character's pose by writing joint
-- Transforms each frame, on THIS client. The server owns pose state
-- (PoseStarted/PoseStopped broadcasts + aura + validation); joint writes
-- cannot replicate, so each client draws the poses it sees, locally.
--
-- Why Transform and not C0: since the 2026 Avatar Joint Upgrade, avatars are
-- rigged with AnimationConstraint, not Motor6D. AnimationConstraint.C0 is a
-- read-only alias; Transform is the writable member that also exists on
-- Motor6D (Roblox's documented procedural path: write Transform every frame
-- in PreSimulation). One renderer covers both rig generations.
--
-- Late/edge cases handled: character spawned before PoseStarted arrived,
-- respawn while posing, player left mid-pose, pose fired for a non-player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("AuraFarmShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local PoseTables = require(Shared:WaitForChild("PoseTables"))

-- character -> { poseId, joints, alpha, retries, gaveUp }
local active: { [Model]: { poseId: string, joints: { PoseTables.ResolvedJoint }, alpha: number, retries: number, gaveUp: boolean } } = {}
-- one zero-joint warning per character (not per PoseStarted)
local warned: { [Model]: boolean } = {}

local EASE_PER_FRAME = 0.13 -- reaches full pose in ~0.25s at 60fps (old tween feel)

-- type() reports "Instance" on real engine objects, "table" in the test
-- harness mocks; both pass the IsA check below, garbage fails it.
local function isInstanceArg(x): boolean
	local t = type(x)
	if t ~= "Instance" and t ~= "table" then
		return false
	end
	return x.IsA ~= nil and x:IsA("Instance")
end

local function setPose(char: Model?, poseId: string?)
	if not char then
		return
	end
	local record = active[char]
	if poseId == nil then
		-- Reset every joint this character was posed with, so the pose can't
		-- freeze mid-air when the rig's Animator isn't actively writing
		-- identity (NPC rigs, or pauses between animation evaluation).
		if record then
			for _, j in record.joints do
				if j.joint.Parent then
					j.joint.Transform = CFrame.new()
				end
			end
		end
		active[char] = nil
		return
	end
	-- Same pose already rendering with joints (or proven impossible): done.
	-- With zero joints we keep retrying — PoseStarted usually arrives the
	-- same frame the character spawns, before its joints exist.
	if record and record.poseId == poseId and (#record.joints > 0 or record.gaveUp) then
		return
	end
	if not char:IsDescendantOf(workspace) then
		return
	end
	-- Reset joints the previous pose used but the new one doesn't (pose
	-- switch with fewer entries — moai -> wave would otherwise leave the
	-- elbows frozen mid-bend).
	if record then
		local nextJoints = {}
		for _, entry in PoseTables.get(poseId) or {} do
			local again = PoseTables.resolveJoint(char, entry)
			if again then
				nextJoints[again.joint] = true
			end
		end
		for _, j in record.joints do
			if not nextJoints[j.joint] and j.joint.Parent then
				j.joint.Transform = CFrame.new()
			end
		end
	end
	local joints = {}
	for _, entry in PoseTables.get(poseId) or {} do
		local resolved = PoseTables.resolveJoint(char, entry)
		if resolved then
			table.insert(joints, resolved)
		end
	end
	if #joints == 0 then
		-- Zero matched joints is invisible by definition. Warn once per
		-- character instead of failing silently (that silence shipped once).
		if not warned[char] then
			warned[char] = true
			warn(("[PoseRenderer] pose %q matched 0 joints on %s -- unknown rig?"):format(poseId, char.Name))
		end
		active[char] = { poseId = poseId, joints = joints, alpha = 0, retries = 0, gaveUp = false }
		return
	end
	warned[char] = nil
	active[char] = { poseId = poseId, joints = joints, alpha = 0, retries = 0, gaveUp = false }
	-- One honest log line per rendered pose: name + joint count. This is the
	-- evidence that the client renderer actually engaged on a real rig.
	print(("[PoseRenderer] pose %q rendering on %s with %d joints"):format(poseId, char.Name, #joints))
end

local function onPoseStarted(who: Player, poseId: string)
	setPose(who.Character, poseId)
	-- A respawn while posing re-enters through the reconciler once the new
	-- character exists (the server clears the attribute on respawn, which
	-- the reconciler reads as pose-off).
end

Remotes.PoseStarted.OnClientEvent:Connect(function(who, poseId)
	if not isInstanceArg(who) or not who:IsA("Player") or type(poseId) ~= "string" then
		return
	end
	onPoseStarted(who, poseId)
end)

Remotes.PoseStopped.OnClientEvent:Connect(function(who)
	if not isInstanceArg(who) or not who:IsA("Player") then
		return
	end
	setPose(who.Character, nil)
end)

Players.PlayerRemoving:Connect(function(who)
	setPose(who.Character, nil)
end)

-- AuraService owns the pose lifecycle on respawn (it clears the replicated
-- character attribute server-side); the reconciler below is the single
-- client-side authority that follows it.

-- Reconciler (2s): heals late joiners, missed broadcasts, and respawns by
-- following the replicated character attribute AuraService writes. When a
-- character is gone (respawned), its entry simply stops being written and
-- the next reconcile drops it.
task.spawn(function()
	while true do
		task.wait(2)
		for _, who in Players:GetPlayers() do
			local char = who.Character
			if char then
				setPose(char, char:GetAttribute("AuraPoseId"))
			end
		end
		-- Drop entries whose character no longer exists.
		for char in active do
			if not char:IsDescendantOf(workspace) then
				active[char] = nil
			end
		end
	end
end)

-- ── Per-frame joint write ───────────────────────────────────────
-- A joint lookup that found nothing gets 60 frame-retries (~1s: the spawn
-- window in which joints appear). After that the rig is genuinely unknown —
-- warn once and stop paying the search cost every frame.
local MAX_JOINT_RETRIES = 60

RunService.PreSimulation:Connect(function()
	for char, record in active do
		if not char:IsDescendantOf(workspace) then
			active[char] = nil
			continue
		end
		if #record.joints == 0 then
			if record.gaveUp then
				continue
			end
			record.retries += 1
			if record.retries > MAX_JOINT_RETRIES then
				record.gaveUp = true
				warn(("[PoseRenderer] pose %q matched 0 joints on %s -- unknown rig?"):format(record.poseId, char.Name))
				continue
			end
			for _, entry in PoseTables.get(record.poseId) or {} do
				local resolved = PoseTables.resolveJoint(char, entry)
				if resolved then
					table.insert(record.joints, resolved)
				end
			end
			if #record.joints > 0 then
				warned[char] = nil
			end
			continue
		end
		if record.alpha < 1 then
			record.alpha = math.min(1, record.alpha + EASE_PER_FRAME)
		end
		local a = record.alpha
		for _, j in record.joints do
			local joint = j.joint
			if not joint.Parent then
				continue
			end
			-- Ease each axis from 0 to its full angle (identity -> pose).
			joint.Transform = CFrame.Angles(j.rx * a, j.ry * a, j.rz * a)
		end
	end
end)
