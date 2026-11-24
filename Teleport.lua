local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่าความช้าและระยะ =================
local DEFAULT_ENABLED = false
local TP_DELAY = 1.5          -- หน่วงเวลา (วินาที) ต่อการขยับ 1 ครั้ง (ยิ่งมากยิ่งช้า)
local MAX_STEP_DISTANCE = 12  -- ระยะขยับสูงสุดต่อ 1 ก้าว (Studs) ยิ่งน้อยยิ่งช้า
local MAX_SCAN_DISTANCE = 80  -- ระยะสแกนหา Orb ใกล้ตัว (Studs)
local MIN_TP_DISTANCE = 4     -- ระยะใกล้สุดที่ไม่ต้องวาร์ปซ้ำ
local HEIGHT_OFFSET = 2.5     -- ความสูงเหนือ Orb
-- ======================================================

local isEnabled = (DEFAULT_ENABLED == true)

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
btn.Size = UDim2.new(0, 170, 0, 40)
btn.Position = UDim2.new(0.5, -85, 0, 16)
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

local function updateBtn()
	if isEnabled then
		btn.Text = "TP ORB: ON"
		btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
	else
		btn.Text = "TP ORB: OFF"
		btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
	end
end

updateBtn()

btn.MouseButton1Click:Connect(function()
	isEnabled = not isEnabled
	updateBtn()
end)

local function getCharacterRoot()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart", true)
end

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
			if dist >= MIN_TP_DISTANCE and dist <= bestDist then
				bestDist = dist
				bestPos = orbPos
			end
		end
	end

	return bestPos
end

local function stepToward(root, targetPos)
	local char = player.Character
	if not char or not root or not root:IsA("BasePart") then return end

	local goal = targetPos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local delta = goal - root.Position
	local dist = delta.Magnitude
	if dist <= 0.01 then return end

	local moveDist = math.min(MAX_STEP_DISTANCE, dist)
	local nextPos = root.Position + (delta.Unit * moveDist)
	local targetCFrame = CFrame.new(nextPos)

	pcall(function()
		if char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			char.HumanoidRootPart.CFrame = targetCFrame
		else
			char:PivotTo(targetCFrame)
		end
	end)
end

task.spawn(function()
	while true do
		if isEnabled then
			local root = getCharacterRoot()
			if root and root:IsA("BasePart") then
				local targetPos = findNearestOrbPos(root.Position)
				if targetPos then
					stepToward(root, targetPos)
					task.wait(TP_DELAY)
				else
					task.wait(0.4)
				end
			else
				task.wait(0.4)
			end
		else
			task.wait(0.2)
		end
	end
end)
