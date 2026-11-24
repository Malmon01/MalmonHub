local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = false
local TP_DELAY = 1.5            -- หน่วงเวลา 3 วินาทีต่อรอบ
local WALK_DURATION = 1.2     -- ระยะเวลาจำลองการเดินหน้าต่อรอบ (วินาที)
local MAX_SCAN_DISTANCE = 100 -- ระยะค้นหา Orb (Studs)
local HEIGHT_OFFSET = 2.5     -- ความสูงตอนวาร์ปเหนือ Orb
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)
local runToken = 0 -- ใช้ตัดลูปทันทีเมื่อกดปิด

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

-- สั่งหยุดเดินทันทีเมื่อปิดระบบ
local function stopWalking()
	local humanoid, root = getCharParts()
	pcall(function()
		if humanoid then
			if root and root:IsA("BasePart") then
				humanoid:MoveTo(root.Position)
			end
			humanoid:Move(Vector3.zero, false)
		end
	end)
end

local function setState(state)
	isEnabled = (state == true)
	runToken += 1 -- เปลี่ยน token เพื่อยกเลิกการทำงานของรอบเก่าทันที

	if isEnabled then
		btn.Text = "TP ORB: ON"
		btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
	else
		btn.Text = "TP ORB: OFF"
		btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		stopWalking()
	end
end

setState(isEnabled)

btn.MouseButton1Click:Connect(function()
	setState(not isEnabled)
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
			local dist = (orbPos - currentPos).Magnitude
			if dist <= bestDist then
				bestDist = dist
				bestPos = orbPos
			end
		end
	end

	return bestPos
end

-- หน่วงเวลาแบบเช็กสถานะตลอดเวลา หากกดปิดจะหยุดรอทันที
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

local function teleportAndWalkForward(orbPos, token)
	local humanoid, root = getCharParts()
	if not root or not root:IsA("BasePart") then return end
	if not isEnabled or token ~= runToken then return end

	-- วาร์ปไปจุดเป้าหมายและหันหน้าไปทาง Orb
	local tpPos = orbPos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local lookTarget = Vector3.new(orbPos.X, tpPos.Y, orbPos.Z)
	local lookCFrame = (lookTarget - tpPos).Magnitude > 0.01
		and CFrame.lookAt(tpPos, lookTarget)
		or CFrame.new(tpPos)

	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = lookCFrame
	end)

	-- จำลองการเดินหน้าต่อช่วงสั้นๆ เฉพาะตอนเปิดอยู่
	local walkElapsed = 0
	while walkElapsed < WALK_DURATION do
		if not isEnabled or token ~= runToken then
			stopWalking()
			return
		end
		humanoid, root = getCharParts()
		if humanoid and root and root:IsA("BasePart") then
			local forwardGoal = root.Position + (root.CFrame.LookVector * 6)
			humanoid:MoveTo(forwardGoal)
		end
		task.wait(0.1)
		walkElapsed += 0.1
	end

	stopWalking()
end

task.spawn(function()
	while true do
		if isEnabled then
			local token = runToken
			local _, root = getCharParts()
			if root and root:IsA("BasePart") then
				local targetPos = findNearestOrbPos(root.Position)
				if targetPos then
					teleportAndWalkForward(targetPos, token)
				end
			end

			-- หน่วง 3 วินาทีก่อนเริ่มรอบถัดไป
			if not waitInterruptible(TP_DELAY, token) then
				stopWalking()
			end
		else
			stopWalking()
			task.wait(0.2)
		end
	end
end)
