--!strict
-- RebirthService: the long-term chase. Rebirthing resets your aura to 0
-- (poses, wins, gamepass perks are KEPT) in exchange for a permanent +25%
-- aura multiplier per rebirth. Each rebirth costs more than the last, so
-- there is always a next goal. R opens the confirm prompt.
--
-- Cost formula: REBIRTH_BASE_COST * (rebirths + 1) — rebirth #1 costs one
-- base, #2 two bases, #3 three... linear, always reachable.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

-- Lazy require: AuraService reads the rebirth multiplier, so a top-level
-- require here would be a cycle. Resolved on first rebirth instead.
local AuraService
local DataService = require(script.Parent.DataService)

local RebirthService = {}

-- The one true multiplier source: everything that reads rebirth power
-- (grantTick, shop UI, HUD, confirm prompt) goes through here.
function RebirthService.getMultiplier(player: Player): number
	local rebirths = DataService.getRebirths(player)
	return 1 + rebirths * Config.REBIRTH_MULTIPLIER_STEP
end

function RebirthService.getCost(player: Player): number
	local rebirths = DataService.getRebirths(player)
	return Config.REBIRTH_BASE_COST * (rebirths + 1)
end

local function rebirth(player: Player): (boolean, string)
	AuraService = AuraService or require(script.Parent.AuraService)
	if player:GetAttribute("InDuel") == true then
		return false, "Finish your duel first! ⚔️"
	end
	local cost = RebirthService.getCost(player)
	if DataService.getSpendableAura(player) < cost then
		return false, ("You need %d aura to rebirth (you have %d)"):format(cost, DataService.getSpendableAura(player))
	end
	DataService.spendAllAura(player)
	DataService.setRebirths(player, DataService.getRebirths(player) + 1)
	-- Reset the visible pose: farming stance is gone with the aura.
	AuraService.setActivePose(player, nil)
	local rebirths = DataService.getRebirths(player)
	print(("[REBIRTH] %s rebirthed #%d — aura reset, multiplier now x%.2f"):format(player.Name, rebirths, RebirthService.getMultiplier(player)))
	Remotes.RebirthDone:FireClient(player, rebirths, RebirthService.getMultiplier(player))
	Remotes.RebirthChanged:FireAllClients(player, rebirths)
	return true, ("REBIRTH #%d! Permanent x%.2f aura 🔁"):format(rebirths, RebirthService.getMultiplier(player))
end

function RebirthService.init()
	Remotes.RebirthRequest.OnServerEvent:Connect(function(player)
		local ok, msg = rebirth(player)
		if not ok then
			Remotes.ShopError:FireClient(player, msg)
		else
			Remotes.ShopError:FireClient(player, msg)
		end
	end)

	-- leaderstats row so the whole server sees prestige count.
	Players.PlayerAdded:Connect(function(player)
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats and not leaderstats:FindFirstChild("Rebirths") then
			local stat = Instance.new("IntValue")
			stat.Name = "Rebirths"
		stat.Value = DataService.getRebirths(player)
			stat.Parent = leaderstats
		end
	end)
	for _, player in Players:GetPlayers() do
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and not leaderstats:FindFirstChild("Rebirths") then
			local stat = Instance.new("IntValue")
			stat.Name = "Rebirths"
			stat.Value = DataService.getRebirths(player)
			stat.Parent = leaderstats
		end
	end
end

return RebirthService
