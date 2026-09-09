--!strict
-- EventService: variable rewards so farming never goes on autopilot.
-- Two event kinds on a random timer:
--   Aura Rain  — global x2 aura for AURA_RAIN_SECONDS (banner + rain FX flag).
--   Golden Chest — a chest part spawns somewhere on the map; first player to
--   touch it wins CHEST_REWARD_MIN..MAX aura.
-- Events never overlap; the next one is scheduled when one finishes.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local EventService = {}

local auraRainEndsAt = 0
local eventRunning = false

function EventService.isAuraRain(): boolean
	return os.clock() < auraRainEndsAt
end

local function randomMapPoint(): Vector3
	-- Walkable plaza points (fountain center / arena / spawn), slight jitter
	-- so the chest isn't always in the identical pixel.
	local anchors = {
		Vector3.new(0, 3.5, 0), -- fountain plaza
		Vector3.new(70, 2, 0), -- arena
		Vector3.new(0, 3.5, 18), -- spawn
		Vector3.new(-50, 2, 0), -- stage
	}
	local base = anchors[math.random(#anchors)]
	return base + Vector3.new(math.random(-6, 6), 0.5, math.random(-6, 6))
end

local function runAuraRain()
	eventRunning = true
	auraRainEndsAt = os.clock() + Config.AURA_RAIN_SECONDS
	Remotes.EventStarted:FireAllClients("auraRain", Config.AURA_RAIN_SECONDS)
	print(("[EVENT] Aura Rain started: global x2 aura for %ds"):format(Config.AURA_RAIN_SECONDS))
	task.delay(Config.AURA_RAIN_SECONDS, function()
		print("[EVENT] Aura Rain ended")
		eventRunning = false
	end)
end

local function runChest()
	eventRunning = true
	local reward = math.random(Config.CHEST_REWARD_MIN, Config.CHEST_REWARD_MAX)
	local chest = Instance.new("Part")
	chest.Name = "GoldenChest"
	chest.Shape = Enum.PartType.Ball
	chest.Size = Vector3.new(3, 3, 3)
	chest.Position = randomMapPoint()
	chest.Color = Color3.fromRGB(255, 200, 60)
	chest.Material = Enum.Material.Neon
	chest.Anchored = true
	chest.Parent = workspace
	Remotes.ChestSpawned:FireAllClients(chest)
	print(("[EVENT] Golden Chest spawned at %s (worth %d aura)"):format(tostring(chest.Position), reward))

	local conn
	conn = chest.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("InDuel") == true then
			return
		end
		conn:Disconnect()
		local newAura = DataService.addAura(player, reward)
		Remotes.AuraChanged:FireClient(player, newAura, reward)
		local stats = player:FindFirstChild("leaderstats")
		local auraStat = stats and stats:FindFirstChild("Aura")
		if auraStat then
			auraStat.Value = newAura
		end
		Remotes.ChestOpened:FireAllClients(player, reward)
		print(("[EVENT] %s opened the Golden Chest (+%d aura)"):format(player.Name, reward))
		chest:Destroy()
		eventRunning = false
	end)
	-- Safety: if nobody finds it in 90s, despawn and let the loop move on.
	task.delay(90, function()
		if chest.Parent then
			conn:Disconnect()
			chest:Destroy()
			print("[EVENT] Golden Chest despawned unclaimed")
			eventRunning = false
		end
	end)
end

function EventService.init()
	task.spawn(function()
		-- First event a couple of minutes in, then random gaps.
		task.wait(Config.EVENT_MIN_GAP)
		while true do
			if math.random() < 0.5 then
				runAuraRain()
			else
				runChest()
			end
			-- Wait for the event to finish, then a random gap until the next.
			while eventRunning do
				task.wait(1)
			end
			task.wait(math.random(Config.EVENT_MIN_GAP, Config.EVENT_MAX_GAP))
		end
	end)
end

return EventService
