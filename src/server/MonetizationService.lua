--!strict
-- MonetizationService: gamepasses + developer products.
-- Passes grant: 2x Aura, VIP Plaza (rooftop), Sigma Pose Pack (free SIGMA
-- pose), Golden Drip Bundle (+50% aura rate). Products: Mog Shield (1h),
-- Cooldown Refill, server-wide Party Mode.
-- With id = 0 in Config the purchase prompt is skipped ("coming soon").

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)
local PoseService = require(script.Parent.PoseService)

local MonetizationService = {}

-- PurchaseId dedupe (receipts can be delivered more than once).
local processedReceipts: { [number]: boolean } = {}

local function auraStat(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Aura") :: IntValue?
end

local function applyPass(player: Player, passKey: string)
	if passKey == "DoubleAura" then
		local stat = auraStat(player)
		if stat then
			stat:SetAttribute("DoubleAura", true)
		end
	elseif passKey == "VipPlaza" then
		local stat = auraStat(player)
		if stat then
			stat:SetAttribute("VipPlaza", true)
		end
	elseif passKey == "SigmaPosePack" then
		DataService.unlockPose(player, "sigma")
		Remotes.PoseUnlocked:FireClient(player, "sigma")
	elseif passKey == "GoldenDripBundle" then
		DataService.setHasDrip(player, true)
	end
end

local function grantProduct(player: Player, productKey: string): boolean
	if productKey == "MogShield" then
		local stat = auraStat(player)
		if stat then
			stat:SetAttribute("MogShieldUntil", os.time() + Config.MOG_SHIELD_SECONDS)
		end
		return true
	elseif productKey == "CooldownRefill" then
		PoseService.clearCooldowns(player)
		return true
	elseif productKey == "PartyMode" then
		AuraService.setPartyMode(Config.PARTY_MODE_SECONDS)
		return true
	end
	return false
end

local function buyPass(player: Player, passKey: string)
	local id = Config.GAMEPASSES[passKey]
	if not id or id == 0 then
		local infoName = passKey
		for _, info in Config.PASS_INFO do
			if info.key == passKey then
				infoName = info.name
				break
			end
		end
		Remotes.ShopError:FireClient(player, infoName .. " — coming soon 💀")
		return
	end
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, id)
	end)
	if not ok then
		Remotes.ShopError:FireClient(player, "Couldn't open the purchase prompt.")
	end
end

local function buyProduct(player: Player, productKey: string)
	local id = Config.DEV_PRODUCTS[productKey]
	if not id or id == 0 then
		Remotes.ShopError:FireClient(player, "Coming soon 💀")
		return
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	if not ok then
		Remotes.ShopError:FireClient(player, "Couldn't open the purchase prompt.")
	end
end

local function checkExistingPasses(player: Player)
	for passKey, id in Config.GAMEPASSES do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				applyPass(player, passKey)
			end
		end
	end
end

function MonetizationService.init()
	-- Shop UI buttons.
	Remotes.BuyPass.OnServerEvent:Connect(buyPass)
	Remotes.BuyProduct.OnServerEvent:Connect(buyProduct)

	-- Legacy remote kept for compatibility: same as buying Party Mode.
	Remotes.RequestPartyMode.OnServerEvent:Connect(function(player)
		buyProduct(player, "PartyMode")
	end)

	-- In-game purchases (prompt finished while playing).
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for passKey, id in Config.GAMEPASSES do
			if id == passId then
				applyPass(player, passKey)
				Remotes.ShopError:FireClient(player, "Purchased! Enjoy 🔥")
			end
		end
	end)

	-- Receipt processing for dev products.
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		if processedReceipts[receiptInfo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		for productKey, id in Config.DEV_PRODUCTS do
			if id == receiptInfo.ProductId then
				if grantProduct(player, productKey) then
					processedReceipts[receiptInfo.PurchaseId] = true
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- On join: check already-owned passes. Delayed a few seconds so the
	-- DataService profile is loaded before SigmaPosePack/Drip grants apply.
	local function checkPassesLater(player: Player)
		task.delay(5, function()
			if player.Parent then
				checkExistingPasses(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(checkPassesLater)
	-- Players who joined before this script ran (Studio fast-join race).
	for _, player in Players:GetPlayers() do
		checkPassesLater(player)
	end
end

return MonetizationService
