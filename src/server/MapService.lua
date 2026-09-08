--!strict
-- MapService: builds the pilot plaza + duel arena out of code (colored parts).
-- Keeps named locations so other services don't hardcode coordinates.

local Players = game:GetService("Players")

local MapService = {}

local LOCATIONS = {}
local SPOT_REGIONS: { { center: Vector3, halfSize: number, multiplier: number, name: string } } = {}

local function part(props: { [string]: any }, parent: Instance)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function buildGround(parent: Instance)
	part({
		Name = "Ground",
		Size = Vector3.new(512, 1, 512),
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(96, 150, 80),
		Material = Enum.Material.Grass,
	}, parent)
end

local function buildFountain(parent: Instance)
	part({
		Name = "FountainBase",
		Size = Vector3.new(10, 2, 10),
		Position = Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(185, 195, 205),
		Material = Enum.Material.Marble,
	}, parent)
	part({
		Name = "FountainPillar",
		Size = Vector3.new(2, 6, 2),
		Position = Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(210, 220, 230),
		Material = Enum.Material.Marble,
	}, parent)
end

local function buildArena(parent: Instance)
	part({
		Name = "ArenaFloor",
		Size = Vector3.new(40, 1, 40),
		Position = Vector3.new(70, 0.5, 0),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.Slate,
	}, parent)
	part({
		Name = "JudgePlatform",
		Size = Vector3.new(12, 1, 4),
		Position = Vector3.new(70, 1.5, -14),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.WoodPlanks,
	}, parent)
	part({
		Name = "JudgeDesk",
		Size = Vector3.new(12, 3, 2),
		Position = Vector3.new(70, 3, -17),
		Color = Color3.fromRGB(255, 120, 60),
		Material = Enum.Material.Wood,
	}, parent)
end

local function buildStage(parent: Instance)
	part({
		Name = "StagePlatform",
		Size = Vector3.new(14, 1, 14),
		Position = Vector3.new(-50, 0.5, 0),
		Color = Color3.fromRGB(255, 90, 120),
		Material = Enum.Material.Neon,
	}, parent)
end

local function buildWalls(parent: Instance)
	part({
		Name = "GraffitiWall1",
		Size = Vector3.new(30, 12, 1),
		Position = Vector3.new(0, 6, -35),
		Color = Color3.fromRGB(90, 90, 110),
		Material = Enum.Material.Concrete,
	}, parent)
end

local function buildVipRooftop(parent: Instance)
	-- Rooftop platform on top of the graffiti wall (VIP gamepass area).
	part({
		Name = "VipRooftop",
		Size = Vector3.new(16, 1, 12),
		Position = Vector3.new(0, 13, -41),
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Metal,
	}, parent)
	part({
		Name = "VipLadder",
		Size = Vector3.new(2, 12, 0.5),
		Position = Vector3.new(8, 6.5, -41),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.DiamondPlate,
	}, parent)
	-- Teleport pad up top: step on it to get boosted to the roof.
	local pad = part({
		Name = "VipPad",
		Size = Vector3.new(4, 0.5, 4),
		Position = Vector3.new(0, 1.25, 10),
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Neon,
	}, parent)
	-- VIP check: attribute on the Aura stat, set by MonetizationService.
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local auraStat = leaderstats and leaderstats:FindFirstChild("Aura")
		if auraStat and auraStat:GetAttribute("VipPlaza") == true then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(Vector3.new(0, 15, -41))
			end
		else
			local Shared = game.ReplicatedStorage.AuraFarmShared
			local Remotes = require(Shared.Remotes)
			Remotes.ShopError:FireClient(player, "VIP rooftop is for VIP Plaza owners 👑 (buy in shop)")
		end
	end)
end

local function buildSpawn(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 18)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Parent = parent
end

function MapService.init(root: Instance?)
	root = root or workspace
	local folder = Instance.new("Folder")
	folder.Name = "AuraFarmMap"
	folder.Parent = root

	buildGround(folder)
	buildFountain(folder)
	buildArena(folder)
	buildStage(folder)
	buildWalls(folder)
	buildVipRooftop(folder)
	buildSpawn(folder)

	LOCATIONS.spawn = Vector3.new(0, 3.5, 18)
	LOCATIONS.fountain = Vector3.new(0, 3.5, 0)
	LOCATIONS.stage = Vector3.new(-50, 2, 0)
	LOCATIONS.arena = Vector3.new(70, 1.5, 0)
	LOCATIONS.arenaPlayerA = Vector3.new(64, 2, 0)
	LOCATIONS.arenaPlayerB = Vector3.new(76, 2, 0)
	LOCATIONS.judges = {
		Vector3.new(66, 3, -14),
		Vector3.new(70, 3, -14),
		Vector3.new(74, 3, -14),
	}
	LOCATIONS.vipRooftop = Vector3.new(0, 14, -41)
	LOCATIONS.trainingPad = Vector3.new(88, 1.3, 10) -- arena corner, ON TOP of the arena floor (floor top is y=1.0)

	-- Spot multipliers: posing inside these radii earns extra aura.
	SPOT_REGIONS = {
		{ name = "stage", center = Vector3.new(-50, 2, 0), halfSize = 9, multiplier = 2 },
		{ name = "arena", center = Vector3.new(70, 2, 0), halfSize = 22, multiplier = 1.5 },
		{ name = "vipRooftop", center = Vector3.new(0, 14, -41), halfSize = 9, multiplier = 2.5 },
	}

	return folder
end

function MapService.getLocation(name: string): Vector3?
	return LOCATIONS[name]
end

function MapService.getJudges(): { Vector3 }
	return LOCATIONS.judges
end

-- Returns the best spot multiplier for a position (default 1).
function MapService.getSpotMultiplier(position: Vector3): number
	local best = 1
	for _, region in SPOT_REGIONS do
		local offset = position - region.center
		if math.abs(offset.X) <= region.halfSize and math.abs(offset.Z) <= region.halfSize then
			if region.multiplier > best then
				best = region.multiplier
			end
		end
	end
	return best
end

return MapService
