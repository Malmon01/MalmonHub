local Players = game:GetService("Players")
local W = game:GetService("Workspace")
local me = Players.LocalPlayer
local pg = me:WaitForChild("PlayerGui")

local RED = Color3.fromRGB(255, 50, 50)
local BLUE = Color3.fromRGB(50, 180, 255)
local YELLOW = Color3.fromRGB(255, 220, 40)
local GREEN = Color3.fromRGB(50, 255, 80)

-- Stop event-based versions previously supplied in this chat.
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

local function listen(signal, fn, bucket)
	local c = signal:Connect(fn)
	table.insert(bucket or connections, c)
	return c
end

local function disconnect(bucket)
	for _, c in ipairs(bucket) do c:Disconnect() end
	table.clear(bucket)
end

local function makeHighlight(target)
	for _, name in ipairs({
		"HighlightTest", "_DiagnosticHighlight",
		"_LiveRoleHighlight", "_PersistentRoleHighlight",
		"_PlayerRoleHighlight", "_ComputerStatusHighlight",
		"_UnifiedHighlight",
	}) do
		local old = target:FindFirstChild(name)
		if old and old:IsA("Highlight") then old:Destroy() end
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

local function colorHighlight(h, color)
	h.FillColor = color
	h.OutlineColor = color
	h.Enabled = true
end

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
panel.Size = UDim2.fromOffset(220, 230)
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
status.Text = "Available: 0"
status.Parent = panel

listen(toggle.Activated, function()
	panel.Visible = not panel.Visible
	toggle.Text = panel.Visible
		and "COMPUTERS — Hide" or "COMPUTERS — Show"
end)

-- PLAYERS

local function clearCharacter(s)
	disconnect(s.characterConnections)
	if s.h then s.h:Destroy() end
	if s.tag then s.tag:Destroy() end
	s.h, s.tag, s.label, s.character = nil, nil, nil, nil
end

local function updatePlayer(p)
	local s = people[p]
	if not alive or not s then return end

	local char = s.character
	if not char then return end

	local stats = p:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")
	local beast = flag and flag:IsA("BoolValue") and flag.Value
	local color = beast and RED or BLUE

	if not s.h or s.h.Parent ~= char then
		s.h = makeHighlight(char)
	end
	colorHighlight(s.h, color)

	local head = char:FindFirstChild("Head")
		or char:FindFirstChild("HumanoidRootPart")

	if not s.tag then
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
		s.tag, s.label = tag, label
	end

	s.tag.Adornee = head
	s.tag.Enabled = head ~= nil and char:IsDescendantOf(W)
	s.label.TextColor3 = color
	s.label.Text = p.DisplayName .. " (@" .. p.Name .. ")\n"
		.. (beast and "BEAST" or "SURVIVOR")
end

local function bindRole(p)
	local s = people[p]
	if not alive or not s then return end
	disconnect(s.roleConnections)

	local stats = p:FindFirstChild("TempPlayerStatsModule")
	if stats then
		local function changed(child)
			if child.Name == "IsBeast" then bindRole(p) end
		end
		listen(stats.ChildAdded, changed, s.roleConnections)
		listen(stats.ChildRemoved, changed, s.roleConnections)

		local flag = stats:FindFirstChild("IsBeast")
		if flag and flag:IsA("BoolValue") then
			listen(flag:GetPropertyChangedSignal("Value"), function()
				updatePlayer(p)
			end, s.roleConnections)
		end
	end
	updatePlayer(p)
end

local function bindCharacter(p, char)
	local s = people[p]
	if not alive or not s then return end
	clearCharacter(s)
	s.character = char

	-- Remove name tags from earlier examples.
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BillboardGui") and obj.Name == "_LiveRoleName" then
			obj:Destroy()
		end
	end

	listen(char.ChildAdded, function(child)
		if child.Name == "Head" or child.Name == "HumanoidRootPart" then
			updatePlayer(p)
		end
	end, s.characterConnections)

	listen(char.ChildRemoved, function(child)
		if child.Name == "Head" or child.Name == "HumanoidRootPart" then
			updatePlayer(p)
		end
	end, s.characterConnections)

	listen(char.AncestryChanged, function()
		updatePlayer(p)
	end, s.characterConnections)

	updatePlayer(p)
end

local function removePlayer(p)
	local s = people[p]
	if not s then return end
	disconnect(s.connections)
	disconnect(s.roleConnections)
	clearCharacter(s)
	people[p] = nil
end

local function addPlayer(p)
	if people[p] or not alive then return end
	local s = {
		connections = {},
		roleConnections = {},
		characterConnections = {},
	}
	people[p] = s

	listen(p.CharacterAdded, function(char)
		bindCharacter(p, char)
	end, s.connections)

	listen(p.CharacterRemoving, function(char)
		if s.character == char then clearCharacter(s) end
	end, s.connections)

	local function changed(child)
		if child.Name == "TempPlayerStatsModule" then bindRole(p) end
	end
	listen(p.ChildAdded, changed, s.connections)
	listen(p.ChildRemoved, changed, s.connections)

	if p.Character then bindCharacter(p, p.Character) end
	bindRole(p)
end

-- COMPUTERS

local function hasClearWall(computer)
	for _, obj in ipairs(computer:GetDescendants()) do
		if obj.Name:lower() == "clearwall" then return true end
	end
	return false
end

local function updateCount()
	local count = 0
	for _, s in pairs(computers) do
		if s.button.Visible then count = count + 1 end
	end
	status.Text = "Available: " .. count
end

local function updateComputer(computer)
	local s = computers[computer]
	if not alive or not s then return end

	local cleared = hasClearWall(computer)
	colorHighlight(s.h, cleared and GREEN or YELLOW)
	s.button.Visible = not cleared
	updateCount()
end

local function queueComputer(computer)
	local s = computers[computer]
	if not alive or not s or s.queued then return end
	s.queued = true

	task.defer(function()
		if not alive or computers[computer] ~= s then return end
		s.queued = false
		updateComputer(computer)
	end)
end

local function teleport(computer)
	if not computer:IsDescendantOf(W) or hasClearWall(computer) then
		status.Text = "Computer unavailable"
		return
	end

	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
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

	local pos = anchor.Position + Vector3.new(
		0, anchor.Size.Y / 2 + hum.HipHeight + root.Size.Y / 2 + 0.5, 0
	)
	local screen = computer:FindFirstChild("Screen", true)
	local center = screen and screen:IsA("BasePart")
		and screen.Position or computer:GetPivot().Position
	local facing = Vector3.new(center.X, pos.Y, center.Z)

	local destination = CFrame.new(pos)
	if (facing - pos).Magnitude > 0.1 then
		destination = CFrame.lookAt(pos, facing)
	end

	local pivotOffset = root.CFrame:ToObjectSpace(char:GetPivot())
	char:PivotTo(destination * pivotOffset)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	status.Text = "Teleport requested"
end

local function removeComputer(computer)
	local s = computers[computer]
	if not s then return end
	computers[computer] = nil
	disconnect(s.connections)
	s.h:Destroy()
	s.button:Destroy()
	if alive then updateCount() end
end

local function addComputer(computer)
	if not alive or computers[computer]
		or computer.Name ~= "ComputerTable"
		or not computer:IsA("Model") then return end

	serial = serial + 1
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(75, 65, 25)
	button.TextColor3 = YELLOW
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = "Teleport → Computer " .. serial
	button.LayoutOrder = serial
	button.Parent = panel

	local s = {
		h = makeHighlight(computer),
		button = button,
		connections = {},
	}
	computers[computer] = s

	listen(button.Activated, function()
		teleport(computer)
	end, s.connections)

	listen(computer.DescendantAdded, function(obj)
		if obj.Name:lower() == "clearwall" then
			queueComputer(computer)
		end
	end, s.connections)

	listen(computer.DescendantRemoving, function(obj)
		if obj.Name:lower() == "clearwall" then
			queueComputer(computer)
		end
	end, s.connections)

	updateComputer(computer)
end

-- LIFECYCLE: one scan, then event-driven updates.

listen(gui.Destroying, function()
	alive = false
	disconnect(connections)
	for p in pairs(people) do removePlayer(p) end
	for computer in pairs(computers) do
		removeComputer(computer)
	end
end)

listen(Players.PlayerAdded, addPlayer)
listen(Players.PlayerRemoving, removePlayer)
listen(W.DescendantAdded, addComputer)
listen(W.DescendantRemoving, function(obj)
	if computers[obj] then removeComputer(obj) end
end)

for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end
for _, obj in ipairs(W:GetDescendants()) do addComputer(obj) end

print("Ready: player highlights + computer status + teleport menu")
