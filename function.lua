-- V2 read-only game-state probe. No movement, pickup, remote calls, or hooks.
-- Run once, then pick up a cheap animal and let a guardian hit you.
-- Press Copy log afterwards. Close stops the probe and removes its local GUI.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local started = os.clock()
local running = true
local lines = {}
local refs = setmetatable({}, {__mode = "k"})
local nextRef = 0
local connections = {}
local remembered = nil
local trackedKeys = {
	"Carrying", "CarryingZone", "CarryingKg", "CarryingSizeMult",
	"CarryingRarity", "CarryingBracket", "CarryCount", "BeingChased",
}

local gui = Instance.new("ScreenGui")
-- This experience's CarryController allows this name while carrying.
gui.Name = "ProximityPrompts"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui:SetAttribute("AfkEggProbe", true)
for _, old in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
	if old:GetAttribute("AfkEggProbe") then old:Destroy() end
end
gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.72, 0, 0.5, 0)
frame.Position = UDim2.new(0.14, 0, 0.16, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 28, 35)
frame.Parent = gui
local box = Instance.new("TextBox")
box.Position = UDim2.fromOffset(8, 46)
box.Size = UDim2.new(1, -16, 1, -54)
box.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
box.TextColor3 = Color3.new(1, 1, 1)
box.TextSize = 12
box.Font = Enum.Font.Code
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.MultiLine = true
box.ClearTextOnFocus = false
box.TextEditable = false
box.Text = "AFK Egg Probe V2: waiting for pickup"
box.Parent = frame
local function button(label, x)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 6)
	b.Size = UDim2.fromOffset(110, 32)
	b.Text = label
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(45, 91, 120)
	b.Parent = frame
	return b
end
local copy = button("Copy log", 8)
local hide = button("Hide log", 126)
local close = button("Close", 244)
local function log(message)
	if not running then return end
	table.insert(lines, string.format("%.2f %s", os.clock() - started, message))
	if #lines > 500 then table.remove(lines, 1) end
	box.Text = table.concat(lines, "\n")
end
local function encode(value)
	local ok, result = pcall(function() return HttpService:JSONEncode(value) end)
	return ok and result or tostring(value)
end
local function carryAttributes()
	local data = {}
	for _, key in ipairs(trackedKeys) do data[key] = player:GetAttribute(key) end
	return data
end
local function remember()
	if player:GetAttribute("Carrying") then remembered = carryAttributes() end
end
local function path(instance)
	if not instance then return "nil" end
	local ok, value = pcall(function() return instance:GetFullName() end)
	return ok and value or "removed"
end
local function id(instance)
	if not refs[instance] then nextRef += 1; refs[instance] = nextRef end
	return "ref" .. refs[instance]
end
local function attributes(instance)
	local ok, value = pcall(function() return HttpService:JSONEncode(instance:GetAttributes()) end)
	return ok and value or "[attributes unavailable]"
end
local function position(model)
	if model:IsA("BasePart") then return model.Position end
	if model:IsA("Model") and model:FindFirstChildWhichIsA("BasePart", true) then
		return model:GetPivot().Position
	end
	return nil
end
local function describe(model)
	local p = position(model)
	log(id(model) .. " " .. path(model) .. " pos=" .. tostring(p) .. " attrs=" .. attributes(model))
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("ProximityPrompt") then
			log(" PROMPT " .. path(item) .. " action=" .. item.ActionText
				.. " object=" .. item.ObjectText .. " enabled=" .. tostring(item.Enabled)
				.. " hold=" .. item.HoldDuration .. " distance=" .. item.MaxActivationDistance)
		end
	end
end
local promptIndex = {}
for _, item in ipairs(workspace:GetDescendants()) do
	if item:IsA("ProximityPrompt") then promptIndex[item] = true end
end
table.insert(connections, workspace.DescendantAdded:Connect(function(item)
	if item:IsA("ProximityPrompt") then promptIndex[item] = true end
end))
table.insert(connections, workspace.DescendantRemoving:Connect(function(item)
	promptIndex[item] = nil
end))
local function promptPosition(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("Attachment") then return parent.WorldPosition end
	return position(parent)
end
local function matchesRemembered(model)
	if not remembered then return false end
	local name = model:GetAttribute("AnimalName") or model.Name
	if name ~= remembered.Carrying then return false end
	local mappings = {
		ZoneId = "CarryingZone", WeightKg = "CarryingKg", SizeMult = "CarryingSizeMult",
		Rarity = "CarryingRarity", WeightBracket = "CarryingBracket",
	}
	for modelKey, playerKey in pairs(mappings) do
		local expected = remembered[playerKey]
		if expected ~= nil and model:GetAttribute(modelKey) ~= expected then return false end
	end
	return true
end
local function snapshot(reason)
	remember()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	log("SNAP " .. reason .. " Carrying=" .. tostring(player:GetAttribute("Carrying"))
		.. " BeingChased=" .. tostring(player:GetAttribute("BeingChased"))
		.. " carryAttrs=" .. encode(carryAttributes()) .. " remembered=" .. encode(remembered))
	if not root then return end
	log("CHAR attrs=" .. attributes(character) .. " pos=" .. tostring(root.Position)
		.. " velocity=" .. tostring(root.AssemblyLinearVelocity)
		.. " state=" .. tostring(humanoid and humanoid:GetState()))
	local nearby, matching, seen = {}, {}, {}
	local function add(model)
		if seen[model] then return end
		seen[model] = true
		local p = position(model)
		if matchesRemembered(model) then table.insert(matching, model) end
		if p and (p - root.Position).Magnitude <= 35 then
			table.insert(nearby, {model = model, distance = (p - root.Position).Magnitude})
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("AnimalPickup")) do add(model) end
	local folder = workspace:FindFirstChild("AnimalPickups")
	if folder then for _, model in ipairs(folder:GetChildren()) do add(model) end end
	table.sort(nearby, function(a, b) return a.distance < b.distance end)
	log("Nearby AnimalPickup count=" .. #nearby)
	for index = 1, math.min(#nearby, 6) do describe(nearby[index].model) end
	log("GLOBAL matching fingerprint count=" .. #matching .. " (same attributes do not prove unique identity)")
	for index = 1, math.min(#matching, 8) do
		log("MATCH " .. index)
		describe(matching[index])
	end
	local points = {root.Position}
	for _, model in ipairs(matching) do
		local p = position(model)
		if p then table.insert(points, p) end
	end
	local promptCount = 0
	for prompt in pairs(promptIndex) do
		local p = promptPosition(prompt)
		local near = false
		if p then
			for _, point in ipairs(points) do
				if (p - point).Magnitude <= 24 then near = true; break end
			end
		end
		if near then
			promptCount += 1
			if promptCount <= 16 then
				log("WORLD PROMPT " .. path(prompt) .. " pos=" .. tostring(p)
					.. " action=" .. prompt.ActionText .. " object=" .. prompt.ObjectText
					.. " enabled=" .. tostring(prompt.Enabled) .. " hold=" .. prompt.HoldDuration
					.. " attrs=" .. attributes(prompt) .. " parentAttrs=" .. attributes(prompt.Parent))
			end
		end
	end
	log("Nearby world prompts=" .. promptCount)
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("ObjectValue") then
			log(" CHAR REF " .. path(item) .. " -> " .. path(item.Value))
		elseif item:IsA("WeldConstraint") or item:IsA("JointInstance") then
			local a, b = item.Part0, item.Part1
			if (a and not a:IsDescendantOf(character)) or (b and not b:IsDescendantOf(character)) then
				log(" EXTERNAL JOINT " .. path(item) .. " " .. path(a) .. " -> " .. path(b))
			end
		end
	end
end

copy.Activated:Connect(function()
	local text = table.concat(lines, "\n")
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard, text)
		copy.Text = ok and "Copied" or "Copy failed"
	else
		box.TextEditable = true
		box:CaptureFocus()
		box.CursorPosition = #box.Text + 1
		box.SelectionStart = 1
		copy.Text = "Select / Copy"
	end
end)
hide.Activated:Connect(function()
	box.Visible = not box.Visible
	frame.Size = box.Visible and UDim2.new(0.72, 0, 0.5, 0) or UDim2.new(0.72, 0, 0, 44)
	hide.Text = box.Visible and "Hide log" or "Show log"
end)
close.Activated:Connect(function() running = false; gui:Destroy() end)
local function stopCapture()
	running = false
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
end
gui.Destroying:Connect(stopCapture)

log("START PROBE V2 placeId=" .. game.PlaceId .. " version=" .. game.PlaceVersion)
local controllers = player:WaitForChild("PlayerScripts"):FindFirstChild("Client")
controllers = controllers and controllers:FindFirstChild("Controllers")
if controllers then
	local names = {}
	for _, item in ipairs(controllers:GetChildren()) do table.insert(names, item.Name) end
	table.sort(names)
	log("CONTROLLERS " .. table.concat(names, ","))
end
local remoteNames = {}
for _, item in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
	if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
		local name = item.Name:lower()
		if name:find("animal") or name:find("carry") or name:find("drop")
			or name:find("bonk") or name:find("guard") or name:find("chase") then
			table.insert(remoteNames, path(item))
		end
	end
end
table.sort(remoteNames)
log("RELEVANT REMOTE NAMES ONLY " .. table.concat(remoteNames, ","))
snapshot("initial")
local latestCarrying = player:GetAttribute("Carrying")
table.insert(connections, player:GetAttributeChangedSignal("Carrying"):Connect(function()
	local before = latestCarrying
	latestCarrying = player:GetAttribute("Carrying")
	remember()
	local prefix = "EVENT Carrying " .. tostring(before) .. " -> " .. tostring(latestCarrying)
	log(prefix)
	for _, delay in ipairs({0, 0.15, 0.5, 1.5}) do
		task.delay(delay, function()
			if not running then return end
			local ok, err = pcall(snapshot, prefix .. " +" .. delay)
			if not ok then log("PROBE ERROR " .. tostring(err)) end
		end)
	end
end))
local build = workspace:FindFirstChild("Build")
local zones = build and build:FindFirstChild("ZoneBuilds")
local zone = zones and zones:FindFirstChild("Zone12")
local boss = zone and zone:FindFirstChild("ZoneBoss")
log("ZONE12 BOSS " .. path(boss) .. " pos=" .. tostring(boss and position(boss)))
task.spawn(function()
	local previousCarrying = player:GetAttribute("Carrying")
	local lastSnapshot = os.clock()
	local lastSpeed = 0
	while running and os.clock() - started < 90 do
		task.wait(0.1)
		if not running then break end
		local carrying = player:GetAttribute("Carrying")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local speed = root and root.AssemblyLinearVelocity.Magnitude or 0
		local reason
		remember()
		if carrying and os.clock() - lastSnapshot >= 5 then
			reason = "holding sample"
		end
		if reason then
			local ok, err = pcall(snapshot, reason)
			if not ok then log("PROBE ERROR " .. tostring(err)) end
			lastSnapshot = os.clock()
		end
		previousCarrying = carrying
		lastSpeed = speed
	end
	if running then
		log("STOP: 90-second capture finished. Copy log is ready.")
		stopCapture()
	end
end)
