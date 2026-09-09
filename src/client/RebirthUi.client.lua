--!strict
-- RebirthUi.client.lua: R opens the rebirth confirm prompt (cost + the
-- multiplier you'd walk away with), the HUD chip shows current prestige,
-- and full-screen banners announce live events (Aura Rain / Golden Chest).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmRebirth"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── HUD chip: current rebirths + multiplier ─────────────────────
local chip = Instance.new("TextLabel")
chip.Name = "RebirthChip"
chip.AnchorPoint = Vector2.new(1, 0)
chip.Position = UDim2.new(1, -12, 0, 8)
chip.Size = UDim2.new(0, 190, 0, 30)
chip.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
chip.BackgroundTransparency = 0.2
chip.Text = "🔁 0 REBIRTHS · x1.00 aura"
chip.TextColor3 = Color3.fromRGB(230, 180, 255)
chip.Font = Enum.Font.GothamBold
chip.TextScaled = true
chip.Parent = screenGui
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0, 10)
chipCorner.Parent = chip

local function formatMult(m: number): string
	return ("x%.2f"):format(m)
end

local function updateChip()
	local rebirths = 0
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Rebirths")
	if stat then
		rebirths = stat.Value
	end
	chip.Text = ("🔁 %d REBIRTHS · %s aura"):format(rebirths, formatMult(1 + rebirths * Config.REBIRTH_MULTIPLIER_STEP))
end

-- ── Confirm prompt ┊─────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name = "RebirthPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 380, 0, 240)
panel.BackgroundColor3 = Color3.fromRGB(24, 16, 36)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 52)
title.BackgroundTransparency = 1
title.Text = "🔁 REBIRTH"
title.TextColor3 = Color3.fromRGB(230, 180, 255)
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.Parent = panel

local info = Instance.new("TextLabel")
info.Position = UDim2.new(0, 16, 0, 56)
info.Size = UDim2.new(1, -32, 0, 110)
info.BackgroundTransparency = 1
info.Text = ""
info.TextColor3 = Color3.new(1, 1, 1)
info.Font = Enum.Font.Gotham
info.TextScaled = true
info.TextWrapped = true
info.Parent = panel

local yes = Instance.new("TextButton")
yes.AnchorPoint = Vector2.new(0.5, 1)
yes.Position = UDim2.new(0.3, 0, 1, -12)
yes.Size = UDim2.new(0, 150, 0, 46)
yes.BackgroundColor3 = Color3.fromRGB(140, 70, 220)
yes.Text = "REBIRTH 🔁"
yes.TextColor3 = Color3.new(1, 1, 1)
yes.Font = Enum.Font.GothamBold
yes.TextScaled = true
yes.Parent = panel
local yesCorner = Instance.new("UICorner")
yesCorner.CornerRadius = UDim.new(0, 10)
yesCorner.Parent = yes

local no = Instance.new("TextButton")
no.AnchorPoint = Vector2.new(0.5, 1)
no.Position = UDim2.new(0.72, 0, 1, -12)
no.Size = UDim2.new(0, 120, 0, 46)
no.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
no.Text = "Not yet"
no.TextColor3 = Color3.new(1, 1, 1)
no.Font = Enum.Font.GothamBold
no.TextScaled = true
no.Parent = panel
local noCorner = Instance.new("UICorner")
noCorner.CornerRadius = UDim.new(0, 10)
noCorner.Parent = no

local auraNow = 0
local function refreshInfo()
	local rebirths = 0
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Rebirths")
	if stat then
		rebirths = stat.Value
	end
	local cost = Config.REBIRTH_BASE_COST * (rebirths + 1)
	local nextMult = 1 + rebirths * Config.REBIRTH_MULTIPLIER_STEP + Config.REBIRTH_MULTIPLIER_STEP
	info.Text = ("Rebirth #%d costs %d aura.\n\nYou lose ALL your aura (poses and wins stay), but your aura gain becomes PERMANENT %s.\n\nYou have: %d aura\n[R] confirm · [Esc] cancel")
		:format(rebirths + 1, cost, formatMult(nextMult), auraNow)
	yes.BackgroundColor3 = auraNow >= cost and Color3.fromRGB(140, 70, 220) or Color3.fromRGB(80, 50, 60)
end

local function refreshAuraNow()
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Aura")
	auraNow = stat and stat.Value or 0
	if panel.Visible then
		refreshInfo()
	end
end

yes.MouseButton1Click:Connect(function()
	Remotes.RebirthRequest:FireServer()
	panel.Visible = false
end)
no.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

ContextActionService:BindAction("OpenRebirth", function(_, state)
	if state == Enum.UserInputState.Begin then
		if panel.Visible then
			-- R again = confirm (keyboard-only path; Esc or "Not yet" cancels).
			Remotes.RebirthRequest:FireServer()
			panel.Visible = false
		else
			refreshAuraNow()
			refreshInfo()
			panel.Visible = true
		end
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.R)
ContextActionService:SetTitle("OpenRebirth", "REBIRTH")

-- Esc closes the prompt without sinking the key when it's not open
-- (Roblox's own menu keeps working).
ContextActionService:BindAction("CloseRebirth", function(_, state)
	if state == Enum.UserInputState.Begin and panel.Visible then
		panel.Visible = false
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Escape)

-- ── Event banners ┊──────────────────────────────────────────────
local banner = Instance.new("TextLabel")
banner.Name = "EventBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 124)
banner.Size = UDim2.new(0, 560, 0, 34)
banner.BackgroundColor3 = Color3.fromRGB(30, 10, 50)
banner.BackgroundTransparency = 0.25
banner.Text = ""
banner.TextColor3 = Color3.fromRGB(255, 220, 120)
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.Visible = false
banner.Parent = screenGui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner

local bannerToken = 0
local function showBanner(text: string, seconds: number)
	bannerToken += 1
	local myToken = bannerToken
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if bannerToken == myToken then
			banner.Visible = false
		end
	end)
end

Remotes.EventStarted.OnClientEvent:Connect(function(kind, seconds)
	if kind == "auraRain" then
		showBanner("🌧️ AURA RAIN! x2 aura for everyone — " .. seconds .. "s!", math.min(seconds, 6))
	end
end)

Remotes.ChestSpawned.OnClientEvent:Connect(function()
	showBanner("💰 A GOLDEN CHEST appeared on the map! Find it first!", 5)
end)

Remotes.ChestOpened.OnClientEvent:Connect(function(who, auraWon)
	local name = typeof(who) == "Instance" and who:IsA("Player") and who.Name or "Someone"
	showBanner(("%s opened the Golden Chest! +%d aura 💰"):format(name, auraWon), 4)
end)

Remotes.RebirthDone.OnClientEvent:Connect(function(rebirths, multiplier)
	showBanner(("🔁 REBIRTH #%d! Permanent %s aura from now on"):format(rebirths, formatMult(multiplier)), 5)
	updateChip()
end)

-- ── Sync ┊───────────────────────────────────────────────────────
local stats = player:WaitForChild("leaderstats", 10)
if stats then
	local rebirthsStat = stats:WaitForChild("Rebirths", 10)
	if rebirthsStat then
		rebirthsStat.Changed:Connect(updateChip)
	end
	local auraStat = stats:WaitForChild("Aura", 10)
	if auraStat then
		auraStat.Changed:Connect(refreshAuraNow)
	end
end
updateChip()

return nil
