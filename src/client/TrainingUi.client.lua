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

-- Owned poses in picker order; index i is picked by pressing the key i.
local pickerPoses: { any } = {}

local function buildPicker()
	table.clear(pickerPoses)
	for _, child in picker:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, pose in Config.POSES do
		if owned[pose.id] then
			table.insert(pickerPoses, pose)
			local btn = Instance.new("TextButton")
			btn.Name = "Train_" .. pose.id
			btn.Size = UDim2.new(0, 92, 0, 44)
			btn.BackgroundColor3 = Color3.fromRGB(60, 90, 70)
			btn.Text = pose.name
			-- Number badge: pressing that digit picks this pose (same as click).
			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(0, 18, 0, 18)
			badge.Position = UDim2.new(0, 4, 0, 4)
			badge.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
			badge.BackgroundTransparency = 0.25
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 12
			badge.Text = tostring(#pickerPoses)
			badge.Parent = btn
			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(1, 0)
			badgeCorner.Parent = badge
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

-- Digits 1..9 pick the Nth shown pose while a round is open (the same packet
-- as clicking the button) — keyboard play for the training picker. Bound after
-- buildPicker/showBanner exist so the handler captures real upvalues. Digit
-- comes from the key's name ("One".."Nine"), which reads the same in every
-- environment that names KeyCodes the Roblox way.
local DIGIT_INDEX = {
	One = 1, Two = 2, Three = 3, Four = 4, Five = 5,
	Six = 6, Seven = 7, Eight = 8, Nine = 9,
}
ContextActionService:BindAction("TrainingPickDigit", function(_, state, input)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local keyName = input and input.KeyCode and input.KeyCode.Name
	local digit = keyName and DIGIT_INDEX[keyName]
	if digit == nil then
		return Enum.ContextActionResult.Pass
	end
	local pose = pickerPoses[digit]
	if pose == nil then
		return Enum.ContextActionResult.Pass
	end
	Remotes.TrainingPick:FireServer(pose.id)
	showBanner("POSE LOCKED: " .. pose.name, 1.2, Color3.fromRGB(120, 255, 140))
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine)

Remotes.TrainingRound.OnClientEvent:Connect(function(seconds: number)
	showBanner("🥋 TRAINING — PICK A POSE! (" .. seconds .. "s) — click or press 1-9", seconds)
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
