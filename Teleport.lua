local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs") --[cite: 1]

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = false -- เริ่มต้นปิดไว้ก่อน กดปุ่มค่อยเปิด
local TP_DELAY = 0.25         -- หน่วงเวลา (วินาที) ก่อนวาร์ปไป Orb ถัดไป
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)

-- ลบปุ่มเก่าถ้ามี
local oldGui = playerGui:FindFirstChild("OrbTpGui")
if oldGui then
	oldGui:Destroy()
end

-- สร้างปุ่มเปิด-ปิดด้านบนกลางจอ
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

-- หาตำแหน่งของ Orb
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

-- Teleport ตัวละครไปยังตำแหน่งเป้าหมาย
local function teleportTo(pos)
	local char = player.Character
	if not char then return end

	local targetCFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
	local root = char:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		root.CFrame = targetCFrame
	elseif char.PrimaryPart then
		char:PivotTo(targetCFrame)
	else
		pcall(function()
			char:PivotTo(targetCFrame)
		end)
	end
end

-- ลูป Teleport ไปหา Orb ใน ClientOrbs
task.spawn(function()
	while true do
		if isEnabled then
			local children = orbsFolder:GetChildren()
			for _, child in ipairs(children) do
				if not isEnabled then break end
				local orbPos = getOrbPosition(child)
				if orbPos then
					teleportTo(orbPos)
					task.wait(TP_DELAY)
				end
			end
		end
		task.wait(0.1)
	end
end)
