--!strict
-- LeaderboardService: global all-time top-aura board using OrderedDataStore,
-- refreshed periodically onto physical boards near spawn. Falls back silently
-- in Studio when API access is off.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local LeaderboardService = {}

local orderedStore
local weeklyStore
local ok = pcall(function()
	orderedStore = DataStoreService:GetOrderedDataStore("AuraFarmTop_v1", "allTime")
	weeklyStore = DataStoreService:GetOrderedDataStore("AuraFarmWeekly_v1", "weekly")
end)
local ENABLED = ok and orderedStore ~= nil

-- Weekly boards reset every Monday 00:00 UTC.
local function weekKey(): string
	local t = os.time()
	local days = math.floor(t / 86400)
	local dow = (days + 4) % 7 -- 1970-01-01 was a Thursday
	local monday = days - ((dow - 1) % 7)
	return "w" .. monday
end

local REFRESH_SECONDS = 60
local BOARD_SIZE = 10

local boardModels: { Model } = {}
local allTimeList: TextLabel?
local weeklyList: TextLabel?

local function buildBoardPart(position: Vector3, titleText: string)
	local model = Instance.new("Model")
	model.Name = "Leaderboard"

	local panel = Instance.new("Part")
	panel.Name = "Panel"
	panel.Size = Vector3.new(10, 12, 1)
	panel.Position = position
	panel.Anchored = true
	panel.Color = Color3.fromRGB(30, 30, 40)
	panel.Parent = model

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 480)
	gui.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextScaled = true
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0.14, 0)
	list.Size = UDim2.new(1, 0, 0.86, 0)
	list.BackgroundTransparency = 1
	list.Text = "…"
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = true
	list.Parent = gui

	model.Parent = workspace
	table.insert(boardModels, model)
	return list
end

local function refresh()
	if not ENABLED then
		return
	end
	pcall(function()
		local pages = orderedStore:GetSortedAsync(false, BOARD_SIZE)
		local top = pages:GetCurrentPage()
		local lines = {}
		for rank, entry in top do
			local name = "???"
			local okName = pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key) or 0)
			end)
			if not okName then
				name = "Player " .. entry.key
			end
			table.insert(lines, ("#%d  %s — %s"):format(rank, name, tostring(entry.value)))
		end
		local text = table.concat(lines, "\n")
		if allTimeList then
			allTimeList.Text = text ~= "" and text or "Nobody has aura yet 💀"
		end
	end)
end

local function refreshWeekly()
	if not ENABLED then
		return
	end
	pcall(function()
		local key = weekKey()
		-- Fetch extra and filter to the current week's prefixed keys.
		local pages = weeklyStore:GetSortedAsync(false, BOARD_SIZE * 4)
		local top = pages:GetCurrentPage()
		local lines = {}
		local shown = 0
		for _, entry in top do			if shown >= BOARD_SIZE then
				break
			end
			if string.sub(entry.key, 1, #key + 1) ~= key .. "_" then
				continue
			end
			local name = "???"
			local okName = pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key) or 0)
			end)
			if not okName then
				name = "Player " .. entry.key
			end
			table.insert(lines, ("#%d  %s — %s"):format(shown, name, tostring(entry.value)))
			shown += 1
		end
		local text = table.concat(lines, "\n")
		if weeklyList then
			weeklyList.Text = text ~= "" and text or "New week, new aura 📅"
		end
	end)
end

function LeaderboardService.init()
	-- Physical boards
	local spawnPos = MapService.getLocation("spawn") or Vector3.zero
	allTimeList = buildBoardPart(spawnPos + Vector3.new(-14, 6, -8), "🏆 TOP AURA")
	weeklyList = buildBoardPart(spawnPos + Vector3.new(14, 6, -8), "📅 WEEKLY TOP")

	-- Periodic save of every player's aura + board refresh.
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			if ENABLED then
				local key = weekKey()
				for _, player in Players:GetPlayers() do
					local profile = DataService.getProfile(player)
					if profile then
						pcall(function()
							orderedStore:SetAsync(tostring(player.UserId), profile.aura)
							weeklyStore:SetAsync(key .. "_" .. tostring(player.UserId), profile.aura)
						end)
					end
				end
			end
			refresh()
			refreshWeekly()
		end
	end)
end

return LeaderboardService
