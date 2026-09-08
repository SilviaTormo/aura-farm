--!strict
-- DuelUi.client.lua: invite panel, round banners/countdown, and a quick
-- pose picker during duel rounds (only unlocked poses are clickable).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local player = Players.LocalPlayer

local owned: { [string]: boolean } = {}
local tallyYou, tallyThem = 0, 0

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmDuel"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── Invite panel ────────────────────────────────────────────────
local invite = Instance.new("Frame")
invite.AnchorPoint = Vector2.new(0.5, 0)
invite.Position = UDim2.new(0.5, 0, 0, 90)
invite.Size = UDim2.new(0, 320, 0, 110)
invite.BackgroundColor3 = Color3.fromRGB(30, 10, 40)
invite.Visible = false
invite.Parent = screenGui
local inviteCorner = Instance.new("UICorner")
inviteCorner.CornerRadius = UDim.new(0, 12)
inviteCorner.Parent = invite

local inviteText = Instance.new("TextLabel")
inviteText.Size = UDim2.new(1, 0, 0.5, 0)
inviteText.BackgroundTransparency = 1
inviteText.Text = ""
inviteText.TextColor3 = Color3.new(1, 1, 1)
inviteText.Font = Enum.Font.FredokaOne
inviteText.TextScaled = true
inviteText.Parent = invite

local acceptBtn = Instance.new("TextButton")
acceptBtn.Position = UDim2.new(0.05, 0, 0.55, 0)
acceptBtn.Size = UDim2.new(0.42, 0, 0.35, 0)
acceptBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
acceptBtn.Text = "MOG HIM ⚔️"
acceptBtn.TextColor3 = Color3.new(1, 1, 1)
acceptBtn.Font = Enum.Font.GothamBold
acceptBtn.TextScaled = true
acceptBtn.Parent = invite
local acceptCorner = Instance.new("UICorner")
acceptCorner.CornerRadius = UDim.new(0, 8)
acceptCorner.Parent = acceptBtn

local declineBtn = Instance.new("TextButton")
declineBtn.Position = UDim2.new(0.53, 0, 0.55, 0)
declineBtn.Size = UDim2.new(0.42, 0, 0.35, 0)
declineBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
declineBtn.Text = "scared 💀"
declineBtn.TextColor3 = Color3.new(1, 1, 1)
declineBtn.Font = Enum.Font.GothamBold
declineBtn.TextScaled = true
declineBtn.Parent = invite
local declineCorner = Instance.new("UICorner")
declineCorner.CornerRadius = UDim.new(0, 8)
declineCorner.Parent = declineBtn

local pendingDuelId: string? = nil

Remotes.DuelInvited.OnClientEvent:Connect(function(duelId: string, challengerName: string)
	pendingDuelId = duelId
	inviteText.Text = challengerName .. " wants to MOG you!"
	invite.Visible = true
	task.delay(15, function()
		if pendingDuelId == duelId then
			invite.Visible = false
			pendingDuelId = nil
		end
	end)
end)

acceptBtn.MouseButton1Click:Connect(function()
	if pendingDuelId then
		Remotes.AcceptDuel:FireServer(pendingDuelId)
		invite.Visible = false
		pendingDuelId = nil
	end
end)

declineBtn.MouseButton1Click:Connect(function()
	if pendingDuelId then
		Remotes.DeclineDuel:FireServer(pendingDuelId)
		invite.Visible = false
		pendingDuelId = nil
	end
end)

-- ── Round banner + quick pose picker ────────────────────────────
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.new(0.5, 0, 0.22, 0)
banner.Size = UDim2.new(0, 560, 0, 64)
banner.BackgroundTransparency = 1
banner.Text = ""
banner.TextColor3 = Color3.fromRGB(255, 200, 60)
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.Parent = screenGui

local function showBanner(text: string, seconds: number, color: Color3?)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 200, 60)
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

local picker = Instance.new("Frame")
picker.AnchorPoint = Vector2.new(0.5, 1)
picker.Position = UDim2.new(0.5, 0, 1, -20)
picker.Size = UDim2.new(0, 520, 0, 60)
picker.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
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
			btn.Name = "Pick_" .. pose.id
			btn.Size = UDim2.new(0, 92, 0, 44)
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
			btn.Text = pose.name
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.GothamBold
			btn.TextScaled = true
			btn.Parent = picker
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 8)
			c.Parent = btn
			btn.MouseButton1Click:Connect(function()
				Remotes.DuelPickPose:FireServer(pose.id)
				showBanner("POSE LOCKED: " .. pose.name, 1.2, Color3.fromRGB(120, 255, 140))
			end)
		end
	end
end

Remotes.DuelStarted.OnClientEvent:Connect(function(_duelId: string, opponentName: string)
	tallyYou, tallyThem = 0, 0
	showBanner("⚔️ DUEL vs " .. opponentName .. " — best of " .. Config.DUEL_ROUNDS, 3)
end)

Remotes.DuelRoundStart.OnClientEvent:Connect(function(round: number, totalRounds: number, seconds: number)
	showBanner(("ROUND %d/%d — PICK A POSE! (%ds)"):format(round, totalRounds, seconds), seconds)
	buildPicker()
	picker.Visible = true
	task.delay(seconds, function()
		picker.Visible = false
	end)
end)

Remotes.DuelVerdict.OnClientEvent:Connect(function(round: number, yourScore: number, theirScore: number, yourStamp: string, theirStamp: string)
	local youInfo = Util.stampInfo(yourStamp)
	local themInfo = Util.stampInfo(theirStamp)
	local won = yourScore > theirScore
	local lost = theirScore > yourScore
	if won then
		tallyYou += 1
	elseif lost then
		tallyThem += 1
	end
	local color = won and Color3.fromRGB(120, 255, 140) or (lost and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(220, 220, 220))
	showBanner(
		("%s %.1f  vs  %.1f %s   [you %d — %d them]  %s"):format(
			youInfo.emoji, yourScore, theirScore, themInfo.emoji,
			tallyYou, tallyThem,
			won and "ROUND WINS!" or (lost and "round lost" or "tie")
		),
		2,
		color
	)
end)

Remotes.SyncUnlocked.OnClientEvent:Connect(function(ids: { string })
	for _, id in ids do
		owned[id] = true
	end
end)

return nil
