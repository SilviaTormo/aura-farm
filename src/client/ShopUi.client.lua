--!strict
-- ShopUi.client.lua: pose shop. Lists every pose with cost; buying fires
-- BuyPose; the server confirms with PoseUnlocked or ShopError.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

-- Robux items: gamepasses + dev products (prompts open only when the Config
-- ID is non-zero; otherwise the server replies "coming soon").

local player = Players.LocalPlayer

local owned: { [string]: boolean } = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuraFarmShop"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 6
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 380, 0, 420)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, 0, 0, 46)
heading.BackgroundTransparency = 1
heading.Text = "🛒 POSE SHOP"
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
scroll.Position = UDim2.new(0, 10, 0, 52)
scroll.Size = UDim2.new(1, -20, 1, -112)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, #Config.POSES * 64)
scroll.ScrollBarThickness = 6
scroll.Parent = panel

-- Dev strip: TRY every Robux perk for free (Studio pilot only).
local devBar = Instance.new("Frame")
devBar.Name = "DevTryBar"
devBar.AnchorPoint = Vector2.new(0.5, 1)
devBar.Position = UDim2.new(0.5, 0, 1, -8)
devBar.Size = UDim2.new(1, -20, 0, 50)
devBar.BackgroundColor3 = Color3.fromRGB(120, 90, 10)
devBar.Parent = panel
local devCorner = Instance.new("UICorner")
devCorner.CornerRadius = UDim.new(0, 10)
devCorner.Parent = devBar
local devLabel = Instance.new("TextLabel")
devLabel.BackgroundTransparency = 1
devLabel.Position = UDim2.new(0, 8, 0, 0)
devLabel.Size = UDim2.new(0.36, 0, 1, 0)
devLabel.Text = "PILOTO: PRUÉBALO GRATIS 🧪"
devLabel.TextColor3 = Color3.fromRGB(255, 230, 140)
devLabel.Font = Enum.Font.GothamBold
devLabel.TextScaled = true
devLabel.TextXAlignment = Enum.TextXAlignment.Left
devLabel.Parent = devBar

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = scroll

local toast

local function setOwned(poseId: string)
	owned[poseId] = true
	local btn = scroll:FindFirstChild("Shop_" .. poseId)
	if btn then
		local buy = btn:FindFirstChild("Buy")
		if buy then
			(buy :: TextButton).Text = "OWNED ✓"
			(buy :: TextButton).BackgroundColor3 = Color3.fromRGB(60, 160, 90)
		end
	end
end

local function buildRow(pose)
	local row = Instance.new("Frame")
	row.Name = "Shop_" .. pose.id
	row.Size = UDim2.new(1, -8, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	row.Parent = scroll
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 10, 0, 4)
	nameLabel.Size = UDim2.new(0.6, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = pose.name .. ("  (%dx aura)"):format(pose.rate)
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.new(0, 10, 0.55, 0)
	descLabel.Size = UDim2.new(0.6, 0, 0.4, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = pose.description
	descLabel.TextColor3 = Color3.fromRGB(170, 170, 190)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -8, 0.5, 0)
	buy.Size = UDim2.new(0, 110, 0, 40)
	buy.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
	buy.Text = pose.cost == 0 and "FREE" or ("BUY %d"):format(pose.cost)
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.Parent = row
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buy

	buy.MouseButton1Click:Connect(function()
		if owned[pose.id] then
			toast("Already owned!")
			return
		end
		Remotes.BuyPose:FireServer(pose.id)
	end)
end

for _, pose in Config.POSES do
	buildRow(pose)
end

-- ── Robux section: passes + products ────────────────────────────
local function buildPassRow(info)
	local row = Instance.new("Frame")
	row.Name = "Pass_" .. info.key
	row.Size = UDim2.new(1, -8, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(70, 50, 20)
	row.Parent = scroll
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 10, 0, 4)
	nameLabel.Size = UDim2.new(0.6, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = info.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.new(0, 10, 0.55, 0)
	descLabel.Size = UDim2.new(0.6, 0, 0.4, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = info.description
	descLabel.TextColor3 = Color3.fromRGB(230, 210, 160)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -8, 0.5, 0)
	buy.Size = UDim2.new(0, 110, 0, 40)
	buy.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	buy.Text = "R$ BUY"
	buy.TextColor3 = Color3.fromRGB(40, 30, 0)
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.Parent = row
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buy

	buy.MouseButton1Click:Connect(function()
		Remotes.BuyPass:FireServer(info.key)
	end)
end

for _, info in Config.PASS_INFO do
	buildPassRow(info)
end

local function buildProductRow(key: string, label: string)
	local row = Instance.new("Frame")
	row.Name = "Product_" .. key
	row.Size = UDim2.new(1, -8, 0, 48)
	row.BackgroundColor3 = Color3.fromRGB(45, 25, 55)
	row.Parent = scroll
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 10, 0, 0)
	nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Color3.fromRGB(230, 180, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -8, 0.5, 0)
	buy.Size = UDim2.new(0, 110, 0, 36)
	buy.BackgroundColor3 = Color3.fromRGB(170, 80, 255)
	buy.Text = "R$ BUY"
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.Parent = row
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buy

	buy.MouseButton1Click:Connect(function()
		Remotes.BuyProduct:FireServer(key)
	end)
end

buildProductRow("MogShield", "🛡️ Mog Shield (1h no steals)")
buildProductRow("CooldownRefill", "⚡ Cooldown Refill")
buildProductRow("PartyMode", "🎉 PARTY MODE x2 (server, 10 min)")
scroll.CanvasSize = UDim2.new(0, 0, 0, (#Config.POSES + #Config.PASS_INFO + 3) * 64)

-- Dev strip buttons: same grant the real purchase gives, zero Robux.
local DEV_ITEMS = {
	{ key = "DoubleAura", label = "⚡2x" },
	{ key = "VipPlaza", label = "👑VIP" },
	{ key = "SigmaPosePack", label = "🗿SIGMA" },
	{ key = "GoldenDripBundle", label = "✨DRIP" },
	{ key = "MogShield", label = "🛡️SHIELD" },
	{ key = "CooldownRefill", label = "⚡REFILL" },
	{ key = "PartyMode", label = "🎉PARTY" },
}
local devList = Instance.new("UIListLayout")
devList.FillDirection = Enum.FillDirection.Horizontal
devList.Padding = UDim.new(0, 4)
devList.VerticalAlignment = Enum.VerticalAlignment.Center
devList.HorizontalAlignment = Enum.HorizontalAlignment.Right
devList.Parent = devBar
for _, item in DEV_ITEMS do
	local b = Instance.new("TextButton")
	b.Name = "DevTry_" .. item.key
	b.Size = UDim2.new(0, 62, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	b.Text = item.label
	b.TextColor3 = Color3.fromRGB(40, 30, 0)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = devBar
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = b
	b.MouseButton1Click:Connect(function()
		Remotes.DevShopTry:FireServer(item.key)
	end)
end

toast = function(msg: string)
	heading.Text = msg
	task.delay(2, function()
		heading.Text = "🛒 POSE SHOP"
	end)
end

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

ContextActionService:BindAction(
	"OpenShop",
	function(_, state)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
		end
		return Enum.ContextActionResult.Sink
	end,
	true, -- mobile touch button
	Enum.KeyCode.B
)
ContextActionService:SetTitle("OpenShop", "SHOP")

Remotes.PoseUnlocked.OnClientEvent:Connect(setOwned)
Remotes.ShopError.OnClientEvent:Connect(function(msg: string)
	toast(msg)
end)
Remotes.SyncUnlocked.OnClientEvent:Connect(function(ids: { string })
	for _, id in ids do
		setOwned(id)
	end
end)

return nil
