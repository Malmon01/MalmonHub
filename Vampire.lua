--// Auto Farm: Orbs / SandOrbs / VoidOrbs + Mob Farm (Zone Lock)
--// Big First + Nearest + Floating UI (ย่อได้ / ลากได้)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

--================ ตั้งค่า ================--
local Settings = { Orb = false, SandOrb = false, VoidOrb = false }
local FOLDERS  = { Orb = "Orbs", SandOrb = "SandOrbs", VoidOrb = "VoidOrbs" }

-- Orb
local COLLECT_TIMEOUT = 1.5
local DELAY_BETWEEN   = 0.15
local SKIP_COOLDOWN   = 5
local BIG_FIRST       = true
local SIZE_TOLERANCE  = 0.3

-- Mob
local MOB_FOLDER   = "Bugs"   -- โฟลเดอร์มอนใน Workspace
local ZONE_RADIUS  = 250      -- รัศมีโซนจากจุดที่กด Set Zone (ปรับตามขนาดแมพ)
local MOB_TIMEOUT  = 25       -- ตีตัวเดียวนานสุดกี่วินาที แล้วเปลี่ยนตัว
local MOB_OFFSET   = 4        -- ยืนห่างจากมอนกี่ studs
local MOB_SKIP     = 10       -- ตีไม่ตายแล้วข้ามตัวนั้นกี่วินาที

local MobFarm     = false
local ZONE_CENTER = nil

local recentlyVisited = setmetatable({}, { __mode = "k" })
local mobSkipped      = setmetatable({}, { __mode = "k" })
local running = false

--================ ฟังก์ชันช่วย ================--
local function orbEnabled()
	for _, v in pairs(Settings) do if v then return true end end
	return false
end

local function anyEnabled()
	return orbEnabled() or MobFarm
end

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

--================ Orb ================--
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

local function getOrbTarget(root, list)
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
		if better then best, bestSize, bestDist = d, size, dist end
	end
	return best
end

local function collectOrb(root, data)
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

--================ Mob ================--
local function readNumber(obj, names)
	for _, n in ipairs(names) do
		local a = obj:GetAttribute(n)
		if typeof(a) == "number" then return a end
		local v = obj:FindFirstChild(n, true)
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v.Value end
	end
end

local function getMobParts(mob)
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
		or mob:FindFirstChildWhichIsA("BasePart", true)
	return hum, root
end

local function isMobAlive(mob, hum)
	if not mob.Parent then return false end
	if hum then return hum.Health > 0 end
	local hp = readNumber(mob, { "Health", "HP" })
	return hp == nil or hp > 0
end

-- คะแนนของมอน: EXP > Level > MaxHealth
local function getMobScore(mob, hum)
	return readNumber(mob, { "XP", "EXP", "Exp", "Xp", "XPReward", "ExpReward" })
		or readNumber(mob, { "Level", "Lv", "Lvl" })
		or (hum and hum.MaxHealth)
		or readNumber(mob, { "MaxHealth", "MaxHP" })
		or 0
end

local function getMobTarget(root)
	if not ZONE_CENTER then return nil end
	local folder = workspace:FindFirstChild(MOB_FOLDER)
	if not folder then return nil end

	local best, bestScore, bestDist = nil, -math.huge, math.huge
	local now = tick()
	for _, mob in ipairs(folder:GetChildren()) do
		if mob:IsA("Model") and not Players:GetPlayerFromCharacter(mob) then
			local last = mobSkipped[mob]
			if not (last and now - last < MOB_SKIP) then
				local hum, mRoot = getMobParts(mob)
				if mRoot and isMobAlive(mob, hum)
					and (mRoot.Position - ZONE_CENTER).Magnitude <= ZONE_RADIUS then
					local score = getMobScore(mob, hum)
					local dist = (mRoot.Position - root.Position).Magnitude
					if score > bestScore or (score == bestScore and dist < bestDist) then
						best, bestScore, bestDist = mob, score, dist
					end
				end
			end
		end
	end
	return best
end

local function attackMob(mob)
	local hum, mRoot = getMobParts(mob)
	local t = tick()
	while MobFarm and isMobAlive(mob, hum) and tick() - t < MOB_TIMEOUT do
		local root = getRoot()
		if not root or not mRoot.Parent then break end
		local pos = (mRoot.CFrame * CFrame.new(0, 0, MOB_OFFSET)).Position
		root.CFrame = CFrame.lookAt(pos, mRoot.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.1)
	end
	if isMobAlive(mob, hum) then mobSkipped[mob] = tick() end
end

--================ ลูปหลัก ================--
local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while anyEnabled() do
			local root = getRoot()
			if not root then
				task.wait(1)
			else
				local did = false

				-- 1) ตีมอนก่อน
				if MobFarm then
					local mob = getMobTarget(root)
					if mob then
						attackMob(mob)
						did = true
					end
				end

				-- 2) ไม่มีมอน -> เก็บ orb
				if not did and orbEnabled() then
					local target = getOrbTarget(root, getOrbs())
					if target then
						collectOrb(root, target)
						task.wait(DELAY_BETWEEN)
						did = true
					end
				end

				if not did then task.wait(0.5) end
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

function ToggleMobFarm(state)
	if state == nil then state = not MobFarm end
	if state and not ZONE_CENTER then
		warn("[MobFarm] กด Set Zone ก่อน")
		return false
	end
	MobFarm = state
	if state then startLoop() end
	return state
end

function SetZone()
	local root = getRoot()
	if root then
		ZONE_CENTER = root.Position
		print("[Zone] ตั้งศูนย์กลางโซนที่", ZONE_CENTER)
		return true
	end
	return false
end

--================ Floating UI ================--
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("OrbCollector")
if old then old:Destroy() end

local BUTTON_COUNT = 6
local WIDTH = 200
local FULL_HEIGHT = 42 + BUTTON_COUNT * 48

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, WIDTH, 0, FULL_HEIGHT)
main.Position = UDim2.new(0, 20, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(80, 80, 95)
stroke.Thickness = 1.5

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
titleText.Text = "Auto Farm"
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

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -42)
body.Position = UDim2.new(0, 10, 0, 38)
body.BackgroundTransparency = 1
body.Parent = main
local layout = Instance.new("UIListLayout", body)
layout.Padding = UDim.new(0, 8)

local ON_COLOR   = Color3.fromRGB(50, 170, 80)
local OFF_COLOR  = Color3.fromRGB(170, 50, 50)
local INFO_COLOR = Color3.fromRGB(60, 90, 160)

local function newButton()
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = body
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	return btn
end

local function makeToggleButton(label, toggleFn, initial)
	local btn = newButton()
	local function render(on)
		btn.Text = label .. (on and ": ON" or ": OFF")
		btn.BackgroundColor3 = on and ON_COLOR or OFF_COLOR
	end
	render(initial or false)
	btn.MouseButton1Click:Connect(function() render(toggleFn()) end)
end

makeToggleButton("Orb",       ToggleOrb,      Settings.Orb)
makeToggleButton("SandOrb",   ToggleSandOrb,  Settings.SandOrb)
makeToggleButton("VoidOrb",   ToggleVoidOrb,  Settings.VoidOrb)
makeToggleButton("Big First", ToggleBigFirst, BIG_FIRST)

-- ปุ่ม Set Zone
local zoneBtn = newButton()
zoneBtn.Text = "Set Zone (ยืนกลางโซน)"
zoneBtn.BackgroundColor3 = INFO_COLOR
zoneBtn.MouseButton1Click:Connect(function()
	if SetZone() then zoneBtn.Text = "Zone: Set ✓ (กดเพื่อตั้งใหม่)" end
end)

makeToggleButton("Mob Farm", ToggleMobFarm, MobFarm)

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
