-- Movement Panel v4: draggable UI, separate destinations, income-filtered auto pickup.
-- Reads displayed income (/s) from animal labels; no guessed income or remote arguments.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Add more destinations here. Coordinates below come from the attached image.
local LOCATIONS = {
	{ name = "New Point", position = Vector3.new(-4684.80176, 2.72430563, -1.22741687) },
}
-- AFK always returns to the ORIGINAL saved point, independently of Teleport.
local AFK_RETURN_POSITION = Vector3.new(-743.648132, 37.7241478, 124.247498)
local DEFAULT_MIN_INCOME = "1t" -- Editable default; the UI also accepts 1m, 100b, 1T, etc.
local TELEPORT_HEIGHT_OFFSET = 0 -- The new screenshot already gives the character's root height.
local AFK_RETURN_HEIGHT_OFFSET = 3 -- Preserve the successful v3 AFK return height.
local JUMP_SPEED = 50
local infiniteJump = false
local noclip = false
local hoverRoot, hoverAttachment, hoverAlign, hoverY = nil, nil, nil, nil
local hoverJumpUntil = 0
local originalCollision = {}
local connections = {}
local cleaned = false
local afk = nil
local TWEEN_SPEED = 16 -- studs/second
local BOSS_ZONE = "Zone12"

-- Replacing a previous panel also disconnects its movement handlers.
local previous = playerGui:FindFirstChild("MovementPanel")
if previous then previous:Destroy() end
for _, item in ipairs(playerGui:GetChildren()) do
	if item:GetAttribute("AfkEggMovementPanel") then item:Destroy() end
end

local gui = Instance.new("ScreenGui")
-- The observed CarryController keeps this GUI name enabled while carrying.
gui.Name = "ProximityPrompts"
gui:SetAttribute("AfkEggMovementPanel", true)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function round(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 340 + #LOCATIONS * 40)
panel.Position = UDim2.new(0, 12, 0.5, -(340 + #LOCATIONS * 40) / 2)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.Parent = gui
round(panel, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "Movement Panel v4  |  drag"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = panel
title.Active = true

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

-- Drag only by the title so the toggles and income field remain easy to use.
local dragInput, dragStart, panelStart = nil, nil, nil
connect(title.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
		dragStart = input.Position
		panelStart = panel.AbsolutePosition - gui.AbsolutePosition
	end
end)
connect(UserInputService.InputChanged, function(input)
	if not dragInput then return end
	local mouseDrag = dragInput.UserInputType == Enum.UserInputType.MouseButton1
	if mouseDrag and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	if not mouseDrag and input ~= dragInput then return end
	local delta = input.Position - dragStart
	local bounds = gui.AbsoluteSize
	local x = math.clamp(panelStart.X + delta.X, 0, math.max(0, bounds.X - panel.AbsoluteSize.X))
	local y = math.clamp(panelStart.Y + delta.Y, 0, math.max(0, bounds.Y - panel.AbsoluteSize.Y))
	panel.Position = UDim2.fromOffset(x, y)
end)
connect(UserInputService.InputEnded, function(input)
	if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragInput = nil end
end)

local MONEY_MULTIPLIERS = {
	[""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12,
	qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33,
}
local function parseMoney(text)
	local clean = text:gsub("<[^>]+>", ""):lower():gsub("[%s,]", ""):gsub("^%$", "")
	local digits, suffix = clean:match("^([%d%.]+)([a-z]*)$")
	local amount = digits and tonumber(digits)
	local multiplier = suffix and MONEY_MULTIPLIERS[suffix]
	if not amount or not multiplier or amount < 0 then return nil end
	local result = amount * multiplier
	if result ~= result or result == math.huge then return nil end
	return result
end

local function incomeFromText(text)
	local clean = text:gsub("<[^>]+>", ""):lower():gsub("[%s,]", "")
	local amount = clean:match("(%$?[%d%.]+[a-z]*)/s")
	return amount and parseMoney(amount) or nil
end

local function restoreCollision()
	for part, value in pairs(originalCollision) do
		if part.Parent then part.CanCollide = value end
	end
	table.clear(originalCollision)
end

local function clearHover()
	if hoverAlign then hoverAlign:Destroy() end
	if hoverAttachment then hoverAttachment:Destroy() end
	hoverRoot, hoverAttachment, hoverAlign, hoverY = nil, nil, nil, nil
	hoverJumpUntil = 0
end

local function ensureHover(root, targetY)
	if hoverRoot ~= root or not hoverAlign or hoverAlign.Parent ~= root
		or not hoverAttachment or hoverAttachment.Parent ~= root then
		clearHover()
		hoverRoot = root
		hoverY = targetY or root.Position.Y
		hoverAttachment = Instance.new("Attachment")
		hoverAttachment.Name = "MovementPanelHoverAttachment"
		hoverAttachment.Parent = root
		hoverAlign = Instance.new("AlignPosition")
		hoverAlign.Name = "MovementPanelVerticalSupport"
		hoverAlign.Mode = Enum.PositionAlignmentMode.OneAttachment
		hoverAlign.Attachment0 = hoverAttachment
		hoverAlign.ApplyAtCenterOfMass = true
		hoverAlign.RigidityEnabled = false
		hoverAlign.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		hoverAlign.ForceRelativeTo = Enum.ActuatorRelativeTo.World
		hoverAlign.MaxAxesForce = Vector3.new(0, 1000000000, 0)
		hoverAlign.MaxVelocity = 100
		hoverAlign.Responsiveness = 100
		hoverAlign.Position = Vector3.new(root.Position.X, hoverY, root.Position.Z)
		hoverAlign.Parent = root
	elseif targetY then
		hoverY = targetY
		hoverJumpUntil = 0
	end
	hoverAlign.Position = Vector3.new(root.Position.X, hoverY, root.Position.Z)
end

local function setNoclip(enabled, targetY)
	noclip = enabled
	if not enabled then
		restoreCollision()
		clearHover()
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then ensureHover(root, targetY) end
end

-- A deliberate teleport must move the hover target too; otherwise the old
-- support height would pull the character back toward its previous altitude.
local function resetHoverHeight(root)
	if noclip then
		ensureHover(root, root.Position.Y)
		hoverAlign.Enabled = true
	end
end

local function paintToggle(b, label, enabled)
	b.Text = label .. (enabled and ": ON" or ": OFF")
	b.BackgroundColor3 = enabled and Color3.fromRGB(28, 132, 92)
		or Color3.fromRGB(55, 61, 77)
end

local jumpButton = button("Infinite Jump: OFF", panel, 46)
local noclipButton = button("Noclip: OFF", panel, 86)
connect(jumpButton.Activated, function()
	if afk and afk.active then return end
	infiniteJump = not infiniteJump
	paintToggle(jumpButton, "Infinite Jump", infiniteJump)
end)
connect(noclipButton.Activated, function()
	if afk and afk.active then return end
	setNoclip(not noclip)
	paintToggle(noclipButton, "Noclip", noclip)
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 42)
status.Position = UDim2.fromOffset(12, 228 + #LOCATIONS * 40)
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
		if afk and afk.active then afk.stop("AFK cancelled by manual teleport") end
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
		setNoclip(true, target.Y)
		paintToggle(noclipButton, "Noclip", true)
		-- Translate the whole model so its root reaches the target; preserve orientation.
		character:PivotTo(character:GetPivot() + (target - root.Position))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		resetHoverHeight(root)
		status.Text = "Teleported to " .. destination.name
	end)
end

local minimumLabel = Instance.new("TextLabel")
minimumLabel.Position = UDim2.fromOffset(12, 126 + #LOCATIONS * 40)
minimumLabel.Size = UDim2.new(1, -24, 0, 18)
minimumLabel.BackgroundTransparency = 1
minimumLabel.Text = "Minimum income /s  (1m, 100b, 1t)"
minimumLabel.TextColor3 = Color3.fromRGB(195, 202, 220)
minimumLabel.TextSize = 12
minimumLabel.Font = Enum.Font.Gotham
minimumLabel.Parent = panel
local minimumInput = Instance.new("TextBox")
minimumInput.Position = UDim2.fromOffset(12, 146 + #LOCATIONS * 40)
minimumInput.Size = UDim2.new(1, -24, 0, 34)
minimumInput.BackgroundColor3 = Color3.fromRGB(38, 44, 57)
minimumInput.TextColor3 = Color3.new(1, 1, 1)
minimumInput.TextSize = 15
minimumInput.Font = Enum.Font.GothamMedium
minimumInput.ClearTextOnFocus = false
minimumInput.Text = DEFAULT_MIN_INCOME
minimumInput.PlaceholderText = "Example: 1t"
minimumInput.Parent = panel
round(minimumInput, 8)
local afkButton = button("AFK Egg: OFF", panel, 186 + #LOCATIONS * 40)
local hideButton = button("Hide menu", panel, 276 + #LOCATIONS * 40)
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
	if UserInputService:GetFocusedTextBox() then return end
	if noclip then hoverJumpUntil = os.clock() + 1 end
	if not infiniteJump then return end
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
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	ensureHover(root)
	local velocity = root.AssemblyLinearVelocity
	if os.clock() < hoverJumpUntil and (velocity.Y > 0
		or humanoid:GetState() == Enum.HumanoidStateType.Jumping) then
		-- Follow a requested jump upward, then support its new height at the apex.
		hoverAlign.Enabled = false
		hoverY = math.max(hoverY, root.Position.Y)
	else
		hoverJumpUntil = 0
		hoverAlign.Enabled = true
		hoverAlign.Position = Vector3.new(root.Position.X, hoverY, root.Position.Z)
		if root.Position.Y < hoverY - 2 then
			character:PivotTo(character:GetPivot() + Vector3.new(0, hoverY - root.Position.Y, 0))
		end
		if velocity.Y < 0 and root.Position.Y <= hoverY + 0.05 then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		end
	end
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
	if afk then afk.stop("AFK stopped: character removed") end
	restoreCollision()
	clearHover()
	lastJump = 0
end)

-- AFK implementation: the game log supplies Carrying attributes, Ragdolled,
-- AnimalPickups and a separate PromptAnchor.StealPrompt. No remote names/args guessed.
local function readHeld()
	local name = player:GetAttribute("Carrying")
	if type(name) ~= "string" or name == "" then return nil end
	return {
		name = name,
		zone = player:GetAttribute("CarryingZone"),
		kg = player:GetAttribute("CarryingKg"),
		size = player:GetAttribute("CarryingSizeMult"),
		rarity = player:GetAttribute("CarryingRarity"),
		bracket = player:GetAttribute("CarryingBracket"),
	}
end

local function sameValue(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) <= 0.001 end
	return a == b
end

local function sameHeld(a, b)
	if not a or not b then return false end
	for _, key in ipairs({"name", "zone", "kg", "size", "rarity", "bracket"}) do
		if not sameValue(a[key], b[key]) then return false end
	end
	return true
end

local function modelMatches(model, held)
	local keys = {AnimalName = "name", ZoneId = "zone", WeightKg = "kg",
		SizeMult = "size", Rarity = "rarity", WeightBracket = "bracket"}
	for attribute, key in pairs(keys) do
		local actual = model:GetAttribute(attribute)
		if attribute == "AnimalName" and actual == nil then actual = model.Name end
		if not sameValue(actual, held[key]) then return false end
	end
	return true
end

local function fingerprintFromModel(model)
	local result = {
		name = model:GetAttribute("AnimalName") or model.Name,
		zone = model:GetAttribute("ZoneId"),
		kg = model:GetAttribute("WeightKg"),
		size = model:GetAttribute("SizeMult"),
		rarity = model:GetAttribute("Rarity"),
		bracket = model:GetAttribute("WeightBracket"),
	}
	if type(result.name) ~= "string" or result.name == "" or not result.zone
		or type(result.kg) ~= "number" or type(result.size) ~= "number"
		or not result.rarity or result.bracket == nil then return nil end
	return result
end

local function spatialPosition(instance)
	if not instance then return nil end
	if instance:IsA("Attachment") then return instance.WorldPosition end
	if instance:IsA("BasePart") then return instance.Position end
	if instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
		return instance:GetPivot().Position
	end
	return nil
end

-- Display labels can round weights, use suffixes, and add rich text or size labels.
-- Identify the animal model using attributes; do not parse the display weight as an ID.
local function containsAnimalName(text, animalName)
	text = text:gsub("<[^>]+>", ""):lower():gsub("%s+", " ")
	animalName = animalName:lower():gsub("%s+", " ")
	local offset = 1
	while true do
		local first, last = text:find(animalName, offset, true)
		if not first then return false end
		local before, after = text:sub(first - 1, first - 1), text:sub(last + 1, last + 1)
		if not before:match("[%w_]") and not after:match("[%w_]") then return true end
		offset = last + 1
	end
end

local function distanceToAnimal(point, model)
	if not model.Parent or not model:FindFirstChildWhichIsA("BasePart", true) then return math.huge end
	local box, size = model:GetBoundingBox()
	local localPoint = box:PointToObjectSpace(point)
	local half = size * 0.5
	local nearest = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - nearest).Magnitude
end

local function directlyReferencesAnimal(prompt, model)
	if prompt:IsDescendantOf(model) then return true end
	-- Some prompt implementations store a target ObjectValue on the anchor.
	for _, parent in ipairs({prompt, prompt.Parent}) do
		if parent then
			for _, value in ipairs(parent:GetChildren()) do
				if value:IsA("ObjectValue") and value.Value then
					if value.Value == model or value.Value:IsDescendantOf(model) then return true end
				end
			end
		end
	end
	return false
end

local function allPickups()
	local result, seen = {}, {}
	local function add(item)
		if item:IsA("Model") and not seen[item] and item:IsDescendantOf(workspace) then
			seen[item] = true
			table.insert(result, item)
		end
	end
	for _, item in ipairs(CollectionService:GetTagged("AnimalPickup")) do add(item) end
	local folder = workspace:FindFirstChild("AnimalPickups")
	if folder then for _, item in ipairs(folder:GetChildren()) do add(item) end end
	return result
end

local prompts = {}
for _, item in ipairs(workspace:GetDescendants()) do
	if item:IsA("ProximityPrompt") then prompts[item] = true end
end
connect(workspace.DescendantAdded, function(item)
	if item:IsA("ProximityPrompt") then prompts[item] = true end
end)
connect(workspace.DescendantRemoving, function(item) prompts[item] = nil end)

-- Animal income can be on the model or on an external BillboardGui with Adornee.
local billboards = {}
local function addBillboard(item)
	if item:IsA("BillboardGui") then billboards[item] = true end
end
for _, item in ipairs(workspace:GetDescendants()) do addBillboard(item) end
for _, item in ipairs(playerGui:GetDescendants()) do addBillboard(item) end
connect(workspace.DescendantAdded, addBillboard)
connect(playerGui.DescendantAdded, addBillboard)
connect(workspace.DescendantRemoving, function(item) billboards[item] = nil end)
connect(playerGui.DescendantRemoving, function(item) billboards[item] = nil end)

local function readDisplayedIncome(model)
	local income, conflicted = nil, false
	local seen = {}
	local function readLabels(container)
		for _, item in ipairs(container:GetDescendants()) do
			if not seen[item] and (item:IsA("TextLabel") or item:IsA("TextButton")) then
				seen[item] = true
				local value = incomeFromText(item.Text)
				if value then
					if income and math.abs(value - income) > math.max(1, income * 0.000001) then
						conflicted = true
					else
						income = value
					end
				end
			end
		end
	end
	readLabels(model)
	for board in pairs(billboards) do
		if board.Parent then
			local adornee = board.Adornee or board.Parent
			if board:IsDescendantOf(model) or adornee == model
				or (adornee and adornee:IsDescendantOf(model)) then
				readLabels(board)
			end
		end
	end
	if conflicted then return nil end
	return income
end

local function bossPosition()
	local build = workspace:FindFirstChild("Build")
	local zones = build and build:FindFirstChild("ZoneBuilds")
	local zone = zones and zones:FindFirstChild(BOSS_ZONE)
	local boss = zone and zone:FindFirstChild("ZoneBoss")
	if not boss then return nil end
	local root = boss:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then return root.Position end
	return spatialPosition(boss)
end

local function moveRoot(character, root, position)
	character:PivotTo(character:GetPivot() + (position - root.Position))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	resetHoverHeight(root)
end

local generation, tween, heldPrompt, pickupKeeper = 0, nil, nil, nil
local savedMovement = nil
afk = {active = false}
function afk.stop(message)
	local wasActive = afk.active
	afk.active = false
	generation = generation + 1
	if tween then tween:Cancel(); tween = nil end
	if pickupKeeper then pickupKeeper:Disconnect(); pickupKeeper = nil end
	if heldPrompt then pcall(function() heldPrompt:InputHoldEnd() end); heldPrompt = nil end
	if wasActive and savedMovement and not cleaned then
		infiniteJump = savedMovement.jump
		setNoclip(savedMovement.noclip)
		paintToggle(jumpButton, "Infinite Jump", infiniteJump)
		paintToggle(noclipButton, "Noclip", noclip)
	end
	savedMovement = nil
	if not cleaned then
		minimumInput.TextEditable = true
		paintToggle(afkButton, "AFK Egg", false)
		if message then status.Text = message end
	end
end

function afk.start()
	if afk.active or cleaned then return end
	local minimumIncome = parseMoney(minimumInput.Text)
	if not minimumIncome or minimumIncome <= 0 then
		status.Text = "Invalid minimum. Try 1m, 100b, 1t or 10T."
		return
	end
	if readHeld() then
		status.Text = "Start empty-handed to verify the income threshold."
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		status.Text = "Spawn and leave your seat first."
		return
	end
	if character:GetAttribute("Ragdolled") then status.Text = "Wait for ragdoll recovery."; return end
	if not bossPosition() then
		status.Text = "Zone12 boss not loaded. Move to the final stage first."
		return
	end
	afk.active = true
	minimumInput.TextEditable = false
	generation = generation + 1
	local token = generation
	savedMovement = {jump = infiniteJump, noclip = noclip}
	infiniteJump = false
	-- Preserve anti-fall support during the potentially long income-selection wait.
	setNoclip(savedMovement.noclip)
	paintToggle(jumpButton, "Infinite Jump", false)
	paintToggle(noclipButton, "Noclip", noclip)
	paintToggle(afkButton, "AFK Egg", true)
	local function current()
		return not cleaned and afk.active and generation == token
	end
	local function valid()
		return current() and player.Character == character and root.Parent
			and humanoid.Parent and humanoid.Health > 0
	end
	local function waitFor(predicate, seconds)
		local deadline = os.clock() + seconds
		while valid() do
			local result = predicate()
			if result then return result end
			if os.clock() >= deadline then return nil end
			RunService.Heartbeat:Wait()
		end
		return nil
	end
	local function pickupAnimal(dropped, selected)
		local droppedPosition = spatialPosition(dropped)
		if not droppedPosition then return "Animal position unavailable." end
		local pickupPoint = droppedPosition + Vector3.new(0, 2.5, 0)
		moveRoot(character, root, pickupPoint)
		-- A one-time teleport can be undone by ongoing knockback before
		-- SmartPromptController has created the prompt.
		pickupKeeper = RunService.Heartbeat:Connect(function()
			if valid() and not readHeld() then moveRoot(character, root, pickupPoint) end
		end)
		status.Text = "AFK: at animal; waiting for Steal prompt"
		local ambiguousPrompt = false
		local namedPrompts, enabledPrompts = 0, 0
		local lastRescan = -math.huge
		local prompt = waitFor(function()
			local candidates = {}
			local p = spatialPosition(dropped)
			if not p then return nil end
			if os.clock() - lastRescan >= 1 then
				-- Also catch prompts reparented/reused by the custom prompt controller.
				for _, item in ipairs(workspace:GetDescendants()) do
					if item:IsA("ProximityPrompt") then prompts[item] = true end
				end
				lastRescan = os.clock()
			end
			namedPrompts, enabledPrompts = 0, 0
			for item in pairs(prompts) do
				if item.Parent and item:IsDescendantOf(workspace) and item.Name == "StealPrompt" then
					namedPrompts = namedPrompts + 1
					if item.Enabled then enabledPrompts = enabledPrompts + 1 end
					local point = spatialPosition(item.Parent)
					local associated = directlyReferencesAnimal(item, dropped)
						or containsAnimalName(item.ObjectText, selected.name)
					if item.Enabled and associated and point
						and distanceToAnimal(point, dropped) <= 12 then
						table.insert(candidates, item)
					end
				end
			end
			if #candidates > 1 then ambiguousPrompt = true; return true end
			return candidates[1]
		end, 5)
		if not valid() then return nil end
		if ambiguousPrompt then return "Multiple pickup prompts; stopped." end
		if not prompt then
			return string.format("No matching Steal prompt: %d found, %d enabled. Return cancelled.",
				namedPrompts, enabledPrompts)
		end
		status.Text = "AFK: picking up " .. selected.name
		local point = spatialPosition(prompt.Parent)
		if not point then return "Pickup prompt removed." end
		pickupPoint = point + Vector3.new(0, 2.5, 0)
		moveRoot(character, root, pickupPoint)
		heldPrompt = prompt
		-- Standard prompt input; use the existing executor helper if it is available.
		if type(fireproximityprompt) == "function" then
			local ok, err = pcall(fireproximityprompt, prompt, prompt.HoldDuration)
			if not valid() then return nil end
			if not ok then return "Prompt failed: " .. tostring(err) end
		else
			prompt:InputHoldBegin()
			local began = os.clock()
			waitFor(function() return os.clock() - began >= prompt.HoldDuration + 0.05 end,
				prompt.HoldDuration + 0.3)
			if not valid() then return nil end
			pcall(function() prompt:InputHoldEnd() end)
		end
		heldPrompt = nil
		if not valid() then return nil end
		local confirmed = waitFor(function() return sameHeld(readHeld(), selected) end, 2)
		if not valid() then return nil end
		if not confirmed then return "Pickup not confirmed; did not teleport to Spawn." end
		if pickupKeeper then pickupKeeper:Disconnect(); pickupKeeper = nil end
		return true
	end

	local function run()
		local lastScan = -math.huge
		status.Text = "AFK: waiting for income >= " .. minimumInput.Text .. "/s"
		local choice = waitFor(function()
			if os.clock() - lastScan < 0.5 then return nil end
			lastScan = os.clock()
			if readHeld() then return {unexpectedCarry = true} end
			local best, readable, total = nil, 0, 0
			for _, model in ipairs(allPickups()) do
				local fingerprint = fingerprintFromModel(model)
				local point = spatialPosition(model)
				if fingerprint and point then
					total = total + 1
					local income = readDisplayedIncome(model)
					if income then
						readable = readable + 1
						local distance = (point - root.Position).Magnitude
						if income >= minimumIncome and (not best or income > best.income
							or (income == best.income and distance < best.distance)) then
							best = {model = model, fingerprint = fingerprint, income = income, distance = distance}
						end
					end
				end
			end
			status.Text = string.format("AFK: waiting >= %s/s | income read %d/%d",
				minimumInput.Text, readable, total)
			return best
		end, math.huge)
		if not valid() then return nil end
		if not choice or choice.unexpectedCarry then return "Manual pickup interrupted automatic selection." end
		if not choice.model.Parent then return "Selected animal disappeared; restart AFK." end
		local incomeNow = readDisplayedIncome(choice.model)
		if not incomeNow or incomeNow < minimumIncome then return "Income changed or unavailable; stopped." end
		local initialPosition = spatialPosition(choice.model)
		if not initialPosition then return "Selected animal is not loaded." end
		setNoclip(true, initialPosition.Y + 2.5)
		paintToggle(noclipButton, "Noclip", true)
		local firstPickup = pickupAnimal(choice.model, choice.fingerprint)
		if not valid() then return nil end
		if firstPickup ~= true then return firstPickup end
		setNoclip(false)
		paintToggle(noclipButton, "Noclip", false)
		local selected = readHeld()
		if not sameHeld(selected, choice.fingerprint) then return "Automatic pickup identity did not match." end
		if player:GetAttribute("CarryCount") ~= 1 or not selected.zone or not selected.kg
			or not selected.size or not selected.rarity or selected.bracket == nil then
			return "Need exactly one animal with complete carry attributes."
		end
		local baseline = {}
		for _, item in ipairs(allPickups()) do baseline[item] = true end
		local lastHeldPosition = root.Position
		local ragdollTime, dropTime = nil, nil
		local travelDeadline = os.clock() + 90
		local lastTweenAt = 0
		status.Text = "AFK: moving toward Zone12 guardian"
		while valid() do
			local now = os.clock()
			local held = readHeld()
			local ragdolled = character:GetAttribute("Ragdolled") == true
			if held and not sameHeld(held, selected) then return "Held animal changed; stopped." end
			if ragdolled and not ragdollTime then ragdollTime = now end
			if not held and not dropTime then dropTime = now end
			if not ragdolled and held then lastHeldPosition = root.Position end
			if ragdollTime and dropTime and math.abs(ragdollTime - dropTime) <= 1 then break end
			if (dropTime and now - dropTime > 1) or (ragdollTime and now - ragdollTime > 1) then
				return "No matching ragdoll/drop event; stopped."
			end
			if now >= travelDeadline then return "Guardian timeout; stopped." end
			if ragdolled or not held then
				if tween then tween:Cancel(); tween = nil end
			elseif now - lastTweenAt >= 0.25 then
				local boss = bossPosition()
				if not boss then return "Guardian streamed out; stopped." end
				if tween then tween:Cancel(); tween = nil end
				local target = Vector3.new(boss.X, root.Position.Y, boss.Z)
				local delta = target - root.Position
				local distance = delta.Magnitude
				if distance > 2 then
					local step = math.min(distance, TWEEN_SPEED * 0.25)
					tween = TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
						CFrame = root.CFrame + delta.Unit * step,
					})
					tween:Play()
				end
				lastTweenAt = now
			end
			RunService.Heartbeat:Wait()
		end
		if not valid() then return nil end
		if tween then tween:Cancel(); tween = nil end
		status.Text = "AFK: locating the dropped animal"
		local ambiguous = false
		local dropped = waitFor(function()
			local candidates = {}
			for _, item in ipairs(allPickups()) do
				local p = spatialPosition(item)
				if not baseline[item] and p and modelMatches(item, selected)
					and (p - lastHeldPosition).Magnitude <= 25 then
					table.insert(candidates, item)
				end
			end
			if #candidates > 1 then ambiguous = true; return true end
			return candidates[1]
		end, 2)
		if not valid() then return nil end
		if ambiguous then return "Multiple matching animals; stopped without picking one." end
		if not dropped then return "Dropped animal not found; return cancelled." end
		local picked = pickupAnimal(dropped, selected)
		if picked ~= true then return picked end
		-- No yield between confirmation and return.
		local returnPosition = AFK_RETURN_POSITION + Vector3.new(0, AFK_RETURN_HEIGHT_OFFSET, 0)
		setNoclip(true, returnPosition.Y)
		paintToggle(noclipButton, "Noclip", true)
		moveRoot(character, root, returnPosition)
		-- Leave noclip and vertical support enabled at the return point.
		if savedMovement then savedMovement.noclip = true end
		return "AFK finished: picked up and returned to original point."
	end
	task.spawn(function()
		local ok, result = xpcall(run, debug.traceback)
		if not current() then return end
		afk.stop(ok and (result or "AFK stopped.") or "AFK error; stopped. See console.")
		if not ok then warn(result) end
	end)
end

connect(afkButton.Activated, function()
	if afk.active then afk.stop("AFK cancelled.") else afk.start() end
end)

local function cleanup()
	if cleaned then return end
	cleaned = true
	if afk then afk.stop() end
	infiniteJump = false
	setNoclip(false)
	for _, connection in ipairs(connections) do connection:Disconnect() end
	restoreCollision()
end
gui.Destroying:Connect(cleanup)
if typeof(script) == "Instance" then
	script.Destroying:Connect(function()
		cleanup()
		gui:Destroy()
	end)
end
