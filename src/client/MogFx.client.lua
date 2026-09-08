--!strict
-- MogFx.client.lua: the payoff. On MogFx (loser character + stolen aura):
-- skull confetti bursts from the loser's head, the head swaps to a skull-ish
-- ball for 2 seconds, aura orbs stream upward off the loser, and the loser's
-- own camera shakes.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.AuraFarmShared
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

-- CaptureService clip prompt (beta): offer "clip that!" after the MOG.
local captureService
pcall(function()
	captureService = game:GetService("CaptureService")
end)

local function promptClip()
	if not captureService then
		return
	end
	task.delay(1.2, function()
		pcall(function()
			captureService:PromptCapture(player)
		end)
	end)
end

local function confettiBurst(head: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Parent = head

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(170, 80, 255))
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(12, 20)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Enabled = true
	emitter.Parent = attachment
	emitter:Emit(60)

	task.delay(2, function()
		attachment:Destroy()
	end)
end

local function skullSwap(head: BasePart)
	local originalColor = head.Color
	-- Only Part has .Shape (R15 heads are MeshParts — assigning .Shape errors).
	local isPart = head:IsA("Part")
	local originalShape = isPart and (head :: Part).Shape or nil
	head.Color = Color3.fromRGB(235, 235, 235)
	if isPart then
		(head :: Part).Shape = Enum.PartType.Ball
	end
	task.delay(2, function()
		if head.Parent then
			head.Color = originalColor
			if isPart and originalShape then
				(head :: Part).Shape = originalShape
			end
		end
	end)
end

local function orbStream(head: BasePart, stolenAura: number)
	local orbCount = math.clamp(math.floor(stolenAura / 50) + 6, 6, 24)
	for i = 1, orbCount do
		task.delay(i * 0.06, function()
			if not head.Parent then
				return
			end
			local orb = Instance.new("Part")
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(0.6, 0.6, 0.6)
			orb.Color = Color3.fromRGB(255, 200, 60)
			orb.Material = Enum.Material.Neon
			orb.Anchored = true
			orb.CanCollide = false
			orb.Position = head.Position + Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
			orb.Parent = workspace

			local target = head.Position + Vector3.new(math.random(-4, 4), math.random(10, 16), math.random(-4, 4))
			local tween = TweenService:Create(orb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = target,
				Size = Vector3.new(0.1, 0.1, 0.1),
				Transparency = 1,
			})
			tween:Play()
			tween.Completed:Connect(function()
				orb:Destroy()
			end)
		end)
	end
end

local function cameraShake(intensity: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local original = camera.CFrame
	for i = 1, 10 do
		task.wait(0.04)
		camera.CFrame = original * CFrame.new(
			math.random(-100, 100) * intensity / 100,
			math.random(-100, 100) * intensity / 100,
			0
		)
	end
end

Remotes.MogFx.OnClientEvent:Connect(function(loserCharacter: Model, stolenAura: number)
	local head = loserCharacter:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		confettiBurst(head)
		skullSwap(head)
		orbStream(head, stolenAura)
	end
	local myChar = player.Character
	if myChar == loserCharacter then
		-- I'm the loser: strong shake + clip prompt.
		task.spawn(cameraShake, 1)
		promptClip()
	else
		-- Witnesses get a mild shake + the clip prompt too (sharing flywheel).
		task.spawn(cameraShake, 0.3)
		promptClip()
	end
end)

return nil
