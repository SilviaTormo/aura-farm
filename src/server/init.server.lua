--!strict
-- AuraFarmServer bootstrap: initializes every service in dependency order.

local ServerScriptService = game:GetService("ServerScriptService")

local services = script -- Rojo: sibling modules become this script's children

local function start(name: string)
	local module = require(services:WaitForChild(name))
	if typeof(module.init) == "function" then
		module.init()
	end
	print("[AuraFarm] started " .. name)
end

-- Order matters: map first (locations), then data, then the rest.
start("MapService")
start("DataService")
start("AuraService")
start("CrowdService")
start("PoseService")
start("JudgeService")
start("DuelService")
start("TrainingService")
start("LeaderboardService")
start("MonetizationService")
-- REMOVE BEFORE PUBLISHING: lets players try Robux perks for free.
start("DevShopService")
start("CapturePromptService")

print("[AuraFarm] 💀 server up — farm aura, mog responsibly")
