-- ===== Orb Teleport + Auto Mutate (รวมไฟล์) =====
-- ปุ่ม TP ORB = วาร์ปเก็บ Orb | ปุ่ม AUTO MUTATE = กด Roll + Skip อัตโนมัติ

-- ================= ส่วนที่ 1: ORB TELEPORT =================
do
	local Players = game:GetService("Players")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local GuiService = game:GetService("GuiService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local playerGui = player:WaitForChild("PlayerGui")
	local orbsFolder = Workspace:WaitForChild("ClientOrbs")

	-- ================= ตั้งค่า =================
	local DEFAULT_ENABLED = false
	local TP_DELAY = 1.5            -- เวลาขั้นต่ำระหว่างการวาร์ปไป Orb ใหม่ (1.5 - 2.2)
	local MAX_SCAN_DISTANCE = 220   -- ระยะค้นหา Orb (Studs)
	local HEIGHT_OFFSET = 0.0       -- ความสูงเหนือ Orb (0 = ทับตรงกลางเลย เก็บติดง่ายกว่า)
	local MAX_ATTEMPTS = 2          -- วาร์ปไป Orb เดิมได้กี่รอบ ถ้ายังไม่หายถือว่าเก็บไม่ได้
	local BLACKLIST_TIME = 20       -- ข้าม Orb ที่เก็บไม่ได้เป็นเวลากี่วินาที
	local NUDGE_RADIUS = 1.5        -- ขยับรอบ Orb เล็กน้อยเพื่อให้ Touch ทำงาน
	local MAX_GROUND_GAP = 15       -- Orb ต้องมีพื้นอยู่ใต้ไม่เกินกี่ studs (กันวาร์ปขึ้นฟ้า)
	local ORB_MOVED_DIST = 4        -- Orb ขยับออกจากจุดเดิมเกินนี้ = ถูกเก็บแล้ว (กำลังเล่นแอนิเมชันลอยขึ้น)
	local AUTO_REBIRTH_ENABLED = true
	local REBIRTH_COOLDOWN = 2.0
	-- ==========================================

	local isEnabled = (DEFAULT_ENABLED == true)
	local runToken = 0
	local lastRebirthTime = 0

	-- เก็บสถานะของแต่ละ Orb (weak key = Orb ถูกลบแล้วข้อมูลหายเอง)
	local orbAttempts = setmetatable({}, { __mode = "k" })
	local orbBlacklistUntil = setmetatable({}, { __mode = "k" })
	local orbScoreCache = setmetatable({}, { __mode = "k" })

	local oldGui = playerGui:FindFirstChild("OrbTpGui")
	if oldGui then
		oldGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OrbTpGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9999
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Name = "ToggleTpButton"
	btn.Size = UDim2.new(0, 176, 0, 40)
	btn.Position = UDim2.new(0.5, -88, 0, 16)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BorderSizePixel = 0
	btn.ZIndex = 999
	btn.Parent = screenGui

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(15, 15, 15)
	stroke.Thickness = 2

	local function getCharRoot()
		local char = player.Character
		if not char then return nil end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then return nil end
		return char:FindFirstChild("HumanoidRootPart")
			or char.PrimaryPart
			or char:FindFirstChildWhichIsA("BasePart", true)
	end

	local function setState(state)
		isEnabled = (state == true)
		runToken += 1

		if isEnabled then
			btn.Text = "TP ORB: ON"
			btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
		else
			btn.Text = "TP ORB: OFF"
			btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		end
	end

	setState(isEnabled)

	btn.MouseButton1Click:Connect(function()
		setState(not isEnabled)
	end)

	local function isGuiReallyVisible(guiObj)
		local current = guiObj
		while current and current ~= playerGui do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			if current:IsA("ScreenGui") and not current.Enabled then
				return false
			end
			current = current.Parent
		end
		return true
	end

	local function clickGuiCenter(guiObj)
		local absPos = guiObj.AbsolutePosition
		local absSize = guiObj.AbsoluteSize
		if absSize.X <= 1 or absSize.Y <= 1 then return false end

		local inset = GuiService:GetGuiInset()
		local x = absPos.X + (absSize.X * 0.5) + inset.X
		local y = absPos.Y + (absSize.Y * 0.5) + inset.Y

		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end)
		return true
	end

	local function tryAutoRebirth()
		if not AUTO_REBIRTH_ENABLED or not isEnabled then return end
		if os.clock() - lastRebirthTime < REBIRTH_COOLDOWN then return end

		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui ~= screenGui and gui:IsA("ScreenGui") and gui.Enabled then
				for _, desc in ipairs(gui:GetDescendants()) do
					if desc:IsA("TextLabel") or desc:IsA("TextButton") then
						local upperText = string.upper(desc.Text or "")
						if string.find(upperText, "REBIRTH", 1, true) and isGuiReallyVisible(desc) then
							local clickable = nil
							if desc:IsA("GuiButton") and desc.Active then
								clickable = desc
							elseif desc.Parent and desc.Parent:IsA("GuiButton") and desc.Parent.Active then
								clickable = desc.Parent
							end

							if clickable and clickable.AbsoluteSize.X > 20 then
								lastRebirthTime = os.clock()
								clickGuiCenter(clickable)
								pcall(function()
									VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
									task.wait(0.05)
									VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
								end)
								return
							end
						end
					end
				end
			end
		end
	end

	local function getOrbPart(obj)
		if not obj or not obj.Parent then return nil end
		if obj:IsA("BasePart") then return obj end
		if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
		return obj:FindFirstChildWhichIsA("BasePart", true)
	end

	local function getOrbPosition(obj)
		if not obj or not obj.Parent then return nil end
		if obj:IsA("Model") then
			return obj:GetPivot().Position
		end
		local part = getOrbPart(obj)
		return part and part.Position or nil
	end

	local function isOrbAlive(obj)
		return obj ~= nil and obj.Parent ~= nil and obj:IsDescendantOf(orbsFolder)
	end

	local function parseAbbreviatedNumber(raw)
		if type(raw) == "number" then return raw end
		if type(raw) ~= "string" then return nil end
		local cleaned = string.gsub(raw, ",", "")
		local numPart, suffix = string.match(cleaned, "^%s*([%d%.]+)%s*([KkMmBbTt]?)%s*$")
		if not numPart then return nil end
		local n = tonumber(numPart)
		if not n then return nil end
		local mult = 1
		local s = string.upper(suffix or "")
		if s == "K" then mult = 1e3
		elseif s == "M" then mult = 1e6
		elseif s == "B" then mult = 1e9
		elseif s == "T" then mult = 1e12
		end
		return n * mult
	end

	local function isExpKeyword(nameStr)
		local lower = string.lower(nameStr or "")
		return string.find(lower, "exp", 1, true)
			or string.find(lower, "xp", 1, true)
			or string.find(lower, "val", 1, true)
			or string.find(lower, "amt", 1, true)
			or string.find(lower, "amount", 1, true)
			or string.find(lower, "power", 1, true)
			or string.find(lower, "reward", 1, true)
			or string.find(lower, "size", 1, true)
			or string.find(lower, "tier", 1, true)
	end

	local function computeOrbExpScore(obj)
		local bestScore = 0
		local foundExplicitValue = false

		local function consider(v)
			local parsed = parseAbbreviatedNumber(v)
			if parsed and parsed > 0 then
				foundExplicitValue = true
				if parsed > bestScore then bestScore = parsed end
			end
		end

		local function scanAttributes(inst)
			for attrName, attrVal in pairs(inst:GetAttributes()) do
				if isExpKeyword(attrName) then consider(attrVal) end
			end
		end

		scanAttributes(obj)
		for _, desc in ipairs(obj:GetDescendants()) do
			scanAttributes(desc)
			if (desc:IsA("NumberValue") or desc:IsA("IntValue") or desc:IsA("StringValue"))
				and isExpKeyword(desc.Name) then
				consider(desc.Value)
			end
		end

		if foundExplicitValue then return bestScore end

		if obj:IsA("Model") then
			local _, size = obj:GetBoundingBox()
			return size.X * size.Y * size.Z
		end
		local part = getOrbPart(obj)
		if part then
			local s = part.Size
			return s.X * s.Y * s.Z
		end
		return 1
	end

	-- คำนวณคะแนนครั้งเดียวต่อ Orb (ลดอาการกระตุก)
	local function getOrbExpScore(obj)
		local cached = orbScoreCache[obj]
		if cached then return cached end
		local ok, score = pcall(computeOrbExpScore, obj)
		score = ok and score or 1
		orbScoreCache[obj] = score
		return score
	end

	local function isBlacklisted(obj)
		local untilT = orbBlacklistUntil[obj]
		if untilT and os.clock() < untilT then return true end
		if untilT then
			orbBlacklistUntil[obj] = nil
			orbAttempts[obj] = nil
		end
		return false
	end

	-- เช็คว่ามีพื้นอยู่ใต้ Orb (Orb ที่ลอยกลางฟ้า/กำลังบินขึ้นหลังเก็บ จะถูกข้าม)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.IgnoreWater = false

	local function hasGroundBelow(pos)
		local ignore = { orbsFolder }
		if player.Character then table.insert(ignore, player.Character) end
		groundParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -(MAX_GROUND_GAP + 1), 0), groundParams)
		return hit ~= nil
	end

	local function isOrbVisible(obj)
		local part = getOrbPart(obj)
		if not part then return false end
		return part.Transparency < 0.95 or part:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
			or part:FindFirstChildWhichIsA("BillboardGui", true) ~= nil
	end

	local function findBestOrb(currentPos)
		local bestOrb, bestPos = nil, nil
		local bestScore = -math.huge
		local bestTieDist = math.huge

		for _, child in ipairs(orbsFolder:GetChildren()) do
			if not isBlacklisted(child) then
				local orbPos = getOrbPosition(child)
				if orbPos then
					local dist = (orbPos - currentPos).Magnitude
					if dist <= MAX_SCAN_DISTANCE and isOrbVisible(child) and hasGroundBelow(orbPos) then
						local score = getOrbExpScore(child)
						if (score > bestScore) or (math.abs(score - bestScore) <= 1e-6 and dist < bestTieDist) then
							bestScore = score
							bestTieDist = dist
							bestOrb = child
							bestPos = orbPos
						end
					end
				end
			end
		end

		return bestOrb, bestPos
	end

	local function setRootCFrame(root, pos)
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
		end)
	end

	-- พยายามให้เกิด Touch กับ Orb (บาง executor มี firetouchinterest)
	local function tryTouch(root, orb)
		local part = getOrbPart(orb)
		if not part then return end
		local fti = (typeof(firetouchinterest) == "function") and firetouchinterest or nil
		if fti then
			pcall(function()
				fti(root, part, 0)
				task.wait()
				fti(root, part, 1)
			end)
		end
	end

	-- รอจน Orb หาย หรือหมดเวลา (ขยับรอบ ๆ Orb ระหว่างรอ)
	-- ใช้ตำแหน่งเริ่มต้นของ Orb เป็นจุดยึด ไม่วิ่งตาม Orb
	-- (เดิมวิ่งตาม Orb ที่กำลังลอยขึ้นหลังเก็บ ทำให้ตัวละครถูกลากขึ้นฟ้า)
	local function waitForCollect(root, orb, anchorPos, seconds, token)
		local start = os.clock()
		local step = 0
		while os.clock() - start < seconds do
			if not isEnabled or token ~= runToken then return false end
			if not isOrbAlive(orb) then return true end
			if not root.Parent then return false end

			local orbPos = getOrbPosition(orb)
			if not orbPos or (orbPos - anchorPos).Magnitude > ORB_MOVED_DIST then
				return true -- Orb ถูกเก็บแล้วและกำลังเล่นแอนิเมชัน
			end

			step += 1
			local angle = step * (math.pi / 2)
			local offset = (step % 2 == 0) and Vector3.zero
				or Vector3.new(math.cos(angle) * NUDGE_RADIUS, 0, math.sin(angle) * NUDGE_RADIUS)
			setRootCFrame(root, anchorPos + Vector3.new(0, HEIGHT_OFFSET, 0) + offset)
			tryTouch(root, orb)
			task.wait(0.15)
		end
		local orbPos = getOrbPosition(orb)
		return (not isOrbAlive(orb)) or (orbPos ~= nil and (orbPos - anchorPos).Magnitude > ORB_MOVED_DIST)
	end

	local function waitInterruptible(seconds, token)
		local elapsed = 0
		while elapsed < seconds do
			if not isEnabled or token ~= runToken then return false end
			local step = math.min(0.1, seconds - elapsed)
			task.wait(step)
			elapsed += step
		end
		return isEnabled and (token == runToken)
	end

	-- ล้างข้อมูลเมื่อเกิดใหม่
	player.CharacterAdded:Connect(function()
		table.clear(orbAttempts)
		table.clear(orbBlacklistUntil)
	end)

	task.spawn(function()
		while true do
			if isEnabled then
				pcall(tryAutoRebirth)
			end
			task.wait(0.5)
		end
	end)

	task.spawn(function()
		while true do
			if isEnabled then
				local token = runToken
				local root = getCharRoot()
				local ok, err = pcall(function()
					if not (root and root:IsA("BasePart")) then
						task.wait(0.5)
						return
					end

					local orb, orbPos = findBestOrb(root.Position)
					if not orb then
						waitInterruptible(0.5, token)
						return
					end

					local tpStart = os.clock()
					setRootCFrame(root, orbPos + Vector3.new(0, HEIGHT_OFFSET, 0))
					local collected = waitForCollect(root, orb, orbPos, TP_DELAY, token)
					local remaining = TP_DELAY - (os.clock() - tpStart)

					if collected then
						-- Orb ที่เก็บแล้วแต่ยังค้างใน folder (กำลังลอยขึ้น) ห้ามเลือกซ้ำ
						orbBlacklistUntil[orb] = os.clock() + BLACKLIST_TIME
					end

					if not collected and isOrbAlive(orb) then
						-- เก็บไม่ได้ → นับครั้ง ถ้าเกินกำหนดให้ข้ามไปชั่วคราว
						orbAttempts[orb] = (orbAttempts[orb] or 0) + 1
						if orbAttempts[orb] >= MAX_ATTEMPTS then
							orbBlacklistUntil[orb] = os.clock() + BLACKLIST_TIME
						end
					else
						-- เก็บได้แล้ว แต่ยังเคารพเวลาขั้นต่ำ ไม่ให้วาร์ปถี่เกิน
						if remaining > 0 then
							waitInterruptible(remaining, token)
						end
					end
				end)
				if not ok then
					warn("[OrbTp] error:", err)
					task.wait(0.5)
				end
			else
				task.wait(0.2)
			end
		end
	end)
end

-- ================= ส่วนที่ 2: AUTO MUTATE =================
do
	-- Auto Roll + Skip สำหรับหน้า MUTATE
	-- วิธีใช้: เปิดหน้า Mutate ค้างไว้ แล้วกดปุ่ม "AUTO MUTATE: ON"
	local Players = game:GetService("Players")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local GuiService = game:GetService("GuiService")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local playerGui = player:WaitForChild("PlayerGui")

	-- ================= ตั้งค่า =================
	local LOOP_DELAY = 0.25         -- ความถี่การเช็ค (วินาที)
	local ROLL_COOLDOWN = 0.6       -- เว้นระยะหลังกด ROLL
	local SKIP_COOLDOWN = 0.3       -- เว้นระยะหลังกด SKIP
	local NO_RESPONSE_LIMIT = 3     -- กด ROLL แล้วไม่หมุนติดกันกี่ครั้ง = Token หมด → ปิดเอง
	-- ==========================================

	local isEnabled = false
	local lastRollTime, lastSkipTime = 0, 0
	local noResponseCount = 0
	local waitingForRoll = false

	local old = playerGui:FindFirstChild("AutoMutateGui")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AutoMutateGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9999
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 176, 0, 40)
	btn.Position = UDim2.new(0.5, -88, 0, 62) -- อยู่ใต้ปุ่ม TP ORB
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BorderSizePixel = 0
	btn.ZIndex = 999
	btn.Parent = screenGui
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(15, 15, 15)
	stroke.Thickness = 2

	local function setState(state, reason)
		isEnabled = state
		noResponseCount = 0
		waitingForRoll = false
		if isEnabled then
			btn.Text = "AUTO MUTATE: ON"
			btn.BackgroundColor3 = Color3.fromRGB(142, 68, 173)
		else
			btn.Text = reason and ("AUTO MUTATE: OFF (" .. reason .. ")") or "AUTO MUTATE: OFF"
			btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		end
	end
	setState(false)
	btn.MouseButton1Click:Connect(function() setState(not isEnabled) end)

	-- ---------- helpers ----------
	local function isReallyVisible(gui)
		local cur = gui
		while cur and cur ~= playerGui do
			if cur:IsA("GuiObject") and not cur.Visible then return false end
			if cur:IsA("ScreenGui") and not cur.Enabled then return false end
			cur = cur.Parent
		end
		return gui.AbsoluteSize.X > 5 and gui.AbsoluteSize.Y > 5
	end

	local function textOf(obj)
		local ok, t = pcall(function() return obj.ContentText end)
		if not ok or not t or t == "" then t = obj.Text or "" end
		return string.upper(t)
	end

	-- รวมข้อความทั้งหมดในปุ่ม (ปุ่มเกมนี้มี "ROLL" กับ "1 TOKEN" เป็น label แยกกัน)
	local function buttonText(button)
		local parts = {}
		if button:IsA("TextButton") then table.insert(parts, textOf(button)) end
		for _, d in ipairs(button:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
				table.insert(parts, textOf(d))
			end
		end
		return table.concat(parts, " ")
	end

	local function clickButton(button)
		-- วิธีที่ 1: ยิง event ตรง (เสถียรกว่าบนมือถือ/emulator)
		local fired = false
		if typeof(getconnections) == "function" then
			for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }) do
				local ok, conns = pcall(getconnections, button[sigName])
				if ok and conns then
					for _, c in ipairs(conns) do
						local fok = pcall(function()
							if c.Fire then c:Fire() elseif c.Function then c.Function() end
						end)
						fired = fired or fok
					end
				end
				if fired then return true end
			end
		end
		-- วิธีที่ 2: คลิกจำลองตรงกลางปุ่ม
		local pos, size = button.AbsolutePosition, button.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		local x = pos.X + size.X / 2 + inset.X
		local y = pos.Y + size.Y / 2 + inset.Y
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end)
		return true
	end

	-- หาปุ่ม SKIP / ROLL (1 Token) และสถานะกำลังหมุน
	local function scanMutate()
		local skipBtn, rollBtn, rolling = nil, nil, false
		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui ~= screenGui and gui:IsA("ScreenGui") and gui.Enabled then
				for _, d in ipairs(gui:GetDescendants()) do
					if d:IsA("GuiButton") and isReallyVisible(d) then
						local t = buttonText(d)
						if string.find(t, "SKIP", 1, true) then
							skipBtn = d
						elseif string.find(t, "ROLL", 1, true)
							and string.find(t, "1 TOKEN", 1, true)
							and not string.find(t, "X5", 1, true)
							and not string.find(t, "5 TOKEN", 1, true) then
							rollBtn = d
						end
						if string.find(t, "ROLLING", 1, true) then
							rolling = true
						end
					end
				end
			end
		end
		return skipBtn, rollBtn, rolling
	end

	-- ---------- main loop ----------
	task.spawn(function()
		while true do
			if isEnabled then
				local ok, err = pcall(function()
					local skipBtn, rollBtn, rolling = scanMutate()
					local now = os.clock()

					-- 1) กำลังหมุน → กด SKIP
					if skipBtn and now - lastSkipTime >= SKIP_COOLDOWN then
						lastSkipTime = now
						waitingForRoll = false
						noResponseCount = 0
						clickButton(skipBtn)
						return
					end

					if rolling then
						waitingForRoll = false
						noResponseCount = 0
						return
					end

					-- 2) ว่างอยู่ → กด ROLL
					if rollBtn and now - lastRollTime >= ROLL_COOLDOWN then
						if waitingForRoll then
							-- กดรอบที่แล้วไม่มีอะไรเกิดขึ้น
							noResponseCount += 1
							if noResponseCount >= NO_RESPONSE_LIMIT then
								setState(false, "หมด Token?")
								return
							end
						end
						lastRollTime = now
						waitingForRoll = true
						clickButton(rollBtn)
					end
				end)
				if not ok then warn("[AutoMutate] error:", err) end
			end
			task.wait(LOOP_DELAY)
		end
	end)
end
