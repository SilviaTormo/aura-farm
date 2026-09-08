--!strict
-- ChallengeUi.client.lua: how duels START. "MOG" button (M on PC, touch button
-- on mobile) opens a panel listing players within challenge range, each with
-- a one-click challenge. Fires the existing RequestDuel remote; the target
-- gets the accept/decline panel from DuelUi.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local player = Players.LocalPlayer

local CHALLENGE_RADIUS = 40 -- studs

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmChallenge"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 7
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── Challenge panel ─────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 340, 0, 360)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, 0, 0, 44)
heading.BackgroundTransparency = 1
heading.Text = "⚔️ MOG SOMEONE"
heading.TextColor3 = Color3.fromRGB(255, 200, 60)
heading.Font = Enum.Font.FredokaOne
heading.TextScaled = true
heading.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Position = UDim2.new(1, -40, 0, 8)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.new(0, 10, 0, 50)
scroll.Size = UDim2.new(1, -20, 1, -60)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = scroll

-- ── Feedback banner ─────────────────────────────────────────────
-- Duel errors arrive via ShopError; ShopUi only toasts them while the shop is
-- open, so this banner makes duel feedback visible at all times.
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.new(0.5, 0, 1, -90)
banner.Size = UDim2.new(0, 480, 0, 40)
banner.BackgroundColor3 = Color3.fromRGB(30, 10, 40)
banner.BackgroundTransparency = 0.3
banner.Text = ""
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Font = Enum.Font.GothamBold
banner.TextScaled = true
banner.Visible = false
banner.Parent = screenGui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner

local function showBanner(text: string)
	banner.Text = text
	banner.Visible = true
	task.delay(2.5, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

Remotes.ShopError.OnClientEvent:Connect(showBanner)

-- ── Nearby list ─────────────────────────────────────────────────
local function refreshList()
	-- Clear EVERYTHING except the UIListLayout. (The old loop only deleted
	-- Frames, so the "nobody to mog" TextLabel stacked a new copy every
	-- refresh tick — the pile-up from the live session.)
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local myChar = player.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local nearby: { Player } = {}
	if myRoot then
		for _, other in Players:GetPlayers() do
			if other == player then
				continue
			end
			local char = other.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - myRoot.Position).Magnitude <= CHALLENGE_RADIUS then
				table.insert(nearby, other)
			end
		end
	end

	if #nearby == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "EmptyRow"
		empty.Size = UDim2.new(1, -8, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "no players nearby — mog a rival 🤖 below"
		empty.TextColor3 = Color3.fromRGB(170, 170, 190)
		empty.Font = Enum.Font.GothamBold
		empty.TextScaled = true
		empty.Parent = scroll
	end

	for _, other in nearby do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		row.Parent = scroll
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 10, 0, 4)
		nameLabel.Size = UDim2.new(0.6, 0, 0.55, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = other.DisplayName
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local auraLabel = Instance.new("TextLabel")
		auraLabel.Position = UDim2.new(0, 10, 0.55, 0)
		auraLabel.Size = UDim2.new(0.6, 0, 0.4, 0)
		auraLabel.BackgroundTransparency = 1
		local stats = other:FindFirstChild("leaderstats")
		local auraStat = stats and stats:FindFirstChild("Aura")
		auraLabel.Text = auraStat and ((Util.abbrev(auraStat.Value)) .. " aura") or "?"
		auraLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		auraLabel.Font = Enum.Font.Gotham
		auraLabel.TextScaled = true
		auraLabel.TextXAlignment = Enum.TextXAlignment.Left
		auraLabel.Parent = row

		local challenge = Instance.new("TextButton")
		challenge.AnchorPoint = Vector2.new(1, 0.5)
		challenge.Position = UDim2.new(1, -8, 0.5, 0)
		challenge.Size = UDim2.new(0, 110, 0, 40)
		challenge.BackgroundColor3 = Color3.fromRGB(170, 80, 255)
		challenge.Text = "MOG HIM ⚔️"
		challenge.TextColor3 = Color3.new(1, 1, 1)
		challenge.Font = Enum.Font.GothamBold
		challenge.TextScaled = true
		challenge.Parent = row
		local challengeCorner = Instance.new("UICorner")
		challengeCorner.CornerRadius = UDim.new(0, 8)
		challengeCorner.Parent = challenge

		challenge.MouseButton1Click:Connect(function()
			Remotes.RequestDuel:FireServer(other.UserId)
			panel.Visible = false
			showBanner("⚔️ Invite sent to " .. other.DisplayName .. " — waiting...")
		end)
	end

	-- ── NPC rivals: solo MOG targets (no second player needed) ──
	-- ALWAYS listed from Config: the server validates the model anyway when
	-- the duel request arrives, and gating on client-side workspace lookups
	-- breaks with distance streaming (rival rows would silently vanish).
	for _, rival in Config.NPC_RIVALS do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(40, 22, 55)
		row.Parent = scroll
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 10, 0, 4)
		nameLabel.Size = UDim2.new(0.6, 0, 0.55, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "🤖 " .. rival.displayName
		nameLabel.TextColor3 = Color3.fromRGB(230, 180, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local subLabel = Instance.new("TextLabel")
		subLabel.Position = UDim2.new(0, 10, 0.55, 0)
		subLabel.Size = UDim2.new(0.6, 0, 0.4, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = ("🏆 bounty +%d aura"):format(rival.bounty)
		subLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextScaled = true
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Parent = row

		local challenge = Instance.new("TextButton")
		challenge.AnchorPoint = Vector2.new(1, 0.5)
		challenge.Position = UDim2.new(1, -8, 0.5, 0)
		challenge.Size = UDim2.new(0, 110, 0, 40)
		challenge.BackgroundColor3 = Color3.fromRGB(170, 80, 255)
		challenge.Text = "MOG BOT ⚔️"
		challenge.TextColor3 = Color3.new(1, 1, 1)
		challenge.Font = Enum.Font.GothamBold
		challenge.TextScaled = true
		challenge.Parent = row
		local challengeCorner = Instance.new("UICorner")
		challengeCorner.CornerRadius = UDim.new(0, 8)
		challengeCorner.Parent = challenge

		challenge.MouseButton1Click:Connect(function()
			Remotes.RequestNpcDuel:FireServer(rival.name)
			panel.Visible = false
			showBanner("⚔️ Retando a " .. rival.displayName .. " — ¡al arena!")
		end)
	end
end

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

ContextActionService:BindAction(
	"OpenChallenge",
	function(_, state)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
			if panel.Visible then
				refreshList()
			end
		end
		return Enum.ContextActionResult.Sink
	end,
	true, -- mobile touch button
	Enum.KeyCode.M
)
ContextActionService:SetTitle("OpenChallenge", "MOG")

-- Keep the list fresh while the panel is open (players walk in/out).
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then
			refreshList()
		end
	end
end)

return nil
