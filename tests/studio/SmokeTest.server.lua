--!strict
-- SmokeTest.server.lua — PILOT-ONLY self-test (Studio Play/Run mode).
-- Server-side: world integrity + direct service calls (the remote layer is
-- covered by the Luau harness in tests/). Prints [SMOKE] lines that land in
-- Studio's log file for automated extraction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local t0 = os.clock()
local function stamp(): string
	return ("[%4.1fs]"):format(os.clock() - t0)
end
local function pass(name: string, detail: string?)
	print(("[SMOKE] PASS %s %s | %s"):format(stamp(), name, detail or ""))
end
local function fail(name: string, detail: string?)
	print(("[SMOKE] FAIL %s %s | %s"):format(stamp(), name, detail or ""))
end
local function check(name: string, ok: boolean, detail: string?)
	if ok then pass(name, detail) else fail(name, detail) end
end

local total, failed = 0, 0
local function scored(name: string, ok: boolean, detail: string?)
	total += 1
	if not ok then failed += 1 end
	check(name, ok, detail)
end

-- ── Boot ────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 20)
scored("boot", remotesFolder ~= nil, remotesFolder and "Remotes folder present" or "missing")
if not remotesFolder then
	print(("[SMOKE] SUMMARY total=%d passed=%d failed=%d"):format(total, total - failed, failed))
	return
end

-- ── Player join ─────────────────────────────────────────────────
local player: Player? = nil
for _ = 1, 200 do
	local list = Players:GetPlayers()
	if #list > 0 then
		player = list[1]
		break
	end
	task.wait(0.1)
end
scored("player_join", player ~= nil, player and ("%s (id %d)"):format(player.Name, player.UserId) or "none within 20s")
if not player then
	print(("[SMOKE] SUMMARY total=%d passed=%d failed=%d"):format(total, total - failed, failed))
	return
end

-- ── leaderstats ─────────────────────────────────────────────────
local leaderstats = player:WaitForChild("leaderstats", 15)
local auraStat = leaderstats and leaderstats:WaitForChild("Aura", 5) :: IntValue?
local winsStat = leaderstats and leaderstats:WaitForChild("Wins", 5) :: IntValue?
scored("leaderstats", auraStat ~= nil and winsStat ~= nil,
	("Aura=%s Wins=%s"):format(tostring(auraStat and auraStat.Value), tostring(winsStat and winsStat.Value)))

-- ── Map world ───────────────────────────────────────────────────
local map = workspace:FindFirstChild("AuraFarmMap")
scored("map", map ~= nil, map and ("%d children"):format(#map:GetChildren()) or "missing")
local crowdFolder = workspace:FindFirstChild("AuraCrowd")
local npcCount = crowdFolder and #crowdFolder:GetChildren() or 0
scored("crowd_npcs", npcCount >= 10, ("%d NPCs spawned"):format(npcCount))
local spawnLoc = map and map:FindFirstChildWhichIsA("SpawnLocation", true)
scored("spawn", spawnLoc ~= nil, "SpawnLocation inside AuraFarmMap")

-- ── Character ───────────────────────────────────────────────────
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 10)
scored("character", root ~= nil, ("at %s"):format(tostring(root and root.Position)))

-- ── Services (direct calls; same server DataModel) ──────────────
local services = ServerScriptService:WaitForChild("AuraFarmServer")
local AuraService = require(services:WaitForChild("AuraService"))
local DataService = require(services:WaitForChild("DataService"))

if root then
	-- Stand at the plaza fountain so the crowd can hype us.
	root.CFrame = CFrame.new(Vector3.new(0, 3.5, 0))
	task.wait(0.5)

	-- POSE: apply through the real AuraService (server-authoritative).
	DataService.addAura(player, 500)
	AuraService.setActivePose(player, "tpose")
	local active = AuraService.getActivePose(player)
	scored("pose_applied", active ~= nil and active.poseId == "tpose",
		active and ("poseId=%s tier=%d"):format(active.poseId, active.tier) or "not active")

	-- Pose rendering contract: the server stamps the replicated character
	-- attribute; each client's PoseRenderer writes joint Transforms from it.
	-- (Joints are AnimationConstraint since the 2026 Avatar Joint Upgrade —
	-- Transform writes cannot replicate, so the server must NOT try.)
	local rs = char:FindFirstChild("RightShoulder", true)
	local allJoints = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			table.insert(allJoints, d.Name .. "(" .. d.ClassName .. ")")
		end
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	scored("pose_render_contract", char:GetAttribute("AuraPoseId") == "tpose",
		("attr=%s | joints [%d]: %s | humanoid=%s rigType=%s"):format(
			tostring(char:GetAttribute("AuraPoseId")),
			#allJoints, table.concat(allJoints, ", "),
			humanoid and "yes" or "no",
			humanoid and tostring(humanoid.RigType) or "-"))
	local _ = rs -- kept for the diagnostic dump above

	-- AURA: crowd hype ticks the rate × multipliers.
	local before = auraStat and auraStat.Value or 0
	task.wait(5)
	local after = auraStat and auraStat.Value or 0
	scored("aura_ticking", after > before, ("%d -> %d in 5s with crowd hype"):format(before, after))

	AuraService.setActivePose(player, nil)
	task.wait(0.3)
	scored("pose_stopped", AuraService.getActivePose(player) == nil, "cleared")

	-- ECONOMY: the shop math via the real DataService.
	local auraBeforeSpend = DataService.getProfile(player).aura
	local okBuy = DataService.spendAura(player, 500)
	scored("shop_spend", okBuy and DataService.getProfile(player).aura == auraBeforeSpend - 500 or false,
		("spend 500 ok=%s aura=%d"):format(tostring(okBuy), DataService.getProfile(player).aura))
	DataService.unlockPose(player, "moai")
	scored("shop_unlock", DataService.isUnlocked(player, "moai"), "moai unlocked")
end

print(("[SMOKE] SUMMARY total=%d passed=%d failed=%d"):format(total, total - failed, failed))
print("[SMOKE] DONE")
