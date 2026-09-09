--!strict
-- RemoteEvent / RemoteFunction registry. Created once by the server,
-- read by both sides. Never create remotes anywhere else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local NAMES = {
	-- client -> server
	"RequestPose", -- (poseId: string)
	"StopPose", -- ()
	"BuyPose", -- (poseId: string) -> ok: boolean, msg: string
	"RequestDuel", -- (targetUserId: number) -> ok: boolean, msg: string
	"RequestNpcDuel", -- (npcName: string) -> starts a judged duel vs an NPC rival (solo mode)
	"AcceptDuel", -- (duelId: string)
	"DeclineDuel", -- (duelId: string)
	"DuelPickPose", -- (poseId: string) -- locked in for current round
	"RequestPartyMode", -- () -- dev product purchase flow
	"BuyPass", -- (passKey: string) -- opens gamepass prompt
	"BuyProduct", -- (productKey: string) -- opens dev product prompt
	"DevShopTry", -- (key: string) -- Studio-only simulated purchase (DevShopService)
	"TrainingStart", -- () -- stand on the pad to open a training round
	"TrainingPick", -- (poseId: string) -- lock a pose for the training round
	"RebirthRequest", -- () -- reset aura for a permanent multiplier (RebirthService)

	-- server -> client
	"AuraChanged", -- (player: Player, aura: number)
	"PoseStarted", -- (player: Player, poseId: string)
	"PoseStopped", -- (player: Player)
	"PoseUnlocked", -- (poseId: string)
	"SyncUnlocked", -- (ids: string[]) -- full unlock list on join
	"ShopError", -- (msg: string)
	"DuelInvited", -- (duelId: string, challengerName: string)
	"DuelStarted", -- (duelId: string, opponentName: string)
	"DuelRoundStart", -- (round: number, totalRounds: number, seconds: number)
	"DuelVerdict", -- (round: number, yourScore: number, theirScore: number, yourStamp: string, theirStamp: string)
	"DuelEnded", -- (youWon: boolean, stolenAura: number, opponentName: string)
	"MogFx", -- (loserCharacter: Model) -- head explosion + orbs cue
	"JudgeStamp", -- (judgeIndex: number, stamp: string, score: number, forPlayer: Player?)
	"PartyModeStarted", -- (seconds: number)
	"TrainingRound", -- (seconds: number) -- training window opened
	"TrainingResult", -- (yourScore, botScore, yourStamp, botStamp, youWon: boolean, auraWon: number)
	"RebirthDone", -- (player: Player, rebirths: number, multiplier: number) -- your rebirth went through
	"RebirthChanged", -- (player: Player, rebirths: number) -- anyone rebirthed (billboard refresh)
	"EventStarted", -- (kind: string, seconds: number) -- Aura Rain / server event
	"ChestSpawned", -- (part: BasePart) -- a Golden Chest appeared at this spot
	"ChestOpened", -- (player: Player, auraWon: number) -- someone opened the chest
}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

export type Remotes = typeof(Remotes)

return Remotes
