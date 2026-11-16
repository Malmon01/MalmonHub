--// Orb Auto Collect (Orbs / SandOrbs / VoidOrbs)
--// Big First + Nearest + Floating UI (ย่อได้ / ลากได้)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

--================ ตั้งค่า ================--
local Settings = { Orb = false, SandOrb = false, VoidOrb = false }
local FOLDERS  = { Orb = "Orbs", SandOrb = "SandOrbs", VoidOrb = "VoidOrbs" }

local COLLECT_TIMEOUT = 1.5   -- รอให้ orb หายไปสูงสุดกี่วินาที
local DELAY_BETWEEN   = 0.15  -- หน่วงระหว่างวาร์ปแต่ละครั้ง
local SKIP_COOLDOWN   = 5     -- ถ้าเก็บแล้วไม่หาย ข้ามกี่วินาที
local BIG_FIRST       = true  -- true = ไปลูกใหญ่ก่อน, false = ไปลูกใกล้ก่อน
local SIZE_TOLERANCE  = 0.3   -- ขนาดต่างกันไม่เกินเท่านี้ ถือว่าเท่ากัน แล้วเลือกลูกที่ใกล้กว่า

local recentlyVisited = setmetatable({}, { __mode = "k" })
local running = false

--================ ฟังก์ชันช่วย ================--
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

local function getOrbSize(orb, part)
	if orb:IsA("Model") then
		local ok, size = pcall(function() return orb:GetExtentsSize() end)
		if ok then return size.Magnitude end
	end
	return part.Size.Magnitude
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

-- เลือกเป้าหมาย: ใหญ่ก่อน ถ้าขนาดพอ ๆ กันเลือกใกล้กว่า
local function getTarget(root, list)
	local best, bestSize, bestDist = nil, -math.huge, math.huge
	for _, d in ipairs(list) do
		local dist = (d.part.Position - root.Position).Magnitude
		local size = BIG_FIRST and getOrbSize(d.orb, d.part) or 0

		local better
		if size > bestSize + SIZE_TOLERANCE then
			better = true
		elseif math.abs(size - bestSize) <= SIZE_TOLERANCE then
			better = dist < bestDist
		end

		if better then
			best, bestSize, bestDist = d, size, dist
		end
	end
	return best
end

local function collect(root, data)
	local orb, part = data.orb, data.part
	root.CFrame = CFrame.new(part.Position)

	-- เก็บแบบแตะ
	if firetouchinterest then
		local parts = orb:IsA("BasePart") and { orb } or orb:GetDescendants()
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				firetouchinterest(root, p, 0)
				firetouchinterest(root, p, 1)
			end
		end
	end

	-- เก็บแบบ ProximityPrompt
	local prompt = orb:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then fireproximityprompt(prompt) end

	-- รอจน orb หาย หรือหมดเวลา
	local t = tick()
	while orb.Parent and tick() - t < COLLECT_TIMEOUT do task.wait() end
	if orb.Parent then recentlyVisited[orb] = tick() end
end

--================ ลูปหลัก ================--
local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while anyEnabled() do
			local root = getRoot()
			if root then
				local target = getTarget(root, getOrbs())
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

function ToggleBigFirst(state)
	if state == nil then state = not BIG_FIRST end
	BIG_FIRST = state
	return state
end

--================ Floating UI ================--
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("OrbCollector")
if old then old:Destroy() end

local FULL_HEIGHT = 238
local WIDTH = 200

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, WIDTH, 0, FULL_HEIGHT)
main.Position = UDim2.new(0, 20, 0, 150)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(80, 80, 95)
stroke.Thickness = 1.5

-- แถบหัว (ลากตรงนี้)
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

local function makeButton(label, toggleFn, initial)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = body
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local function render(on)
		btn.Text = label .. (on and ": ON" or ": OFF")
		btn.BackgroundColor3 = on and ON_COLOR or OFF_COLOR
	end
	render(initial or false)

	btn.MouseButton1Click:Connect(function()
		render(toggleFn())
	end)
end

makeButton("Orb",       ToggleOrb,      Settings.Orb)
makeButton("SandOrb",   ToggleSandOrb,  Settings.SandOrb)
makeButton("VoidOrb",   ToggleVoidOrb,  Settings.VoidOrb)
makeButton("Big First", ToggleBigFirst, BIG_FIRST)

-- ย่อ / ขยาย
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = UDim2.new(0, WIDTH, 0, minimized and 32 or FULL_HEIGHT)
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
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
