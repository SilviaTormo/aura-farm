--!strict
-- CapturePromptService (pilot stub): prompts the Roblox video-capture UI at
-- hype moments. Real CaptureService wiring lands in M3/M5; this pass exposes
-- the hook point so DuelService/MogFx already call it.

local CapturePromptService = {}

-- Call on MOG moments: ask the loser/winner/witnesses to clip it.
function CapturePromptService.promptClip(player: Player, reason: string)
	-- TODO(M3): CaptureService:PromptCapture(player) once enabled for the place.
	-- During the pilot this is a no-op with a log line for playtest observers.
	print(("[AuraFarm] clip prompt (%s) for %s"):format(reason, player.Name))
end

return CapturePromptService
