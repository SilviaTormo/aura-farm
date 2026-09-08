--!strict
-- DataService: loads/saves player aura + unlocked poses.
-- Falls back gracefully in Studio when DataStore API access is off.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.AuraFarmShared.Config)

local DataService = {}

local store
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore("AuraFarm_v1")
end)
local DATA_ENABLED = ok and store ~= nil

if not DATA_ENABLED then
	warn("[AuraFarm] DataStore unavailable (enable Studio API access). Session-only data.")
end

export type Profile = {
	aura: number,
	unlocked: { string },
	wins: number,
	losses: number,
	hasDrip: boolean,
}

local profiles: { [number]: Profile } = {}
local sessionLocks: { [number]: boolean } = {}

-- Keep the visible leaderstats value in lockstep with the profile on EVERY
-- mutation. (Each caller used to re-sync manually and the purchase path
-- forgot — the player saw a stale aura counter for seconds.)
local function syncStats(player: Player, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
	if auraStat then
		auraStat.Value = value
	end
end

local function defaultProfile(): Profile
	return {
		aura = Config.STARTING_AURA,
		unlocked = { "tpose", "wave" },
		wins = 0,
		losses = 0,
		hasDrip = false,
	}
end

function DataService.getProfile(player: Player): Profile
	return profiles[player.UserId]
end

function DataService.addAura(player: Player, delta: number): number
	local profile = profiles[player.UserId]
	if not profile then
		return 0
	end
	profile.aura = math.max(0, math.floor(profile.aura + delta))
	syncStats(player, profile.aura)
	return profile.aura
end

function DataService.spendAura(player: Player, amount: number): boolean
	local profile = profiles[player.UserId]
	if not profile or profile.aura < amount then
		return false
	end
	profile.aura -= amount
	syncStats(player, profile.aura)
	return true
end

function DataService.unlockPose(player: Player, poseId: string)
	local profile = profiles[player.UserId]
	if profile and not table.find(profile.unlocked, poseId) then
		table.insert(profile.unlocked, poseId)
	end
end

function DataService.isUnlocked(player: Player, poseId: string): boolean
	local profile = profiles[player.UserId]
	return profile ~= nil and table.find(profile.unlocked, poseId) ~= nil
end

function DataService.setHasDrip(player: Player, value: boolean)
	local profile = profiles[player.UserId]
	if profile then
		profile.hasDrip = value
	end
end

function DataService.addWin(player: Player, won: boolean)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	if won then
		profile.wins += 1
	else
		profile.losses += 1
	end
end

local function load(player: Player): Profile
	if not DATA_ENABLED then
		return defaultProfile()
	end
	local loaded
	local okLoad = pcall(function()
		loaded = store:GetAsync("player_" .. player.UserId)
	end)
	if okLoad and type(loaded) == "table" then
		local profile = defaultProfile()
		profile.aura = tonumber(loaded.aura) or 0
		profile.wins = tonumber(loaded.wins) or 0
		profile.losses = tonumber(loaded.losses) or 0
		if type(loaded.unlocked) == "table" then
			for _, id in loaded.unlocked do
				table.insert(profile.unlocked, tostring(id))
			end
		end
		profile.hasDrip = loaded.hasDrip == true
		-- Seed the session-lock baseline from the loaded record: without this,
		-- the first save of every returning player would see old.lock > 0 and
		-- silently abort (total session loss).
		sessionLocks[player.UserId] = tonumber(loaded.lock) or 0
		return profile
	end
	return defaultProfile()
end

local function save(player: Player)
	if not DATA_ENABLED then
		return
	end
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function(old)
			-- Session-lock style guard: never overwrite a newer concurrent save.
			if old and old.lock and old.lock > (sessionLocks[player.UserId] or 0) then
				return nil
			end
			local now = os.time()
			sessionLocks[player.UserId] = now
			return {
				aura = profile.aura,
				unlocked = profile.unlocked,
				wins = profile.wins,
				losses = profile.losses,
				hasDrip = profile.hasDrip,
				lock = now,
			}
		end, 30)
	end)
end

local function onPlayerAdded(player: Player)
	profiles[player.UserId] = load(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	profiles[player.UserId] = nil
	sessionLocks[player.UserId] = nil
end)

game:BindToClose(function()
	if not DATA_ENABLED then
		return
	end
	for _, player in Players:GetPlayers() do
		save(player)
	end
end)

function DataService.init()
	-- Players who joined before this script ran (Studio fast-join race).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
