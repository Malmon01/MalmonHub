local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer

local RED = Color3.fromRGB(255, 50, 50)
local BLUE = Color3.fromRGB(50, 180, 255)
local GREEN = Color3.fromRGB(50, 255, 80)

-- Stop the previous copy when running this code again.
local KEY = "_PersistentHighlightRun"
local token = (me:GetAttribute(KEY) or 0) + 1
me:SetAttribute(KEY, token)

local running = true
local connections = {}
local playerStates = {}
local highlights = {}

local function connect(signal, callback, list)
	local connection = signal:Connect(callback)
	table.insert(list or connections, connection)
	return connection
end

local function disconnectAll(list)
	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	table.clear(list)
end

local function removeHighlight(target)
	local h = highlights[target]
	if h then
		h:Destroy()
		highlights[target] = nil
	end
end

local function mark(target, color)
	if not running then return end

	local h = highlights[target]
	if not h or h.Parent ~= target then
		-- Remove only effects from our earlier examples.
		for _, name in ipairs({
			"HighlightTest",
			"_DiagnosticHighlight",
			"_LiveRoleHighlight",
			"_PersistentRoleHighlight",
		}) do
			local old = target:FindFirstChild(name)
			if old and old:IsA("Highlight") then
				old:Destroy()
			end
		end

		h = Instance.new("Highlight")
		h.Name = "_PersistentRoleHighlight"
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.5
		h.OutlineTransparency = 0
		h.Parent = target
		highlights[target] = h
	end

	h.FillColor = color
	h.OutlineColor = color
	h.Enabled = true
end

local function refreshPlayer(player)
	local state = playerStates[player]
	if not state or not running then return end

	local character = player.Character
	if state.character ~= character then
		if state.character then
			removeHighlight(state.character)
		end
		state.character = character
	end

	if not character or not character:IsDescendantOf(Workspace) then
		return
	end

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")
	local beast = flag and flag:IsA("BoolValue") and flag.Value

	mark(character, beast and RED or BLUE)
end

local function bindRole(player)
	local state = playerStates[player]
	if not state or not running then return end

	disconnectAll(state.roleConnections)

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	if stats then
		local function roleStructureChanged(child)
			if child.Name == "IsBeast" then
				bindRole(player)
			end
		end

		connect(stats.ChildAdded, roleStructureChanged, state.roleConnections)
		connect(stats.ChildRemoved, roleStructureChanged, state.roleConnections)

		local flag = stats:FindFirstChild("IsBeast")
		if flag and flag:IsA("BoolValue") then
			connect(flag:GetPropertyChangedSignal("Value"), function()
				refreshPlayer(player)
			end, state.roleConnections)
		end
	end

	refreshPlayer(player)
end

local function watchPlayer(player)
	if playerStates[player] or not running then return end

	local state = {
		connections = {},
		roleConnections = {},
		character = nil,
	}
	playerStates[player] = state

	connect(player.CharacterAdded, function()
		refreshPlayer(player)
	end, state.connections)

	connect(player.CharacterRemoving, function(character)
		removeHighlight(character)
		if state.character == character then
			state.character = nil
		end
	end, state.connections)

	local function statsChanged(child)
		if child.Name == "TempPlayerStatsModule" then
			bindRole(player)
		end
	end

	connect(player.ChildAdded, statsChanged, state.connections)
	connect(player.ChildRemoved, statsChanged, state.connections)

	bindRole(player)
end

local function unwatchPlayer(player)
	local state = playerStates[player]
	if not state then return end

	disconnectAll(state.connections)
	disconnectAll(state.roleConnections)
	if state.character then
		removeHighlight(state.character)
	end
	playerStates[player] = nil
end

local function objectAdded(object)
	if not running then return end

	if object.Name == "ComputerTable"
		and (object:IsA("Model") or object:IsA("BasePart")) then
		mark(object, GREEN)
	elseif object:IsA("Model") then
		-- Handles characters entering Workspace after CharacterAdded.
		local player = Players:GetPlayerFromCharacter(object)
		if player then
			refreshPlayer(player)
		end
	end
end

local function stop()
	if not running then return end
	running = false

	disconnectAll(connections)

	for player in pairs(playerStates) do
		unwatchPlayer(player)
	end

	for target in pairs(highlights) do
		removeHighlight(target)
	end
end

connect(me:GetAttributeChangedSignal(KEY), function()
	if me:GetAttribute(KEY) ~= token then
		stop()
	end
end)

connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, unwatchPlayer)

connect(Workspace.DescendantAdded, objectAdded)
connect(Workspace.DescendantRemoving, function(object)
	if highlights[object] then
		removeHighlight(object)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

-- Scan once; future maps are handled by DescendantAdded.
for _, object in ipairs(Workspace:GetDescendants()) do
	if object.Name == "ComputerTable"
		and (object:IsA("Model") or object:IsA("BasePart")) then
		mark(object, GREEN)
	end
end

print("Highlight active: automatic rounds, respawns and role changes")
