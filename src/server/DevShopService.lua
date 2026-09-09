--!strict
-- DevShopService: local-only purchase simulator for Studio pilot testing.
-- Adds a dev-shop panel to the B (shop) UI's bottom section so players can
-- TRY every Robux perk without spending Robux (no real Marketplace prompts).
-- Effect grants reuse MonetizationService's exact functions; a '[DEV-SHOP]'
-- line marks each simulated purchase in the Output log. Strip before
-- publishing (remove one entry in init.server.lua).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)
local PoseService = require(script.Parent.PoseService)

local DevShopService = {}

-- Gate: grants require BOTH the Config flag AND Studio, evaluated per
-- request. Two independent switches so a published server can never serve
-- free perks, even if a pilot build with the flag on is accidentally
-- published — IsStudio() is false on real servers no matter what Config says.
local function gateOpen(): boolean
	return Config.DEV_SHOP_ENABLED == true and RunService:IsStudio()
end
local warned = false

-- The dev shop calls the SAME grant functions MonetizationService uses for
-- real purchases, so what you try here behaves identically to the real thing.
function DevShopService.grant(player: Player, key: string)
	print(("[DEV-SHOP] %s simulates purchase: %s"):format(player.Name, key))
	if key == "DoubleAura" then
		local stat = player:FindFirstChild("leaderstats")
		local aura = stat and stat:FindFirstChild("Aura")
		if aura then
			aura:SetAttribute("DoubleAura", true)
		end
		Remotes.ShopError:FireClient(player, "2x Aura ACTIVATED (dev sim) ⚡")
	elseif key == "VipPlaza" then
		local stat = player:FindFirstChild("leaderstats")
		local aura = stat and stat:FindFirstChild("Aura")
		if aura then
			aura:SetAttribute("VipPlaza", true)
		end
		Remotes.ShopError:FireClient(player, "VIP Plaza ACTIVATED (dev sim) 👑")
	elseif key == "SigmaPosePack" then
		DataService.unlockPose(player, "sigma")
		Remotes.PoseUnlocked:FireClient(player, "sigma")
		Remotes.ShopError:FireClient(player, "SIGMA pose UNLOCKED (dev sim) 🗿")
	elseif key == "GoldenDripBundle" then
		DataService.setHasDrip(player, true)
		Remotes.ShopError:FireClient(player, "Golden Drip ON (dev sim) ✨")
	elseif key == "MogShield" then
		local stat = player:FindFirstChild("leaderstats")
		local aura = stat and stat:FindFirstChild("Aura")
		if aura then
			aura:SetAttribute("MogShieldUntil", os.time() + Config.MOG_SHIELD_SECONDS)
		end
		Remotes.ShopError:FireClient(player, "Mog Shield ARMED (dev sim) 🛡️")
	elseif key == "CooldownRefill" then
		PoseService.clearCooldowns(player)
		Remotes.ShopError:FireClient(player, "Cooldowns CLEARED (dev sim) ⚡")
	elseif key == "PartyMode" then
		AuraService.setPartyMode(Config.PARTY_MODE_SECONDS)
		Remotes.ShopError:FireClient(player, "PARTY MODE x2 started (dev sim) 🎉")
	else
		Remotes.ShopError:FireClient(player, "Unknown dev item")
	end
end

function DevShopService.init()
	Remotes.DevShopTry.OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" then
			return
		end
		if not gateOpen() then
			if not warned then
				warned = true
				warn("[DEV-SHOP] grant refused: gate is closed (needs DEV_SHOP_ENABLED + Studio)")
			end
			return
		end
		DevShopService.grant(player, key)
	end)
end

return DevShopService
