-- harness.lua: mock Roblox environment for the standalone luau runtime.
-- Loads the REAL game modules (src/server, src/shared) and executes them with
-- a manual clock so tests can drive task.wait/task.delay deterministically.
-- Events fired via RemoteEvent:FireClient land in Harness.events.

local Harness = {}

Harness.now = 1000 -- os.clock seconds (float)
Harness.timeNow = 1796000000 -- os.time seconds (int)

Harness.events = {}
local function logEvent(name, player, ...)
	table.insert(Harness.events, { name = name, player = player, args = { ... } })
end
function Harness.clearEvents()
	Harness.events = {}
end
function Harness.eventsFor(name, player)
	local out = {}
	for _, e in Harness.events do
		if e.name == name and (player == nil or e.player == player) then
			table.insert(out, e)
		end
	end
	return out
end
function Harness.lastEvent(name, player)
	local list = Harness.eventsFor(name, player)
	return list[#list]
end

-- Forward declaration: FireAllClients (defined before Players below) fans
-- broadcasts out to every connected player.
local Players
local Vector3mt = {
	__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
	__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
	__mul = function(a, b)
		if type(b) == "number" then
			return Vector3.new(a.X * b, a.Y * b, a.Z * b)
		end
		return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__index = function(v, k)
		if k == "Magnitude" then
			return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		end
		return nil
	end,
}
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3mt)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)

-- ── CFrame (rotation matrix + Position; supports *, :Lerp) ────
-- Rotation is stored as a 3x3 matrix so pose tests can verify that Motor6D
-- C0s actually rotate (the pose-visibility regression needs real angles).
local IDENTITY3 = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
local function mat3Mul(a, b)
	local out = {}
	for i = 1, 3 do
		local row = {}
		for j = 1, 3 do
			row[j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
		out[i] = row
	end
	return out
end
local function mat3Vec(m, v)
	return Vector3.new(
		m[1][1] * v.X + m[1][2] * v.Y + m[1][3] * v.Z,
		m[2][1] * v.X + m[2][2] * v.Y + m[2][3] * v.Z,
		m[3][1] * v.X + m[3][2] * v.Y + m[3][3] * v.Z
	)
end
local function eulerMat3(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	-- Roblox fromEulerAnglesXYZ: X first, then Y, then Z (R = Rz*Ry*Rx).
	local rxy = {
		{ cy, 0, sy },
		{ sx * sy, cx, -sx * cy },
		{ -cx * sy, sx, cx * cy },
	}
	return mat3Mul({ { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }, rxy)
end
local CFrameMt = {}
local function newCFrame(position, rot)
	return setmetatable({ Position = position or Vector3.zero, _rot = rot or IDENTITY3 }, CFrameMt)
end
CFrameMt.__mul = function(a, b)
	return newCFrame(
		a.Position + mat3Vec(a._rot or IDENTITY3, b.Position or Vector3.zero),
		mat3Mul(a._rot or IDENTITY3, b._rot or IDENTITY3)
	)
end
CFrameMt.__index = function(self, k)
	if k == "Lerp" then
		return function(_, target, alpha)
			local p, q = self.Position, target.Position
			return newCFrame(
				Vector3.new(
					p.X + (q.X - p.X) * alpha,
					p.Y + (q.Y - p.Y) * alpha,
					p.Z + (q.Z - p.Z) * alpha
				),
				alpha < 0.5 and self._rot or target._rot
			)
		end
	end
	return nil
end
CFrame = {
	new = function(a, b, c)
		-- 3-number form: CFrame.new(x, y, z)
		if type(a) == "number" then
			return newCFrame(Vector3.new(a, b or 0, c or 0))
		end
		local pos = a
		if type(a) ~= "table" then
			pos = Vector3.zero
		end
		return newCFrame(pos)
	end,
	Angles = function(rx, ry, rz)
		return newCFrame(Vector3.zero, eulerMat3(rx or 0, ry or 0, rz or 0))
	end,
	lookAt = function(eye, target)
		-- Yaw-only rotation so the result's forward points from eye at target.
		local d = target and (target - eye) or Vector3.zero
		local yaw = math.atan2(-d.X, -d.Z)
		return newCFrame(eye, eulerMat3(0, yaw, 0))
	end,
}

Color3 = {
	fromRGB = function(r, g, b) return { r = r, g = g, b = b } end,
	fromHSV = function(h, s, v) return { h = h, s = s, v = v } end,
	new = function(r, g, b) return { r = r, g = g, b = b } end,
}
UDim2 = { new = function(...) return { args = { ... } } end }
UDim = { new = function(...) return { args = { ... } } end }
Vector2 = { new = function(...) return { args = { ... } } end }
TweenInfo = { new = function(...) return { args = { ... } } end }

local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, key)
		if enumCache[key] == nil then
			enumCache[key] = setmetatable({}, {
				__index = function(_, sub)
					enumCache[key][sub] = { enumType = key, Name = sub }
					return enumCache[key][sub]
				end,
			})
		end
		return enumCache[key]
	end,
})

-- ── Signals ─────────────────────────────────────────────────────
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ listeners = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { fn = fn }
	table.insert(self.listeners, conn)
	conn.Disconnect = function()
		for i, c in self.listeners do
			if c == conn then
				table.remove(self.listeners, i)
				break
			end
		end
	end
	return conn
end
function Signal:Fire(...)
	for _, conn in table.clone(self.listeners) do
		local ok, err = pcall(conn.fn, ...)
		if not ok then
			error("signal handler error: " .. tostring(err))
		end
	end
end

-- ── Instances ───────────────────────────────────────────────────
local InstanceMethods = {}
function InstanceMethods:IsA(className)
	if className == "Instance" then
		return true
	end
	return self._className == className
end
function InstanceMethods:FindFirstChild(name, recursive)
	for _, child in self._children do
		if child._Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function InstanceMethods:WaitForChild(name)
	return self:FindFirstChild(name)
end
function InstanceMethods:GetAttribute(key)
	return self._attributes[key]
end
function InstanceMethods:SetAttribute(key, value)
	self._attributes[key] = value
end
function InstanceMethods:Destroy()
	local old = rawget(self, "_Parent")
	if old then
		local idx = table.find(old._children, self)
		if idx then
			table.remove(old._children, idx)
		end
	end
	rawset(self, "_Parent", nil)
end
function InstanceMethods:GetChildren()
	return table.clone(self._children)
end
function InstanceMethods:IsDescendantOf(ancestor)
	local cur = rawget(self, "_Parent")
	while cur do
		if cur == ancestor then
			return true
		end
		cur = rawget(cur, "_Parent")
	end
	return false
end

local Instancemt = {}
Instancemt.__index = function(self, key)
	local method = InstanceMethods[key]
	if method then
		return method
	end
	local backing = rawget(self, "_" .. key)
	if backing ~= nil then
		return backing
	end
	-- Sensible geometry defaults: parts read CFrame/Position before any write.
	if key == "Position" then
		return Vector3.zero
	end
	if key == "CFrame" then
		return CFrame.new(rawget(self, "_Position") or Vector3.zero)
	end
	-- Motor6D joints read as "at rest" before anything posed them.
	if key == "C0" or key == "C1" or key == "Transform" then
		return CFrame.new()
	end
	-- Property-style child access: script.Parent.SiblingName
	for _, child in self._children do
		if child._Name == key then
			return child
		end
	end
	return nil
end
Instancemt.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_Parent")
		if old and old._children then
			local idx = table.find(old._children, self)
			if idx then
				table.remove(old._children, idx)
			end
		end
		rawset(self, "_Parent", value)
		if value and value._children then
			table.insert(value._children, self)
		end
		return
	end
	rawset(self, "_" .. key, value)
end

Instance = {
	new = function(className)
		local inst = {
			_className = className,
			_Name = className,
			_Parent = nil,
			_children = {},
			_attributes = {},
			ChildAdded = Signal.new(),
			AncestryChanged = Signal.new(),
			Touched = Signal.new(),
			CharacterAdded = Signal.new(),
		}
		if className == "TextButton" or className == "ImageButton" then
			-- GUI buttons carry click signals (TrainingUi picker binds them).
			inst.MouseButton1Click = Signal.new()
			inst.Activated = Signal.new()
		end
		if className == "RemoteEvent" then
			inst.OnServerEvent = Signal.new()
			inst.OnClientEvent = Signal.new()
			function inst:FireClient(player, ...)
				logEvent(self._Name, player, ...)
				-- Single-machine model: connected client handlers run too, so
				-- client modules (PoseRenderer) are testable end-to-end.
				-- Real Roblox passes ONLY the payload on the receiving side —
				-- the sender's player is not prepended.
				inst.OnClientEvent:Fire(...)
			end
			function inst:FireAllClients(...)
				for _, player in Players.byUserId do
					logEvent(self._Name, player, ...)
					inst.OnClientEvent:Fire(...)
				end
			end
			function inst:FireServer(...)
				-- Client->server: real Roblox prepends the LocalPlayer on the
				-- receiving side (OnServerEvent handlers always get player first).
				local lp = Players.LocalPlayer
				logEvent(self._Name, lp, ...)
				inst.OnServerEvent:Fire(lp, ...)
			end
		end
		return setmetatable(inst, Instancemt)
	end,
}

-- ── DataStore mock ──────────────────────────────────────────────
-- (declared in two steps: methods reference the table itself, which isn't
-- in scope inside its own constructor otherwise)
local DataStoreService
DataStoreService = {
	stores = {},
	GetDataStore = function(_, name)
		local store = DataStoreService.stores[name]
		if not store then
			store = { data = {}, updateCalls = {} }
			function store:GetAsync(key)
				return self.data[key]
			end
			function store:UpdateAsync(key, fn, timeout)
				table.insert(self.updateCalls, { key = key, timeout = timeout })
				local old = self.data[key]
				local new = fn(old)
				if new ~= nil then
					self.data[key] = new
				end
				return new
			end
			DataStoreService.stores[name] = store
		end
		return store
	end,
	GetOrderedDataStore = function(_, name, scope)
		local id = name .. "/" .. scope
		local store = DataStoreService.stores[id]
		if not store then
			store = { data = {} }
			function store:SetAsync(key, value)
				self.data[key] = value
			end
			function store:GetSortedAsync(_, maxSize)
				local entries = {}
				for k, v in self.data do
					table.insert(entries, { key = k, value = v })
				end
				table.sort(entries, function(a, b) return a.value > b.value end)
				while #entries > maxSize do
					table.remove(entries)
				end
				return { GetCurrentPage = function() return entries end }
			end
			DataStoreService.stores[id] = store
		end
		return store
	end,
}

-- ── Players mock ────────────────────────────────────────────────
-- (assigns the single forward-declared local above, so FireAllClients and
-- the methods below all share one variable)
Players = {
	byUserId = {},
	-- The client view (TrainingUi binds to it at require time); tests point
	-- it at the player under test before requiring a client UI module.
	LocalPlayer = nil :: any,
	PlayerAdded = Signal.new(),
	PlayerRemoving = Signal.new(),
	GetPlayers = function()
		local list = {}
		for _, p in Players.byUserId do
			table.insert(list, p)
		end
		return list
	end,
	GetPlayerByUserId = function(_, userId)
		return Players.byUserId[userId]
	end,
	GetPlayerFromCharacter = function(_, model)
		for _, p in Players.byUserId do
			if rawget(p, "_Character") == model then
				return p
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, userId)
		return "User" .. tostring(userId)
	end,
}
function Players.add(player)
	Players.byUserId[player.UserId] = player
	player.Parent = Players -- real players live under the Players service
	Players.PlayerAdded:Fire(player)
end
function Players.remove(player)
	Players.byUserId[player.UserId] = nil
	Players.PlayerRemoving:Fire(player)
end

local function makePlayer(userId, name)
	local p = Instance.new("Player")
	-- Property writes (NOT rawset): __newindex stores under "_Key", which is
	-- exactly what __index reads back. rawset would bypass that pairing and
	-- leave .UserId/.Name nil inside game modules.
	p.Name = name
	p.DisplayName = name
	p.UserId = userId
	return p
end

-- ── game / services / workspace ─────────────────────────────────
local services = {
	DataStoreService = DataStoreService,
	Players = Players,
	RunService = {
		IsServer = function() return true end,
		IsStudio = function() return false end,
		IsClient = function() return false end,
		-- PoseRenderer (client module) binds this; tests drive it manually.
		PreSimulation = Signal.new(),
	},
	-- PoseAnimator tweens Motor6D.C0; tests apply the final value instantly.
	TweenService = {
		Create = function(_, instance, _tweenInfo, props)
			return {
				Play = function()
					for prop, value in props do
						(instance :: any)[prop] = value
					end
				end,
			}
		end,
	},
	MarketplaceService = {
		PromptGamePassPurchaseFinished = Signal.new(),
		ProcessReceipt = nil,
		lastGamePassPlayer = nil,
		lastGamePassPrompt = nil,
		lastProductPrompt = nil,
		PromptGamePassPurchase = function(self, player, passId)
			self.lastGamePassPlayer = player
			self.lastGamePassPrompt = passId
		end,
		PromptProductPurchase = function(self, player, productId)
			self.lastProductPrompt = productId
		end,
		UserOwnsGamePassAsync = function() return false end,
	},
	CaptureService = {},
	-- Client controls bind through ContextActionService (the T key already
	-- does); tests fire bound handlers via fireContextAction.
	ContextActionService = {
		boundActions = {},
		BindAction = function(self, name, fn, createTouchButton, ...)
			self.boundActions[name] = { fn = fn, keys = { ... } }
		end,
		UnbindAction = function(self, name)
			self.boundActions[name] = nil
		end,
		SetTitle = function() end,
	},
}
local bindToCloseFns = {}
local game = {
	GetService = function(_, name)
		return services[name] or Instance.new("Service")
	end,
	BindToClose = function(_, fn)
		table.insert(bindToCloseFns, fn)
	end,
}
Harness.bindToCloseFns = bindToCloseFns
-- Fires a ContextActionService-bound handler the way the engine would
-- (actionName, state, input). Returns the handler's result.
function Harness.fireContextAction(name, state, input)
	local action = services.ContextActionService.boundActions[name]
	if not action then
		error("no bound ContextActionService action named " .. tostring(name))
	end
	return action.fn(name, state, input)
end

local workspace = Instance.new("Workspace")
local replicatedStorage = Instance.new("ReplicatedStorage")
local serverScriptService = Instance.new("ServerScriptService")
game.ReplicatedStorage = replicatedStorage
game.ServerScriptService = serverScriptService
workspace.Parent = game
Harness.workspace = workspace

-- ── task scheduler (manual clock) ───────────────────────────────
local scheduled = {}
local function schedule(co, wakeAt)
	table.insert(scheduled, { co = co, wakeAt = wakeAt })
end

local task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local args = table.pack(...)
		schedule(co, Harness.now)
		coroutine.resume(co, table.unpack(args, 1, args.n))
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		local args = table.pack(...)
		schedule(co, Harness.now)
		coroutine.resume(co, table.unpack(args, 1, args.n))
		return co
	end,
	delay = function(seconds, fn)
		local co = coroutine.create(fn)
		schedule(co, Harness.now + seconds)
		return co
	end,
	wait = function(seconds)
		local dt = seconds or 0
		coroutine.yield({ waitUntil = Harness.now + dt })
		return dt
	end,
}

function Harness.pump()
	table.sort(scheduled, function(a, b) return a.wakeAt < b.wakeAt end)
	local i = 1
	while i <= #scheduled do
		local item = scheduled[i]
		if item.wakeAt > Harness.now then
			i += 1
		else
			table.remove(scheduled, i)
			local ok, yielded = coroutine.resume(item.co)
			if not ok then
				error("coroutine error: " .. tostring(yielded))
			end
			if type(yielded) == "table" and yielded.waitUntil then
				schedule(item.co, math.max(yielded.waitUntil, Harness.now))
			end
		end
	end
end
function Harness.advance(dt)
	Harness.now += dt
	Harness.pump()
end

-- ── Module loader ───────────────────────────────────────────────
local moduleCache = {}
local ROOT = "src"

local function makeModuleScript(name, relPath)
	local inst = Instance.new("ModuleScript")
	inst._Name = name
	rawset(inst, "_sourcePath", ROOT .. "/" .. relPath)
	return inst
end

local sharedFolder = Instance.new("Folder")
sharedFolder.Name = "AuraFarmShared"
sharedFolder.Parent = replicatedStorage
for _, name in { "Config", "Remotes", "Util", "PoseTables" } do
	makeModuleScript(name, "shared/" .. name .. ".lua").Parent = sharedFolder
end

local serverFolder = Instance.new("Folder")
serverFolder.Name = "AuraFarmServer"
serverFolder.Parent = serverScriptService
for _, name in {
	"MapService", "DataService", "RebirthService", "EventService",
	"AuraService", "CrowdService", "PoseService",
	"JudgeService", "DuelService", "TrainingService",
	"LeaderboardService", "MonetizationService", "CapturePromptService",
	"DevShopService",
} do
	makeModuleScript(name, "server/" .. name .. ".lua").Parent = serverFolder
end

-- Client modules under StarterPlayerScripts (PoseRenderer is loadable and
-- testable in the mock: the harness env is server-shaped, but the renderer
-- only needs Players/RunService/ReplicatedStorage/remotes, which exist).
local starterPlayerScripts = Instance.new("Folder")
starterPlayerScripts.Name = "StarterPlayerScripts"
starterPlayerScripts.Parent = game
local poseRendererModule = makeModuleScript("PoseRenderer.client", "client/PoseRenderer.client.lua")
poseRendererModule.Parent = starterPlayerScripts
Harness.poseRendererModule = poseRendererModule
local trainingUiModule = makeModuleScript("TrainingUi.client", "client/TrainingUi.client.lua")
trainingUiModule.Parent = starterPlayerScripts
Harness.trainingUiModule = trainingUiModule

-- Free names bound into every game module (param list of the wrapper).
local _ENV_BINDING = {
	game = game,
	workspace = workspace,
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	UDim2 = UDim2,
	UDim = UDim,
	Vector2 = Vector2,
	-- Particle/datatype constructors used by PoseTables.FX and the FX emitters.
	NumberRange = { new = function(a, b) return { min = a, max = b or a } end },
	NumberSequence = { new = function(a, b) return { a, b or a } end },
	ColorSequence = { new = function(a, b) return { a, b or a } end },
	TweenInfo = TweenInfo,
	Enum = Enum,
	task = task,
	math = math,
	table = table,
	string = string,
	pcall = pcall,
	ipairs = ipairs,
	pairs = pairs,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	typeof = typeof,
	error = error,
	assert = assert,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	next = next,
	warn = function(...) end,
	print = print,
}
local realOs = os
local mockOs = {
	clock = function() return Harness.now end,
	time = function() return Harness.timeNow end,
	exit = function(code) realOs.exit(code) end,
}
local ENV_NAMES = {
	"game", "workspace", "script", "Instance", "Vector3", "CFrame", "Color3",
	"UDim2", "UDim", "Vector2", "NumberRange", "NumberSequence", "ColorSequence",
	"TweenInfo", "Enum", "task", "require", "os",
	-- Standard libs passed explicitly too: identical values if the chunk env
	-- already has them, guaranteed values if it doesn't.
	"math", "table", "string", "pcall", "ipairs", "pairs", "tonumber",
	"tostring", "type", "typeof", "error", "assert", "select", "setmetatable",
	"getmetatable", "rawget", "rawset", "next", "warn", "print",
}
local ENV_HEADER = "return function(" .. table.concat(ENV_NAMES, ", ") .. ")\n"

local function realRequire(target)
	if type(target) == "table" and rawget(target, "_sourcePath") then
		local path = target._sourcePath
		if moduleCache[path] then
			return moduleCache[path].value
		end
		-- The luau CLI strips the io library; module sources come pre-bundled
		-- by tests/bundle.js (run `node aura-farm/tests/bundle.js` first).
		local BUNDLE = require("./bundle_data")
		local source = BUNDLE[path]
		assert(source, "harness: no bundled source for " .. path .. " (run bundle.js?)")
		local chunk, err = loadstring(ENV_HEADER .. source .. "\nend", "@" .. path)
		assert(chunk, "harness: compile error in " .. path .. ": " .. tostring(err))
		local factory = chunk()
		-- Bind the env: script points at the module's own ModuleScript instance.
		local values = {}
		for i, name in ENV_NAMES do
			if name == "script" then
				values[i] = target
			elseif name == "os" then
				values[i] = mockOs
			elseif name == "require" then
				values[i] = realRequire
			else
				values[i] = _ENV_BINDING[name]
			end
		end
		local ok, value = pcall(factory, table.unpack(values, 1, #values))
		assert(ok, "harness: runtime error loading " .. path .. ": " .. tostring(value))
		moduleCache[path] = { value = value }
		return value
	end
	error("harness: unsupported require target: " .. tostring(target))
end

Harness.game = game
Harness.Players = Players
Harness.makePlayer = makePlayer
Harness.services = services
Harness.Instance = Instance
Harness.Enum = Enum
Harness.Vector3 = Vector3
Harness.CFrame = CFrame
Harness.os = mockOs
Harness.sharedFolder = sharedFolder
Harness.serverFolder = serverFolder
Harness.requireModule = realRequire

return Harness
