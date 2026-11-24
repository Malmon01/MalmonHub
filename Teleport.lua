local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = false
local TP_DELAY = 0.5         -- หน่วง 2 วินาทีต่อรอบ ให้แต้มขึ้นทัน
local MAX_SCAN_DISTANCE = 300 -- เก็บเฉพาะเม็ดใกล้ตัวมาก (กันหลุดโซน/ตกน้ำ)
local MIN_TP_DISTANCE = 2.5   -- ระยะใกล้สุดที่ไม่ต้องวาร์ปซ้ำ
local MAX_DROP_HEIGHT = 6     -- กันวาร์ปลงจุดที่ต่ำกว่าตัวละครเกินไป (เช่น ผิวน้ำ/หลุม)
local WALK_SPEED_BOOST = 9    -- ความเร็วเดินหน้าต่อเนื่องตอนเปิด (หยุดทันทีเมื่อปิด)
local HEIGHT_OFFSET = 2.5     -- ความสูงตอนวาร์ปเหนือ Orb
local AUTO_REBIRTH_ENABLED = true
local REBIRTH_COOLDOWN = 2.0  -- เวลารอหลังกด Rebirth ก่อนเช็กซ้ำ (วินาที)
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)
local runToken = 0
local lastRebirthTime = 0

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

local function getCharParts()
	local char = player.Character
	if not char then return nil, nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart", true)
	return humanoid, root
end

local function stopAllMovement()
	local humanoid, root = getCharParts()
	pcall(function()
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			if root and root:IsA("BasePart") then
				humanoid:MoveTo(root.Position)
			end
		end
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
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
		stopAllMovement()
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

-- เดินหน้าต่อเนื่องเฉพาะตอนกดเปิด (หยุดทันทีเมื่อกดปิด)
RunService.Heartbeat:Connect(function(dt)
	if not isEnabled then return end
	if type(dt) ~= "number" or dt <= 0 then return end

	local humanoid, root = getCharParts()
	if not root or not root:IsA("BasePart") then return end

	pcall(function()
		if humanoid then
			humanoid:Move(Vector3.new(0, 0, -1), true)
		end

		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if forward.Magnitude > 0.001 then
			forward = forward.Unit
			local step = forward * (WALK_SPEED_BOOST * dt)
			root.CFrame = root.CFrame + step
		end
	end)
end)

local function getOrbPosition(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then
		return obj.Position
	elseif obj:IsA("Model") then
		return obj:GetPivot().Position
	else
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position or nil
	end
end

local function findNearestOrbPos(currentPos)
	local bestPos = nil
	local bestDist = MAX_SCAN_DISTANCE

	for _, child in ipairs(orbsFolder:GetChildren()) do
		local orbPos = getOrbPosition(child)
		if orbPos then
			local isTooLow = orbPos.Y < (currentPos.Y - MAX_DROP_HEIGHT)
			local dist = (orbPos - currentPos).Magnitude
			if not isTooLow and dist >= MIN_TP_DISTANCE and dist <= bestDist then
				bestDist = dist
				bestPos = orbPos
			end
		end
	end

	return bestPos
end

local function waitInterruptible(seconds, token)
	local elapsed = 0
	while elapsed < seconds do
		if not isEnabled or token ~= runToken then
			return false
		end
		local step = math.min(0.1, seconds - elapsed)
		task.wait(step)
		elapsed += step
	end
	return isEnabled and (token == runToken)
end

local function teleportToOrb(orbPos)
	local _, root = getCharParts()
	if not root or not root:IsA("BasePart") then return end

	local tpPos = orbPos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local lookTarget = Vector3.new(orbPos.X, tpPos.Y, orbPos.Z)
	local lookCFrame = (lookTarget - tpPos).Magnitude > 0.01
		and CFrame.lookAt(tpPos, lookTarget)
		or CFrame.new(tpPos)

	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = lookCFrame
	end)
end

task.spawn(function()
	while true do
		if isEnabled then
			tryAutoRebirth()
		end
		task.wait(0.4)
	end
end)

task.spawn(function()
	while true do
		if isEnabled then
			local token = runToken
			local _, root = getCharParts()
			if root and root:IsA("BasePart") then
				local targetPos = findNearestOrbPos(root.Position)
				if targetPos then
					teleportToOrb(targetPos)
				end
			end

			if not waitInterruptible(TP_DELAY, token) then
				stopAllMovement()
			end
		else
			stopAllMovement()
			task.wait(0.2)
		end
	end
end)
