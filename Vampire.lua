--// Orb Auto Collect (Orbs / SandOrbs / VoidOrbs) - Nearest First + Floating UI
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Settings = { Orb = false, SandOrb = false, VoidOrb = false }
local FOLDERS  = { Orb = "Orbs", SandOrb = "SandOrbs", VoidOrb = "VoidOrbs" }

local COLLECT_TIMEOUT = 1.5   -- รอให้ orb หายไปสูงสุดกี่วินาที
local DELAY_BETWEEN   = 0.15  -- หน่วงระหว่างวาร์ปแต่ละครั้ง
local SKIP_COOLDOWN   = 5     -- ถ้าเก็บแล้วไม่หาย ข้ามกี่วินาที

local recentlyVisited = setmetatable({}, { __mode = "k" })
local running = false

local function anyEnabled()
	for _, v in pairs(Settings) do if v then return true end end
	return false
end

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getOrbPart(orb)
	if orb:IsA("BasePart") then return orb end
	if orb:IsA("Model") then
		return orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart", true)
	end
end

local function getOrbs()
	local list, now = {}, tick()
	for key, enabled in pairs(Settings) do
		if enabled then
			local folder = workspace:FindFirstChild(FOLDERS[key])
			if folder then
				for _, orb in ipairs(folder:GetChildren()) do
					local part = getOrbPart(orb)
					local last = recentlyVisited[orb]
					if part and not (last and now - last < SKIP_COOLDOWN) then
						table.insert(list, { orb = orb, part = part })
					end
				end
			end
		end
	end
	return list
end

local function getNearest(root, list)
	local best, bestDist = nil, math.huge
	for _, d in ipairs(list) do
		local dist = (d.part.Position - root.Position).Magnitude
		if dist < bestDist then best, bestDist = d, dist end
	end
	return best
end

local function collect(root, data)
	local orb, part = data.orb, data.part
	root.CFrame = CFrame.new(part.Position)

	if firetouchinterest then
		local parts = orb:IsA("BasePart") and { orb } or orb:GetDescendants()
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				firetouchinterest(root, p, 0)
				firetouchinterest(root, p, 1)
			end
		end
	end

	local prompt = orb:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then fireproximityprompt(prompt) end

	local t = tick()
	while orb.Parent and tick() - t < COLLECT_TIMEOUT do task.wait() end
	if orb.Parent then recentlyVisited[orb] = tick() end
end

local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while anyEnabled() do
			local root = getRoot()
			if root then
				local target = getNearest(root, getOrbs())
				if target then
					collect(root, target)
					task.wait(DELAY_BETWEEN)
				else
					task.wait(0.5)
				end
			else
				task.wait(1)
			end
		end
		running = false
	end)
end

--================ ฟังก์ชันเปิด/ปิด ================--
local function makeToggle(key)
	return function(state)
		if state == nil then state = not Settings[key] end
		Settings[key] = state
		if state then startLoop() end
		return state
	end
end

ToggleOrb     = makeToggle("Orb")
ToggleSandOrb = makeToggle("SandOrb")
ToggleVoidOrb = makeToggle("VoidOrb")

--================ Floating UI ================--
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("OrbCollector")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 200, 0, 190)
main.Position = UDim2.new(0, 20, 0, 150)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(80, 80, 95)
stroke.Thickness = 1.5

-- แถบหัว (ใช้ลาก)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
title.BorderSizePixel = 0
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Orb Collector"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = title

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 26, 0, 22)
minBtn.Position = UDim2.new(1, -31, 0, 5)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
minBtn.Text = "–"
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.Parent = title
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- เนื้อหา
local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -42)
body.Position = UDim2.new(0, 10, 0, 38)
body.BackgroundTransparency = 1
body.Parent = main
local layout = Instance.new("UIListLayout", body)
layout.Padding = UDim.new(0, 8)

local ON_COLOR  = Color3.fromRGB(50, 170, 80)
local OFF_COLOR = Color3.fromRGB(170, 50, 50)

local function makeButton(label, toggleFn)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = OFF_COLOR
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = label .. ": OFF"
	btn.Parent = body
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	btn.MouseButton1Click:Connect(function()
		local on = toggleFn()
		btn.Text = label .. (on and ": ON" or ": OFF")
		btn.BackgroundColor3 = on and ON_COLOR or OFF_COLOR
	end)
end

makeButton("Orb",     ToggleOrb)
makeButton("SandOrb", ToggleSandOrb)
makeButton("VoidOrb", ToggleVoidOrb)

-- ย่อ / ขยาย
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = minimized and UDim2.new(0, 200, 0, 32) or UDim2.new(0, 200, 0, 190)
	minBtn.Text = minimized and "+" or "–"
end)

-- ลากย้าย (เมาส์ + ทัช)
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
