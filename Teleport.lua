-- teleport_to_player_client_only_v7.lua
-- Client-only teleport/follow.
--
-- NO ServerScript, NO RemoteEvent, NO server-side changes.
--
-- Strategy:
-- 1) Try small CFrame steps (not one huge jump).
-- 2) Detect when the server/physics pulls us back.
-- 3) Automatically fall back to Humanoid:MoveTo so normal Roblox
--    character movement replication can keep moving toward the target.
--
-- This is not a true server-authoritative teleport. If the game server
-- rejects all client position changes, no client-only script can guarantee
-- an instant teleport. This script tries the most reliable client-only path.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------
-- SETTINGS
--------------------------------------------------------------

local FRONT_DISTANCE = 3

-- CFrame movement per step.
local STEP_DISTANCE = 2.25

-- Close enough to snap directly.
local SNAP_DISTANCE = 6

-- If two consecutive CFrame steps are rejected, use MoveTo.
local RUBBERBAND_FAILS_BEFORE_MOVETO = 2

-- Loop update speed.
local LOOP_INTERVAL = 0.05

-- Single teleport safety timeout.
local TELEPORT_TIMEOUT = 12

--------------------------------------------------------------
-- CLEAN OLD GUI
--------------------------------------------------------------

local old = PlayerGui:FindFirstChild("ClientOnlyTeleportV7")
if old then
	old:Destroy()
end

--------------------------------------------------------------
-- CHARACTER / TARGET HELPERS
--------------------------------------------------------------

local function getCharacter(player)
	return player and player.Character
end

local function getRoot(player)
	local character = getCharacter(player)
	if not character then return nil end

	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
end

local function getHumanoid(player)
	local character = getCharacter(player)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function trim(value)
	return (
		string.gsub(
			tostring(value or ""),
			"^%s*(.-)%s*$",
			"%1"
		)
	)
end

local function findPlayer(input)
	input = string.lower(trim(input))

	if input == "" then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.lower(player.Name) == input then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.lower(player.DisplayName) == input then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.find(
				string.lower(player.Name),
				input,
				1,
				true
			) then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer
			and string.find(
				string.lower(player.DisplayName),
				input,
				1,
				true
			) then
			return player
		end
	end

	return nil
end

local function getFrontCFrame(targetRoot)
	local front =
		targetRoot.Position
		+ targetRoot.CFrame.LookVector * FRONT_DISTANCE

	return CFrame.lookAt(
		front,
		targetRoot.Position
	)
end

--------------------------------------------------------------
-- CLIENT MOVEMENT
--------------------------------------------------------------

local function stopHumanoidMove()
	local humanoid = getHumanoid(LocalPlayer)
	local root = getRoot(LocalPlayer)

	if humanoid and root then
		pcall(function()
			humanoid:MoveTo(root.Position)
		end)
	end
end

local function cframeStepToward(target)
	local root = getRoot(LocalPlayer)
	local targetRoot = getRoot(target)

	if not root or not targetRoot then
		return false, "Character not ready", false
	end

	local wanted = getFrontCFrame(targetRoot)
	local delta = wanted.Position - root.Position
	local distance = delta.Magnitude

	if distance <= SNAP_DISTANCE then
		local before = root.Position

		root.CFrame = wanted

		RunService.Heartbeat:Wait()

		local after = root.Position
		local madeProgress =
			(after - before).Magnitude > 0.35
			or (after - wanted.Position).Magnitude < SNAP_DISTANCE

		return true, "SNAP", not madeProgress
	end

	local direction = delta.Unit
	local stepDistance = math.min(STEP_DISTANCE, distance)

	local before = root.Position
	local nextPosition =
		before + direction * stepDistance

	root.CFrame =
		CFrame.lookAt(
			nextPosition,
			targetRoot.Position
		)

	-- Give replication/physics one frame to react.
	RunService.Heartbeat:Wait()

	local after = root.Position
	local progress =
		(after - before):Dot(direction)

	-- Little/no forward progress = likely rubber-band correction.
	local rubberband =
		progress < math.max(0.20, stepDistance * 0.15)

	return true, "STEP", rubberband
end

local function moveToFallback(target)
	local humanoid = getHumanoid(LocalPlayer)
	local targetRoot = getRoot(target)

	if not humanoid or not targetRoot then
		return false
	end

	local wanted = getFrontCFrame(targetRoot)

	pcall(function()
		humanoid:MoveTo(wanted.Position)
	end)

	return true
end

--------------------------------------------------------------
-- GUI
--------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ClientOnlyTeleportV7"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(350, 292)
frame.Position = UDim2.new(0.5, -175, 0.5, -146)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 0, 42)
title.Position = UDim2.fromOffset(14, 6)
title.BackgroundTransparency = 1
title.Text = "Client Teleport"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local badge = Instance.new("TextLabel")
badge.Size = UDim2.fromOffset(98,20)
badge.Position = UDim2.new(1,-148,0,17)
badge.BackgroundTransparency = 1
badge.Text = "CLIENT V7"
badge.TextColor3 = Color3.fromRGB(120,210,150)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 10
badge.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34,34)
close.Position = UDim2.new(1,-42,0,8)
close.BackgroundColor3 = Color3.fromRGB(65,65,75)
close.Text = "X"
close.TextColor3 = Color3.new(1,1,1)
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0,8)

local input = Instance.new("TextBox")
input.Size = UDim2.new(1,-28,0,42)
input.Position = UDim2.fromOffset(14,58)
input.BackgroundColor3 = Color3.fromRGB(45,45,54)
input.PlaceholderText = "Username / DisplayName"
input.Text = ""
input.ClearTextOnFocus = false
input.TextColor3 = Color3.new(1,1,1)
input.PlaceholderColor3 = Color3.fromRGB(155,155,165)
input.Font = Enum.Font.Gotham
input.TextSize = 16
input.Parent = frame
Instance.new("UICorner", input).CornerRadius = UDim.new(0,8)

local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1,-28,0,42)
teleportButton.Position = UDim2.fromOffset(14,110)
teleportButton.BackgroundColor3 = Color3.fromRGB(45,135,85)
teleportButton.Text = "TELEPORT / ADAPTIVE"
teleportButton.TextColor3 = Color3.new(1,1,1)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 16
teleportButton.Parent = frame
Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0,8)

local loopButton = Instance.new("TextButton")
loopButton.Size = UDim2.new(1,-28,0,42)
loopButton.Position = UDim2.fromOffset(14,160)
loopButton.BackgroundColor3 = Color3.fromRGB(70,70,82)
loopButton.Text = "LOOP : OFF"
loopButton.TextColor3 = Color3.new(1,1,1)
loopButton.Font = Enum.Font.GothamBold
loopButton.TextSize = 16
loopButton.Parent = frame
Instance.new("UICorner", loopButton).CornerRadius = UDim.new(0,8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,68)
status.Position = UDim2.fromOffset(14,212)
status.BackgroundTransparency = 1
status.Text = "Ready | CFrame steps + MoveTo fallback"
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(190,190,200)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = frame

--------------------------------------------------------------
-- RUNTIME STATE
--------------------------------------------------------------

local loopEnabled = false
local loopTarget = nil
local loopConnection = nil
local loopGeneration = 0
local singleGeneration = 0
local consecutiveRubberbands = 0
local lastLoopTick = 0

local function stopLoop()
	loopEnabled = false
	loopTarget = nil
	loopGeneration += 1
	consecutiveRubberbands = 0

	if loopConnection then
		pcall(function()
			loopConnection:Disconnect()
		end)
		loopConnection = nil
	end

	stopHumanoidMove()

	loopButton.Text = "LOOP : OFF"
	loopButton.BackgroundColor3 = Color3.fromRGB(70,70,82)
end

local function startLoop(target)
	stopLoop()

	loopEnabled = true
	loopTarget = target
	loopGeneration += 1

	local generation = loopGeneration
	lastLoopTick = 0
	consecutiveRubberbands = 0

	loopButton.Text = "LOOP : ON"
	loopButton.BackgroundColor3 = Color3.fromRGB(45,135,85)

	loopConnection =
		RunService.Heartbeat:Connect(function()
			if not loopEnabled
				or generation ~= loopGeneration then
				return
			end

			if not loopTarget
				or loopTarget.Parent ~= Players then

				stopLoop()
				status.Text = "Target left the server."
				return
			end

			local now = os.clock()
			if now - lastLoopTick < LOOP_INTERVAL then
				return
			end
			lastLoopTick = now

			local ok, mode, rubberband =
				cframeStepToward(loopTarget)

			if not ok then
				status.Text = tostring(mode)
				return
			end

			if rubberband then
				consecutiveRubberbands += 1
			else
				consecutiveRubberbands = 0
			end

			if consecutiveRubberbands
				>= RUBBERBAND_FAILS_BEFORE_MOVETO then

				moveToFallback(loopTarget)

				status.Text =
					"LOOP: server correction detected -> MoveTo fallback"
			else
				status.Text =
					"LOOP "
					.. tostring(mode)
					.. " -> "
					.. loopTarget.Name
			end
		end)
end

--------------------------------------------------------------
-- BUTTONS
--------------------------------------------------------------

teleportButton.MouseButton1Click:Connect(function()
	local target = findPlayer(input.Text)

	if not target then
		status.Text = "Player not found in this server."
		return
	end

	singleGeneration += 1
	local generation = singleGeneration

	status.Text =
		"Moving to "
		.. target.Name
		.. "..."

	task.spawn(function()
		local startTime = os.clock()
		local failures = 0

		while generation == singleGeneration
			and target.Parent == Players
			and os.clock() - startTime < TELEPORT_TIMEOUT do

			local myRoot = getRoot(LocalPlayer)
			local targetRoot = getRoot(target)

			if not myRoot or not targetRoot then
				status.Text = "Character not ready."
				return
			end

			local wanted = getFrontCFrame(targetRoot)
			local distance =
				(myRoot.Position - wanted.Position).Magnitude

			if distance <= 3.5 then
				myRoot.CFrame = wanted
				stopHumanoidMove()

				status.Text =
					"Reached "
					.. target.Name
				return
			end

			local ok, mode, rubberband =
				cframeStepToward(target)

			if not ok then
				status.Text = tostring(mode)
				return
			end

			if rubberband then
				failures += 1
			else
				failures = 0
			end

			if failures
				>= RUBBERBAND_FAILS_BEFORE_MOVETO then

				moveToFallback(target)

				status.Text =
					"Rubber-band detected -> normal MoveTo fallback"

				task.wait(0.15)
			end

			RunService.Heartbeat:Wait()
		end

		if generation == singleGeneration then
			status.Text =
				"Could not reach target client-only."
		end
	end)
end)

loopButton.MouseButton1Click:Connect(function()
	if loopEnabled then
		stopLoop()
		status.Text = "Loop stopped. No movement task remains."
		return
	end

	local target = findPlayer(input.Text)

	if not target then
		status.Text = "Player not found in this server."
		return
	end

	startLoop(target)
	status.Text = "Looping to " .. target.Name
end)

input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		teleportButton:Activate()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player == loopTarget then
		stopLoop()
		status.Text = "Target left the server."
	end
end)

close.MouseButton1Click:Connect(function()
	singleGeneration += 1
	stopLoop()
	gui:Destroy()
end)
