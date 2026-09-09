--!strict
-- PoseController.client.lua: pose input (P on PC, on-screen button on mobile),
-- pose wheel UI. The server owns pose state and broadcasts PoseStarted/
-- PoseStopped; joint rendering happens in PoseRenderer.client (client-side
-- Transform writes — AnimationConstraint Transforms do not replicate).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local poseWheelOpen = false
local currentPose: string? = nil
local ownedPoses: { [string]: boolean } = { tpose = true, wave = true } -- defaults; SyncUnlocked refines it

-- ── Pose wheel UI ───────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmPoseWheel"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

local wheel = Instance.new("Frame")
wheel.Name = "PoseWheel"
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.new(0.5, 0, 0.5, 0)
-- Scroll frame holds the pose buttons; the outer wheel is just the panel.
-- With 11 poses a fixed 420px panel overflowed (buttons clipped past the
-- circle — the "half the wheel is invisible" effect).
wheel.Size = UDim2.new(0, 340, 0, 480)
wheel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
wheel.BackgroundTransparency = 0.2
wheel.Visible = false
wheel.Parent = screenGui

local wheelCorner = Instance.new("UICorner")
wheelCorner.CornerRadius = UDim.new(1, 0)
wheelCorner.Parent = wheel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "POSE WHEEL"
title.TextColor3 = Color3.fromRGB(255, 200, 60)
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.Parent = wheel

-- Scrollable button area (below the title, above the footer).
local poseScroll = Instance.new("ScrollingFrame")
poseScroll.Name = "PoseScroll"
poseScroll.Position = UDim2.new(0, 8, 0, 46)
poseScroll.Size = UDim2.new(1, -16, 1, -86)
poseScroll.BackgroundTransparency = 1
poseScroll.BorderSizePixel = 0
poseScroll.ScrollBarThickness = 6
poseScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
poseScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
poseScroll.Parent = wheel

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.FillDirection = Enum.FillDirection.Vertical
scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
scrollLayout.Padding = UDim.new(0, 6)
scrollLayout.Parent = poseScroll

local function closeWheel()
	wheel.Visible = false
	poseWheelOpen = false
end

local function openWheel()
	wheel.Visible = true
	poseWheelOpen = true
end

local footer = Instance.new("TextLabel")
footer.Name = "WheelFooter"
footer.Position = UDim2.new(0, 0, 1, -34)
footer.Size = UDim2.new(1, 0, 0, 28)
footer.BackgroundTransparency = 1
footer.Text = "P = POSE WHEEL  ·  B = SHOP"
footer.TextColor3 = Color3.fromRGB(200, 200, 220)
footer.Font = Enum.Font.GothamBold
footer.TextSize = 14
footer.Parent = wheel

-- Locked poses tell you WHY nothing happened instead of just closing the
-- wheel (the old silent close read as "this button doesn't work").
local function onPoseButton(pose)
	return function()
		if pose.cost > 0 and not ownedPoses[pose.id] then
			footer.Text = ("🔒 %s costs %d aura — press B to buy it!"):format(pose.name, pose.cost)
			task.delay(2.5, function()
				if footer.Text:find(pose.name, 1, true) then
					footer.Text = "P = POSE WHEEL  ·  B = SHOP"
				end
			end)
			return -- keep the wheel open
		end
		if currentPose == pose.id then
			currentPose = nil
			Remotes.StopPose:FireServer()
		else
			currentPose = pose.id
			Remotes.RequestPose:FireServer(pose.id)
		end
		closeWheel()
	end
end

-- Tier order (strongest first), not alphabetical — reads like a progression.
local sortedPoses: { Config.Pose } = {}
for _, pose in Config.POSES do
	table.insert(sortedPoses, pose)
end
table.sort(sortedPoses, function(a, b)
	if a.tier ~= b.tier then
		return a.tier > b.tier
	end
	return a.cost < b.cost
end)

-- The wheel lists ONLY owned poses (locked ones live in the SHOP; the old
-- full list read as a wall of buttons that "didn't work"). Rebuilt from the
-- sorted pool whenever ownership changes.
local function buildWheelButtons()
	for _, child in poseScroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local anyOwned = false
	for _, pose in sortedPoses do
		if not ownedPoses[pose.id] then
			continue
		end
		anyOwned = true
		local btn = Instance.new("TextButton")
		btn.Name = "Pose_" .. pose.id
		btn.Size = UDim2.new(0, 290, 0, 40)
		btn.BackgroundColor3 = pose.cost == 0 and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(90, 60, 200)
		btn.Text = pose.name .. (pose.tier >= 3 and " ⭐" or "")
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.Parent = poseScroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = btn
		btn.MouseButton1Click:Connect(onPoseButton(pose))
	end
	if not anyOwned then
		local empty = Instance.new("TextLabel")
		empty.Name = "EmptyWheel"
		empty.Size = UDim2.new(0, 290, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "no poses yet — press B to buy"
		empty.TextColor3 = Color3.fromRGB(170, 170, 190)
		empty.Font = Enum.Font.GothamBold
		empty.TextScaled = true
		empty.Parent = poseScroll
	end
end

-- Initial paint with the defaults; ownership events (below) rebuild it.
buildWheelButtons()

-- Mobile-friendly action button for the wheel toggle.
ContextActionService:BindAction("OpenPoseWheel", function(_, state)
	if state == Enum.UserInputState.Begin then
		if poseWheelOpen then
			closeWheel()
		else
			openWheel()
		end
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.P)
ContextActionService:SetTitle("OpenPoseWheel", "POSE")

player.CharacterAdded:Connect(function()
	currentPose = nil
end)

Remotes.SyncUnlocked.OnClientEvent:Connect(function(ids: { string })
	for _, id in ids do
		ownedPoses[id] = true
	end
	buildWheelButtons()
end)
Remotes.PoseUnlocked.OnClientEvent:Connect(function(poseId: string)
	ownedPoses[poseId] = true
	buildWheelButtons()
end)

return nil
