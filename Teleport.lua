local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = true   -- สถานะเริ่มต้น (true = เปิด, false = ปิด)
local TOGGLE_KEY = Enum.KeyCode.E -- ปุ่มคีย์บอร์ดสำหรับเปิด/ปิด (เปลี่ยนเป็น nil ได้ถ้าไม่ใช้)
local MAGNET_RANGE = 25      -- ระยะเริ่มดูด (Studs)
local COLLECT_RANGE = 3      -- ระยะเก็บเข้าตัว (Studs)
local MOVE_SPEED = 50        -- ความเร็วในการดูดเข้าหาตัว
-- ==========================================

local isEnabled = DEFAULT_ENABLED

-- สร้างปุ่มเปิด-ปิดบนหน้าจอ (ScreenGui + TextButton)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbAutoCollectGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleOrbButton"
toggleButton.Size = UDim2.new(0, 170, 0, 44)
toggleButton.Position = UDim2.new(0, 20, 0.5, -22) -- อยู่ฝั่งซ้ายกลางจอ (ลากย้ายที่ในโค้ดได้)
toggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 15
toggleButton.BorderSizePixel = 0
toggleButton.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = toggleButton

-- ฟังก์ชันอัปเดตสถานะเปิด/ปิด และสีของปุ่ม
local function setEnabled(state)
	isEnabled = state
	if isEnabled then
		toggleButton.Text = "Orb Collect: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- สีเขียว
	else
		toggleButton.Text = "Orb Collect: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- สีแดง
	end
end

-- ตั้งค่าเริ่มต้นตามตัวแปร DEFAULT_ENABLED
setEnabled(isEnabled)

-- กดปุ่มที่หน้าจอเพื่อสลับเปิด/ปิด
toggleButton.MouseButton1Click:Connect(function()
	setEnabled(not isEnabled)
end)

-- กดปุ่มคีย์บอร์ดเพื่อสลับเปิด/ปิด
if TOGGLE_KEY then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == TOGGLE_KEY then
			setEnabled(not isEnabled)
		end
	end)
end

-- ลูปทำงานหลักสำหรับดูดและเก็บ Orb ใน Workspace.ClientOrbs
RunService.Heartbeat:Connect(function(dt)
	if not isEnabled then return end -- ถ้าปิดอยู่ จะไม่ทำงาน

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local playerPos = rootPart.Position

	for _, orb in ipairs(orbsFolder:GetChildren()) do
		if orb:IsA("BasePart") and orb.Name == "Orb" then
			local distance = (orb.Position - playerPos).Magnitude

			if distance <= COLLECT_RANGE then
				-- [ใส่โค้ดเพิ่มคะแนน / เล่นเสียง / ส่ง RemoteEvent ไป Server ตรงนี้]
				orb:Destroy()
			elseif distance <= MAGNET_RANGE then
				local direction = (playerPos - orb.Position).Unit
				orb.Position += direction * MOVE_SPEED * dt
			end
		end
	end
end)
