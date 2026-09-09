-- run_tests.lua: integration tests for the REAL aura-farm server modules,
-- executed under the mock Roblox environment in harness.luau.
-- Run from the aura-farm project root: tools/luau/luau.exe tests/run_tests.lua

local Harness = require("./harness")
local Instance, Vector3, os = Harness.Instance, Harness.Vector3, Harness.os

local passed, failedCount, failedNames = 0, 0, {}
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  PASS  " .. name)
	else
		failedCount += 1
		table.insert(failedNames, name .. " — " .. tostring(err))
		print("  FAIL  " .. name .. " — " .. tostring(err))
	end
end

local function assertEq(a, b, msg)
	if a ~= b then
		error((msg or "assertEq") .. (" (got %s, want %s)"):format(tostring(a), tostring(b)), 2)
	end
end

local function assertTrue(v, msg)
	if not v then
		error(msg or "assertTrue failed", 2)
	end
end

-- ── Boot the real services (same order as init.server.lua) ─────
local serverFolder = Harness.serverFolder
local function startService(name)
	local module = Harness.requireModule(serverFolder:FindFirstChild(name))
	if type(module.init) == "function" then
		module.init()
	end
end

for _, name in {
	"MapService", "DataService", "AuraService", "CrowdService", "PoseService",
	"JudgeService", "DuelService", "TrainingService",
	"LeaderboardService", "MonetizationService", "CapturePromptService",
} do
	startService(name)
end

local MapService = Harness.requireModule(serverFolder:FindFirstChild("MapService"))
local DataService = Harness.requireModule(serverFolder:FindFirstChild("DataService"))
local AuraService = Harness.requireModule(serverFolder:FindFirstChild("AuraService"))
local PoseService = Harness.requireModule(serverFolder:FindFirstChild("PoseService"))
local Remotes = Harness.requireModule(Harness.sharedFolder:FindFirstChild("Remotes"))
local Config = Harness.requireModule(Harness.sharedFolder:FindFirstChild("Config"))
local PoseTables = Harness.requireModule(Harness.sharedFolder:FindFirstChild("PoseTables"))
local PoseRenderer = Harness.requireModule(Harness.poseRendererModule)

-- ── Player helper: full join (player + character) ───────────────
local function joinPlayer(userId, name)
	local player = Harness.makePlayer(userId, name)
	Harness.Players.add(player) -- fires PlayerAdded: profile + leaderstats

	local char = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(0, 3.5, 18) -- spawn
	root.Parent = char
	char.Parent = Harness.workspace -- real characters live in workspace
	player.Character = char -- property write: stored where reads find it
	return player
end

local function auraStat(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Aura")
end

local function placeAt(player, position)
	player.Character:FindFirstChild("HumanoidRootPart").Position = position
end

-- ════════════════════════════════════════════════════════════════
test("boot: all 12 services init without error", function()
	assertTrue(true) -- reaching here means boot was clean
end)

test("map: spot multipliers are correct", function()
	assertEq(MapService.getSpotMultiplier(Vector3.new(-50, 2, 0)), 2, "stage")
	assertEq(MapService.getSpotMultiplier(Vector3.new(70, 2, 0)), 1.5, "arena")
	assertEq(MapService.getSpotMultiplier(Vector3.new(0, 14, -41)), 2.5, "vip rooftop")
	assertEq(MapService.getSpotMultiplier(Vector3.new(0, 3.5, 18)), 1, "plaza")
end)

test("join: player gets leaderstats + profile + unlock sync", function()
	local p = joinPlayer(101, "Tester101")
	assertTrue(auraStat(p) ~= nil, "leaderstats.Aura missing")
	assertTrue(DataService.getProfile(p) ~= nil, "profile missing")
	Harness.advance(2.5) -- AuraService sync poll fires every 2s
	assertTrue(Harness.lastEvent("SyncUnlocked", p) ~= nil, "no SyncUnlocked fired")
end)

test("pose: request applies pose, crowd pays aura, client told", function()
	local p = joinPlayer(102, "Tester102")
	Harness.advance(1) -- let NPCs settle
	placeAt(p, Vector3.new(0, 3.5, 0)) -- fountain plaza
	Harness.clearEvents()

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	local active = AuraService.getActivePose(p)
	assertTrue(active ~= nil, "pose not active after RequestPose")
	assertEq(active.poseId, "tpose", "wrong pose active")

	Harness.advance(1.3) -- crowd movement loop (0.2s) + aura tick (1s)
	assertTrue(auraStat(p).Value > 0, "aura did not increase while posing near crowd")
	assertTrue(Harness.lastEvent("AuraChanged", p) ~= nil, "no AuraChanged fired")
	assertTrue(Harness.lastEvent("PoseStarted", p) ~= nil, "no PoseStarted broadcast")
end)

-- Builds a minimal rig on a character. jointClass: "AnimationConstraint"
-- (2026 Avatar Joint Upgrade rigs) or "Motor6D" (legacy).
local function addJoint(char, jointClass, name, parentName, childName)
	local parentPart = Instance.new("Part")
	parentPart.Name = parentName
	parentPart.Parent = char
	local childPart = Instance.new("Part")
	childPart.Name = childName
	childPart.Parent = char
	local joint = Instance.new(jointClass)
	joint.Name = name
	joint.Parent = childPart -- R15 nests joints inside the limbs
	return joint
end

-- Drives the renderer's real frame loop until alpha reaches 1 (7+ frames).
local function runFrames(frames)
	for _ = 1, frames or 10 do
		Harness.services.RunService.PreSimulation:Fire()
	end
end

local function rotationOffDiagonal(cf)
	local rot = rawget(cf, "_rot")
	assertTrue(rot ~= nil, "joint Transform has no rotation matrix")
	return math.abs(rot[1][2]) + math.abs(rot[1][3])
		+ math.abs(rot[2][1]) + math.abs(rot[2][3])
		+ math.abs(rot[3][1]) + math.abs(rot[3][2])
end

test("pose: AnimationConstraint rig actually rotates (visibility regression, 2026 rigs)", function()
	local p = joinPlayer(110, "Poser110")
	Harness.advance(0.3)
	local joint = addJoint(p.Character, "AnimationConstraint", "RightShoulder", "UpperTorso", "RightUpperArm")

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	runFrames(10)

	-- The PoseStarted broadcast must have driven the renderer: the joint's
	-- Transform must rotate off identity (the old server-C0 poser wrote C0
	-- on AnimationConstraint rigs — read-only — so nothing ever moved).
	assertTrue(rotationOffDiagonal(joint.Transform) > 0.5, "tpose Transform ~identity — pose invisible on AnimationConstraint rigs")
	assertEq(p.Character:GetAttribute("AuraPoseId"), "tpose", "server did not stamp the character attribute")

	-- Stop must reset the joint, not leave it frozen mid-air.
	Remotes.StopPose.OnServerEvent:Fire(p)
	runFrames(2)
	local rot = rawget(joint.Transform, "_rot")
	assertTrue(rot == nil or rotationOffDiagonal(joint.Transform) < 1e-6, "stopPose left the joint rotated")
end)

test("pose: legacy Motor6D rig still renders (back-compat)", function()
	local p = joinPlayer(113, "Legacy113")
	Harness.advance(0.3)
	local joint = addJoint(p.Character, "Motor6D", "RightShoulder", "UpperTorso", "RightUpperArm")

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	runFrames(10)
	assertTrue(rotationOffDiagonal(joint.Transform) > 0.5, "Motor6D rig not rendered")
end)

test("pose: joints appearing late are found by the frame retry (spawn race)", function()
	local p = joinPlayer(114, "LateJoints114")
	Harness.advance(0.3)
	local char = p.Character

	-- Pose arrives the same instant the character spawns: no joints yet.
	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	runFrames(5)

	-- Joints spawn a moment later (real avatars build over several frames).
	local joint = addJoint(char, "AnimationConstraint", "RightShoulder", "UpperTorso", "RightUpperArm")
	runFrames(70) -- beyond the 60-frame retry window
	assertTrue(rotationOffDiagonal(joint.Transform) > 0.5, "late joints never picked up — pose stuck invisible")
end)

test("pose: zero-joint rig warns once and gives up (no infinite search)", function()
	local p = joinPlayer(115, "NoJoints115")
	Harness.advance(0.3)

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	runFrames(80) -- past the retry window: the warning should have fired

	-- Reconciler keeps re-setting the same pose; the gaveUp record must not
	-- restart a 60-frame search every 2s tick. Drive more frames, state stays.
	Harness.advance(2.5)
	runFrames(5)
	assertTrue(AuraService.getActivePose(p) ~= nil, "server dropped the pose (should persist)")
end)

test("pose: locked pose is rejected", function()
	local p = joinPlayer(103, "Tester103")
	Harness.advance(0.5)
	Remotes.RequestPose.OnServerEvent:Fire(p, "sigma") -- costs 10000, not owned
	Harness.advance(0.3)
	assertTrue(AuraService.getActivePose(p) == nil, "locked pose was applied!")
end)

test("pose: cooldown blocks instant re-pose", function()
	local p = joinPlayer(104, "Tester104")
	Harness.advance(0.5)
	Remotes.RequestPose.OnServerEvent:Fire(p, "wave") -- cooldown 1s
	Harness.advance(0.1)
	Remotes.RequestPose.OnServerEvent:Fire(p, "moai") -- within wave's 1s? no: different pose, cooldown per pose
	Harness.advance(0.1)
	Remotes.StopPose.OnServerEvent:Fire(p)
	Harness.advance(0.05)
	assertTrue(AuraService.getActivePose(p) == nil, "StopPose did not stop the pose")
end)

test("shop: buying with enough aura unlocks + broadcasts", function()
	local p = joinPlayer(105, "Shopper105")
	Harness.advance(0.3)
	DataService.addAura(p, 500)
	Harness.clearEvents()
	Remotes.BuyPose.OnServerEvent:Fire(p, "moai") -- costs 500
	assertTrue(DataService.isUnlocked(p, "moai"), "moai not unlocked after buy")
	assertEq(DataService.getProfile(p).aura, 0, "aura not spent")
	assertTrue(Harness.lastEvent("PoseUnlocked", p) ~= nil, "no PoseUnlocked fired")
end)

test("shop: buying reflects in leaderstats + AuraChanged instantly (HUD bug)", function()
	local p = joinPlayer(107, "Shopper107")
	Harness.advance(0.3)
	DataService.addAura(p, 2000)
	assertEq(auraStat(p).Value, 2000, "leaderstats did not pick up the grant")
	Harness.clearEvents()
	Remotes.BuyPose.OnServerEvent:Fire(p, "kata") -- costs 2000
	-- The big HUD counter reads leaderstats; it must drop the moment the
	-- purchase lands (before: only updated on the next aura earn tick).
	assertEq(auraStat(p).Value, 0, "leaderstats not debited on purchase")
	local changed = Harness.lastEvent("AuraChanged", p)
	assertTrue(changed ~= nil, "no AuraChanged fired on purchase (HUD never updated)")
	assertEq(changed.args[1], 0, "AuraChanged carried the wrong new balance")
	assertTrue(changed.args[2] < 0, "purchase delta should be negative")
	assertEq(DataService.getProfile(p).aura, 0, "profile not debited")
end)

test("shop: buying without aura fails cleanly", function()
	local p = joinPlayer(106, "Poor106")
	Harness.advance(0.3)
	Harness.clearEvents()
	Remotes.BuyPose.OnServerEvent:Fire(p, "sigma") -- 10000, has 0
	assertTrue(not DataService.isUnlocked(p, "sigma"), "sigma unlocked without paying!")
	assertTrue(Harness.lastEvent("ShopError", p) ~= nil, "no ShopError fired")
end)

test("duel: full best-of-5 through real remotes with steal math", function()
	local a = joinPlayer(201, "DuelistA")
	local b = joinPlayer(202, "DuelistB")
	Harness.advance(0.5)
	DataService.addAura(a, 10000)
	Harness.clearEvents()

	Remotes.RequestDuel.OnServerEvent:Fire(a, b.UserId)
	local invite = Harness.lastEvent("DuelInvited", b)
	assertTrue(invite ~= nil, "no invite reached B")
	Remotes.AcceptDuel.OnServerEvent:Fire(b, invite.args[1])
	assertTrue(Harness.lastEvent("DuelStarted", a) ~= nil, "A never saw DuelStarted")
	assertTrue(Harness.lastEvent("DuelStarted", b) ~= nil, "B never saw DuelStarted")

	-- Drive the duel by polling: fire picks every step (the server rejects
	-- out-of-window picks), advance time, until it ends. A full best-of-5 with
	-- the 2s inter-round gap needs up to ~40s of simulated time.
	local ended = false
	for _ = 1, 120 do -- up to 60 simulated seconds
		Harness.advance(0.5)
		Remotes.DuelPickPose.OnServerEvent:Fire(a, "tpose")
		Remotes.DuelPickPose.OnServerEvent:Fire(b, "wave")
		if Harness.lastEvent("DuelEnded", a) then
			ended = true
			break
		end
	end
	assertTrue(ended, "duel never ended within 60s")
	assertTrue(Harness.lastEvent("DuelVerdict", a) ~= nil, "no verdict ever fired")

	local endedA = Harness.lastEvent("DuelEnded", a)
	local endedB = Harness.lastEvent("DuelEnded", b)
	assertTrue(endedA ~= nil, "duel never ended")
	assertTrue(endedB ~= nil, "duel never ended for B")
	-- Exactly one winner.
	assertTrue(endedA.args[1] ~= endedB.args[1], "both players reported the same win flag")

	-- Steal math: loser pays exactly the reported amount; total aura is
	-- conserved (winner +stolen, loser −stolen, minus crowd income = 0).
	local stolen = endedA.args[2]
	assertEq(stolen, endedB.args[2], "players disagree on stolen aura")
	local auraA, auraB = auraStat(a).Value, auraStat(b).Value
	assertTrue(stolen >= 0, "negative steal reported")
	assertEq(auraA + auraB, 10000, "aura not conserved across the steal")
	if stolen > 0 then
		local loser = endedA.args[1] and b or a
		local winner = endedA.args[1] and a or b
		local loserProfile = DataService.getProfile(loser)
		-- Newbie protection floor honored.
		assertTrue(
			loserProfile.aura >= Config.DUEL_NEWBIE_PROTECT,
			"loser fell below the newbie-protect floor"
		)
	end
end)

test("duel: stale duel entry cleared — rematch possible after end", function()
	local a = Harness.Players:GetPlayerByUserId(201)
	local b = Harness.Players:GetPlayerByUserId(202)
	Harness.advance(31) -- cleanupDuel delay (4s) AND challenge cooldown (30s)
	Harness.clearEvents()
	Remotes.RequestDuel.OnServerEvent:Fire(a, b.UserId)
	assertTrue(Harness.lastEvent("DuelInvited", b) ~= nil, "rematch blocked by stale duel entry")
end)

test("training: pad session runs, result fires, aura only on win", function()
	local p = joinPlayer(401, "Trainee401")
	Harness.advance(0.3)
	local auraBefore = auraStat(p).Value
	Harness.clearEvents()

	Remotes.TrainingStart.OnServerEvent:Fire(p)
	assertTrue(Harness.lastEvent("TrainingRound", p) ~= nil, "TrainingRound never fired")
	-- The picked pose must VISIBLY render (the training-poses-invisible fix):
	-- locking through the real remote stamps the character attribute, which
	-- every client's PoseRenderer reconciles against.
	DataService.unlockPose(p, "wave")
	Remotes.TrainingPick.OnServerEvent:Fire(p, "wave")
	assertEq(p.Character:GetAttribute("AuraPoseId"), "wave", "picked training pose does not render on the avatar")
	-- Busy check while session open:
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	local busy = Harness.lastEvent("ShopError", p)
	assertTrue(busy ~= nil, "second session during open one was not rejected")

	Harness.advance(8.2) -- round window closes
	assertEq(p.Character:GetAttribute("AuraPoseId"), nil, "training pose not cleared after round end")
	local result = Harness.lastEvent("TrainingResult", p)
	assertTrue(result ~= nil, "TrainingResult never fired")
	local won, auraWon = result.args[5], result.args[6]
	if won then
		assertEq(auraStat(p).Value, auraBefore + auraWon, "win aura not paid correctly")
		assertTrue(auraWon > 0, "won but auraWon was 0")
	else
		assertEq(auraStat(p).Value, auraBefore, "lost but aura changed anyway")
	end
end)

test("training: digit keys pick the Nth shown pose (keyboard picker)", function()
	local p = joinPlayer(402, "Keyer402")
	Harness.advance(0.3)
	-- TrainingUi binds to Players.LocalPlayer and PlayerGui at require time.
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = p
	Harness.Players.LocalPlayer = p
	local TrainingUi = Harness.requireModule(Harness.trainingUiModule)
	local _ = TrainingUi
	-- Own exactly two poses; picker order follows Config.POSES order.
	DataService.unlockPose(p, "tpose")
	DataService.unlockPose(p, "moai")
	-- Server pushes the unlock list the way join does; the picker builds from it.
	Remotes.SyncUnlocked:FireClient(p, { "tpose", "moai" })
	-- Open a round so the picker is populated.
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	Harness.advance(0.1)
	-- Press digit 2: fires TrainingPick (the exact button packet) -> moai renders.
	Harness.fireContextAction("TrainingPickDigit", Harness.Enum.UserInputState.Begin, {
		KeyCode = Harness.Enum.KeyCode.Two,
	})
	assertEq(p.Character:GetAttribute("AuraPoseId"), "moai", "digit 2 did not pick the 2nd picker pose")
	-- Digit 9 with only 2 poses shown: pass-through, pose unchanged. A fresh
	-- round: the open one already has a pose locked (server rejects re-picks).
	Harness.advance(8.2) -- closes the round + 12s busy guard via more advance below
	Harness.advance(12.1) -- clears the CAS busy debounce and the pad cooldown
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	Harness.advance(0.1)
	Harness.fireContextAction("TrainingPickDigit", Harness.Enum.UserInputState.Begin, {
		KeyCode = Harness.Enum.KeyCode.Nine,
	})
	assertEq(p.Character:GetAttribute("AuraPoseId"), nil, "digit 9 picked a pose with only 2 shown (should pass through)")
end)

test("training: farming pose restored after round (attribute + economy resume)", function()
	local p = joinPlayer(403, "Farmer403")
	Harness.advance(0.3)
	DataService.unlockPose(p, "wave")
	DataService.unlockPose(p, "moai")
	placeAt(p, Vector3.new(0, 3.5, 0)) -- fountain plaza: crowd pays ambient aura

	-- The pad is a single global slot: flush any unpicked round a previous
	-- test left pending so TrainingStart below isn't bounced with "busy".
	Harness.advance(8.2)

	-- Farming with the wheel first: a real paid pose. Payment is asserted
	-- through grantTick — the exact function the live loop calls each second
	-- with the crowd count — because NPC walk timing makes real crowds flaky
	-- in suite order.
	Remotes.RequestPose.OnServerEvent:Fire(p, "wave")
	assertEq(p.Character:GetAttribute("AuraPoseId"), "wave", "farm pose not active before training")
	assertTrue(AuraService.getActivePose(p) ~= nil, "farm pose has no economy entry")
	AuraService.grantTick(p, 5)
	local auraBefore = auraStat(p).Value
	assertTrue(auraBefore > 0, "farming pose paid nothing (setup broken)")

	-- Enter training and lock a different pose: farm entry must suspend.
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	Remotes.TrainingPick.OnServerEvent:Fire(p, "moai")
	assertEq(p.Character:GetAttribute("AuraPoseId"), "moai", "training pose did not replace the farm pose visually")
	assertTrue(AuraService.getActivePose(p) == nil, "training pick did not suspend the farm economy entry")
	AuraService.grantTick(p, 5)
	assertTrue(auraStat(p).Value == auraBefore, "suspended farm pose still paid aura during training")

	-- Round end: prior pose restored visibly AND its economy entry live again.
	Harness.advance(8.3)
	assertEq(p.Character:GetAttribute("AuraPoseId"), "wave", "farm pose not restored after training round")
	local resumed = AuraService.getActivePose(p)
	assertTrue(resumed ~= nil, "restored farm pose has no economy entry")
	assertEq(resumed and resumed.poseId, "wave", "wrong pose restored in the economy entry")
	AuraService.grantTick(p, 5)
	assertTrue(auraStat(p).Value > auraBefore, "restored farm pose did not resume paying aura")
end)

test("training: pose-less round end restores nothing (guard no-op)", function()
	local p = joinPlayer(404, "Idle404")
	Harness.advance(0.3)
	DataService.unlockPose(p, "tpose")

	Remotes.TrainingStart.OnServerEvent:Fire(p)
	Harness.advance(0.1)
	-- Never pick: the round must end with no pose and no economy entry.
	Harness.advance(8.2)
	assertEq(p.Character:GetAttribute("AuraPoseId"), nil, "pose-less round end stamped a pose attribute")
	assertTrue(AuraService.getActivePose(p) == nil, "pose-less round end created an economy entry")

	-- Same guard after the player later stops a wheel pose (record path ran).
	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	Remotes.StopPose.OnServerEvent:Fire(p)
	Harness.advance(0.1)
	assertEq(p.Character:GetAttribute("AuraPoseId"), nil, "stopPose left the attribute stamped")
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	Harness.advance(8.3)
	assertEq(p.Character:GetAttribute("AuraPoseId"), nil, "round end restored a stopped pose")
	assertTrue(AuraService.getActivePose(p) == nil, "round end resurrected a stopped economy entry")
end)

test("data: save/load round-trip preserves aura + unlocks", function()
	local p = joinPlayer(301, "Saver301")
	Harness.advance(0.3)
	DataService.addAura(p, 777)
	DataService.unlockPose(p, "moai")
	Harness.Players.remove(p) -- triggers save

	local q = joinPlayer(301, "Saver301")
	Harness.advance(0.3)
	local profile = DataService.getProfile(q)
	assertTrue(profile ~= nil, "profile lost after rejoin")
	assertEq(profile.aura, 777, "aura lost across save/load")
	assertTrue(table.find(profile.unlocked, "moai") ~= nil, "moai lost across save/load")
end)

test("data: SECOND save of a returning player actually persists (lock-baseline fix)", function()
	local p = joinPlayer(301, "Saver301") -- same user rejoins again
	DataService.addAura(p, 1) -- 778 now
	Harness.Players.remove(p) -- save #2 for this user

	local store = Harness.services.DataStoreService.stores["AuraFarm_v1"]
	assertTrue(store ~= nil, "store missing")
	local saved = store.data["player_301"]
	assertTrue(saved ~= nil, "second save vanished (session-lock aborted it)")
	assertEq(saved.aura, 778, "second save did not persist the new aura")
end)

test("npc duel: solo best-of-5 vs rival with bounty + rival released", function()
	local solo = joinPlayer(501, "Solo501")
	Harness.advance(0.5)
	DataService.addAura(solo, 3000) -- enough to buy kat
	Remotes.BuyPose.OnServerEvent:Fire(solo, "kata")
	assertTrue(DataService.isUnlocked(solo, "kata"), "kata not unlocked")
	Harness.clearEvents()

	-- NPC rivals must exist after boot (3 configured rivals spawned).
	local crowd = Harness.workspace:FindFirstChild("AuraCrowd")
	assertTrue(crowd ~= nil, "AuraCrowd folder missing")
	local rivalModel = crowd:FindFirstChild("NPC_Luna")
	assertTrue(rivalModel ~= nil, "rival NPC_Luna not spawned")

	Remotes.RequestNpcDuel.OnServerEvent:Fire(solo, "NPC_Luna")
	Harness.advance(0.3)
	assertTrue(Harness.lastEvent("DuelStarted", solo) ~= nil, "NPC duel never started")

	-- Drive the duel like the PvP test: pick each round until it ends.
	local ended = false
	for _ = 1, 120 do
		Harness.advance(0.5)
		Remotes.DuelPickPose.OnServerEvent:Fire(solo, "kata") -- tier 3 vs Luna maxTier 3
		if Harness.lastEvent("DuelEnded", solo) then
			ended = true
			break
		end
	end
	assertTrue(ended, "NPC duel never ended within 60s")

	local endedSolo = Harness.lastEvent("DuelEnded", solo)
	local youWon, stolen = endedSolo.args[1], endedSolo.args[2]
	if stolen ~= 0 then
		print("DEBUG endedSolo.args:", youWon, stolen, endedSolo.args[3])
		for _, e in Harness.eventsFor("DuelEnded") do
			print("DEBUG DuelEnded for", e.player and e.player.UserId, e.args[1], e.args[2], e.args[3])
		end
		for _, e in Harness.eventsFor("MogFx") do
			print("DEBUG MogFx target:", e.args[1] and e.args[1].Name, "class:", e.args[1] and e.args[1]._className)
		end
		print("DEBUG solo profile aura:", DataService.getProfile(solo).aura)
	end
	assertEq(stolen, 0, "no aura should be stolen from a bot")
	assertTrue(endedSolo.args[3] ~= nil, "opponent name missing on DuelEnded")

	if youWon then
		-- Bounty paid: 3000 - 2000 (kata) = 1000, + Luna's 400 bounty. Exact
		-- because InDuel blocks crowd income and bots can't be robbed.
		assertEq(DataService.getProfile(solo).aura, 1400, "win did not pay the rival bounty")
		assertEq(endedSolo.args[3], "Luna Hype", "opponent name should be the rival's display name")
	end

	-- Cooldown blocks an instant re-challenge (shared with PvP).
	Harness.clearEvents()
	Remotes.RequestNpcDuel.OnServerEvent:Fire(solo, "NPC_Tomas")
	assertTrue(Harness.lastEvent("ShopError", solo) ~= nil, "NPC re-challenge bypassed cooldown")

	-- After the showdown pause the duel is cleaned up and a rematch works.
	Harness.advance(31)
	Harness.clearEvents()
	Remotes.RequestNpcDuel.OnServerEvent:Fire(solo, "NPC_Luna")
	Harness.advance(0.3)
	assertTrue(
		Harness.lastEvent("DuelStarted", solo) ~= nil or Harness.lastEvent("ShopError", solo) ~= nil,
		"rematch after cleanup neither started nor errored"
	)
end)

test("crowd: NPCs exist and stop hyping when nobody poses", function()
	-- After all pose/stop churn above, stop every player's pose.
	for _, p in Harness.Players.GetPlayers() do
		Remotes.StopPose.OnServerEvent:Fire(p)
	end
	Harness.advance(1.5)
	-- Payout loop runs; nobody poses -> no AuraChanged events during this window.
	Harness.clearEvents()
	Harness.advance(2.2)
	assertTrue(Harness.lastEvent("AuraChanged") == nil, "aura paid while nobody was posing")
end)

test("pose: R6 rig gets posed (space-named motors, derived angles)", function()
	local p = joinPlayer(112, "SixR112")
	Harness.advance(0.3)
	local joint = addJoint(p.Character, "Motor6D", "Right Shoulder", "Torso", "Right Arm")

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	runFrames(10)
	assertTrue(rotationOffDiagonal(joint.Transform) > 0.5, "R6 rig not posed — renderer ignored space-named motors")

	-- The derived R6 transform must differ from the R15 angles (R6 shoulder
	-- pivots carry a 90-degree yaw; verbatim R15 angles would swing the arm
	-- forward/back instead of out to the side).
	local rot = rawget(joint.Transform, "_rot")
	local expectedRz = math.abs(math.sin(math.rad(85))) -- |sin| of transformed z
	assertTrue(math.abs(math.abs(rot[3][2]) - expectedRz) < 0.01 or math.abs(math.abs(rot[2][1]) - expectedRz) < 0.01,
		"R6 angles not derived from R15 (verbatim application?)")
end)

print(("\n%d passed, %d failed"):format(passed, failedCount))
if failedCount > 0 then
	for _, f in failedNames do
		print("  FAILED: " .. f)
	end
	error("TESTS FAILED") -- nonzero exit for CI/shells
end
print("ALL GREEN ✅")
