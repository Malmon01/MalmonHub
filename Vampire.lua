--// Auto Farm: Orbs / Mob / Corpse / Egg + Cave Farm
--// Smooth Follow + Status + Floating UI (ย่อได้ / ลากได้)
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
local CAVE_MOB_TIMEOUT  = 30     -- ตีตัวเดียวนานสุด
local DODGE_DIST        = 18     -- ถอยห่างตอนหลบ
local DODGE_TIME        = 1.2    -- หลบนานกี่วินาที
local WEB_OFFSET        = 4      -- ระยะยืนตีใย
local WEB_TIMEOUT       = 60     -- ตีใยนานสุด
local RUN_RADIUS        = 2500   -- ห่างจาก Origin ของถ้ำไม่เกินนี้ = อยู่ในถ้ำ
local INSIDE_GRACE      = 8      -- เพิ่งอยู่ในถ้ำไม่เกินกี่วิ = ยังถือว่าอยู่ข้างใน
local PREFER_HIGH_TIER  = true   -- เลือกถ้ำ Tier สูงก่อน
local DEBUG_ATTR        = false  -- true = พิมพ์ Attribute มอนที่เปลี่ยน
local WINDUP_ATTRS = {
	WindUp = true, Winding = true, Attacking = true, Charging = true,
	Telegraph = true, State = true, AttackTick = true,
}

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
local roomCenters     = setmetatable({}, { __mode = "k" })
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

--================ เกาะติดเป้าหมายแบบนิ่ง ================--
local followPart, followOffset = nil, 0

RunService.Heartbeat:Connect(function()
	if not followPart or not followPart.Parent then return end
	local root = getRoot()
	if not root then return end
	local target = followPart.Position
	local pos = target + Vector3.new(0, 0, followOffset)
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

-- เลือดลด = หลบ (ใช้ตอน Cave Farm)
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

--================ Cave ================--
local lastInside = 0
local currentCave = nil

local function pressButton(btn)
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

local function getCaveGui()
	local pg = player:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild("Cave")
end

local function getLobbyStart()
	local gui = getCaveGui()
	local lobby = gui and gui:FindFirstChild("CaveLobby")
	local start = lobby and lobby:FindFirstChild("Start")
	if start and gui.Enabled and lobby.Visible and start.Visible then return start end
end

-- หน้าจอถ้ำของเกมยังเปิดอยู่ไหม (ล็อบบี้ / HUD ในถ้ำ)
local function caveGuiActive()
	local gui = getCaveGui()
	if not (gui and gui.Enabled) then return false end
	for _, c in ipairs(gui:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible then return true end
	end
	return false
end

local function getMyLevel()
	local v = player:GetAttribute("Level") or player:GetAttribute("Lv")
	if typeof(v) == "number" then return v end
	local ls = player:FindFirstChild("leaderstats")
	local s = ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("Lv"))
	if s then return tonumber(s.Value) or math.huge end
	return math.huge
end

-- หาถ้ำที่เราอยู่ (ใกล้ Origin ที่สุด)
local function getMyRun(root)
	local folder = workspace:FindFirstChild("CaveRuns")
	if not folder then return nil end
	local best, bestDist, bestId
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") then
			local origin = m:GetAttribute("Origin")
			if typeof(origin) == "Vector3" then
				local d = (origin - root.Position).Magnitude
				if d < RUN_RADIUS and d < (bestDist or math.huge) then
					best, bestDist, bestId = m, d, m.Name:match("^CaveRun_(.+)$")
				end
			end
		end
	end
	return best, bestId
end

local function getCaveEnemies(id)
	local list = {}
	local runs = workspace:FindFirstChild("CaveRuns")
	local folder = runs and runs:FindFirstChild("Enemies_" .. tostring(id))
	if not folder then return list end
	for _, e in ipairs(folder:GetChildren()) do
		local hum = e:FindFirstChildOfClass("Humanoid")
		local hrp = e:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 then table.insert(list, e) end
	end
	return list
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

	local conn = e.AttributeChanged:Connect(function(name)
		if DEBUG_ATTR then print("[Attr]", e.Name, name, e:GetAttribute(name)) end
		if WINDUP_ATTRS[name] then dodgeUntil = tick() + DODGE_TIME end
	end)

	local t = tick()
	while CaveFarm and e.Parent and hum.Health > 0 and part.Parent and tick() - t < CAVE_MOB_TIMEOUT do
		lastInside = tick()
		if tick() < dodgeUntil then
			stickTo(part, DODGE_DIST)
		else
			stickTo(part, CAVE_OFFSET)
		end
		task.wait(0.05)
	end

	conn:Disconnect()
	stopFollow()
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

local function caveLabel(cave)
	return tostring(cave:GetAttribute("CaveName") or cave.Name)
end

local function getPrompt(cave)
	local mouth = cave:FindFirstChild("Mouth")
	return mouth and mouth:FindFirstChild("CavePrompt"), mouth
end

local function chooseCave()
	local caves = workspace:FindFirstChild("Caves")
	if not caves then return nil end
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
	return open or breakable
end

-- ล็อกถ้ำเดียวจนกว่าจะเสร็จหรือพัง
local function pickCave()
	if currentCave and currentCave.Parent then
		local last = caveSkipped[currentCave]
		if not (last and tick() - last < 30) then return currentCave end
	end
	currentCave = chooseCave()
	return currentCave
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
	if web.Parent and not (prompt and prompt.Enabled) then
		caveSkipped[cave] = tick() -- ตีไม่แตก ข้ามไปก่อน
	end
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

		local t = tick()
		while tick() - t < 4 do
			local r = getRoot()
			if getLobbyStart() or (r and getMyRun(r)) then
				lastInside = tick()
				return true
			end
			task.wait(0.2)
		end
		setStatus(("Entering: %s (retry %d)"):format(caveLabel(cave), attempt))
	end

	caveSkipped[cave] = tick()
	currentCave = nil
	return false
end

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

			-- 1) หน้าจอเริ่ม -> กด START
			local start = getLobbyStart()
			if start then
				lastInside = tick()
				setStatus("Lobby: pressing START")
				pressButton(start)
				task.wait(2)
				continue
			end

			-- 2) อยู่ในถ้ำ -> ตีมอน / ไปห้องถัดไป
			local run, id = getMyRun(root)
			if run then
				lastInside = tick()
				local enemies = getCaveEnemies(id)
				if #enemies > 0 then
					emptySince = nil
					setStatus(("Cave %s: %d enemies"):format(tostring(id), #enemies))
					attackCaveEnemy(nearestOf(root, enemies))
				else
					emptySince = emptySince or tick()
					if tick() - emptySince > 1.5 then
						if advanceRoom(run, root) then
							setStatus("Next room")
							emptySince = nil
							task.wait(1.5)
						else
							setStatus("Last room - waiting")
							task.wait(1)
						end
					else
						task.wait(0.3)
					end
				end
				continue
			end

			-- 3) เพิ่งออกจากถ้ำ / หน้าจอถ้ำยังเปิด -> รอ ห้ามวาร์ปออก
			local since = tick() - lastInside
			if since < INSIDE_GRACE or (since < 120 and caveGuiActive()) then
				setStatus("Waiting in cave...")
				task.wait(0.5)
				continue
			end

			-- 4) อยู่ข้างนอก -> ถ้ำเดิมที่ล็อกไว้
			emptySince = nil
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
