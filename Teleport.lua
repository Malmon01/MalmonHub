-- OurTeleportInstaller.lua
-- ONE-FILE INSTALLER FOR ROBLOX STUDIO
--
-- Run this from Roblox Studio Command Bar / an authorized Studio plugin context.
-- It installs/updates:
--
--   ServerScriptService
--   └─ OurTeleportRuntimeServer
--
--   StarterPlayer
--   └─ StarterPlayerScripts
--      └─ OurTeleportRuntimeClient
--
-- Re-running this installer updates both scripts in place.
--
-- IMPORTANT:
-- This installer is for Studio authoring. A normal LocalScript/loadstring
-- running inside a live game cannot create a real server-running Script.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local StarterPlayerScripts =
	StarterPlayer:WaitForChild("StarterPlayerScripts")

local SERVER_SCRIPT_NAME = "OurTeleportRuntimeServer"
local CLIENT_SCRIPT_NAME = "OurTeleportRuntimeClient"

local SERVER_SOURCE = [==[
-- OurTeleportRuntime.server.lua
-- Server-side teleport bridge.
--
-- IMPORTANT:
-- There is NO PrivateServerOwnerId / UserId allowlist here.
-- A player is authorized only after the companion client script
-- activates this system for THAT player during the current server session.
--
-- This means:
--   - Players who never run the client script do not get a token.
--   - Their teleport / loop requests are rejected.
--   - If another player obtains and runs the same client script,
--     they can authorize themselves too. This is runtime-gating,
--     not a secret anti-copy system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FOLDER_NAME = "OurTeleportRuntime"
local FRONT_DISTANCE = 3
local LOOP_INTERVAL = 0.08

--------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------

local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)

if not folder then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
end

local function getRemote(name)
	local remote = folder:FindFirstChild(name)

	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	return remote
end

local Activate = getRemote("Activate")
local TeleportRequest = getRemote("TeleportRequest")
local LoopRequest = getRemote("LoopRequest")
local Status = getRemote("Status")

--------------------------------------------------------------
-- RUNTIME AUTH
--------------------------------------------------------------

local sessions = {}
local loopTargets = {}

local function isAuthorized(player, token)
	return player
		and sessions[player] ~= nil
		and type(token) == "string"
		and token == sessions[player]
end

Activate.OnServerEvent:Connect(function(player)
	-- New random token for this player + this server session.
	local token =
		HttpService:GenerateGUID(false)
		.. "-"
		.. HttpService:GenerateGUID(false)

	sessions[player] = token
	loopTargets[player] = nil

	-- Only send the token back to the player who activated.
	Status:FireClient(
		player,
		"ACTIVATED",
		token
	)
end)

--------------------------------------------------------------
-- CHARACTER HELPERS
--------------------------------------------------------------

local function getRoot(player)
	local character = player and player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
end

local function getHumanoid(player)
	local character = player and player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getPlayerByUserId(userId)
	userId = tonumber(userId)
	if not userId then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function buildFrontCFrame(targetRoot)
	local frontPosition =
		targetRoot.Position
		+ targetRoot.CFrame.LookVector * FRONT_DISTANCE

	return CFrame.lookAt(
		frontPosition,
		targetRoot.Position
	)
end

local function serverTeleport(player, target)
	if not player or not target or target == player then
		return false, "Invalid target."
	end

	if target.Parent ~= Players then
		return false, "Target left the server."
	end

	local character = player.Character
	local root = getRoot(player)
	local targetRoot = getRoot(target)
	local humanoid = getHumanoid(player)

	if not character
		or not root
		or not targetRoot
		or not humanoid
		or humanoid.Health <= 0 then

		return false, "Character is not ready."
	end

	-- Server-authoritative move.
	character:PivotTo(
		buildFrontCFrame(targetRoot)
	)

	return true
end

--------------------------------------------------------------
-- SINGLE TELEPORT
--------------------------------------------------------------

TeleportRequest.OnServerEvent:Connect(
	function(player, token, targetUserId)
		if not isAuthorized(player, token) then
			Status:FireClient(
				player,
				"DENIED",
				"Run/activate the teleport client first."
			)
			return
		end

		local target =
			getPlayerByUserId(targetUserId)

		local ok, message =
			serverTeleport(player, target)

		Status:FireClient(
			player,
			ok and "INFO" or "ERROR",
			ok
				and ("Teleported to " .. target.Name)
				or (message or "Teleport failed.")
		)
	end
)

--------------------------------------------------------------
-- LOOP TELEPORT
--------------------------------------------------------------

LoopRequest.OnServerEvent:Connect(
	function(player, token, enabled, targetUserId)
		if not isAuthorized(player, token) then
			loopTargets[player] = nil

			Status:FireClient(
				player,
				"DENIED",
				"Run/activate the teleport client first."
			)
			return
		end

		if enabled ~= true then
			loopTargets[player] = nil

			Status:FireClient(
				player,
				"INFO",
				"Loop stopped."
			)
			return
		end

		local target =
			getPlayerByUserId(targetUserId)

		if not target or target == player then
			loopTargets[player] = nil

			Status:FireClient(
				player,
				"ERROR",
				"Target is not available."
			)
			return
		end

		loopTargets[player] = target

		Status:FireClient(
			player,
			"INFO",
			"Looping to " .. target.Name
		)
	end
)

task.spawn(function()
	while true do
		for player, target in pairs(loopTargets) do
			if player.Parent ~= Players
				or not sessions[player] then

				loopTargets[player] = nil

			elseif not target
				or target.Parent ~= Players then

				loopTargets[player] = nil

				if player.Parent == Players then
					Status:FireClient(
						player,
						"ERROR",
						"Target left the server."
					)
				end

			else
				serverTeleport(player, target)
			end
		end

		task.wait(LOOP_INTERVAL)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	loopTargets[player] = nil

	for owner, target in pairs(loopTargets) do
		if target == player then
			loopTargets[owner] = nil
		end
	end
end)

print("[OurTeleportRuntime] Server bridge ready.")

]==]

local CLIENT_SOURCE = [==[
-- OurTeleportRuntime.client.lua
-- Only the client that RUNS this script gets activated for this server session.
--
-- This client creates a LOCAL folder in ReplicatedStorage for its own state.
-- It then requests a random per-session token from the server bridge.
--
-- If another player never runs this script, they do not receive a token
-- and their teleport requests are rejected by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SERVER_FOLDER = "OurTeleportRuntime"

--------------------------------------------------------------
-- SERVER BRIDGE
--------------------------------------------------------------

local folder =
	ReplicatedStorage:WaitForChild(
		SERVER_FOLDER,
		10
	)

if not folder then
	warn(
		"[OurTeleport] Server bridge missing. "
		.. "Install OurTeleportRuntime.server.lua in ServerScriptService."
	)
	return
end

local Activate = folder:WaitForChild("Activate")
local TeleportRequest = folder:WaitForChild("TeleportRequest")
local LoopRequest = folder:WaitForChild("LoopRequest")
local StatusRemote = folder:WaitForChild("Status")

--------------------------------------------------------------
-- CLIENT-ONLY FOLDER
--------------------------------------------------------------

local localFolder =
	ReplicatedStorage:FindFirstChild(
		"OurTeleportClient"
	)

if localFolder then
	localFolder:Destroy()
end

localFolder = Instance.new("Folder")
localFolder.Name = "OurTeleportClient"
localFolder.Parent = ReplicatedStorage

local targetValue = Instance.new("IntValue")
targetValue.Name = "SelectedTargetUserId"
targetValue.Value = 0
targetValue.Parent = localFolder

local loopValue = Instance.new("BoolValue")
loopValue.Name = "LoopEnabled"
loopValue.Value = false
loopValue.Parent = localFolder

local activeValue = Instance.new("BoolValue")
activeValue.Name = "Activated"
activeValue.Value = false
activeValue.Parent = localFolder

--------------------------------------------------------------
-- PLAYER SEARCH
--------------------------------------------------------------

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

--------------------------------------------------------------
-- GUI
--------------------------------------------------------------

local old =
	PlayerGui:FindFirstChild(
		"OurTeleportRuntimeGUI"
	)

if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "OurTeleportRuntimeGUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(350,275)
frame.Position = UDim2.new(0.5,-175,0.5,-137)
frame.BackgroundColor3 = Color3.fromRGB(28,28,34)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,0,42)
title.Position = UDim2.fromOffset(14,6)
title.BackgroundTransparency = 1
title.Text = "Runtime Teleport"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local badge = Instance.new("TextLabel")
badge.Size = UDim2.fromOffset(105,20)
badge.Position = UDim2.new(1,-155,0,17)
badge.BackgroundTransparency = 1
badge.Text = "RUNNER ONLY"
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
Instance.new("UICorner",close).CornerRadius = UDim.new(0,8)

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
Instance.new("UICorner",input).CornerRadius = UDim.new(0,8)

local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1,-28,0,42)
teleportButton.Position = UDim2.fromOffset(14,110)
teleportButton.BackgroundColor3 = Color3.fromRGB(45,135,85)
teleportButton.Text = "TELEPORT"
teleportButton.TextColor3 = Color3.new(1,1,1)
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextSize = 16
teleportButton.Parent = frame
Instance.new("UICorner",teleportButton).CornerRadius = UDim.new(0,8)

local loopButton = Instance.new("TextButton")
loopButton.Size = UDim2.new(1,-28,0,42)
loopButton.Position = UDim2.fromOffset(14,160)
loopButton.BackgroundColor3 = Color3.fromRGB(70,70,82)
loopButton.Text = "LOOP TELEPORT : OFF"
loopButton.TextColor3 = Color3.new(1,1,1)
loopButton.Font = Enum.Font.GothamBold
loopButton.TextSize = 16
loopButton.Parent = frame
Instance.new("UICorner",loopButton).CornerRadius = UDim.new(0,8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,52)
status.Position = UDim2.fromOffset(14,210)
status.BackgroundTransparency = 1
status.Text = "Activating this client..."
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(190,190,200)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = frame

--------------------------------------------------------------
-- RUNTIME TOKEN
--------------------------------------------------------------

local sessionToken = nil

local function updateLoopButton()
	loopButton.Text =
		loopValue.Value
		and "LOOP TELEPORT : ON"
		or "LOOP TELEPORT : OFF"

	loopButton.BackgroundColor3 =
		loopValue.Value
		and Color3.fromRGB(45,135,85)
		or Color3.fromRGB(70,70,82)
end

local function selectTarget()
	local target = findPlayer(input.Text)

	if not target then
		status.Text = "Player not found in this server."
		return nil
	end

	targetValue.Value = target.UserId
	return target
end

StatusRemote.OnClientEvent:Connect(
	function(kind, message)
		if kind == "ACTIVATED" then
			sessionToken = tostring(message)
			activeValue.Value = true
			status.Text = "Activated for this client session."
			return
		end

		status.Text = tostring(message or kind)

		if tostring(message):lower():find(
			"loop stopped",
			1,
			true
		) then
			loopValue.Value = false
			updateLoopButton()
		end
	end
)

-- Running this script is what activates this player.
Activate:FireServer()

--------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------

teleportButton.MouseButton1Click:Connect(function()
	if not sessionToken then
		status.Text = "Still activating..."
		return
	end

	local target = selectTarget()
	if not target then
		return
	end

	TeleportRequest:FireServer(
		sessionToken,
		target.UserId
	)
end)

loopButton.MouseButton1Click:Connect(function()
	if not sessionToken then
		status.Text = "Still activating..."
		return
	end

	if loopValue.Value then
		loopValue.Value = false
		updateLoopButton()

		LoopRequest:FireServer(
			sessionToken,
			false,
			0
		)

		return
	end

	local target = selectTarget()
	if not target then
		return
	end

	loopValue.Value = true
	updateLoopButton()

	LoopRequest:FireServer(
		sessionToken,
		true,
		target.UserId
	)
end)

input.FocusLost:Connect(function(enterPressed)
	if enterPressed
		and sessionToken then

		local target = selectTarget()

		if target then
			TeleportRequest:FireServer(
				sessionToken,
				target.UserId
			)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.UserId == targetValue.Value then
		targetValue.Value = 0
		loopValue.Value = false
		updateLoopButton()
	end
end)

close.MouseButton1Click:Connect(function()
	if sessionToken and loopValue.Value then
		LoopRequest:FireServer(
			sessionToken,
			false,
			0
		)
	end

	loopValue.Value = false
	gui:Destroy()
end)

updateLoopButton()

]==]

local function installScript(parent, className, name, source)
	local existing = parent:FindFirstChild(name)

	if existing and not existing:IsA(className) then
		existing:Destroy()
		existing = nil
	end

	local object = existing

	if not object then
		object = Instance.new(className)
		object.Name = name
		object.Parent = parent
	end

	local ok, err = pcall(function()
		object.Source = source
	end)

	if not ok then
		error(
			"Could not write Source for "
			.. name
			.. ". Run this installer from Roblox Studio Command Bar "
			.. "or an authorized Studio plugin context.\n"
			.. tostring(err)
		)
	end

	object.Disabled = false

	return object
end

print("==============================================")
print(" Installing OurTeleport Runtime...")
print("==============================================")

local serverScript =
	installScript(
		ServerScriptService,
		"Script",
		SERVER_SCRIPT_NAME,
		SERVER_SOURCE
	)

local clientScript =
	installScript(
		StarterPlayerScripts,
		"LocalScript",
		CLIENT_SCRIPT_NAME,
		CLIENT_SOURCE
	)

print("Installed / updated:")
print(" - " .. serverScript:GetFullName())
print(" - " .. clientScript:GetFullName())
print("")
print("Next:")
print(" 1) Publish the place")
print(" 2) Start a fresh server")
print(" 3) The client GUI will be installed automatically for players")
print("==============================================")
