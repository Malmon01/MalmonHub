local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่าความเร็วและระยะ =================
local DEFAULT_ENABLED = false
local TP_DELAY = 0.8          -- หน่วงเวลา (วินาที) ต่อการไปหา Orb แต่ละเม็ด (เพิ่มเลขนี้ถ้ายังเร็วไป)
local MAX_TP_DISTANCE = 90    -- ระยะไกลสุดที่จะไปหา (Studs) กันวาร์ปไกลข้ามโซน
local MIN_TP_DISTANCE = 4     -- ระยะใกล้สุดที่ไม่ต้องวาร์ปซ้ำ
local HEIGHT_OFFSET = 2.5     -- ความสูงเหนือตำแหน่ง Orb
local SMOOTH_MOVE = true      -- true = ขยับเข้าหาแบบนุ่มนวล, false = วาร์ปตรงทันที
-- ========================================================

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

local function moveToOrb(pos)
	local char = player.Character
	local root = getCharacterRoot()
	if not char or not root or not root:IsA("BasePart") then return end

	local targetPos = pos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local finalPos = targetPos

	if SMOOTH_MOVE then
		-- ดึงเข้าหา 65% ของระยะต่อรอบ เพื่อไม่ให้กระโดดแรงจนหลุดพื้นที่
		finalPos = root.Position:Lerp(targetPos, 0.65)
	end

	local targetCFrame = CFrame.new(finalPos)
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
				local currentPos = root.Position
				local children = orbsFolder:GetChildren()

				for _, child in ipairs(children) do
					if not isEnabled then break end

					local orbPos = getOrbPosition(child)
					if orbPos then
						local dist = (orbPos - currentPos).Magnitude
						if dist >= MIN_TP_DISTANCE and dist <= MAX_TP_DISTANCE then
							moveToOrb(orbPos)
							currentPos = orbPos
							task.wait(TP_DELAY)
						end
					end
				end
			end
		end
		task.wait(0.2)
	end
end)
