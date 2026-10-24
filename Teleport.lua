local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local YELLOW = Color3.fromRGB(255, 220, 40)
local GREEN = Color3.fromRGB(50, 255, 80)
local GUI_NAME = "_ComputerTravelMenu"

-- Clean up the previous copy of this add-on.
local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local connections = {}
local computers = {}
local alive = true
local queued = false
local nextId = 0

local function listen(signal, callback, bucket)
	local connection = signal:Connect(callback)
	table.insert(bucket or connections, connection)
	return connection
end

local function disconnect(bucket)
	for _, connection in ipairs(bucket) do
		connection:Disconnect()
	end
end

local function hasClearWall(computer)
	for _, object in ipairs(computer:GetDescendants()) do
		if object.Name:lower() == "clearwall" then
			return true
		end
	end
	return false
end

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(220, 36)
toggle.Position = UDim2.new(1, -235, 0, 80)
toggle.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.Text = "COMPUTERS — Hide"
toggle.Parent = gui

local panel = Instance.new("ScrollingFrame")
panel.Position = UDim2.new(1, -235, 0, 120)
panel.Size = UDim2.fromOffset(220, 230)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
panel.BorderSizePixel = 0
panel.ScrollBarThickness = 5
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.CanvasSize = UDim2.new()
panel.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -8, 0, 34)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 13
status.Font = Enum.Font.Gotham
status.LayoutOrder = -1
status.Parent = panel

listen(toggle.Activated, function()
	panel.Visible = not panel.Visible
	toggle.Text = panel.Visible
		and "COMPUTERS — Hide"
		or "COMPUTERS — Show"
end)

local function teleportTo(computer)
	if not computer:IsDescendantOf(Workspace)
		or hasClearWall(computer) then
		status.Text = "Computer no longer available"
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root or not humanoid or humanoid.Health <= 0 then
		status.Text = "Character not ready"
		return
	end

	local trigger = computer:FindFirstChild("ComputerTrigger1", true)
	local base = computer:FindFirstChild("BasePart", true)
	local anchor = trigger or base

	if not anchor or not anchor:IsA("BasePart") then
		status.Text = "Teleport position not found"
		return
	end

	-- Place the character above the interaction area.
	local position = anchor.Position + Vector3.new(
		0, anchor.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2 + 0.5, 0
	)

	local screen = computer:FindFirstChild("Screen", true)
	local facing = screen and screen:IsA("BasePart")
		and screen.Position or computer:GetPivot().Position

	local lookAt = Vector3.new(facing.X, position.Y, facing.Z)
	local destination = CFrame.new(position)

	if (lookAt - position).Magnitude > 0.1 then
		destination = CFrame.lookAt(position, lookAt)
	end

	-- Preserve the model pivot's offset from HumanoidRootPart.
	local offset = root.CFrame:ToObjectSpace(character:GetPivot())
	character:PivotTo(destination * offset)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	status.Text = "Teleport requested"
end

local function refresh()
	if not alive then return end
	local pending = 0

	for computer, entry in pairs(computers) do
		if computer:IsDescendantOf(Workspace) then
			local cleared = hasClearWall(computer)
			local color = cleared and GREEN or YELLOW

			-- Reuse the existing highlight to avoid overlapping effects.
			local h = computer:FindFirstChild("_PersistentRoleHighlight")
				or computer:FindFirstChild("_DiagnosticHighlight")

			if not h or not h:IsA("Highlight") then
				h = computer:FindFirstChild("_ComputerStatusHighlight")
				if not h then
					h = Instance.new("Highlight")
					h.Name = "_ComputerStatusHighlight"
					h.Adornee = computer
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.FillTransparency = 0.5
					h.OutlineTransparency = 0
					h.Parent = computer
					entry.ownedHighlight = h
				end
			end

			h.FillColor = color
			h.OutlineColor = color
			h.Enabled = true
			entry.button.Visible = not cleared

			if not cleared then
				pending = pending + 1
			end
		end
	end

	status.Text = "Available computers: " .. pending
end

local function scheduleRefresh()
	if queued or not alive then return end
	queued = true
	task.defer(function()
		queued = false
		refresh()
	end)
end

local function register(computer)
	if computers[computer]
		or computer.Name ~= "ComputerTable"
		or not computer:IsA("Model") then
		return
	end

	nextId = nextId + 1

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(75, 65, 25)
	button.TextColor3 = YELLOW
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = "Teleport → Computer " .. nextId
	button.LayoutOrder = nextId
	button.Parent = panel

	local entry = { button = button, connections = {} }
	computers[computer] = entry

	listen(button.Activated, function()
		teleportTo(computer)
	end, entry.connections)

	listen(computer.DescendantAdded, scheduleRefresh, entry.connections)
	listen(computer.DescendantRemoving, scheduleRefresh, entry.connections)

	scheduleRefresh()
end

listen(Workspace.DescendantAdded, register)

listen(Workspace.DescendantRemoving, function(object)
	local entry = computers[object]
	if not entry then return end

	disconnect(entry.connections)
	entry.button:Destroy()
	if entry.ownedHighlight then
		entry.ownedHighlight:Destroy()
	end
	computers[object] = nil
	scheduleRefresh()
end)

listen(gui.Destroying, function()
	alive = false
	disconnect(connections)

	for _, entry in pairs(computers) do
		disconnect(entry.connections)
		if entry.ownedHighlight then
			entry.ownedHighlight:Destroy()
		end
	end
	table.clear(computers)
end)

-- One initial scan; subsequent changes use events.
for _, object in ipairs(Workspace:GetDescendants()) do
	register(object)
end

scheduleRefresh()
print("Computer menu ready: yellow = no ClearWall, green = ClearWall")
