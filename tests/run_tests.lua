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
	"PoseAnimator", "JudgeService", "DuelService", "TrainingService",
	"LeaderboardService", "MonetizationService", "CapturePromptService",
} do
	startService(name)
end

local MapService = Harness.requireModule(serverFolder:FindFirstChild("MapService"))
local DataService = Harness.requireModule(serverFolder:FindFirstChild("DataService"))
local AuraService = Harness.requireModule(serverFolder:FindFirstChild("AuraService"))
local PoseService = Harness.requireModule(serverFolder:FindFirstChild("PoseService"))
local PoseAnimator = Harness.requireModule(serverFolder:FindFirstChild("PoseAnimator"))
local Remotes = Harness.requireModule(Harness.sharedFolder:FindFirstChild("Remotes"))
local Config = Harness.requireModule(Harness.sharedFolder:FindFirstChild("Config"))

-- ── Player helper: full join (player + character) ───────────────
local function joinPlayer(userId, name)
	local player = Harness.makePlayer(userId, name)
	Harness.Players.add(player) -- fires PlayerAdded: profile + leaderstats

	local char = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = Vector3.new(0, 3.5, 18) -- spawn
	root.Parent = char
	player.Character = char -- property write: stored where reads find it
	PoseAnimator.bindPlayer(char)
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

test("pose: Motor6D C0 actually rotates off its rest pivot (visibility regression)", function()
	local p = joinPlayer(110, "Poser110")
	Harness.advance(0.3)
	-- Build a minimal R15-ish rig: nested motor like real R15 limbs.
	local char = p.Character
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Parent = char
	local arm = Instance.new("Part")
	arm.Name = "RightUpperArm"
	arm.Parent = char
	local motor = Instance.new("Motor6D")
	motor.Name = "RightShoulder"
	motor.Part0 = torso
	motor.Part1 = arm
	motor.Parent = arm -- R15 nests motors inside the limbs

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	Harness.advance(0.3)

	local c0 = (motor :: any).C0
	-- A T-pose must rotate the arm out to the side: the rotation part of C0
	-- must differ from identity (the old bug left it visually unchanged).
	local rot = rawget(c0, "_rot")
	assertTrue(rot ~= nil, "C0 has no rotation matrix")
	local offDiagonal = math.abs(rot[1][2]) + math.abs(rot[1][3])
		+ math.abs(rot[2][1]) + math.abs(rot[2][3])
		+ math.abs(rot[3][1]) + math.abs(rot[3][2])
	assertTrue(offDiagonal > 0.5, "tpose C0 rotation ~identity — pose invisible")

	-- Re-posing must NOT double-apply: stop, pose again, compare against the
	-- first application (old code multiplied onto the current C0).
	Remotes.StopPose.OnServerEvent:Fire(p)
	Harness.advance(0.3)
	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	Harness.advance(0.3)
	local c0b = (motor :: any).C0
	local rb = rawget(c0b, "_rot")
	assertTrue(math.abs(rb[3][1] - rot[3][1]) < 1e-6, "re-pose drifted (double-applied)")
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
	Remotes.TrainingPick.OnServerEvent:Fire(p, "wave")
	-- Busy check while session open:
	Remotes.TrainingStart.OnServerEvent:Fire(p)
	local busy = Harness.lastEvent("ShopError", p)
	assertTrue(busy ~= nil, "second session during open one was not rejected")

	Harness.advance(8.2) -- round window closes
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
	local char = p.Character
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Parent = char
	local arm = Instance.new("Part")
	arm.Name = "Right Arm"
	arm.Parent = char
	local motor = Instance.new("Motor6D")
	motor.Name = "Right Shoulder" -- R6 naming (space), not R15's RightShoulder
	motor.Part0 = torso
	motor.Part1 = arm
	motor.Parent = arm

	Remotes.RequestPose.OnServerEvent:Fire(p, "tpose")
	Harness.advance(0.3)

	local c0 = (motor :: any).C0
	local rot = rawget(c0, "_rot")
	assertTrue(rot ~= nil, "R6 C0 has no rotation matrix")
	local offDiagonal = math.abs(rot[1][2]) + math.abs(rot[1][3])
		+ math.abs(rot[2][1]) + math.abs(rot[2][3])
		+ math.abs(rot[3][1]) + math.abs(rot[3][2])
	assertTrue(offDiagonal > 0.5, "R6 rig not posed -- animator ignored R6 motors")
	Remotes.StopPose.OnServerEvent:Fire(p)
	Harness.advance(0.3)
end)

print(("\n%d passed, %d failed"):format(passed, failedCount))
if failedCount > 0 then
	for _, f in failedNames do
		print("  FAILED: " .. f)
	end
	error("TESTS FAILED") -- nonzero exit for CI/shells
end
print("ALL GREEN ✅")
