--!strict
-- PoseService: handles pose requests from clients, validates cooldowns and
-- ownership, and hands validated state to AuraService.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)

local PoseService = {}

local lastUse: { [number]: { [string]: number } } = {}

local function findPose(poseId: string)
	for _, pose in Config.POSES do
		if pose.id == poseId then
			return pose
		end
	end
	return nil
end

function PoseService.getPoseById(poseId: string)
	return findPose(poseId)
end

local function onRequestPose(player: Player, poseId: string)
	if typeof(poseId) ~= "string" then
		return
	end
	local pose = findPose(poseId)
	if not pose then
		return
	end
	if not DataService.isUnlocked(player, poseId) then
		Remotes.ShopError:FireClient(player, "Pose not unlocked: buy it in the shop!")
		return
	end

	-- Cooldown check
	local playerCooldowns = lastUse[player.UserId] or {}
	local now = os.clock()
	if pose.cooldown > 0 and (playerCooldowns[poseId] or 0) > now then
		return
	end
	playerCooldowns[poseId] = now + pose.cooldown
	lastUse[player.UserId] = playerCooldowns

	AuraService.setActivePose(player, poseId)
end

local function onStopPose(player: Player)
	AuraService.setActivePose(player, nil)
end

local function onBuyPose(player: Player, poseId: string)
	if typeof(poseId) ~= "string" then
		return
	end
	local pose = findPose(poseId)
	if not pose then
		return
	end
	if DataService.isUnlocked(player, poseId) then
		Remotes.ShopError:FireClient(player, "Already unlocked!")
		return
	end
	if DataService.spendAura(player, pose.cost) then
		DataService.unlockPose(player, poseId)
		-- Push the new balance NOW: without this the HUD counter (which only
		-- listens to AuraChanged) kept the old number until the next aura tick.
		local newAura = DataService.getProfile(player).aura
		Remotes.AuraChanged:FireClient(player, newAura, -pose.cost)
		local leaderstats = player:FindFirstChild("leaderstats")
		local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
		if auraStat then
			auraStat.Value = newAura
		end
		Remotes.PoseUnlocked:FireClient(player, poseId)
	else
		Remotes.ShopError:FireClient(player, ("Need %d aura for %s!"):format(pose.cost, pose.name))
	end
end

-- Dev product: clear all pose cooldowns for this player.
function PoseService.clearCooldowns(player: Player)
	lastUse[player.UserId] = nil
end

function PoseService.init()
	Remotes.RequestPose.OnServerEvent:Connect(onRequestPose)
	Remotes.StopPose.OnServerEvent:Connect(onStopPose)
	Remotes.BuyPose.OnServerEvent:Connect(onBuyPose)

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player.UserId] = nil
	end)
end

return PoseService
