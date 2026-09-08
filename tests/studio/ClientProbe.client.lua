--!strict
-- ClientProbe.client.lua — PILOT-ONLY client-path probe (like SmokeTest).
-- Path 1: teleports the real avatar onto the TRAIN pad so physics fires
--         Touched -> [TRAIN] open ... PAD TOUCH in the server log.
-- Path 2: on any training round, fires TrainingPick (the SAME remote the
--         picker buttons fire) -> proves the client->server pick path.
-- Remove from default.project.json for production builds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrainingPick = remotes:WaitForChild("TrainingPick") :: RemoteEvent
local TrainingRound = remotes:WaitForChild("TrainingRound") :: RemoteEvent

-- Path 1: land the avatar on the pad (88, 1.3, 10) 10s after join.
task.delay(10, function()
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(Vector3.new(88, 4, 10)) -- small drop -> Touched
	print("[PROBE] avatar dropped onto TRAIN pad zone")
end)

-- Path 2: client-initiated pick 1.5s into any opened round.
TrainingRound.OnClientEvent:Connect(function()
	task.delay(1.5, function()
		TrainingPick:FireServer("wave")
		print("[PROBE] client fired TrainingPick(wave)")
	end)
end)
