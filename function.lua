-- Read-only game-state probe. No movement, pickup, remote calls, or hooks.
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

local gui = Instance.new("ScreenGui")
-- This experience's CarryController allows this name while carrying.
gui.Name = "ProximityPrompts"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui:SetAttribute("AfkEggProbe", true)
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
box.Text = "AFK Egg Probe: waiting for pickup"
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
	table.insert(lines, string.format("%.2f %s", os.clock() - started, message))
	if #lines > 500 then table.remove(lines, 1) end
	box.Text = table.concat(lines, "\n")
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
local function snapshot(reason)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	log("SNAP " .. reason .. " Carrying=" .. tostring(player:GetAttribute("Carrying"))
		.. " BeingChased=" .. tostring(player:GetAttribute("BeingChased"))
		.. " playerAttrs=" .. attributes(player))
	if not root then return end
	log("CHAR attrs=" .. attributes(character) .. " pos=" .. tostring(root.Position)
		.. " velocity=" .. tostring(root.AssemblyLinearVelocity)
		.. " state=" .. tostring(humanoid and humanoid:GetState()))
	local nearby, seen = {}, {}
	local function add(model)
		if seen[model] then return end
		seen[model] = true
		local p = position(model)
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
gui.Destroying:Connect(function() running = false end)

log("START placeId=" .. game.PlaceId .. " version=" .. game.PlaceVersion)
snapshot("initial")
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
		if carrying ~= previousCarrying then
			reason = "Carrying changed " .. tostring(previousCarrying) .. " -> " .. tostring(carrying)
		elseif speed > 70 and lastSpeed <= 70 then
			reason = "velocity threshold crossed (not proof of boss hit)"
		elseif carrying and os.clock() - lastSnapshot >= 3 then
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
	if running then log("STOP: 90-second capture finished. Copy log is ready.") end
end)
