--!strict
-- DuelService: player-vs-player judged pose-offs.
-- Flow: challenge -> invite -> accept -> teleport to arena -> best-of-5 rounds
-- -> each round both players lock a pose -> JudgeService scores -> MOG FX ->
-- aura steal -> MOGGED debuff billboard -> teleport back.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AuraService = require(script.Parent.AuraService)
local CrowdService = require(script.Parent.CrowdService)
local DataService = require(script.Parent.DataService)
local JudgeService = require(script.Parent.JudgeService)
local MapService = require(script.Parent.MapService)
local PoseService = require(script.Parent.PoseService)

local DuelService = {}

type Duel = {
	id: string,
	playerA: Player,
	playerB: Player?, -- nil in NPC bot duels
	npcModel: Model?, -- set in bot duels
	npcHome: CFrame?, -- where the rival returns to after the duel
	bot: boolean?,
	round: number,
	poseA: string?,
	poseB: string?,
	lockedAtA: number?,
	lockedAtB: number?,
	roundEndsAt: number?,
	crowdVotesA: number,
	crowdVotesB: number,
	winsA: number,
	winsB: number,
	originalPositions: { [number]: Vector3 },
	active: boolean,
}

local pendingInvites: { [number]: { id: string, from: number, at: number } } = {} -- by target UserId
local activeDuels: { [number]: Duel } = {} -- by participant UserId
local lastChallenge: { [number]: number } = {}
local busyRivals: { [string]: boolean } = {} -- rival NPCs mid-duel, by model name

local function getDuel(player: Player): Duel?
	return activeDuels[player.UserId]
end

local function cleanupDuel(duel: Duel)
	for _, player in { duel.playerA, duel.playerB } do
		if not player then
			continue
		end
		activeDuels[player.UserId] = nil
		player:SetAttribute("InDuel", nil)
		if player.Parent then
			-- Restore position
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local original = duel.originalPositions[player.UserId]
			if root and original then
				root.CFrame = CFrame.new(original + Vector3.new(0, 3, 0))
			end
			AuraService.setActivePose(player, nil)
		end
	end
	-- Free the NPC rival, then send them back to their plaza spot.
	if duel.npcModel then
		busyRivals[duel.npcModel.Name] = nil
		CrowdService.teleportRival(duel.npcModel, duel.npcHome or CFrame.new(70, 4.7, 12))
		duel.npcModel = nil
	end
end

local function npcSpecFor(duel: Duel)
	if not duel.npcModel then
		return nil
	end
	for _, rival in Config.NPC_RIVALS do
		if rival.name == duel.npcModel.Name then
			return rival
		end
	end
	return nil
end

local function npcDisplayName(duel: Duel): string
	local spec = npcSpecFor(duel)
	return (spec and spec.displayName) or (duel.npcModel and duel.npcModel.Name) or "???"
end

-- The bot picks its pose at the buzzer, gated by the rival's maxTier
-- (stronger poses need aura in the shop, so a "Tomás" can't SIGMA).
local function pickBotPose(duel: Duel): string
	local spec = npcSpecFor(duel)
	local maxTier = (spec and spec.maxTier) or 2
	local pool = {}
	for _, pose in Config.POSES do
		if pose.tier <= maxTier then
			table.insert(pool, pose.id)
		end
	end
	return pool[math.random(#pool)]
end

local function finishDuel(duel: Duel, winner: Player?, loser: Player?)
	duel.active = false

	-- MOGGED billboard debuff on the loser (Config.MOGGED_DEBUFF_SECONDS).
	if loser and loser.Parent then
		local char = loser.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "MoggedBillboard"
			billboard.Size = UDim2.new(0, 160, 0, 40)
			billboard.StudsOffset = Vector3.new(0, 2.6, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = "MOGGED 💀"
			label.TextColor3 = Color3.fromRGB(170, 80, 255)
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.Parent = billboard
			task.delay(Config.MOGGED_DEBUFF_SECONDS, function()
				if billboard.Parent then
					billboard:Destroy()
				end
			end)
		end
	end

	local stolenAura = 0
	if winner and loser then
		local loserProfile = DataService.getProfile(loser)
		local winnerProfile = DataService.getProfile(winner)
		-- MogShield: a loser holding an active shield keeps their aura.
		local shieldUntil = 0
		local loserStats = loser:FindFirstChild("leaderstats")
		local loserAuraStat = loserStats and loserStats:FindFirstChild("Aura")
		if loserAuraStat then
			shieldUntil = loserAuraStat:GetAttribute("MogShieldUntil") or 0
		end
		local shielded = os.time() < (tonumber(shieldUntil) or 0)

		if loserProfile and winnerProfile then
			if not shielded then
			local raw = math.floor(loserProfile.aura * Config.DUEL_STEAL_FRACTION)
			stolenAura = math.min(raw, Config.DUEL_STEAL_CAP)
			-- Newbie protection: can't take below the protect floor.
			if loserProfile.aura - stolenAura < Config.DUEL_NEWBIE_PROTECT then
				stolenAura = math.max(0, loserProfile.aura - Config.DUEL_NEWBIE_PROTECT)
			end
			if stolenAura > 0 then
			DataService.addAura(winner, stolenAura)
			DataService.addAura(loser, -stolenAura)
		end
		end -- shielded: steal blocked, match still recorded
			DataService.addWin(winner, true)
			DataService.addWin(loser, false)
			local wl = winner:FindFirstChild("leaderstats")
			local ll = loser:FindFirstChild("leaderstats")
			if wl then
				wl.Aura.Value = DataService.getProfile(winner).aura
				wl.Wins.Value = DataService.getProfile(winner).wins
			end
			if ll then
				ll.Aura.Value = DataService.getProfile(loser).aura
			end
		end

	end

	-- THE MOG: head explosion + aura orbs + stamps. Player-vs-bot routes the
	-- explosion onto the rival dummy (playMogFx expects a Player character).
	if winner and loser then
		JudgeService.playMogFx(winner, loser, stolenAura)
	elseif duel.bot and winner == duel.playerA and duel.npcModel then
		JudgeService.playMogFxOnModel(winner, duel.npcModel, stolenAura)
	end

	-- NPC rival duel: no aura to steal from a bot, so the payoff is the
	-- rival's bounty (bigger bounty = harder rival).
	if duel.bot and winner ~= nil and winner == duel.playerA and winner.Parent then
		local spec = npcSpecFor(duel)
		local bounty = (spec and spec.bounty) or 100
		local newAura = DataService.addAura(winner, bounty)
		Remotes.AuraChanged:FireClient(winner, newAura, bounty)
		local stats = winner:FindFirstChild("leaderstats")
		local auraStat = stats and stats:FindFirstChild("Aura")
		if auraStat then
			auraStat.Value = newAura
		end
	end

	-- Display name of whoever lost (player-vs-bot uses the rival's meme name).
	local loserName = loser and loser.Name
		or (duel.playerB and duel.playerB.Name)
		or npcDisplayName(duel)

	Remotes.DuelEnded:FireClient(duel.playerA, winner == duel.playerA, stolenAura, loserName)
	if duel.playerB then
		Remotes.DuelEnded:FireClient(duel.playerB, winner == duel.playerB, stolenAura, duel.playerA.Name)
	end

	-- Showdown pause so the MOG moment lands before everyone teleports back.
	task.delay(Config.NPC_DUEL_RESULT_SECONDS, function()
		cleanupDuel(duel)
	end)
end

local function playRound(duel: Duel)
	-- Round timing for the judge timing bonus.
	duel.roundEndsAt = os.clock() + Config.DUEL_ROUND_SECONDS
	duel.lockedAtA, duel.lockedAtB = nil, nil

	-- Give both players a moment, then open the round window.
	for _, player in { duel.playerA, duel.playerB } do
		if player then
			Remotes.DuelRoundStart:FireClient(player, duel.round, Config.DUEL_ROUNDS, Config.DUEL_ROUND_SECONDS)
		end
	end
	task.wait(Config.DUEL_ROUND_SECONDS)

	-- Snapshot locked poses, then clear for next round.
	local poseA, poseB = duel.poseA, duel.poseB
	duel.poseA, duel.poseB = nil, nil

	-- The NPC bot picks at the buzzer and only sometimes lands the timing
	-- beat (design's "upsets happen" — it should be beatable but not free).
	if duel.bot then
		poseB = pickBotPose(duel)
		if math.random() < 0.35 then
			duel.lockedAtB = duel.roundEndsAt
				and (duel.roundEndsAt - math.random() * Config.DUEL_TIMING_WINDOW)
				or nil
		end
	end

	-- Timing capture: how long each fighter had left when they locked in.
	local remainingA = duel.roundEndsAt and duel.lockedAtA
		and math.max(0, duel.roundEndsAt - duel.lockedAtA) or nil
	local remainingB = duel.roundEndsAt and duel.lockedAtB
		and math.max(0, duel.roundEndsAt - duel.lockedAtB) or nil

	-- Crowd votes: NPCs currently hyping each fighter count as their votes.
	local crowdVotesA = CrowdService.getHypeCount(duel.playerA)
	local crowdVotesB = duel.playerB and CrowdService.getHypeCount(duel.playerB) or 0

	local verdict = JudgeService.scoreRound(
		duel.id,
		duel.playerA, poseA,
		duel.playerB, poseB,
		crowdVotesA, crowdVotesB,
		function(poseId)
			return PoseService.getPoseById(poseId)
		end,
		remainingA,
		remainingB
	)

	Remotes.DuelVerdict:FireClient(
		duel.playerA, duel.round, verdict.scoreA, verdict.scoreB, verdict.stampA, verdict.stampB
	)
	if duel.playerB then
		Remotes.DuelVerdict:FireClient(
			duel.playerB, duel.round, verdict.scoreB, verdict.scoreA, verdict.stampB, verdict.stampA
		)
	end

	if verdict.winner == duel.playerA then
		duel.winsA += 1
	elseif duel.playerB ~= nil and verdict.winner == duel.playerB then
		-- nil-check matters in bot duels: playerB is nil there, and a tie round
		-- (verdict.winner == nil) would otherwise score FOR the bot.
		duel.winsB += 1
	end

	-- Early exit on majority
	if duel.winsA >= 3 or duel.winsB >= 3 then
		local winner = duel.winsA >= 3 and duel.playerA or duel.playerB
		local loser: Player?
		if winner == duel.playerA then
			loser = duel.playerB -- nil in bot duels: no "loser" to rob
		else
			loser = duel.playerA
		end
		finishDuel(duel, winner, loser)
		return
	end

	duel.round += 1
	if duel.round > Config.DUEL_ROUNDS then
		-- Tie-break by total round wins; if still tied, higher aura wins (aura flexes).
		local winner, loser
		if duel.winsA > duel.winsB then
			winner, loser = duel.playerA, duel.playerB
		elseif duel.winsB > duel.winsA then
			winner, loser = duel.playerB, duel.playerA
		elseif duel.bot then
			-- Player-vs-bot tie at the end of 5 rounds goes to the player:
			-- losing a bounty to a jitter roll feels awful.
			winner, loser = duel.playerA, nil
		else
			local auraA = DataService.getProfile(duel.playerA).aura
			local auraB = DataService.getProfile(duel.playerB).aura
			winner = auraA >= auraB and duel.playerA or duel.playerB
			loser = winner == duel.playerA and duel.playerB or duel.playerA
		end
		finishDuel(duel, winner, loser)
		return
	end

	task.wait(2)
	playRound(duel)
end

local function startDuel(duel: Duel)
	for _, player in { duel.playerA, duel.playerB } do
		activeDuels[player.UserId] = duel
		player:SetAttribute("InDuel", true)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			duel.originalPositions[player.UserId] = root.Position
		end
	end

	-- Teleport to arena spots.
	local posA = MapService.getLocation("arenaPlayerA") or Vector3.new(64, 2, 0)
	local posB = MapService.getLocation("arenaPlayerB") or Vector3.new(76, 2, 0)
	for _, pair in {
		{ duel.playerA, posA },
		{ duel.playerB, posB },
	} do
		if not pair[1] then
			continue -- bot duels have no playerB
		end
		local char = pair[1].Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(pair[2])
		end
	end

	Remotes.DuelStarted:FireClient(duel.playerA, duel.id, duel.playerB.Name)
	Remotes.DuelStarted:FireClient(duel.playerB, duel.id, duel.playerA.Name)

	playRound(duel)
end

-- ── Solo mode: NPC rival duels ─────────────────────────────────
-- No second player needed: pick a rival, both "teleport" to the arena, and
-- the same judge loop scores every round. The bot picks its pose at the
-- buzzer; the payoff is its bounty instead of an aura steal.
local function startNpcDuel(player: Player, model: Model)
	local duel: Duel = {
		id = "npc_" .. tostring(os.clock()) .. "_" .. player.UserId,
		playerA = player,
		playerB = nil,
		npcModel = model,
		bot = true,
		round = 1,
		poseA = nil,
		poseB = nil,
		crowdVotesA = 0,
		crowdVotesB = 0,
		winsA = 0,
		winsB = 0,
		originalPositions = {},
		active = true,
	}
	activeDuels[player.UserId] = duel
	player:SetAttribute("InDuel", true)
	busyRivals[model.Name] = true

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		duel.originalPositions[player.UserId] = root.Position
	end

	local posA = MapService.getLocation("arenaPlayerA") or Vector3.new(64, 2, 0)
	local posB = MapService.getLocation("arenaPlayerB") or Vector3.new(76, 2, 0)
	if root then
		root.CFrame = CFrame.new(posA)
	end
	-- Stage the rival on the B spot facing the player (teleportRival re-seats
	-- all limbs; the dummy has no Humanoid/Motor6D rig of its own).
	duel.npcHome = CFrame.new(70, 4.7, 12)
	local bPos = posB + Vector3.new(0, 2.7, 0)
	CrowdService.teleportRival(model, CFrame.lookAt(bPos, Vector3.new(posA.X, bPos.Y, posA.Z)))

	Remotes.DuelStarted:FireClient(player, duel.id, npcDisplayName(duel))
	playRound(duel)
end

local function onRequestNpcDuel(player: Player, npcName: string)
	if typeof(npcName) ~= "string" then
		return
	end
	if getDuel(player) then
		Remotes.ShopError:FireClient(player, "You're already in a duel!")
		return
	end
	local now = os.clock()
	if (lastChallenge[player.UserId] or 0) + Config.DUEL_CHALLENGE_COOLDOWN > now then
		Remotes.ShopError:FireClient(player, "Challenge cooldown — chill 😤")
		return
	end
	lastChallenge[player.UserId] = now

	local spec
	for _, rival in Config.NPC_RIVALS do
		if rival.name == npcName then
			spec = rival
			break
		end
	end
	if not spec then
		return
	end
	if busyRivals[npcName] then
		Remotes.ShopError:FireClient(player, spec.displayName .. " is already dueling!")
		return
	end

	for model, _state in CrowdService.allRivals() do
		if model.Name == npcName then
			task.spawn(startNpcDuel, player, model)
			return
		end
	end
end

local function onRequestDuel(player: Player, targetUserId: number)
	if typeof(targetUserId) ~= "number" then
		return
	end
	if getDuel(player) then
		Remotes.ShopError:FireClient(player, "You're already in a duel!")
		return
	end
	local now = os.clock()
	if (lastChallenge[player.UserId] or 0) + Config.DUEL_CHALLENGE_COOLDOWN > now then
		Remotes.ShopError:FireClient(player, "Challenge cooldown — chill 😤")
		return
	end
	lastChallenge[player.UserId] = now

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	if getDuel(target) then
		Remotes.ShopError:FireClient(player, target.Name .. " is already dueling!")
		return
	end

	local duelId = tostring(os.clock()) .. "_" .. player.UserId
	pendingInvites[target.UserId] = { id = duelId, from = player.UserId, at = now }
	Remotes.DuelInvited:FireClient(target, duelId, player.Name)
end

local function onAcceptDuel(player: Player, duelId: string)
	local invite = pendingInvites[player.UserId]
	if not invite or invite.id ~= duelId then
		return
	end
	if os.clock() - invite.at > 15 then
		pendingInvites[player.UserId] = nil
		return
	end
	pendingInvites[player.UserId] = nil

	local challenger = Players:GetPlayerByUserId(invite.from)
	if not challenger or getDuel(challenger) or getDuel(player) then
		return
	end

	local duel: Duel = {
		id = duelId,
		playerA = challenger,
		playerB = player,
		round = 1,
		poseA = nil,
		poseB = nil,
		crowdVotesA = 0,
		crowdVotesB = 0,
		winsA = 0,
		winsB = 0,
		originalPositions = {},
		active = true,
	}
	task.spawn(startDuel, duel)
end

local function onDeclineDuel(player: Player, duelId: string)
	local invite = pendingInvites[player.UserId]
	if invite and invite.id == duelId then
		pendingInvites[player.UserId] = nil
		local challenger = Players:GetPlayerByUserId(invite.from)
		if challenger then
			Remotes.ShopError:FireClient(challenger, player.Name .. " declined. Cringe.")
		end
	end
end

local function onDuelPickPose(player: Player, poseId: string)
	local duel = getDuel(player)
	if not duel or not duel.active then
		return
	end
	if typeof(poseId) ~= "string" then
		return
	end
	-- Round already scored: a late pick would farm a fake timing bonus.
	if duel.roundEndsAt and os.clock() > duel.roundEndsAt then
		return
	end
	local pose = PoseService.getPoseById(poseId)
	if not pose or not DataService.isUnlocked(player, poseId) then
		return
	end
	if player == duel.playerA then
		duel.poseA = poseId
		duel.lockedAtA = os.clock()
	else
		duel.poseB = poseId
		duel.lockedAtB = os.clock()
	end
	-- Visually lock the pose (no aura ticking during duels — judge scores only).
	AuraService.setActivePose(player, poseId)
end

function DuelService.init()
	Remotes.RequestDuel.OnServerEvent:Connect(onRequestDuel)
	Remotes.RequestNpcDuel.OnServerEvent:Connect(onRequestNpcDuel)
	Remotes.AcceptDuel.OnServerEvent:Connect(onAcceptDuel)
	Remotes.DeclineDuel.OnServerEvent:Connect(onDeclineDuel)
	Remotes.DuelPickPose.OnServerEvent:Connect(onDuelPickPose)

	Players.PlayerRemoving:Connect(function(player)
		pendingInvites[player.UserId] = nil
		local duel = getDuel(player)
		if duel and duel.active then
			local opponent = duel.playerA == player and duel.playerB or duel.playerA
			finishDuel(duel, opponent, nil) -- walkover win, no steal
		end
	end)
end

return DuelService
