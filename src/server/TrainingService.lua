--!strict
-- TrainingService: the arena training pad. Solo practice rounds judged by the
-- REAL JudgeService against a simulated opponent pose, so players can warm up
-- (and test the judge pipeline) with nobody else in the server.
-- Flow: step on the pad -> 8s window opens -> lock a pose -> judges stamp ->
-- win pays a small aura reward.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CrowdService = require(script.Parent.CrowdService)
local DataService = require(script.Parent.DataService)
local JudgeService = require(script.Parent.JudgeService)
local MapService = require(script.Parent.MapService)

local TrainingService = {}

local ROUND_SECONDS = 8
local PAD_COOLDOWN = 10
local WIN_AURA_PER_TIER = 10

type Session = {
	player: Player,
	poseId: string?,
	lockedAt: number?,
	endsAt: number,
}

local pad: BasePart? = nil
local session: Session? = nil
local lastRun: { [number]: number } = {}
local lastTouch: { [number]: number } = {}

-- Touched fires continuously while standing on the pad; debounce per player.
local TOUCH_DEBOUNCE = 3

local function findPose(poseId: string)
	for _, pose in Config.POSES do
		if pose.id == poseId then
			return pose
		end
	end
	return nil
end

local function buildPad()
	local spot = MapService.getLocation("trainingPad") or Vector3.new(88, 0.5, 10)
	local thePad = Instance.new("Part")
	thePad.Name = "TrainingPad"
	thePad.Size = Vector3.new(8, 0.5, 8)
	thePad.Position = spot
	thePad.Anchored = true
	thePad.Material = Enum.Material.Neon
	thePad.Color = Color3.fromRGB(120, 255, 140)
	thePad.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = thePad
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.Text = "TRAIN 🥋"
	label.Parent = billboard

	pad = thePad
end

local function finishSession(current: Session)
	if session ~= current then
		return -- a newer session replaced this one
	end
	session = nil

	local player = current.player
	local remaining = current.lockedAt and math.max(0, current.endsAt - current.lockedAt) or nil

	-- The bot: random pose, random timing (sometimes it hits the beat too).
	local botPose = Config.POSES[math.random(#Config.POSES)]
	local botRemaining = math.random() * 3

	local votes = CrowdService.getHypeCount(player)
	local verdict = JudgeService.scoreRound(
		"training_" .. player.UserId,
		player, current.poseId,
		nil :: any, botPose.id,
		votes, 0,
		findPose,
		remaining,
		botRemaining
	)

	local won = verdict.winner == player
	local auraWon = 0
	if won then
		auraWon = botPose.tier * WIN_AURA_PER_TIER
		local newAura = DataService.addAura(player, auraWon)
		Remotes.AuraChanged:FireClient(player, newAura, auraWon)
		local leaderstats = player:FindFirstChild("leaderstats")
		local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
		if auraStat then
			auraStat.Value = newAura
		end
	end

	print(("[TRAIN] result for %s: %s %.1f vs bot %.1f %s — %s (+%d aura)"):format(player.Name, verdict.stampA, verdict.scoreA, verdict.scoreB, verdict.stampB, won and "WIN" or "LOSE", auraWon))
	Remotes.TrainingResult:FireClient(
		player, verdict.scoreA, verdict.scoreB, verdict.stampA, verdict.stampB, won, auraWon
	)
end

local function openSession(player: Player, viaTouch: boolean)
	local now = os.clock()
	if viaTouch then
		if (lastTouch[player.UserId] or 0) + TOUCH_DEBOUNCE > now then
			return
		end
		lastTouch[player.UserId] = now
	end
	if session then
		Remotes.ShopError:FireClient(player, "The training pad is busy!")
		return
	end
	if (lastRun[player.UserId] or 0) + PAD_COOLDOWN > now then
		Remotes.ShopError:FireClient(player, "Training cooldown — catch your breath 🥋")
		return
	end
	lastRun[player.UserId] = now

	local current: Session = {
		player = player,
		poseId = nil,
		lockedAt = nil,
		endsAt = now + ROUND_SECONDS,
	}
	session = current

	print(("[TRAIN] open for %s via %s (%ds window)"):format(player.Name, viaTouch and "PAD TOUCH" or "T KEY", ROUND_SECONDS))
	Remotes.TrainingRound:FireClient(player, ROUND_SECONDS)
	task.delay(ROUND_SECONDS + 0.1, function()
		finishSession(current)
	end)
end

local function onTrainingPick(player: Player, poseId: string)
	local current = session
	if not current or current.player ~= player then
		return
	end
	if typeof(poseId) ~= "string" then
		return
	end
	if os.clock() > current.endsAt then
		return -- window closed
	end
	if current.poseId then
		return -- already locked
	end
	local pose = findPose(poseId)
	if not pose or not DataService.isUnlocked(player, poseId) then
		return
	end
	current.poseId = poseId
	current.lockedAt = os.clock()
	print(("[TRAIN] %s locked pose '%s' at %.1fs left"):format(player.Name, poseId, current.endsAt - current.lockedAt))
end

local function onTrainingStart(player: Player)
	openSession(player, false)
end

function TrainingService.init()
	buildPad()

	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			openSession(player, true)
		end
	end)

	Remotes.TrainingStart.OnServerEvent:Connect(onTrainingStart)
	Remotes.TrainingPick.OnServerEvent:Connect(onTrainingPick)

	Players.PlayerRemoving:Connect(function(player)
		lastRun[player.UserId] = nil
		lastTouch[player.UserId] = nil
		local current = session
		if current and current.player == player then
			session = nil
		end
	end)
end

return TrainingService
