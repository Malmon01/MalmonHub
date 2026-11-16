--// Auto Farm: Orbs / SandOrbs / VoidOrbs + Mob Farm + Eat Corpse + Eat Egg
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
local MOB_FOLDER   = "Bugs"
local ZONE_RADIUS  = 250      -- รัศมีโซนจากจุดที่กด Set Zone
local MOB_TIMEOUT  = 25
local MOB_OFFSET   = 4
local MOB_SKIP     = 10

-- Corpse (ซาก)
local CORPSE_FOLDERS = { "Corpses", "Corpse", "Carcasses", "Bodies", "DeadBugs", "Meat" }
local EAT_TIMEOUT    = 15
local EAT_OFFSET     = 3
local CORPSE_SKIP    = 20

-- Egg (ไข่ใน Breakables)
local EGG_FOLDER    = "Breakables"
local EGG_NAMES     = {
	["Egg Cluster"]   = true,
	-- ["Golden Cocoon"] = true,   -- เอาเครื่องหมาย -- ออกถ้าอยากตีด้วย
	-- ["Acorn"]         = true,
}
local EGG_ZONE_ONLY = false   -- true = เฉพาะในโซน, false = ทั้งแมพ
local EGG_TIMEOUT   = 10
local EGG_OFFSET    = 2
local EGG_SKIP      = 20

local MobFarm     = false
local EatCorpse   = false
local EatEgg      = false
local ZONE_CENTER = nil

local recentlyVisited = setmetatable({}, { __mode = "k" })
local mobSkipped      = setmetatable({}, { __mode = "k" })
local corpseSkipped   = setmetatable({}, { __mode = "k" })
local eggSkipped      = setmetatable({}, { __mode = "k" })
local running = false

--================ ฟังก์ชันช่วย ================--
local function orbEnabled()
	for _, v in pairs(Settings) do if v then return true end end
	return false
end

local function anyEnabled()
	return orbEnabled() or MobFarm or EatCorpse or EatEgg
end

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getMainPart(obj)
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		local hb = obj:FindFirstChild("Hitbox")
		if hb and hb:IsA("BasePart") then return hb end
		return obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
			or obj:FindFirstChildWhichIsA("BasePart", true)
	end
end

local function inZone(pos)
	return ZONE_CENTER ~= nil and (pos - ZONE_CENTER).Magnitude <= ZONE_RADIUS
end

local function readNumber(obj, names)
	for _, n in ipairs(names) do
		local a = obj:GetAttribute(n)
		if typeof(a) == "number" then return a end
		local v = obj:FindFirstChild(n, true)
		if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v.Value end
	end
end

local function fireInteract(root, obj)
	if firetouchinterest then
		local parts = obj:IsA("BasePart") and { obj } or obj:GetDescendants()
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				firetouchinterest(root, p, 0)
				firetouchinterest(root, p, 1)
			end
		end
	end
	local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then fireproximityprompt(prompt) end
end

local function stickTo(root, part, offset)
	local pos = (part.CFrame * CFrame.new(0, 0, offset)).Position
	root.CFrame = CFrame.lookAt(pos, part.Position)
	root.AssemblyLinearVelocity = Vector3.zero
end

--================ Orb ================--
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
					local part = getMainPart(orb)
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
	fireInteract(root, orb)
	local t = tick()
	while orb.Parent and tick() - t < COLLECT_TIMEOUT do task.wait() end
	if orb.Parent then recentlyVisited[orb] = tick() end
end

--================ Mob / Corpse / Egg ================--
local function getScore(obj)
	local hum = obj:FindFirstChildOfClass("Humanoid")
	return readNumber(obj, { "XP", "EXP", "Exp", "Xp", "XPReward", "ExpReward" })
		or readNumber(obj, { "Level", "Lv", "Lvl" })
		or (hum and hum.MaxHealth)
		or readNumber(obj, { "MaxHealth", "MaxHP" })
		or 0
end

-- ตาย / แตก แล้วหรือยัง
local function isDead(obj)
	if obj:GetAttribute("Dead") or obj:GetAttribute("IsDead")
		or obj:GetAttribute("IsCorpse") or obj:GetAttribute("Corpse")
		or obj:GetAttribute("Broken") then
		return true
	end
	if obj:IsA("Model") then
		local hum = obj:FindFirstChildOfClass("Humanoid")
		if hum then return hum.Health <= 0 end
	end
	local hp = readNumber(obj, { "Health", "HP" })
	if hp then return hp <= 0 end
	return false
end

local function isMobAlive(mob)
	return mob.Parent ~= nil and not isDead(mob)
end

local function isPlayerChar(obj)
	return Players:GetPlayerFromCharacter(obj) ~= nil
end

local function pickBest(root, list, zoneOnly)
	local best, bestScore, bestDist = nil, -math.huge, math.huge
	for _, obj in ipairs(list) do
		local part = getMainPart(obj)
		if part and (not zoneOnly or inZone(part.Position)) then
			local score = getScore(obj)
			local dist = (part.Position - root.Position).Magnitude
			if score > bestScore or (score == bestScore and dist < bestDist) then
				best, bestScore, bestDist = obj, score, dist
			end
		end
	end
	return best
end

local function getMobTarget(root)
	local folder = workspace:FindFirstChild(MOB_FOLDER)
	if not folder then return nil end
	local list, now = {}, tick()
	for _, mob in ipairs(folder:GetChildren()) do
		local last = mobSkipped[mob]
		if mob:IsA("Model") and not isPlayerChar(mob) and isMobAlive(mob)
			and not (last and now - last < MOB_SKIP) then
			table.insert(list, mob)
		end
	end
	return pickBest(root, list, true)
end

local function getCorpseTarget(root)
	local list, now = {}, tick()
	local function add(obj)
		local last = corpseSkipped[obj]
		if not (last and now - last < CORPSE_SKIP) then table.insert(list, obj) end
	end

	local mobFolder = workspace:FindFirstChild(MOB_FOLDER)
	if mobFolder then
		for _, obj in ipairs(mobFolder:GetChildren()) do
			if not isPlayerChar(obj) and isDead(obj) then add(obj) end
		end
	end

	for _, name in ipairs(CORPSE_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, obj in ipairs(f:GetChildren()) do
				if obj:IsA("Model") or obj:IsA("BasePart") then add(obj) end
			end
		end
	end

	return pickBest(root, list, true)
end

local function getEggTarget(root)
	local folder = workspace:FindFirstChild(EGG_FOLDER)
	if not folder then return nil end
	local list, now = {}, tick()
	for _, obj in ipairs(folder:GetChildren()) do
		local last = eggSkipped[obj]
		if EGG_NAMES[obj.Name] and not isDead(obj)
			and not (last and now - last < EGG_SKIP) then
			table.insert(list, obj)
		end
	end
	return pickBest(root, list, EGG_ZONE_ONLY)
end

local function attackMob(mob)
	local part = getMainPart(mob)
	local t = tick()
	while MobFarm and isMobAlive(mob) and tick() - t < MOB_TIMEOUT do
		local root = getRoot()
		if not root or not part or not part.Parent then break end
		stickTo(root, part, MOB_OFFSET)
		task.wait(0.1)
	end
	if isMobAlive(mob) then mobSkipped[mob] = tick() end
end

-- กินซาก / ตีไข่ (เกาะติดจนหายหรือแตก)
local function eatTarget(obj, isOn, timeout, offset, skipTable, stopWhenDead)
	local part = getMainPart(obj)
	local t, lastFire = tick(), 0
	while isOn() and obj.Parent and tick() - t < timeout do
		if stopWhenDead and isDead(obj) then return end
		local root = getRoot()
		if not root or not part or not part.Parent then break end
		stickTo(root, part, offset)
		if tick() - lastFire > 0.5 then
			fireInteract(root, obj)
			lastFire = tick()
		end
		task.wait(0.1)
	end
	if obj.Parent then skipTable[obj] = tick() end
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

				-- 1) กินซาก
				if EatCorpse and ZONE_CENTER then
					local corpse = getCorpseTarget(root)
					if corpse then
						eatTarget(corpse, function() return EatCorpse end,
							EAT_TIMEOUT, EAT_OFFSET, corpseSkipped, false)
						did = true
					end
				end

				-- 2) ตีไข่
				if not did and EatEgg then
					local egg = getEggTarget(root)
					if egg then
						eatTarget(egg, function() return EatEgg end,
							EGG_TIMEOUT, EGG_OFFSET, eggSkipped, true)
						did = true
					end
				end

				-- 3) ตีมอน
				if not did and MobFarm and ZONE_CENTER then
					local mob = getMobTarget(root)
					if mob then
						attackMob(mob)
						did = true
					end
				end

				-- 4) เก็บ orb
				if not did and orbEnabled() then
					local target = getOrbTarget(root, getOrbs())
					if target then
						collectOrb(root, target)
						task.wait(DELAY_BETWEEN)
						did = true
					end
				end

				if not did then task.wait(0.3) end
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

function ToggleEatCorpse(state)
	if state == nil then state = not EatCorpse end
	if state and not ZONE_CENTER then
		warn("[EatCorpse] กด Set Zone ก่อน")
		return false
	end
	EatCorpse = state
	if state then startLoop() end
	return state
end

function ToggleEatEgg(state)
	if state == nil then state = not EatEgg end
	if state and EGG_ZONE_ONLY and not ZONE_CENTER then
		warn("[EatEgg] กด Set Zone ก่อน")
		return false
	end
	EatEgg = state
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

local BUTTON_COUNT = 8
local BTN_H, BTN_GAP = 34, 6
local WIDTH = 200
local FULL_HEIGHT = 42 + BUTTON_COUNT * (BTN_H + BTN_GAP)

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, WIDTH, 0, FULL_HEIGHT)
main.Position = UDim2.new(0, 20, 0, 80)
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
layout.Padding = UDim.new(0, BTN_GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local ON_COLOR   = Color3.fromRGB(50, 170, 80)
local OFF_COLOR  = Color3.fromRGB(170, 50, 50)
local INFO_COLOR = Color3.fromRGB(60, 90, 160)
local order = 0

local function newButton()
	order += 1
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Size = UDim2.new(1, 0, 0, BTN_H)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
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

local zoneBtn = newButton()
zoneBtn.Text = "Set Zone (ยืนกลางโซน)"
zoneBtn.BackgroundColor3 = INFO_COLOR
zoneBtn.MouseButton1Click:Connect(function()
	if SetZone() then zoneBtn.Text = "Zone: Set ✓ (กดตั้งใหม่)" end
end)

makeToggleButton("Mob Farm",   ToggleMobFarm,   MobFarm)
makeToggleButton("Eat Corpse", ToggleEatCorpse, EatCorpse)
makeToggleButton("Eat Egg",    ToggleEatEgg,    EatEgg)

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
