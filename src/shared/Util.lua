--!strict
-- Small helpers shared by server and client.

local Util = {}

function Util.round(n: number): number
	return math.floor(n + 0.5)
end

function Util.clamp(n: number, min: number, max: number): number
	if n < min then
		return min
	elseif n > max then
		return max
	end
	return n
end

-- Formats 1234567 -> "1.23M" for HUD/billboards.
function Util.abbrev(n: number): string
	local abs = math.abs(n)
	if abs >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif abs >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- Judge stamp metadata used by both judge NPCs (server) and UI (client).
local STAMPS = {
	FIRE = { emoji = "🔥", label = "FIRE", color = Color3.fromRGB(255, 170, 0), minScore = 9 },
	MID = { emoji = "😐", label = "mid", color = Color3.fromRGB(200, 200, 200), minScore = 4 },
	CRINGE = { emoji = "💀", label = "CRINGE", color = Color3.fromRGB(120, 60, 160), minScore = 0 },
}

function Util.stampForScore(score: number): string
	if score >= STAMPS.FIRE.minScore then
		return "FIRE"
	elseif score >= STAMPS.MID.minScore then
		return "MID"
	end
	return "CRINGE"
end

function Util.stampInfo(stamp: string)
	return STAMPS[stamp] or STAMPS.MID
end

return Util
