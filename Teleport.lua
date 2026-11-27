-- ===== Orb Tween + Auto Mutate x5 (รวมไฟล์) =====
-- ปุ่ม TP ORB = Tween เก็บ Orb ที่ใกล้สุด (หยุดตอนเป็นดักแด้) + Auto Rebirth | ปุ่ม AUTO MUTATE x5 = สุ่ม x5 + Skip

-- ================= ส่วนที่ 1: ORB TWEEN =================
do
	local Players = game:GetService("Players")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local GuiService = game:GetService("GuiService")
	local Workspace = game:GetService("Workspace")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local playerGui = player:WaitForChild("PlayerGui")
	local orbsFolder = Workspace:WaitForChild("ClientOrbs")

	-- ================= ตั้งค่า =================
	local DEFAULT_ENABLED = false
	local TWEEN_SPEED = 130         -- ความเร็ว Tween (studs/วินาที) ยิ่งมากยิ่งไว แต่เสี่ยงโดนเตะ
	local TWEEN_MIN_TIME = 0.08     -- เวลา Tween ขั้นต่ำ
	local COLLECT_WAIT = 0.5        -- รอเก็บ Orb หลังไปถึงนานสุดกี่วินาที
	local MAX_SCAN_DISTANCE = 220   -- ระยะค้นหา Orb (Studs)
	local HEIGHT_OFFSET = 0.0       -- ความสูงเหนือ Orb (0 = ทับตรงกลางเลย เก็บติดง่ายกว่า)
	local MAX_ATTEMPTS = 2          -- วาร์ปไป Orb เดิมได้กี่รอบ ถ้ายังไม่หายถือว่าเก็บไม่ได้
	local BLACKLIST_TIME = 20       -- ข้าม Orb ที่เก็บไม่ได้เป็นเวลากี่วินาที
	local NUDGE_RADIUS = 1.5        -- ขยับรอบ Orb เล็กน้อยเพื่อให้ Touch ทำงาน
	local MAX_GROUND_GAP = 15       -- Orb ต้องมีพื้นอยู่ใต้ไม่เกินกี่ studs (กันวาร์ปขึ้นฟ้า)
	local ORB_MOVED_DIST = 4        -- Orb ขยับออกจากจุดเดิมเกินนี้ = ถูกเก็บแล้ว (กำลังเล่นแอนิเมชันลอยขึ้น)
	local AUTO_REBIRTH_ENABLED = true
	local REBIRTH_COOLDOWN = 2.0
	local PAUSE_WHEN_COCOON = true
	local COCOON_RESUME_DELAY = 1.5
	-- ==========================================

	local isEnabled = (DEFAULT_ENABLED == true)
	local runToken = 0
	local lastRebirthTime = 0
	local lastCocoonTime = -math.huge
	local cocoonGuiScanTime = -math.huge
	local cocoonGuiTextDetected = false

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

	local function isCocoon()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local detected = false

		if char and hum and (hum.WalkSpeed <= 0.5 or hum.PlatformStand) then detected = true end
		if root and root.Anchored then detected = true end

		local nameTokens = { "cocoon", "pupa", "chrysalis", "evolv", "molt" }
		local function hasCocoonAttribute(inst)
			if not inst then return false end
			for attrName, value in pairs(inst:GetAttributes()) do
				local lowerName = string.lower(attrName)
				local matchesName = false
				for _, token in ipairs(nameTokens) do
					if string.find(lowerName, token, 1, true) then matchesName = true break end
				end
				if matchesName and (value == true or (type(value) == "string" and value ~= "")
					or (type(value) == "number" and value > 0)) then return true end
			end
			return false
		end
		if hasCocoonAttribute(char) or hasCocoonAttribute(hum) or hasCocoonAttribute(root)
			or hasCocoonAttribute(player) then detected = true end

		if char then
			for _, desc in ipairs(char:GetDescendants()) do
				local lowerName = string.lower(desc.Name)
				if string.find(lowerName, "cocoon", 1, true) or string.find(lowerName, "pupa", 1, true)
					or string.find(lowerName, "chrysalis", 1, true) then
					detected = true
					break
				end
			end
		end

		local now = os.clock()
		if now - cocoonGuiScanTime >= 1 then
			cocoonGuiScanTime = now
			cocoonGuiTextDetected = false
			for _, desc in ipairs(playerGui:GetDescendants()) do
				if desc:IsA("TextLabel") and isGuiReallyVisible(desc) then
					local current = desc
					local skip = false
					while current and current ~= playerGui do
						if current.Name == "OrbTpGui" or current.Name == "AutoMutateGui" then skip = true break end
						current = current.Parent
					end
					if not skip then
						local upperText = string.upper(desc.Text or "")
						if string.find(upperText, "COCOON", 1, true) or string.find(upperText, "PUPA", 1, true)
							or string.find(upperText, "EVOLVING", 1, true) then
							cocoonGuiTextDetected = true
							break
						end
					end
				end
			end
		end
		if cocoonGuiTextDetected then detected = true end
		if detected then lastCocoonTime = now end
		return PAUSE_WHEN_COCOON and (detected or now - lastCocoonTime < COCOON_RESUME_DELAY)
	end

	local function waitWhileCocoon(token)
		while isCocoon() do
			if not isEnabled or token ~= runToken then return false end
			task.wait(0.3)
		end
		return isEnabled and token == runToken
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
		if not AUTO_REBIRTH_ENABLED or not isEnabled or isCocoon() then return end
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
								-- บอก Auto Mutate ให้หยุดสุ่มชั่วคราว แล้วรอให้หน้าผลสุ่มปิดก่อนกด
								local Shared = (typeof(getgenv) == "function" and getgenv()) or _G
								Shared.AntMutatePauseUntil = math.max(Shared.AntMutatePauseUntil or 0, os.clock() + 3)
								task.wait(0.3)
								-- ยิง event ตรง ๆ ก่อน (ไม่โดนหน้าต่างอื่นบัง) ถ้าไม่ได้ค่อยคลิกจำลอง
								local fired = false
								if typeof(getconnections) == "function" then
									for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
										local ok, conns = pcall(getconnections, clickable[sigName])
										if ok and conns then
											for _, c in ipairs(conns) do
												if pcall(function()
													if c.Fire then c:Fire() elseif c.Function then task.spawn(c.Function) end
												end) then fired = true end
											end
										end
										if fired then break end
									end
								end
								if not fired then
									clickGuiCenter(clickable)
								end
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
		local bestDist = math.huge

		for _, child in ipairs(orbsFolder:GetChildren()) do
			if not isBlacklisted(child) then
				local orbPos = getOrbPosition(child)
				if orbPos then
					local dist = (orbPos - currentPos).Magnitude
					if dist <= MAX_SCAN_DISTANCE and dist < bestDist
						and isOrbVisible(child) and hasGroundBelow(orbPos) then
						bestDist = dist
						bestOrb = child
						bestPos = orbPos
					end
				end
			end
		end

		return bestOrb, bestPos
	end

	local function tweenToOrb(root, orb, startPos, token)
		local targetPos = startPos + Vector3.new(0, HEIGHT_OFFSET, 0)
		local distance = (targetPos - root.Position).Magnitude
		local duration = math.max(TWEEN_MIN_TIME, distance / TWEEN_SPEED)
		local rotation = root.CFrame - root.CFrame.Position
		local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(targetPos) * rotation,
		})
		local velocityConnection = RunService.Heartbeat:Connect(function()
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end)

		tween:Play()
		local cancelled = false
		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not isEnabled or token ~= runToken or not isOrbAlive(orb) or isCocoon() then
				cancelled = true
				break
			end
			local orbPos = getOrbPosition(orb)
			if not orbPos or (orbPos - startPos).Magnitude > ORB_MOVED_DIST then
				cancelled = true
				break
			end
			task.wait()
		end

		if cancelled then tween:Cancel() end
		velocityConnection:Disconnect()
		return not cancelled and isEnabled and token == runToken
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
			if isCocoon() then
				task.wait(0.3)
				continue
			end

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
				if not waitWhileCocoon(token) then task.wait(0.3) continue end
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

					local arrived = tweenToOrb(root, orb, orbPos, token)
					if not arrived then
						-- Orb ถูกเก็บ/ลอยหนีระหว่างทาง → ห้ามเลือกซ้ำ
						orbBlacklistUntil[orb] = os.clock() + BLACKLIST_TIME
						task.wait()
						return
					end
					local collected = waitForCollect(root, orb, orbPos, COLLECT_WAIT, token)

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
					end
					task.wait()
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

-- ================= ส่วนที่ 2: AUTO MUTATE x5 =================
do
	-- Auto Roll x5 + Skip สำหรับ MUTATE (ไม่ต้องเปิดหน้าต่าง, ทำจนกว่าจะกดปิดเอง)
	-- โครงสร้างจาก Dex:
	--   PlayerGui.AntMutate.Root.Window.Panel.Body.Right.Buttons.Roll5Ho... -> ปุ่ม ROLL x5
	--   PlayerGui.AntMutate.Root.Window.Panel.Body.Right.Info.SkipHo...     -> ปุ่ม SKIP
	local Players = game:GetService("Players")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local playerGui = player:WaitForChild("PlayerGui")

	-- ================= ตั้งค่า =================
	local ROLL_DELAY = 0.15         -- เวลาระหว่างการกด Roll x5 แต่ละครั้ง (ยิ่งน้อยยิ่งไว)
	local SKIP_SPAM = 3             -- กด Skip ซ้ำกี่ครั้งหลัง Roll
	local SKIP_GAP = 0.03           -- ระยะห่างระหว่างการกด Skip
	local ROLL_BUTTON = "Roll5"     -- เปลี่ยนเป็น "Roll1" ถ้าอยากสุ่มทีละ 1
	local PAUSE_FOR_REBIRTH = true  -- หยุดสุ่มชั่วคราวเมื่อปุ่ม REBIRTH ขึ้น (ให้รีได้ทันที)
	local REBIRTH_PAUSE_AFTER = 2.5 -- หยุดต่ออีกกี่วินาทีหลังปุ่ม REBIRTH หายไป
	-- ==========================================

	local isEnabled = false
	local Shared = (typeof(getgenv) == "function" and getgenv()) or _G
	Shared.AntMutatePauseUntil = Shared.AntMutatePauseUntil or 0

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

	local function setState(state)
		isEnabled = state
		if isEnabled then
			btn.Text = "AUTO MUTATE x5: ON"
			btn.BackgroundColor3 = Color3.fromRGB(142, 68, 173)
		else
			btn.Text = "AUTO MUTATE x5: OFF"
			btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		end
	end
	setState(false)
	btn.MouseButton1Click:Connect(function() setState(not isEnabled) end)

	-- ---------- หาปุ่ม ----------
	local function startsWith(s, prefix)
		return string.sub(string.lower(s), 1, #prefix) == string.lower(prefix)
	end

	local function getMutateRight()
		local g = playerGui:FindFirstChild("AntMutate")
		if not g then return nil end
		local ok, right = pcall(function() return g.Root.Window.Panel.Body.Right end)
		if ok and right then return right end
		return g:FindFirstChild("Right", true)
	end

	local function findHolder(parent, prefix)
		if not parent then return nil end
		for _, c in ipairs(parent:GetChildren()) do
			if startsWith(c.Name, prefix) then return c end
		end
		return nil
	end

	local function resolveButton(obj, preferName)
		if not obj then return nil end
		if obj:IsA("GuiButton") then return obj end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("GuiButton") and startsWith(d.Name, preferName) then return d end
		end
		return obj:FindFirstChildWhichIsA("GuiButton", true) or obj:FindFirstAncestorWhichIsA("GuiButton")
	end

	local cachedRoll, cachedSkip
	local function getButtons()
		if cachedRoll and cachedRoll.Parent and cachedSkip and cachedSkip.Parent then
			return cachedRoll, cachedSkip
		end
		local right = getMutateRight()
		if not right then return nil, nil end
		cachedRoll = resolveButton(findHolder(right:FindFirstChild("Buttons"), ROLL_BUTTON), "Roll")
		local info = right:FindFirstChild("Info")
		cachedSkip = resolveButton(findHolder(info, "SkipHo") or findHolder(info, "Skip"), "Skip")
		return cachedRoll, cachedSkip
	end

	-- ---------- ยิง event ของปุ่มตรง ๆ (ทำงานได้แม้หน้าต่างปิดอยู่) ----------
	local SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }

	local function fireButton(button)
		if not button then return false end
		for _, sigName in ipairs(SIGNALS) do
			local sig = button[sigName]
			local fired = false
			if typeof(getconnections) == "function" then
				local ok, conns = pcall(getconnections, sig)
				if ok and conns then
					for _, c in ipairs(conns) do
						if pcall(function()
							if c.Fire then c:Fire() elseif c.Function then task.spawn(c.Function) end
						end) then fired = true end
					end
				end
			elseif typeof(firesignal) == "function" then
				fired = pcall(firesignal, sig)
			end
			if fired then return true end -- ยิงแค่ signal แรกที่มีคนฟัง กันกดซ้อน
		end
		return false
	end

	-- ---------- ตรวจปุ่ม REBIRTH (สแกนทุก 1 วินาที ไม่หน่วงเกม) ----------
	local rebirthButtons = {}

	local function isReallyVisible(gui)
		local cur = gui
		while cur and cur ~= playerGui do
			if cur:IsA("GuiObject") and not cur.Visible then return false end
			if cur:IsA("LayerCollector") and not cur.Enabled then return false end
			cur = cur.Parent
		end
		return gui.AbsoluteSize.X > 2 and gui.AbsoluteSize.Y > 2
	end

	local function textOf(obj)
		local ok, t = pcall(function() return obj.ContentText end)
		if not ok or not t or t == "" then t = obj.Text or "" end
		return string.upper(t)
	end

	task.spawn(function()
		while true do
			if isEnabled and PAUSE_FOR_REBIRTH then
				local found = {}
				for _, gui in ipairs(playerGui:GetChildren()) do
					if gui:IsA("ScreenGui") and gui ~= screenGui and gui.Name ~= "OrbTpGui"
						and gui.Name ~= "AntMutate" and gui.Name ~= "AntMutateReveal" then
						for _, d in ipairs(gui:GetDescendants()) do
							-- นับเฉพาะ "ปุ่ม" Rebirth (กันไปเจอข้อความเควสที่มีคำว่า Rebirth)
							if (d:IsA("TextLabel") or d:IsA("TextButton"))
								and string.find(textOf(d), "REBIRTH", 1, true) then
								local b = d:IsA("GuiButton") and d
									or (d.Parent and d.Parent:IsA("GuiButton") and d.Parent)
								if b then table.insert(found, b) end
							end
						end
					end
				end
				rebirthButtons = found
			end
			task.wait(1)
		end
	end)

	local function rebirthIsUp()
		for _, d in ipairs(rebirthButtons) do
			if d.Parent and isReallyVisible(d) then return true end
		end
		return false
	end

	-- ---------- main loop ----------
	local warned = false
	task.spawn(function()
		while true do
			if isEnabled then
				local ok, err = pcall(function()
					local rollBtn, skipBtn = getButtons()
					if not rollBtn then
						if not warned then
							warned = true
							warn("[AutoMutate] หาปุ่ม " .. ROLL_BUTTON .. " ไม่เจอ ลองเปิดหน้า Mutate 1 ครั้งก่อน")
						end
						return
					end
					warned = false

					-- ปุ่ม REBIRTH ขึ้น → หยุดสุ่ม ปิดหน้าผลสุ่มให้ แล้วรอจนรีเสร็จ
					if PAUSE_FOR_REBIRTH and rebirthIsUp() then
						Shared.AntMutatePauseUntil = math.max(Shared.AntMutatePauseUntil, os.clock() + REBIRTH_PAUSE_AFTER)
					end
					if os.clock() < Shared.AntMutatePauseUntil then
						fireButton(skipBtn)
						return
					end

					fireButton(rollBtn)
					for _ = 1, SKIP_SPAM do
						task.wait(SKIP_GAP)
						fireButton(skipBtn)
					end
				end)
				if not ok then warn("[AutoMutate] error:", err) end
				task.wait(ROLL_DELAY)
			else
				task.wait(0.2)
			end
		end
	end)
end
