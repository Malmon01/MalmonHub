-- teleport_to_player.lua
-- Teleport to a player in the SAME server by Username / DisplayName.
-- Supports exact or partial name matching.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = PlayerGui:FindFirstChild("TeleportToPlayerGUI")
if old then
	old:Destroy()
end

local function getCharacterRoot(player)
	if not player then return nil end

	local character = player.Character
	if not character then return nil end

	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
end

local function findPlayer(input)
	input = string.lower(
		string.gsub(
			tostring(input or ""),
			"^%s*(.-)%s*$",
			"%1"
		)
	)

	if input == "" then
		return nil
	end

	-- Exact username first.
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.lower(player.Name) == input then
			return player
		end
	end

	-- Exact display name.
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.lower(player.DisplayName) == input then
			return player
		end
	end

	-- Partial username.
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.find(string.lower(player.Name), input, 1, true) then
			return player
		end
	end

	-- Partial display name.
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.find(string.lower(player.DisplayName), input, 1, true) then
			return player
		end
	end

	return nil
end

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportToPlayerGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(330, 270)
frame.Position = UDim2.new(0.5, -165, 0.5, -122)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 42)
title.Position = UDim2.fromOffset(14, 6)
title.BackgroundTransparency = 1
title.Text = "Teleport to Player"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local version = Instance.new("TextLabel")
version.Size = UDim2.fromOffset(80, 20)
version.Position = UDim2.new(1, -128, 0, 17)
version.BackgroundTransparency = 1
version.Text = "LOOP V2"
version.TextColor3 = Color3.fromRGB(120, 210, 150)
version.Font = Enum.Font.GothamBold
version.TextSize = 11
version.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -42, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -28, 0, 42)
input.Position = UDim2.fromOffset(14, 57)
input.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
input.PlaceholderText = "Username / DisplayName"
input.Text = ""
input.ClearTextOnFocus = false
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderColor3 = Color3.fromRGB(155, 155, 165)
input.Font = Enum.Font.Gotham
input.TextSize = 16
input.Parent = frame
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)

local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1, -28, 0, 42)
teleportButton.Position = UDim2.fromOffset(14, 108)
teleportButton.BackgroundColor3 = Color3.fromRGB(45, 135, 85)
teleportButton.Text = "TELEPORT"
teleportButton.TextColor3 = Color3.new(1, 1, 1)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 16
teleportButton.Parent = frame
Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0, 8)

local loopButton = Instance.new("TextButton")
loopButton.Size = UDim2.new(1, -28, 0, 42)
loopButton.Position = UDim2.fromOffset(14, 158)
loopButton.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
loopButton.Text = "LOOP TELEPORT : OFF"
loopButton.TextColor3 = Color3.new(1, 1, 1)
loopButton.Font = Enum.Font.GothamBold
loopButton.TextSize = 16
loopButton.Parent = frame
Instance.new("UICorner", loopButton).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -28, 0, 24)
status.Position = UDim2.fromOffset(14, 215)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(190, 190, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local busy = false
local loopEnabled = false
local loopTarget = nil

-- Lower = follows the player more tightly.
local LOOP_INTERVAL = 0.08

local function setLoopState(enabled)
	loopEnabled = enabled == true

	loopButton.Text =
		loopEnabled
		and "LOOP TELEPORT : ON"
		or "LOOP TELEPORT : OFF"

	loopButton.BackgroundColor3 =
		loopEnabled
		and Color3.fromRGB(45, 135, 85)
		or Color3.fromRGB(70, 70, 82)

	if not loopEnabled then
		loopTarget = nil
	end
end

local function teleportToTarget(target)
	if not target or target.Parent ~= Players then
		return false, "Player left the server."
	end

	local myRoot = getCharacterRoot(LocalPlayer)
	local targetRoot = getCharacterRoot(target)

	if not myRoot then
		return false, "Your character is not ready."
	end

	if not targetRoot then
		return false, target.Name .. " character is not ready."
	end

	-- Stay about 3 studs behind the target.
	local destination =
		targetRoot.CFrame
		* CFrame.new(0, 0, 3)

	pcall(function()
		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.AssemblyAngularVelocity = Vector3.zero
	end)

	myRoot.CFrame = destination

	return true
end

local function teleportToInput()
	if busy then
		return
	end

	busy = true

	local target = findPlayer(input.Text)

	if not target then
		status.Text = "Player not found in this server."
		busy = false
		return
	end

	local ok, err = teleportToTarget(target)

	if not ok then
		status.Text = err or "Teleport failed."
		busy = false
		return
	end

	status.Text =
		"Teleported to "
		.. target.Name
		.. " ("
		.. target.DisplayName
		.. ")"

	busy = false
end

teleportButton.MouseButton1Click:Connect(teleportToInput)

loopButton.MouseButton1Click:Connect(function()
	if loopEnabled then
		setLoopState(false)
		status.Text = "Loop stopped."
		return
	end

	local target = findPlayer(input.Text)

	if not target then
		status.Text = "Player not found in this server."
		return
	end

	loopTarget = target
	setLoopState(true)

	status.Text =
		"Looping to "
		.. target.Name
end)

task.spawn(function()
	while gui.Parent do
		if loopEnabled then
			if not loopTarget
				or loopTarget.Parent ~= Players then

				setLoopState(false)
				status.Text = "Target left the server."
			else
				local ok, err =
					teleportToTarget(loopTarget)

				if ok then
					status.Text =
						"LOOP -> "
						.. loopTarget.Name
				else
					status.Text =
						err or "Loop teleport failed."
				end
			end
		end

		task.wait(LOOP_INTERVAL)
	end
end)

input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		teleportToInput()
	end
end)

close.MouseButton1Click:Connect(function()
	setLoopState(false)
	gui:Destroy()
end)
