--!strict
-- CrowdService: spawns NPC crowd, moves them around the plaza, tracks which
-- player each NPC is currently hyped by, and pays aura ticks to AuraService.
--
-- NPCs are chunky part-dummies with procedural walk/cheer animation (no
-- animation assets needed): they wander, face the posing player they hype,
-- swing limbs while walking, bounce arms while cheering, and emote with
-- billboard emojis (🔥💀🗿).

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Config = require(Shared.Config)

local AuraService = require(script.Parent.AuraService)
local MapService = require(script.Parent.MapService)

local CrowdService = {}

local crowdFolder
local npcs = {} -- model -> state

local WANDER_TICK = 2

local CHEER_EMOJIS = { "🔥", "💀", "🗿", "😤", "⚡" }

export type NpcState = {
	model: Model,
	torso: BasePart,
	head: BasePart,
	armL: BasePart,
	armR: BasePart,
	legL: BasePart,
	legR: BasePart,
	emojiLabel: TextLabel,
	currentTarget: Player?,
	attentionUntil: number,
	home: Vector3,
	nextWanderAt: number,
	walkPhase: number,
	isRival: boolean,
}

local function makePart(name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function makeNpc(name: string, position: Vector3, opts: { isRival: boolean?, displayName: string? }?): NpcState
	local model = Instance.new("Model")
	model.Name = name

	local bodyColor = Color3.fromHSV(math.random(), 0.55, 1)
	local torso = makePart("Torso", Vector3.new(2, 2, 1), bodyColor)
	torso.Position = position
	torso.CanCollide = true
	torso.Parent = model

	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 220, 180))
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	local armL = makePart("ArmL", Vector3.new(0.5, 2, 0.5), bodyColor)
	armL.Parent = model
	local armR = makePart("ArmR", Vector3.new(0.5, 2, 0.5), bodyColor)
	armR.Parent = model
	local legL = makePart("LegL", Vector3.new(0.7, 2, 0.7), Color3.fromRGB(40, 40, 60))
	legL.Parent = model
	local legR = makePart("LegR", Vector3.new(0.7, 2, 0.7), Color3.fromRGB(40, 40, 60))
	legR.Parent = model

	-- Ground-height fix: the torso center used to be placed at the raw spawn
	-- height, sinking the legs 2 studs into the floor ("NPCs half-buried").
	-- Seat the model so the legs just clear the ground instead.
	local groundY = 0.5
	torso.Position = Vector3.new(position.X, groundY + legL.Size.Y + torso.Size.Y / 2, position.Z)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CheerBillboard"
	billboard.Size = UDim2.new(0, 60, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Emoji"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = ""
	label.Parent = billboard

	model.PrimaryPart = torso

	-- Name tag: rivals advertise the duel ("MOG ME ⚔️"), crowd NPCs just say hi.
	local nameBillboard = Instance.new("BillboardGui")
	nameBillboard.Name = "NameBillboard"
	nameBillboard.Size = UDim2.new(0, 120, 0, 26)
	nameBillboard.StudsOffset = Vector3.new(0, 3.5, 0)
	nameBillboard.AlwaysOnTop = true
	nameBillboard.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextColor3 = opts and opts.isRival and Color3.fromRGB(170, 80, 255) or Color3.new(1, 1, 1)
	nameLabel.Text = opts and opts.displayName or name
	nameLabel.Parent = nameBillboard

	model.Parent = crowdFolder

	local state: NpcState = {
		model = model,
		torso = torso,
		head = head,
		armL = armL,
		armR = armR,
		legL = legL,
		legR = legR,
		emojiLabel = label,
		currentTarget = nil,
		attentionUntil = 0,
		home = position,
		nextWanderAt = os.clock() + math.random(1, 4),
		walkPhase = 0,
		isRival = (opts and opts.isRival) or false,
	}
	npcs[model] = state
	return state
end

-- Procedural body animation: positions every limb relative to the torso.
-- isMoving -> walk swing; cheering -> raised bouncing arms.
local function animateNpc(npc: NpcState, dt: number, isMoving: boolean, cheering: boolean)
	local cf = npc.torso.CFrame
	local t = os.clock()

	if isMoving then
		npc.walkPhase += dt * 9
		local swing = math.sin(npc.walkPhase) * 0.6
		npc.armL.CFrame = cf * CFrame.new(-1.3, 0, 0) * CFrame.Angles(swing, 0, 0.15)
		npc.armR.CFrame = cf * CFrame.new(1.3, 0, 0) * CFrame.Angles(-swing, 0, -0.15)
		npc.legL.CFrame = cf * CFrame.new(-0.5, -2, 0) * CFrame.Angles(-swing * 0.8, 0, 0)
		npc.legR.CFrame = cf * CFrame.new(0.5, -2, 0) * CFrame.Angles(swing * 0.8, 0, 0)
	elseif cheering then
		local bounce = math.sin(t * 8) * 0.25
		npc.armL.CFrame = cf * CFrame.new(-1.3, 0.4 + bounce, 0) * CFrame.Angles(0, 0, math.rad(160))
		npc.armR.CFrame = cf * CFrame.new(1.3, 0.4 - bounce, 0) * CFrame.Angles(0, 0, math.rad(-160))
		npc.legL.CFrame = cf * CFrame.new(-0.5, -2, 0)
		npc.legR.CFrame = cf * CFrame.new(0.5, -2, 0)
	else
		npc.armL.CFrame = cf * CFrame.new(-1.3, 0, 0)
		npc.armR.CFrame = cf * CFrame.new(1.3, 0, 0)
		npc.legL.CFrame = cf * CFrame.new(-0.5, -2, 0)
		npc.legR.CFrame = cf * CFrame.new(0.5, -2, 0)
	end

	npc.head.CFrame = cf * CFrame.new(0, 1.7, 0)
end

local function clearEmoji(npc: NpcState)
	npc.emojiLabel.Text = ""
end

local function cheerAt(npc: NpcState, text: string)
	npc.emojiLabel.Text = text
	task.delay(0.8, function()
		if npc.emojiLabel.Text == text then
			clearEmoji(npc)
		end
	end)
end

local function getTopPlayer(): Player?
	local top: Player? = nil
	for _, player in Players:GetPlayers() do
		local stats = player:FindFirstChild("leaderstats")
		local aura = stats and stats:FindFirstChild("Aura")
		if aura and (not top or aura.Value > (top:FindFirstChild("leaderstats") :: any).Aura.Value) then
			top = player
		end
	end
	return top
end

local function pickWanderTarget(npc: NpcState)
	-- 70% wander around the plaza, 30% drift toward the top aura player (influencer).
	local topPlayer = getTopPlayer()

	if topPlayer and math.random() < 0.3 then
		local char = topPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			npc.home = root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		end
	else
		local center = MapService.getLocation("fountain") or Vector3.zero
		npc.home = center + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
	end
end

local function moveToward(npc: NpcState, position: Vector3, speed: number, dt: number): boolean
	local torso = npc.torso
	local flat = (position - torso.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.5 then
		torso.CFrame = torso.CFrame:Lerp(
			CFrame.new(position) * CFrame.new(0, torso.Size.Y / 2, 0),
			math.clamp(speed * dt / flat.Magnitude, 0, 1)
		)
		return true
	end
	return false
end

function CrowdService.init()
	crowdFolder = Instance.new("Folder")
	crowdFolder.Name = "AuraCrowd"
	crowdFolder.Parent = workspace

	for i = 1, 12 do
		local center = MapService.getLocation("fountain") or Vector3.zero
		local spawnPos = center + Vector3.new(math.random(-30, 30), 3, math.random(-30, 30))
		makeNpc("HypeGuy" .. i, spawnPos)
	end

	-- NPC rivals: standing near the arena, name-tagged, excluded from the hype
	-- crowd so their attention is reserved for duels (ChallengeUi lists them).
	local arena = MapService.getLocation("arena") or Vector3.new(70, 2, 0)
	for _, rival in Config.NPC_RIVALS do
		local spawnPos = arena + Vector3.new(math.random(-14, 14), 3, math.random(10, 16))
		makeNpc(rival.name, spawnPos, { isRival = true, displayName = rival.displayName })
	end

	-- Wander loop
	task.spawn(function()
		while true do
			task.wait(WANDER_TICK)
			for _, npc in npcs do
				if os.clock() >= npc.nextWanderAt then
					pickWanderTarget(npc)
					npc.nextWanderAt = os.clock() + math.random(3, 8)
				end
			end
		end
	end)

	-- Movement + hype + animation loop
	task.spawn(function()
		while true do
			local dt = task.wait(0.2)
			for _, npc in npcs do
				if npc.isRival then
					continue -- rivals judge duels at the arena; they never join the hype crowd
				end
				-- Decide who to hype: nearest posing player inside HYPE_RADIUS.
				local best: Player? = nil
				local bestDist = math.huge
				for _, player in Players:GetPlayers() do
					-- Only hype players who are actually posing.
					if AuraService.getActivePose(player) then
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if root then
							local dist = (root.Position - npc.torso.Position).Magnitude
							if dist <= Config.HYPE_RADIUS and dist < bestDist then
								best, bestDist = player, dist
							end
						end
					end
				end

				local isMoving = false
				if best then
					if npc.currentTarget ~= best then
						npc.currentTarget = best
						npc.attentionUntil = os.clock() + Config.ATTENTION_DECAY_SECONDS
						cheerAt(npc, CHEER_EMOJIS[math.random(#CHEER_EMOJIS)])
					end
					local char = best.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						isMoving = moveToward(npc, root.Position, 6, dt)
						-- Face the target
						local look = root.Position
						npc.torso.CFrame = CFrame.lookAt(
							npc.torso.Position,
							Vector3.new(look.X, npc.torso.Position.Y, look.Z)
						)
					end
					-- Attention decay: bored NPCs stop hyping.
					if npc.currentTarget and os.clock() > npc.attentionUntil then
						npc.currentTarget = nil
						clearEmoji(npc)
					end
				else
					npc.currentTarget = nil
					-- Wander: actually walk toward the chosen home spot (the
					-- design's "wander / follow the #1 farmer" behavior — NPCs
					-- previously teleported-nowhere and stood frozen).
					isMoving = moveToward(npc, npc.home, 4, dt)
				end

				local cheering = npc.currentTarget ~= nil
				if cheering then
					-- Re-cheer periodically while hyped.
					if math.random() < dt * 0.6 then
						cheerAt(npc, CHEER_EMOJIS[math.random(#CHEER_EMOJIS)])
					end
				end
				animateNpc(npc, dt, isMoving, cheering)
			end
		end
	end)

	-- Aura payout loop
	task.spawn(function()
		while true do
			task.wait(Config.AURA_TICK_SECONDS)
			local counts: { [number]: number } = {}
			for _, npc in npcs do
				if npc.currentTarget then
					counts[npc.currentTarget.UserId] = (counts[npc.currentTarget.UserId] or 0) + 1
				end
			end
			for userId, count in counts do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					AuraService.grantTick(player, count)
				end
			end
		end
	end)
end

function CrowdService.getHypeCount(player: Player): number
	local count = 0
	for _, npc in npcs do
		if npc.currentTarget == player then
			count += 1
		end
	end
	return count
end

-- ── NPC rivals: solo-duel support (used by DuelService) ────────

function CrowdService.allRivals(): { [Model]: NpcState }
	local out = {}
	for model, state in npcs do
		if state.isRival then
			out[model] = state
		end
	end
	return out
end

function CrowdService.isRival(model: Model?): boolean
	local state = model and npcs[model]
	return state ~= nil and state.isRival
end

function CrowdService.teleportRival(model: Model, cframe: CFrame)
	local state = npcs[model]
	if not state then
		return
	end
	state.home = cframe.Position
	state.torso.CFrame = cframe
	-- Rivals skip the animation loop, so re-seat every limb manually.
	state.head.CFrame = cframe * CFrame.new(0, 1.7, 0)
	state.armL.CFrame = cframe * CFrame.new(-1.3, 0, 0)
	state.armR.CFrame = cframe * CFrame.new(1.3, 0, 0)
	state.legL.CFrame = cframe * CFrame.new(-0.5, -2, 0)
	state.legR.CFrame = cframe * CFrame.new(0.5, -2, 0)
end

return CrowdService
