--!strict
-- Hud.client.lua: aura counter, hype readout, and full-screen stamps
-- (judge verdicts, MOGGED banner, duel banners).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── Controls hint ───────────────────────────────────────────────
local hint = Instance.new("TextLabel")
hint.Name = "ControlsHint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 86) -- centered, just below the aura counter (ends y=74)
hint.Size = UDim2.new(0, 520, 0, 30)
hint.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
hint.BackgroundTransparency = 0.35
hint.Text = "P = POSE   ·   B = SHOP   ·   M = MOG ⚔️ (bots!)   ·   T = TRAIN 🥋"
hint.TextColor3 = Color3.fromRGB(255, 235, 150)
hint.TextTransparency = 0
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.Font = Enum.Font.GothamBold
hint.TextSize = 17
hint.Parent = screenGui
local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hint

-- Version stamp: makes stale-place confusion instantly visible (the user
-- kept playing hours-old sessions whose UI predated several fixes).
local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "VersionStamp"
versionLabel.AnchorPoint = Vector2.new(0, 1)
versionLabel.Position = UDim2.new(0, 8, 1, -6)
versionLabel.Size = UDim2.new(0, 160, 0, 20)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v" .. Config.VERSION .. " · AURA FARM pilot"
versionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
versionLabel.TextTransparency = 0.4
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 13
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = screenGui

-- ── Aura counter ────────────────────────────────────────────────
local auraFrame = Instance.new("Frame")
auraFrame.AnchorPoint = Vector2.new(0.5, 0)
auraFrame.Position = UDim2.new(0.5, 0, 0, 10)
auraFrame.Size = UDim2.new(0, 260, 0, 64)
auraFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
auraFrame.BackgroundTransparency = 0.25
auraFrame.Parent = screenGui

local auraCorner = Instance.new("UICorner")
auraCorner.CornerRadius = UDim.new(0, 14)
auraCorner.Parent = auraFrame

local auraLabel = Instance.new("TextLabel")
auraLabel.Size = UDim2.new(1, 0, 0.6, 0)
auraLabel.BackgroundTransparency = 1
auraLabel.Text = "0 AURA"
auraLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
auraLabel.Font = Enum.Font.FredokaOne
auraLabel.TextScaled = true
auraLabel.Parent = auraFrame

local subLabel = Instance.new("TextLabel")
subLabel.Position = UDim2.new(0, 0, 0.62, 0)
subLabel.Size = UDim2.new(1, 0, 0.38, 0)
subLabel.BackgroundTransparency = 1
subLabel.Text = "pose to farm aura"
subLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
subLabel.Font = Enum.Font.GothamBold
subLabel.TextScaled = true
subLabel.Parent = auraFrame

-- ── Stamps layer (verdicts / MOGGED) ────────────────────────────
local function bigStamp(text: string, color: Color3, seconds: number)
	local stamp = Instance.new("TextLabel")
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.new(0.5, 0, 0.35, 0)
	stamp.Size = UDim2.new(0, 520, 0, 110)
	stamp.BackgroundTransparency = 1
	stamp.Text = text
	stamp.TextColor3 = color
	stamp.Font = Enum.Font.FredokaOne
	stamp.TextScaled = true
	stamp.Rotation = math.random(-8, 8)
	stamp.Parent = screenGui

	stamp.Size = UDim2.new(0, 700, 0, 150)
	local shrink = TweenService:Create(
		stamp,
		TweenInfo.new(0.18, Enum.EasingStyle.Back),
		{ Size = UDim2.new(0, 520, 0, 110) }
	)
	shrink:Play()

	task.delay(seconds, function()
		local fade = TweenService:Create(stamp, TweenInfo.new(0.4), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		stamp:Destroy()
	end)
end

-- ── Remote wiring ───────────────────────────────────────────────
Remotes.AuraChanged.OnClientEvent:Connect(function(newAura: number, gained: number)
	auraLabel.Text = Util.abbrev(newAura) .. " AURA"
	if gained > 0 then
		subLabel.Text = "+" .. gained .. " 🔥"
		task.delay(1, function()
			if subLabel.Text == "+" .. gained .. " 🔥" then
				subLabel.Text = "pose to farm aura"
			end
		end)
	elseif gained < 0 then
		-- A purchase: show the deduction instead of a fake earn.
		subLabel.Text = Util.abbrev(gained) .. " 🛒"
		task.delay(1, function()
			if subLabel.Text == Util.abbrev(gained) .. " 🛒" then
				subLabel.Text = "pose to farm aura"
			end
		end)
	end
end)

-- Safety net: keep the big counter in sync with the authoritative value even
-- if an AuraChanged for it is missed (e.g. purchases before this HUD loaded).
local function syncFromLeaderstats()
	local stats = player:FindFirstChild("leaderstats")
	local auraStat = stats and stats:FindFirstChild("Aura")
	if auraStat then
		auraLabel.Text = Util.abbrev(auraStat.Value) .. " AURA"
	end
end
local auraStat = player:WaitForChild("leaderstats"):WaitForChild("Aura") :: IntValue
auraStat.Changed:Connect(function()
	syncFromLeaderstats()
end)
syncFromLeaderstats()

Remotes.JudgeStamp.OnClientEvent:Connect(function(judgeIndex: number, stamp: string, score: number, forPlayer: Player)
	if forPlayer ~= player then
		return
	end
	local info = Util.stampInfo(stamp)
	bigStamp(("%s %s/10"):format(info.emoji, Util.round(score)), info.color, 1.6)
end)

Remotes.DuelEnded.OnClientEvent:Connect(function(youWon: boolean, stolenAura: number, opponentName: string)
	if youWon then
		local bonus = ""
		if stolenAura > 0 then
			bonus = ("  +%s AURA"):format(Util.abbrev(stolenAura))
		end
		bigStamp("W 🔥 MOGGED " .. opponentName .. bonus, Color3.fromRGB(255, 200, 60), 3)
	else
		local lost = stolenAura > 0 and ("  -%s AURA"):format(Util.abbrev(stolenAura)) or ""
		bigStamp("💀 MOGGED by " .. opponentName .. lost, Color3.fromRGB(170, 80, 255), 3)
	end
end)

Remotes.PartyModeStarted.OnClientEvent:Connect(function(seconds: number)
	bigStamp("🎉 PARTY MODE x2 — " .. seconds .. "s", Color3.fromRGB(255, 100, 200), 3)
end)

return nil
