-- Roblox Studio: StarterPlayer > StarterPlayerScripts > LocalScript
-- Test with Play. Client-side movement panel for your own experience.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Add more destinations here. Coordinates below come from the attached image.
local LOCATIONS = {
	{ name = "Spawn Point", position = Vector3.new(-743.648132, 37.7241478, 124.247498) },
}
local TELEPORT_HEIGHT_OFFSET = 3
local JUMP_SPEED = 50
local infiniteJump = false
local noclip = false
local originalCollision = {}
local connections = {}
local cleaned = false

-- Replacing a previous panel also disconnects its movement handlers.
local previous = playerGui:FindFirstChild("MovementPanel")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MovementPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function round(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 228 + #LOCATIONS * 40)
panel.Position = UDim2.new(0, 12, 0.5, -(228 + #LOCATIONS * 40) / 2)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.Parent = gui
round(panel, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "Movement Panel"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = panel

local function button(text, parent, y)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -24, 0, 34)
	b.Position = UDim2.fromOffset(12, y)
	b.BackgroundColor3 = Color3.fromRGB(55, 61, 77)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 14
	b.Font = Enum.Font.GothamMedium
	b.Text = text
	b.Parent = parent
	round(b, 8)
	return b
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function restoreCollision()
	for part, value in pairs(originalCollision) do
		if part.Parent then part.CanCollide = value end
	end
	table.clear(originalCollision)
end

local function paintToggle(b, label, enabled)
	b.Text = label .. (enabled and ": ON" or ": OFF")
	b.BackgroundColor3 = enabled and Color3.fromRGB(28, 132, 92)
		or Color3.fromRGB(55, 61, 77)
end

local jumpButton = button("Infinite Jump: OFF", panel, 46)
local noclipButton = button("Noclip: OFF", panel, 86)
connect(jumpButton.Activated, function()
	infiniteJump = not infiniteJump
	paintToggle(jumpButton, "Infinite Jump", infiniteJump)
end)
connect(noclipButton.Activated, function()
	noclip = not noclip
	if not noclip then restoreCollision() end
	paintToggle(noclipButton, "Noclip", noclip)
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 30)
status.Position = UDim2.fromOffset(12, 128 + #LOCATIONS * 40)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(195, 202, 220)
status.TextSize = 12
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.Parent = panel

for index, destination in ipairs(LOCATIONS) do
	local teleportButton = button("Teleport: " .. destination.name, panel, 126 + (index - 1) * 40)
	connect(teleportButton.Activated, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			status.Text = "Wait for your character to spawn."
			return
		end
		if humanoid.SeatPart then
			status.Text = "Leave your seat before teleporting."
			return
		end
		local target = destination.position + Vector3.new(0, TELEPORT_HEIGHT_OFFSET, 0)
		-- Translate the whole model so its root reaches the target; preserve orientation.
		character:PivotTo(character:GetPivot() + (target - root.Position))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		status.Text = "Teleported to " .. destination.name
	end)
end

local hideButton = button("Hide menu", panel, 164 + #LOCATIONS * 40)
local showButton = button("Show menu", gui, 12)
showButton.Size = UDim2.fromOffset(120, 34)
showButton.Visible = false
connect(hideButton.Activated, function()
	panel.Visible = false
	showButton.Visible = true
end)
connect(showButton.Activated, function()
	panel.Visible = true
	showButton.Visible = false
end)

local lastJump = 0
connect(UserInputService.JumpRequest, function()
	if not infiniteJump or UserInputService:GetFocusedTextBox() then return end
	local now = os.clock()
	if now - lastJump < 0.12 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then return end
	lastJump = now
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, JUMP_SPEED, velocity.Z)
end)

connect(RunService.PreSimulation, function()
	if not noclip then return end
	local character = player.Character
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if originalCollision[part] == nil then
				originalCollision[part] = part.CanCollide
			end
			part.CanCollide = false
		end
	end
end)

connect(player.CharacterRemoving, function()
	restoreCollision()
	lastJump = 0
end)

local function cleanup()
	if cleaned then return end
	cleaned = true
	infiniteJump = false
	noclip = false
	for _, connection in ipairs(connections) do connection:Disconnect() end
	restoreCollision()
end
gui.Destroying:Connect(cleanup)
script.Destroying:Connect(function()
	cleanup()
	gui:Destroy()
end)
