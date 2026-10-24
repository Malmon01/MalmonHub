local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer

local KEY = "_PlayerRoleHighlightVersion"
local version = (me:GetAttribute(KEY) or 0) + 1
me:SetAttribute(KEY, version)

local connections = {}
local states = {}
local active = true

local function connect(signal, callback, bucket)
	local c = signal:Connect(callback)
	table.insert(bucket or connections, c)
end

local function disconnect(bucket)
	for _, c in ipairs(bucket) do
		c:Disconnect()
	end
	table.clear(bucket)
end

local function clearCharacter(state)
	disconnect(state.characterConnections)
	if state.highlight then
		state.highlight:Destroy()
		state.highlight = nil
	end
end

local function update(player)
	local state = states[player]
	if not active or not state then return end

	local character = player.Character
	if not character or not character:IsDescendantOf(Workspace) then
		return
	end

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")
	local beast = flag and flag:IsA("BoolValue") and flag.Value
	local color = beast
		and Color3.fromRGB(255, 50, 50)
		or Color3.fromRGB(50, 180, 255)

	local h = state.highlight
	if not h or h.Parent ~= character then
		-- Reuse the highlight from the earlier scripts if present.
		h = character:FindFirstChild("_PersistentRoleHighlight")
			or character:FindFirstChild("_DiagnosticHighlight")
			or character:FindFirstChild("_PlayerRoleHighlight")

		if not h or not h:IsA("Highlight") then
			h = Instance.new("Highlight")
			h.Name = "_PlayerRoleHighlight"
			h.Parent = character
		end

		state.highlight = h
	end

	h.Adornee = character
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0
	h.FillColor = color
	h.OutlineColor = color
	h.Enabled = true
end

local function bindRole(player)
	local state = states[player]
	if not active or not state then return end

	disconnect(state.roleConnections)

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	if stats then
		local function changed(child)
			if child.Name == "IsBeast" then
				bindRole(player)
			end
		end

		connect(stats.ChildAdded, changed, state.roleConnections)
		connect(stats.ChildRemoved, changed, state.roleConnections)

		local flag = stats:FindFirstChild("IsBeast")
		if flag and flag:IsA("BoolValue") then
			connect(flag:GetPropertyChangedSignal("Value"), function()
				update(player)
			end, state.roleConnections)
		end
	end

	update(player)
end

local function bindCharacter(player, character)
	local state = states[player]
	if not active or not state then return end

	clearCharacter(state)

	connect(character.AncestryChanged, function()
		update(player)
	end, state.characterConnections)

	update(player)
end

local function removePlayer(player)
	local state = states[player]
	if not state then return end

	disconnect(state.connections)
	disconnect(state.roleConnections)
	clearCharacter(state)
	states[player] = nil
end

local function addPlayer(player)
	if states[player] or not active then return end

	local state = {
		connections = {},
		roleConnections = {},
		characterConnections = {},
	}
	states[player] = state

	connect(player.CharacterAdded, function(character)
		bindCharacter(player, character)
	end, state.connections)

	connect(player.CharacterRemoving, function()
		clearCharacter(state)
	end, state.connections)

	local function statsChanged(child)
		if child.Name == "TempPlayerStatsModule" then
			bindRole(player)
		end
	end

	connect(player.ChildAdded, statsChanged, state.connections)
	connect(player.ChildRemoved, statsChanged, state.connections)

	if player.Character then
		bindCharacter(player, player.Character)
	end
	bindRole(player)
end

connect(me:GetAttributeChangedSignal(KEY), function()
	if me:GetAttribute(KEY) == version then return end

	active = false
	disconnect(connections)
	for player in pairs(states) do
		removePlayer(player)
	end
end)

connect(Players.PlayerAdded, addPlayer)
connect(Players.PlayerRemoving, removePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end

print("Player highlights active: RED beast / BLUE survivors")
