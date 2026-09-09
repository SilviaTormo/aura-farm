--!strict
-- AuraService: server-authoritative aura ticking for active poses.
-- The client never reports aura; it only reports which pose it is holding,
-- and this service validates everything else.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local AuraService = {}

-- player.UserId -> { poseId, startedAt, spotMultiplier, dripMultiplier }
local activePoses: { [number]: any } = {}

local partyModeEndsAt = 0

-- Push the full unlock list + current aura to the client on join.
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in Players:GetPlayers() do
			local profile = DataService.getProfile(player)
			if profile then
				Remotes.SyncUnlocked:FireClient(player, profile.unlocked)
				local leaderstats = player:FindFirstChild("leaderstats")
				local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
				if auraStat then
					auraStat.Value = profile.aura
				end
			end
		end
	end
end)

function AuraService.setActivePose(player: Player, poseId: string | nil)
	if poseId == nil then
		activePoses[player.UserId] = nil
		-- Clear both replicated signals the renderers reconcile against:
		-- the explicit broadcast and the attribute.
		local char = player.Character
		if char then
			char:SetAttribute("AuraPoseId", nil)
		end
		Remotes.PoseStopped:FireAllClients(player)
		return
	end
	-- Validate pose exists and is unlocked.
	local pose
	for _, p in Config.POSES do
		if p.id == poseId then
			pose = p
			break
		end
	end
	if not pose or not DataService.isUnlocked(player, poseId) then
		return
	end

	-- Multipliers are computed SERVER-side (never trusted from the client):
	-- spot (where you pose) × drip (Golden Drip pass) × aura pass (2x Aura).
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local spotMultiplier = root and MapService.getSpotMultiplier(root.Position) or 1
	local profile = DataService.getProfile(player)
	local dripMultiplier = profile and profile.hasDrip and Config.DRIP_AURA_MULTIPLIER or 1

	activePoses[player.UserId] = {
		poseId = poseId,
		tier = pose.tier,
		rate = pose.rate,
		startedAt = os.clock(),
		spotMultiplier = spotMultiplier,
		dripMultiplier = dripMultiplier,
	}

	if char then
		-- The pose id replicates via attribute for every client's renderer;
		-- joint Transforms are written client-side (AnimationConstraint's
		-- Transform does not replicate, C0 is read-only).
		char:SetAttribute("AuraPoseId", poseId)
	end
	Remotes.PoseStarted:FireAllClients(player, poseId)
end

function AuraService.getActivePose(player: Player)
	return activePoses[player.UserId]
end

function AuraService.setPartyMode(seconds: number)
	partyModeEndsAt = os.clock() + seconds
	Remotes.PartyModeStarted:FireAllClients(seconds)
end

function AuraService.isPartyMode(): boolean
	return os.clock() < partyModeEndsAt
end

function AuraService.grantTick(player: Player, crowdCount: number)
	-- Duelists earn nothing from the crowd: their payoff is the judged verdict
	-- (and the steal), so crowd income can't be farmed mid-duel. DuelService
	-- tags participants with the attribute; an attribute avoids a require cycle.
	if player:GetAttribute("InDuel") == true then
		return
	end
	local active = activePoses[player.UserId]
	if not active or crowdCount <= 0 then
		return
	end
	local multiplier = active.rate * active.spotMultiplier * active.dripMultiplier
	-- 2x Aura gamepass (attribute set by MonetizationService).
	local leaderstats = player:FindFirstChild("leaderstats")
	local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
	if auraStat and auraStat:GetAttribute("DoubleAura") == true then
		multiplier *= Config.PASS_AURA_MULTIPLIER
	end
	if AuraService.isPartyMode() then
		multiplier *= 2
	end
	local gained = math.max(1, math.floor(crowdCount * multiplier))
	local newAura = DataService.addAura(player, gained)
	Remotes.AuraChanged:FireClient(player, newAura, gained)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local auraStat = leaderstats:FindFirstChild("Aura")
		if auraStat then
			auraStat.Value = newAura
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		-- A respawned character is no longer holding a pose: clear the
		-- replicated attribute the renderers reconcile against.
		char:SetAttribute("AuraPoseId", nil)
		activePoses[player.UserId] = nil
	end)
	if player.Character then
		player.Character:SetAttribute("AuraPoseId", nil)
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local aura = Instance.new("IntValue")
	aura.Name = "Aura"
	aura.Value = 0
	aura.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)

function AuraService.init()
	-- Players who joined before this script ran (Studio fast-join race).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	activePoses[player.UserId] = nil
end)

return AuraService
