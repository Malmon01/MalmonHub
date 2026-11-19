--// Auto Farm: Orbs / Mob / Corpse / Egg + Cave Farm
--// Smooth Follow + Telegraph Dodge + Status + Floating UI (ย่อได้ / ลากได้)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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

-- Mob (ข้างนอก)
local MOB_FOLDER   = "Bugs"
local ZONE_RADIUS  = 250
local MOB_TIMEOUT  = 25
local MOB_OFFSET   = 4
local MOB_SKIP     = 10

-- Corpse
local CORPSE_FOLDERS = { "Corpses", "Corpse", "Carcasses", "Bodies", "DeadBugs", "Meat" }
local EAT_TIMEOUT    = 15
local EAT_OFFSET     = 3
local CORPSE_SKIP    = 20

-- Egg
local EGG_FOLDER    = "Breakables"
local EGG_NAMES     = {
	["Egg Cluster"]   = true,
	-- ["Golden Cocoon"] = true,
	-- ["Acorn"]         = true,
}
local EGG_ZONE_ONLY = false
local EGG_TIMEOUT   = 10
local EGG_OFFSET    = 2
local EGG_SKIP      = 20

-- Cave
local CAVE_OFFSET       = 4      -- ระยะยืนตีมอนในถ้ำ
local CAVE_MOB_TIMEOUT  = 30     -- ตีตัวเดียวนานสุด (วินาที)
local DOOR_OFFSET       = 4      -- ระยะยืนกัดประตูใย
local DOOR_TIMEOUT      = 40     -- กัดประตูนานสุด
local DODGE_DIST        = 18     -- ถอยห่างตอนหลบ
local DODGE_TIME        = 1.2    -- หลบนานกี่วินาที (ตอนเลือดลด)
local DANGER_MARGIN     = 3      -- ระยะเผื่อจากวงแดง
local WEB_OFFSET        = 4      -- ระยะยืนตีใยหน้าถ้ำ
local WEB_TIMEOUT       = 60
local ENTER_WAIT        = 12     -- รอโหลดเข้าถ้ำนานสุด
local INSIDE_GRACE      = 10     -- เพิ่งอยู่ในถ้ำไม่เกินกี่วิ = ยังถือว่าอยู่ข้างใน
local ENEMY_RANGE       = 250    -- มอนในถ้ำที่ห่างไม่เกินนี้ถึงจะตี
local DOOR_RANGE        = 400    -- ประตูใยที่ห่างไม่เกินนี้
local CAVE_LOOT         = true   -- กัด Geode (เหรียญในถ้ำ) ก่อนกัดประตู
local LOOT_RANGE        = 80     -- Geode ที่ห่างไม่เกินนี้ (กันวาร์ปทะลุไปห้องถัดไป)
local CAVE_BITE_EXTRAS  = false  -- true = กัดของอื่น เช่น Acorn ด้วย (หลังไม่มีมอน/Geode/ประตู)
local PREFER_HIGH_TIER  = true
local DEBUG_ATTR        = false  -- true = พิมพ์ Attribute มอนที่เปลี่ยน

local MobFarm     = false
local EatCorpse   = false
local EatEgg      = false
local CaveFarm    = false
local ZONE_CENTER = nil

local recentlyVisited = setmetatable({}, { __mode = "k" })
local mobSkipped      = setmetatable({}, { __mode = "k" })
local corpseSkipped   = setmetatable({}, { __mode = "k" })
local eggSkipped      = setmetatable({}, { __mode = "k" })
local caveSkipped     = setmetatable({}, { __mode = "k" })
local doorSkipped     = setmetatable({}, { __mode = "k" })
local roomCenters     = setmetatable({}, { __mode = "k" })
local dangerZones     = setmetatable({}, { __mode = "k" })
local running, caveRunning = false, false
local dodgeUntil = 0

--================ สถานะ (โชว์ที่หัว UI) ================--
local statusLabel
local lastStatus = ""
local function setStatus(s)
	if s == lastStatus then return end
	lastStatus = s
	print("[AutoFarm]", s)
	if statusLabel then statusLabel.Text = s end
end

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

--================ วงแดงเตือนโจมตี (Telegraph) ================--
local function isTelegraph(p)
	if not p:IsA("BasePart") or p.CanCollide then return false end
	if p.Transparency >= 0.98 then return false end
	local c = p.Color
	if not (c.R > 0.55 and c.G < 0.4 and c.B < 0.4) then return false end
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) < 3 then return false end
	local char = player.Character
	if char and p:IsDescendantOf(char) then return false end
	-- ข้ามพื้น/ลาวาที่เป็นส่วนของห้อง
	local cur = p.Parent
	while cur and cur ~= workspace do
		if cur.Name:match("^Room%d+") then return false end
		cur = cur.Parent
	end
	return true
end

workspace.DescendantAdded:Connect(function(o)
	if not CaveFarm or not o:IsA("BasePart") then return end
	task.defer(function()
		if o.Parent and isTelegraph(o) then dangerZones[o] = true end
	end)
end)

local function inDanger(pos)
	for p in pairs(dangerZones) do
		if not p.Parent then
			dangerZones[p] = nil
		else
			local s = p.Size
			local r = math.max(s.X, s.Y, s.Z) / 2 + DANGER_MARGIN
			local flat = Vector3.new(pos.X - p.Position.X, 0, pos.Z - p.Position.Z)
			if flat.Magnitude < r then return true end
		end
	end
	return false
end

local DIRS = {}
for i = 0, 7 do
	local a = i * math.pi / 4
	table.insert(DIRS, Vector3.new(math.cos(a), 0, math.sin(a)))
end

--================ เกาะติดเป้าหมายแบบนิ่ง + หลบ ================--
local followPart, followOffset = nil, 0
local followDir = Vector3.new(0, 0, 1)

local function safeSpot(target, dist)
	if not inDanger(target + followDir * dist) then return followDir, dist end
	for _, d in ipairs(DIRS) do
		if not inDanger(target + d * dist) then return d, dist end
	end
	for _, d in ipairs(DIRS) do
		if not inDanger(target + d * DODGE_DIST) then return d, DODGE_DIST end
	end
	return followDir, DODGE_DIST * 1.5
end

RunService.Heartbeat:Connect(function()
	if not followPart or not followPart.Parent then return end
	local root = getRoot()
	if not root then return end
	local target = followPart.Position
	local dir, dist = followDir, followOffset
	if CaveFarm then
		if tick() < dodgeUntil then dist = DODGE_DIST end
		dir, dist = safeSpot(target, dist)
		followDir = dir
	end
	local pos = target + dir * dist
	local look = Vector3.new(target.X, pos.Y, target.Z)
	root.CFrame = CFrame.lookAt(pos, look)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end)

local function stickTo(part, offset)
	followPart, followOffset = part, offset
end

local function stopFollow()
	followPart = nil
end

-- เลือดลด = ถอยหลบชั่วคราว (ใช้ตอน Cave Farm)
local function hookHealth()
	local char = player.Character
	local hum = char and char:WaitForChild("Humanoid", 5)
	if not hum then return end
	local last = hum.Health
	hum.HealthChanged:Connect(function(h)
		if CaveFarm and h < last then dodgeUntil = tick() + DODGE_TIME end
		last = h
	end)
end
player.CharacterAdded:Connect(function() task.wait(1) hookHealth() end)
task.spawn(hookHealth)

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
	root.AssemblyLinearVelocity = Vector3.zero
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
	if not part then return end
	stickTo(part, MOB_OFFSET)
	local t = tick()
	while MobFarm and not CaveFarm and isMobAlive(mob) and part.Parent and tick() - t < MOB_TIMEOUT do
		task.wait(0.1)
	end
	stopFollow()
	if isMobAlive(mob) then mobSkipped[mob] = tick() end
end

local function eatTarget(obj, isOn, timeout, offset, skipTable, stopWhenDead)
	local part = getMainPart(obj)
	if not part then return end
	stickTo(part, offset)
	local t, lastFire = tick(), 0
	while isOn() and not CaveFarm and obj.Parent and part.Parent and tick() - t < timeout do
		if stopWhenDead and isDead(obj) then
			stopFollow()
			return
		end
		local root = getRoot()
		if root and tick() - lastFire > 0.5 then
			fireInteract(root, obj)
			lastFire = tick()
		end
		task.wait(0.1)
	end
	stopFollow()
	if obj.Parent then skipTable[obj] = tick() end
end

--================ ลูปหลัก (ข้างนอก) ================--
local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while anyEnabled() do
			if CaveFarm then task.wait(0.5) continue end

			local root = getRoot()
			if not root then
				task.wait(1)
				continue
			end

			local did = false

			if EatCorpse and ZONE_CENTER then
				local corpse = getCorpseTarget(root)
				if corpse then
					eatTarget(corpse, function() return EatCorpse end,
						EAT_TIMEOUT, EAT_OFFSET, corpseSkipped, false)
					did = true
				end
			end

			if not did and EatEgg then
				local egg = getEggTarget(root)
				if egg then
					eatTarget(egg, function() return EatEgg end,
						EGG_TIMEOUT, EGG_OFFSET, eggSkipped, true)
					did = true
				end
			end

			if not did and MobFarm and ZONE_CENTER then
				local mob = getMobTarget(root)
				if mob then
					attackMob(mob)
					did = true
				end
			end

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
		stopFollow()
		running = false
	end)
end

--================ Cave: GUI ================--
local lastInside = 0
local currentCave = nil

local function isShown(obj)
	local cur = obj
	while cur and not cur:IsA("PlayerGui") do
		if cur:IsA("GuiObject") and not cur.Visible then return false end
		if cur:IsA("ScreenGui") and not cur.Enabled then return false end
		cur = cur.Parent
	end
	return cur ~= nil
end

local function findShownText(matchFn)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, o in ipairs(pg:GetDescendants()) do
		if (o:IsA("TextLabel") or o:IsA("TextButton")) and matchFn(o.Text) and isShown(o) then
			return o
		end
	end
end

local function pressButton(btn)
	if not btn:IsA("GuiButton") then
		btn = btn:FindFirstAncestorWhichIsA("GuiButton")
		if not btn then return end
	end
	local fired = false
	if getconnections then
		for _, sig in ipairs({ btn.MouseButton1Click, btn.Activated, btn.MouseButton1Down }) do
			for _, c in ipairs(getconnections(sig)) do
				pcall(function()
					if c.Fire then c:Fire() elseif c.Function then c.Function() end
				end)
				fired = true
			end
		end
	end
	if not fired and firesignal then
		pcall(firesignal, btn.MouseButton1Click)
		pcall(firesignal, btn.Activated)
		fired = true
	end
	if not fired then
		local vim = game:GetService("VirtualInputManager")
		local inset = game:GetService("GuiService"):GetGuiInset()
		local p = btn.AbsolutePosition + btn.AbsoluteSize / 2 + inset
		vim:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
		task.wait(0.05)
		vim:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
	end
end

local function getLobbyStart()
	local pg = player:FindFirstChild("PlayerGui")
	local gui = pg and pg:FindFirstChild("Cave")
	local lobby = gui and gui:FindFirstChild("CaveLobby")
	local start = lobby and lobby:FindFirstChild("Start")
	if start and isShown(start) then return start end
end

-- หน้าจอชนะ: ปุ่ม CLAIM ALL
local function getClaimAll()
	return findShownText(function(t)
		return t:upper():find("CLAIM ALL", 1, true) ~= nil
	end)
end

-- HUD ในถ้ำ (ROOM 1/4, BUGS LEFT, BITE THROUGH ...) = อยู่ในถ้ำ
local function isRoomText(t)
	t = t:upper()
	return t:find("ROOM%s*%d+%s*/%s*%d+") ~= nil
		or t:find("BUGS? LEFT") ~= nil
		or t:find("BITE THROUGH", 1, true) ~= nil
		or t:find("ROOM CLEAR", 1, true) ~= nil
		or t:find("THE WAY ON", 1, true) ~= nil
end

local hudCache, hudScanAt = nil, 0
local function inCaveRun()
	if hudCache and hudCache.Parent and isRoomText(hudCache.Text) and isShown(hudCache) then
		return true
	end
	if tick() - hudScanAt < 0.75 then return false end
	hudScanAt = tick()
	hudCache = findShownText(isRoomText)
	return hudCache ~= nil
end

--================ Cave: ในถ้ำ ================--
-- กล่องขอบเขตของแต่ละถ้ำ (คำนวณครั้งเดียว)
local runBoxes = setmetatable({}, { __mode = "k" })
local function getRunBox(m)
	local box = runBoxes[m]
	if box then return box end
	local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
	if not ok then return nil end
	box = { cf = cf, size = size }
	runBoxes[m] = box
	return box
end

-- ถ้ำที่ตัวเรายืนอยู่ข้างใน (ดูจากตำแหน่ง ไม่ต้องพึ่ง HUD)
local function getRunAt(root)
	local folder = workspace:FindFirstChild("CaveRuns")
	if not folder then return nil end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^CaveRun_") then
			local box = getRunBox(m)
			if box then
				local p = box.cf:PointToObjectSpace(root.Position)
				local h = box.size / 2 + Vector3.new(40, 60, 40)
				if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
					return m
				end
			end
		end
	end
end

-- มอนทุกตัวในโฟลเดอร์ Enemies_* ที่อยู่ใกล้ตัว
local function getCaveEnemies(root)
	local list = {}
	local runs = workspace:FindFirstChild("CaveRuns")
	if not runs then return list end
	for _, f in ipairs(runs:GetChildren()) do
		if f.Name:match("^Enemies_") then
			for _, e in ipairs(f:GetChildren()) do
				local hum = e:FindFirstChildOfClass("Humanoid")
				local hrp = e:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0
					and (hrp.Position - root.Position).Magnitude < ENEMY_RANGE then
					table.insert(list, e)
				end
			end
		end
	end
	return list
end

-- ของที่ต้องกัดในถ้ำ: Geode (CaveLoot) ใกล้ ๆ ก่อน -> ประตูใย (CaveDoor) -> ของอื่น
local function getRunBreakable(run, root)
	local bestDoor, doorDist, bestLoot, lootDist, bestExtra, extraDist
	local now = tick()
	local function consider(m)
		if not (m:IsA("Model") and m:GetAttribute("BreakId")) then return end
		local hp = m:GetAttribute("HP")
		if hp and hp <= 0 then return end
		local last = doorSkipped[m]
		if last and now - last < 20 then return end
		local p = getMainPart(m)
		if not p then return end
		local d = (p.Position - root.Position).Magnitude
		if d > DOOR_RANGE then return end
		local id = tostring(m:GetAttribute("BreakId"))
		if id == "CaveLoot" then
			if CAVE_LOOT and d <= LOOT_RANGE and d < (lootDist or math.huge) then
				bestLoot, lootDist = m, d
			end
		elseif id == "CaveDoor" then
			if d < (doorDist or math.huge) then bestDoor, doorDist = m, d end
		elseif CAVE_BITE_EXTRAS then
			if d < (extraDist or math.huge) then bestExtra, extraDist = m, d end
		end
	end
	if run then
		for _, o in ipairs(run:GetDescendants()) do consider(o) end
	end
	if CAVE_BITE_EXTRAS then
		local br = workspace:FindFirstChild("Breakables")
		if br then
			for _, o in ipairs(br:GetChildren()) do consider(o) end
		end
	end
	return bestLoot or bestDoor or bestExtra
end

local function nearestOf(root, list)
	local best, bestDist = nil, math.huge
	for _, e in ipairs(list) do
		local d = (e.HumanoidRootPart.Position - root.Position).Magnitude
		if d < bestDist then best, bestDist = e, d end
	end
	return best
end

local function attackCaveEnemy(e)
	local hum = e:FindFirstChildOfClass("Humanoid")
	local part = e:FindFirstChild("HumanoidRootPart")
	if not hum or not part then return end

	local conn
	if DEBUG_ATTR then
		conn = e.AttributeChanged:Connect(function(name)
			print("[Attr]", e.Name, name, e:GetAttribute(name))
		end)
	end

	stickTo(part, CAVE_OFFSET)
	local t = tick()
	while CaveFarm and e.Parent and hum.Health > 0 and part.Parent and tick() - t < CAVE_MOB_TIMEOUT do
		lastInside = tick()
		task.wait(0.1)
	end

	if conn then conn:Disconnect() end
	stopFollow()
end

local function biteBreakable(m)
	local part = getMainPart(m)
	if not part then return end
	stickTo(part, DOOR_OFFSET)
	local t = tick()
	while CaveFarm and m.Parent and part.Parent and tick() - t < DOOR_TIMEOUT do
		lastInside = tick()
		local hp = m:GetAttribute("HP")
		if hp and hp <= 0 then break end
		task.wait(0.1)
	end
	stopFollow()
	local hp = m:GetAttribute("HP")
	if m.Parent and not (hp and hp <= 0) then doorSkipped[m] = tick() end
end

local function roomCenter(room)
	if roomCenters[room] then return roomCenters[room] end
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(room:GetDescendants()) do
		if p:IsA("BasePart") then
			sum += p.Position
			n += 1
		end
	end
	if n == 0 then return nil end
	roomCenters[room] = sum / n
	return roomCenters[room]
end

local function advanceRoom(run, root)
	local rooms = {}
	for i = 1, 10 do
		local r = run:FindFirstChild("Room" .. i)
		if r then
			local c = roomCenter(r)
			if c then table.insert(rooms, { i = i, c = c }) end
		end
	end
	local cur, best = nil, math.huge
	for _, r in ipairs(rooms) do
		local d = (r.c - root.Position).Magnitude
		if d < best then cur, best = r, d end
	end
	if not cur then return false end
	for _, r in ipairs(rooms) do
		if r.i == cur.i + 1 then
			root.CFrame = CFrame.new(r.c + Vector3.new(0, 5, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			return true
		end
	end
	return false
end

--================ Cave: ข้างนอก ================--
local function getMyLevel()
	local v = player:GetAttribute("Level") or player:GetAttribute("Lv")
	if typeof(v) == "number" then return v end
	local ls = player:FindFirstChild("leaderstats")
	local s = ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("Lv"))
	if s then return tonumber(s.Value) or math.huge end
	return math.huge
end

local function caveLabel(cave)
	return tostring(cave:GetAttribute("CaveName") or cave.Name)
end

local function getPrompt(cave)
	local mouth = cave:FindFirstChild("Mouth")
	return mouth and mouth:FindFirstChild("CavePrompt"), mouth
end

-- คูลดาวน์เข้าถ้ำ ("ready in 0:27") คืนค่าเป็นวินาที
local function getCaveCooldown()
	local caves = workspace:FindFirstChild("Caves")
	if not caves then return 0 end
	for _, cave in ipairs(caves:GetChildren()) do
		local prompt = getPrompt(cave)
		if prompt then
			local txt = (prompt.ObjectText .. " " .. prompt.ActionText):lower()
			local m, s = txt:match("ready in%s*(%d+):(%d+)")
			if m then return tonumber(m) * 60 + tonumber(s) end
		end
	end
	return 0
end

local function chooseCave()
	local caves = workspace:FindFirstChild("Caves")
	if not caves then return nil, nil end
	local myLv = getMyLevel()
	local open, breakable
	local function better(a, b)
		if not b then return true end
		local ta, tb = a:GetAttribute("Tier") or 0, b:GetAttribute("Tier") or 0
		if PREFER_HIGH_TIER then return ta > tb else return ta < tb end
	end
	for _, cave in ipairs(caves:GetChildren()) do
		local prompt = getPrompt(cave)
		local web = cave:FindFirstChild("Spider Web")
		local last = caveSkipped[cave]
		if prompt and not (last and tick() - last < 30) then
			if prompt.Enabled then
				if better(cave, open) then open = cave end
			elseif web and (web:GetAttribute("MinLevel") or 0) <= myLv then
				if better(cave, breakable) then breakable = cave end
			end
		end
	end
	return open, breakable
end

-- ถ้ามีถ้ำเปิดอยู่ไปถ้ำนั้น ไม่งั้นล็อกถ้ำเดิมไว้ตีใยจนแตก
local function pickCave()
	local open, breakable = chooseCave()
	if currentCave and currentCave.Parent then
		local prompt = getPrompt(currentCave)
		if prompt and prompt.Enabled then return currentCave end
	end
	if open then
		currentCave = open
		return open
	end
	if currentCave and currentCave.Parent then
		local last = caveSkipped[currentCave]
		if not (last and tick() - last < 30) then return currentCave end
	end
	currentCave = breakable
	return breakable
end

local function breakWeb(cave)
	local web = cave:FindFirstChild("Spider Web")
	local prompt = getPrompt(cave)
	local part = web and getMainPart(web)
	if not part then return end
	setStatus("Breaking web: " .. caveLabel(cave))
	stickTo(part, WEB_OFFSET)
	local t = tick()
	while CaveFarm and web.Parent and tick() - t < WEB_TIMEOUT do
		local hp = web:GetAttribute("HP")
		if (hp and hp <= 0) or (prompt and prompt.Enabled) then break end
		task.wait(0.1)
	end
	stopFollow()
	if web.Parent and not (prompt and prompt.Enabled) then caveSkipped[cave] = tick() end
end

local function enterCave(cave)
	local prompt, mouth = getPrompt(cave)
	if not (prompt and mouth) then return false end
	setStatus("Entering: " .. caveLabel(cave))
	stopFollow()

	for attempt = 1, 3 do
		local root = getRoot()
		if not root or not CaveFarm then return false end
		root.CFrame = CFrame.new(mouth.Position + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.4)

		if fireproximityprompt then
			pcall(fireproximityprompt, prompt)
		else
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.1)
			prompt:InputHoldEnd()
		end

		-- รอจอโหลด ("3 LIVES ...") จนขึ้น HUD ในถ้ำ
		local t = tick()
		while tick() - t < ENTER_WAIT do
			local r = getRoot()
			if (r and getRunAt(r)) or inCaveRun() or getLobbyStart() then
				lastInside = tick()
				return true
			end
			task.wait(0.25)
		end

		if getCaveCooldown() > 0 then return false end -- ติดคูลดาวน์ ไม่ใช่ถ้ำพัง
		setStatus(("Entering: %s (retry %d)"):format(caveLabel(cave), attempt))
	end

	caveSkipped[cave] = tick()
	currentCave = nil
	return false
end

--================ Cave: ลูปหลัก ================--
local function startCaveLoop()
	if caveRunning then return end
	caveRunning = true
	task.spawn(function()
		local emptySince
		while CaveFarm do
			local root = getRoot()
			if not root then
				setStatus("Waiting for character")
				task.wait(1)
				continue
			end

			-- 1) หน้าจอ VICTORY -> CLAIM ALL
			local claim = getClaimAll()
			if claim then
				setStatus("Victory: CLAIM ALL")
				pressButton(claim)
				lastInside = tick()
				task.wait(1.5)
				continue
			end

			-- 2) ล็อบบี้ (ถ้ามี) -> START
			local start = getLobbyStart()
			if start then
				lastInside = tick()
				setStatus("Lobby: START")
				pressButton(start)
				task.wait(2)
				continue
			end

			-- 3) อยู่ในถ้ำ (ดูจากตำแหน่ง หรือ HUD)
			local run = getRunAt(root)
			if run or inCaveRun() then
				lastInside = tick()
				local enemies = getCaveEnemies(root)
				if #enemies > 0 then
					emptySince = nil
					setStatus(("Cave: %d bugs left"):format(#enemies))
					attackCaveEnemy(nearestOf(root, enemies))
					continue
				end

				local door = getRunBreakable(run, root)
				if door then
					emptySince = nil
					setStatus("Cave: biting " .. tostring(door:GetAttribute("BarName") or door.Name))
					biteBreakable(door)
					continue
				end

				emptySince = emptySince or tick()
				if run and tick() - emptySince > 6 then
					setStatus("Cave: next room")
					advanceRoom(run, root)
					emptySince = nil
					task.wait(1.5)
				else
					setStatus("Cave: waiting for bugs")
					task.wait(0.3)
				end
				continue
			end
			emptySince = nil

			-- 4) เพิ่งออก / กำลังโหลด -> รอ ห้ามวาร์ปไปไหน
			if tick() - lastInside < INSIDE_GRACE then
				setStatus("Loading...")
				task.wait(0.5)
				continue
			end

			-- 5) คูลดาวน์เข้าถ้ำ -> รอ
			local cd = getCaveCooldown()
			if cd > 0 then
				setStatus(("Cooldown %d:%02d"):format(cd // 60, cd % 60))
				task.wait(1)
				continue
			end

			-- 6) เข้าถ้ำที่เปิด / ตีใยถ้ำที่ล็อกไว้
			local cave = pickCave()
			if not cave then
				setStatus("No cave available")
				task.wait(2)
				continue
			end
			local prompt = getPrompt(cave)
			if prompt and prompt.Enabled then
				enterCave(cave)
			else
				breakWeb(cave)
			end
		end
		stopFollow()
		setStatus("Auto Farm")
		caveRunning = false
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

function ToggleCaveFarm(state)
	if state == nil then state = not CaveFarm end
	CaveFarm = state
	if state then
		stopFollow()
		currentCave = nil
		startCaveLoop()
	end
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

local BUTTON_COUNT = 9
local BTN_H, BTN_GAP = 34, 6
local WIDTH = 220
local FULL_HEIGHT = 42 + BUTTON_COUNT * (BTN_H + BTN_GAP)

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, WIDTH, 0, FULL_HEIGHT)
main.Position = UDim2.new(0, 20, 0, 60)
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
titleText.Size = UDim2.new(1, -45, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Auto Farm"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 12
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextTruncate = Enum.TextTruncate.AtEnd
titleText.Parent = title
statusLabel = titleText

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
makeToggleButton("Cave Farm",  ToggleCaveFarm,  CaveFarm)

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
