--!strict
-- JudgeService: the 3 NPC judges. Computes server-authoritative round scores
-- from (pose tier + timing bonus + crowd vote share + small upset jitter),
-- fires stamp events for the UI, and triggers the MOG FX on duel end.
-- Judges never trust the client: DuelService asks, JudgeService decides.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local MapService = require(script.Parent.MapService)

local JudgeService = {}

local JUDGE_NAMES = { "Judge Chad", "Judge Gigachad", "Judge LiterallyAChild" }

-- Called by DuelService when a round ends. Both players have already locked
-- in their pose ids. Returns the verdict table and fires all judge events.
function JudgeService.scoreRound(
	duelId: string,
	playerA: Player,
	poseIdA: string?,
	playerB: Player,
	poseIdB: string?,
	crowdVotesA: number,
	crowdVotesB: number,
	poseLookup: (string) -> any,
	remainingA: number?,
	remainingB: number?
): { winner: Player?, scoreA: number, scoreB: number, stampA: string, stampB: string }
	local poseA = poseIdA and poseLookup(poseIdA) or nil
	local poseB = poseIdB and poseLookup(poseIdB) or nil

	-- Timing bonus: locking your pose right at the end of the round ("on the
	-- beat") scores extra. Locking early = no bonus.
	local function timingBonus(remaining: number?): number
		if not remaining then
			return 0
		end
		if remaining >= Config.DUEL_TIMING_WINDOW then
			return 0
		end
		return Config.TIMING_BONUS_POINTS * (1 - remaining / Config.DUEL_TIMING_WINDOW)
	end

	local function baseScore(pose, crowdVotes, remaining)
		if not pose then
			return 0 -- timed out without posing: instant cringe
		end
		local tierPoints = pose.tier * 2 -- 2..8
		local votePoints = math.min(2, crowdVotes * 0.5) -- crowd share, capped
		local timing = timingBonus(remaining)
		local jitter = math.random() * 2 - 1 -- -1..+1: upsets happen
		local score = Util.clamp(tierPoints + votePoints + timing + jitter, 0, 10)
		return math.floor(score * 10) / 10
	end

	local scoreA = baseScore(poseA, crowdVotesA, remainingA)
	local scoreB = baseScore(poseB, crowdVotesB, remainingB)

	local stampA = Util.stampForScore(scoreA)
	local stampB = Util.stampForScore(scoreB)

	-- Each judge slams a stamp with slight personality variance.
	for judgeIndex = 1, 3 do
		local personalA = stampA
		local personalB = stampB
		-- One judge is a hater: 20% chance to downgrade a FIRE to MID.
		if judgeIndex == 3 and math.random() < 0.2 then
			if personalA == Config.STAMP_FIRE then
				personalA = Config.STAMP_MID
			end
			if personalB == Config.STAMP_FIRE then
				personalB = Config.STAMP_MID
			end
		end
		Remotes.JudgeStamp:FireAllClients(judgeIndex, personalA, scoreA, playerA)
		Remotes.JudgeStamp:FireAllClients(judgeIndex, personalB, scoreB, playerB)
	end

	local winner
	if scoreA > scoreB then
		winner = playerA
	elseif scoreB > scoreA then
		winner = playerB
	end
	-- Ties: nobody wins the round.

	return {
		winner = winner,
		scoreA = scoreA,
		scoreB = scoreB,
		stampA = stampA,
		stampB = stampB,
	}
end

-- The final MOG: tell every client to play the head explosion + orb stream
-- on the loser's character, and stamp MOGGED on their screen.
function JudgeService.playMogFx(winner: Player, loser: Player, stolenAura: number)
	local loserChar = loser.Character
	if loserChar then
		JudgeService.playMogFxOnModel(winner, loserChar, stolenAura)
	end
end

-- Same cue against a bare Model — used when the loser is an NPC rival dummy
-- (which has no Player object).
function JudgeService.playMogFxOnModel(winner: Player?, loserModel: Model, stolenAura: number)
	if loserModel and loserModel.Parent then
		Remotes.MogFx:FireAllClients(loserModel, stolenAura)
	end
end

function JudgeService.init()
	-- Build the 3 judge NPC dummies at the arena (visual only; scoring is math).
	local judges = MapService.getJudges()
	for i, position in judges do
		local model = Instance.new("Model")
		model.Name = JUDGE_NAMES[i] or ("Judge" .. i)

		local body = Instance.new("Part")
		body.Name = "Torso"
		body.Size = Vector3.new(2, 2, 1)
		body.Position = position
		body.Color = Color3.fromRGB(40, 40, 60)
		body.Anchored = true
		body.Parent = model

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.4, 1.4, 1.4)
		head.Position = position + Vector3.new(0, 1.9, 0)
		head.Color = Color3.fromRGB(255, 220, 180)
		head.Anchored = true
		head.Parent = model

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 100, 0, 24)
		billboard.StudsOffset = Vector3.new(0, 1.6, 0)
		billboard.Parent = head
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextScaled = true
		nameLabel.Text = model.Name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Parent = billboard

		model.Parent = workspace
	end
end

return JudgeService
