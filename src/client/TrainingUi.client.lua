--!strict
-- TrainingUi.client.lua: the training pad round UI. Shows the countdown,
-- a pose picker (unlocked poses only), and the result banner with stamps.
-- Mirrors DuelUi's picker/banner pattern so the UX stays consistent.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local owned: { [string]: boolean } = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmTraining"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.Parent = player:WaitForChild("PlayerGui")

-- T key: open a training round from anywhere (the pad also works on touch).
local ContextActionService = game:GetService("ContextActionService")
local busy = false
ContextActionService:BindAction("OpenTraining", function(_, state)
	if state ~= Enum.UserInputState.Begin or busy then
		return Enum.ContextActionResult.Pass
	end
	busy = true
	task.delay(12, function()
		busy = false
	end)
	Remotes.TrainingStart:FireServer()
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.T)
ContextActionService:SetTitle("OpenTraining", "TRAIN")

-- ── Banner ──────────────────────────────────────────────────────
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.new(0.5, 0, 0.3, 0)
banner.Size = UDim2.new(0, 560, 0, 64)
banner.BackgroundTransparency = 1
banner.Text = ""
banner.TextColor3 = Color3.fromRGB(120, 255, 140)
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.Parent = screenGui

local function showBanner(text: string, seconds: number, color: Color3?)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(120, 255, 140)
	banner.Size = UDim2.new(0, 700, 0, 80)
	TweenService:Create(banner, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 560, 0, 64),
	}):Play()
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Text = ""
		end
	end)
end

-- ── Pose picker (same pattern as DuelUi) ────────────────────────
local picker = Instance.new("Frame")
picker.AnchorPoint = Vector2.new(0.5, 1)
picker.Position = UDim2.new(0.5, 0, 1, -20)
picker.Size = UDim2.new(0, 520, 0, 60)
picker.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
picker.BackgroundTransparency = 0.2
picker.Visible = false
picker.Parent = screenGui
local pickerCorner = Instance.new("UICorner")
pickerCorner.CornerRadius = UDim.new(0, 12)
pickerCorner.Parent = picker
local pickerLayout = Instance.new("UIListLayout")
pickerLayout.FillDirection = Enum.FillDirection.Horizontal
pickerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
pickerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pickerLayout.Padding = UDim.new(0, 8)
pickerLayout.Parent = picker

local function buildPicker()
	for _, child in picker:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, pose in Config.POSES do
		if owned[pose.id] then
			local btn = Instance.new("TextButton")
			btn.Name = "Train_" .. pose.id
			btn.Size = UDim2.new(0, 92, 0, 44)
			btn.BackgroundColor3 = Color3.fromRGB(60, 90, 70)
			btn.Text = pose.name
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextScaled = true
			btn.Parent = picker
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 8)
			c.Parent = btn
			btn.MouseButton1Click:Connect(function()
				Remotes.TrainingPick:FireServer(pose.id)
				showBanner("POSE LOCKED: " .. pose.name, 1.2, Color3.fromRGB(120, 255, 140))
			end)
		end
	end
end

Remotes.TrainingRound.OnClientEvent:Connect(function(seconds: number)
	showBanner("🥋 TRAINING — PICK A POSE! (" .. seconds .. "s)", seconds)
	buildPicker()
	picker.Visible = true
	task.delay(seconds, function()
		picker.Visible = false
	end)
end)

Remotes.TrainingResult.OnClientEvent:Connect(function(
	yourScore: number, botScore: number, yourStamp: string, botStamp: string,
	won: boolean, auraWon: number
)
	local reward = won and ("  +%d aura 🥋"):format(auraWon) or "  (no aura)"
	local color = won and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 90, 90)
	showBanner(
		("🥋 you %.1f %s  vs  %.1f %s bot%s"):format(yourScore, yourStamp, botScore, botStamp, reward),
		3,
		color
	)
end)

Remotes.SyncUnlocked.OnClientEvent:Connect(function(ids: { string })
	for _, id in ids do
		owned[id] = true
	end
end)

return nil
