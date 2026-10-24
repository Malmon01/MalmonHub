local Players = game:GetService("Players")
local W = game:GetService("Workspace")
local me = Players.LocalPlayer
local pg = me:WaitForChild("PlayerGui")

local RED = Color3.fromRGB(255, 50, 50)
local BLUE = Color3.fromRGB(50, 180, 255)
local YELLOW = Color3.fromRGB(255, 220, 40)
local GREEN = Color3.fromRGB(50, 255, 80)

-- Stop earlier versions.
for _, key in ipairs({
	"_PersistentHighlightRun",
	"_PlayerRoleHighlightVersion",
	"_RoleHighlightRun",
}) do
	me:SetAttribute(key, (me:GetAttribute(key) or 0) + 1)
end

for _, name in ipairs({
	"_ComputerTravelMenu",
	"_UnifiedHighlightMenu",
}) do
	local old = pg:FindFirstChild(name)
	if old then old:Destroy() end
end

for _, name in ipairs({
	"RoleHighlights",
	"_RoleHighlightEffects",
}) do
	local old = W:FindFirstChild(name)
	if old then old:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "_UnifiedHighlightMenu"
gui.ResetOnSpawn = false
gui.Parent = pg

local alive = true
local connections = {}
local people = {}
local computers = {}
local serial = 0

local function listen(signal, callback, bucket)
	local connection = signal:Connect(callback)
	table.insert(bucket or connections, connection)
	return connection
end

local function disconnect(bucket)
	for _, connection in ipairs(bucket) do
		connection:Disconnect()
	end
	table.clear(bucket)
end

local function makeHighlight(target)
	for _, name in ipairs({
		"HighlightTest",
		"_DiagnosticHighlight",
		"_LiveRoleHighlight",
		"_PersistentRoleHighlight",
		"_PlayerRoleHighlight",
		"_ComputerStatusHighlight",
		"_UnifiedHighlight",
	}) do
		local old = target:FindFirstChild(name)
		if old and old:IsA("Highlight") then
			old:Destroy()
		end
	end

	local h = Instance.new("Highlight")
	h.Name = "_UnifiedHighlight"
	h.Adornee = target
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0
	h.Parent = target
	return h
end

local function setColor(h, color)
	h.FillColor = color
	h.OutlineColor = color
	h.Enabled = true
end

-- MENU

local toggle = Instance.new("TextButton")
toggle.Position = UDim2.new(1, -235, 0, 80)
toggle.Size = UDim2.fromOffset(220, 36)
toggle.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.TextSize = 14
toggle.Font = Enum.Font.GothamBold
toggle.Text = "COMPUTERS — Hide"
toggle.Parent = gui

local panel = Instance.new("ScrollingFrame")
panel.Position = UDim2.new(1, -235, 0, 120)
panel.Size = UDim2.fromOffset(220, 260)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
panel.BorderSizePixel = 0
panel.ScrollBarThickness = 5
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.CanvasSize = UDim2.fromOffset(0, 0)
panel.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -8, 0, 34)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.LayoutOrder = -1
status.Text = "Computers: 0"
status.Parent = panel

listen(toggle.Activated, function()
	panel.Visible = not panel.Visible
	toggle.Text = panel.Visible
		and "COMPUTERS — Hide"
		or "COMPUTERS — Show"
end)

-- PLAYER HIGHLIGHTS AND NAMES

local function clearCharacter(state)
	disconnect(state.characterConnections)

	if state.h then state.h:Destroy() end
	if state.tag then state.tag:Destroy() end

	state.h = nil
	state.tag = nil
	state.label = nil
	state.character = nil
end

local function updatePlayer(player)
	local state = people[player]
	if not alive or not state then return end

	local character = state.character
	if not character then return end

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")
	local beast = flag and flag:IsA("BoolValue") and flag.Value
	local color = beast and RED or BLUE

	if not state.h or state.h.Parent ~= character then
		state.h = makeHighlight(character)
	end
	setColor(state.h, color)

	local head = character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")

	if not state.tag then
		local tag = Instance.new("BillboardGui")
		tag.Name = "_UnifiedName"
		tag.Size = UDim2.fromOffset(250, 48)
		tag.StudsOffset = Vector3.new(0, 2.8, 0)
		tag.AlwaysOnTop = true
		tag.Parent = gui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextStrokeTransparency = 0
		label.Parent = tag

		state.tag = tag
		state.label = label
	end

	state.tag.Adornee = head
	state.tag.Enabled =
		head ~= nil and character:IsDescendantOf(W)

	state.label.TextColor3 = color
	state.label.Text =
		player.DisplayName .. " (@" .. player.Name .. ")\n"
		.. (beast and "BEAST" or "SURVIVOR")
end

local function bindRole(player)
	local state = people[player]
	if not alive or not state then return end

	disconnect(state.roleConnections)

	local stats = player:FindFirstChild("TempPlayerStatsModule")
	if stats then
		local function changed(child)
			if child.Name == "IsBeast" then
				bindRole(player)
			end
		end

		listen(stats.ChildAdded, changed, state.roleConnections)
		listen(stats.ChildRemoved, changed, state.roleConnections)

		local flag = stats:FindFirstChild("IsBeast")
		if flag and flag:IsA("BoolValue") then
			listen(flag:GetPropertyChangedSignal("Value"), function()
				updatePlayer(player)
			end, state.roleConnections)
		end
	end

	updatePlayer(player)
end

local function bindCharacter(player, character)
	local state = people[player]
	if not alive or not state then return end

	clearCharacter(state)
	state.character = character

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BillboardGui")
			and object.Name == "_LiveRoleName" then
			object:Destroy()
		end
	end

	local function bodyChanged(child)
		if child.Name == "Head"
			or child.Name == "HumanoidRootPart" then
			updatePlayer(player)
		end
	end

	listen(character.ChildAdded, bodyChanged, state.characterConnections)
	listen(character.ChildRemoved, bodyChanged, state.characterConnections)

	listen(character.AncestryChanged, function()
		updatePlayer(player)
	end, state.characterConnections)

	updatePlayer(player)
end

local function removePlayer(player)
	local state = people[player]
	if not state then return end

	disconnect(state.connections)
	disconnect(state.roleConnections)
	clearCharacter(state)
	people[player] = nil
end

local function addPlayer(player)
	if people[player] or not alive then return end

	local state = {
		connections = {},
		roleConnections = {},
		characterConnections = {},
	}
	people[player] = state

	listen(player.CharacterAdded, function(character)
		bindCharacter(player, character)
	end, state.connections)

	listen(player.CharacterRemoving, function(character)
		if state.character == character then
			clearCharacter(state)
		end
	end, state.connections)

	local function statsChanged(child)
		if child.Name == "TempPlayerStatsModule" then
			bindRole(player)
		end
	end

	listen(player.ChildAdded, statsChanged, state.connections)
	listen(player.ChildRemoved, statsChanged, state.connections)

	if player.Character then
		bindCharacter(player, player.Character)
	end

	bindRole(player)
end

-- COMPUTER HIGHLIGHTS

local function hasClearWall(computer)
	for _, object in ipairs(computer:GetDescendants()) do
		if object.Name:lower() == "clearwall" then
			return true
		end
	end
	return false
end

local function updateCount()
	local count = 0
	for _ in pairs(computers) do
		count = count + 1
	end
	status.Text = "Computers: " .. count
end

local function updateComputer(computer)
	local state = computers[computer]
	if not alive or not state then return end

	local color = hasClearWall(computer) and GREEN or YELLOW
	setColor(state.h, color)

	-- Every computer stays in the teleport menu.
	state.button.Visible = true
	state.button.TextColor3 = color
end

local function queueComputer(computer)
	local state = computers[computer]
	if not alive or not state or state.queued then return end

	state.queued = true
	task.defer(function()
		if not alive or computers[computer] ~= state then return end
		state.queued = false
		updateComputer(computer)
	end)
end

-- TELEPORT TO ANY COMPUTER

local function teleport(computer)
	if not computer:IsDescendantOf(W) then
		status.Text = "Computer unavailable"
		return
	end

	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		status.Text = "Character not ready"
		return
	end

	local anchor = computer:FindFirstChild("ComputerTrigger1", true)
	if not anchor or not anchor:IsA("BasePart") then
		anchor = computer:FindFirstChild("BasePart", true)
	end

	if not anchor or not anchor:IsA("BasePart") then
		status.Text = "Position unavailable"
		return
	end

	local position = anchor.Position + Vector3.new(
		0,
		anchor.Size.Y / 2
			+ humanoid.HipHeight
			+ root.Size.Y / 2
			+ 0.5,
		0
	)

	local screen = computer:FindFirstChild("Screen", true)
	local center = screen and screen:IsA("BasePart")
		and screen.Position or computer:GetPivot().Position

	local facing = Vector3.new(center.X, position.Y, center.Z)
	local destination = CFrame.new(position)

	if (facing - position).Magnitude > 0.1 then
		destination = CFrame.lookAt(position, facing)
	end

	local offset = root.CFrame:ToObjectSpace(character:GetPivot())
	character:PivotTo(destination * offset)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	status.Text = "Teleport requested"
end

local function removeComputer(computer)
	local state = computers[computer]
	if not state then return end

	computers[computer] = nil
	disconnect(state.connections)
	state.h:Destroy()
	state.button:Destroy()

	if alive then updateCount() end
end

local function addComputer(computer)
	if not alive or computers[computer]
		or computer.Name ~= "ComputerTable"
		or not computer:IsA("Model") then
		return
	end

	serial = serial + 1

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = "Teleport → Computer " .. serial
	button.LayoutOrder = serial
	button.Parent = panel

	local state = {
		h = makeHighlight(computer),
		button = button,
		connections = {},
	}
	computers[computer] = state

	listen(button.Activated, function()
		teleport(computer)
	end, state.connections)

	listen(computer.DescendantAdded, function(object)
		if object.Name:lower() == "clearwall" then
			queueComputer(computer)
		end
	end, state.connections)

	listen(computer.DescendantRemoving, function(object)
		if object.Name:lower() == "clearwall" then
			queueComputer(computer)
		end
	end, state.connections)

	updateComputer(computer)
	updateCount()
end

-- CLEANUP AND AUTOMATIC UPDATES

listen(gui.Destroying, function()
	alive = false
	disconnect(connections)

	for player in pairs(people) do
		removePlayer(player)
	end

	for computer in pairs(computers) do
		removeComputer(computer)
	end
end)

listen(Players.PlayerAdded, addPlayer)
listen(Players.PlayerRemoving, removePlayer)

listen(W.DescendantAdded, addComputer)
listen(W.DescendantRemoving, function(object)
	if computers[object] then
		removeComputer(object)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end

-- Scan once. New maps are handled by events.
for _, object in ipairs(W:GetDescendants()) do
	addComputer(object)
end

print("Ready: player highlights + ALL computer teleports")
