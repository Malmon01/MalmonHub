local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = true
local TOGGLE_KEY = Enum.KeyCode.E
local MAGNET_RANGE = 40      -- เพิ่มระยะดูดให้กว้างขึ้น (ปรับได้)
local COLLECT_RANGE = 5      -- ระยะเก็บ
local MOVE_SPEED = 70        -- ความเร็วดูด
local DEBUG_LOG = false      -- เปลี่ยนเป็น true หากอยากดู log ใน Output
-- ==========================================

local isEnabled = DEFAULT_ENABLED

-- ลบ GUI เก่าถ้ามีอยู่แล้ว เพื่อไม่ให้ซ้อนกัน
local oldGui = playerGui:FindFirstChild("OrbAutoCollectGui")
if oldGui then oldGui:Destroy() end

-- สร้างปุ่มบนจอให้อยู่ด้านบนกลาง และลอยทับ UI เกม
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbAutoCollectGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleOrbButton"
toggleButton.Size = UDim2.new(0, 180, 0, 42)
toggleButton.Position = UDim2.new(0.5, -90, 0, 14) -- ด้านบนกลางจอ ไม่โดนเมนูซ้ายบัง
toggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 15
toggleButton.BorderSizePixel = 0
toggleButton.ZIndex = 100
toggleButton.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(20, 20, 20)
stroke.Thickness = 2
stroke.Parent = toggleButton

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = toggleButton

local function setEnabled(state)
	isEnabled = state
	if isEnabled then
		toggleButton.Text = "Orb Collect: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	else
		toggleButton.Text = "Orb Collect: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	end
	if DEBUG_LOG then
		print("[OrbCollect] Status =", isEnabled, "| Orbs count =", #orbsFolder:GetChildren())
	end
end

setEnabled(isEnabled)

toggleButton.MouseButton1Click:Connect(function()
	setEnabled(not isEnabled)
end)

if TOGGLE_KEY then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == TOGGLE_KEY then
			setEnabled(not isEnabled)
		end
	end)
end

-- หาตำแหน่งตัวละครของผู้เล่น (รองรับทั้งมด/ตัวละครที่ไม่มี HumanoidRootPart)
local function getTargetPosition()
	local character = player.Character
	if not character then return nil end

	local root = character:FindFirstChild("HumanoidRootPart")
		or character.PrimaryPart
		or character:FindFirstChildWhichIsA("BasePart", true)

	return root and root.Position or nil
end

-- ดึง Part หลักของ Orb (รองรับทั้ง BasePart และ Model)
local function getOrbPart(item)
	if item:IsA("BasePart") then
		return item
	elseif item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt)
	if not isEnabled then return end

	local playerPos = getTargetPosition()
	if not playerPos then return end

	for _, child in ipairs(orbsFolder:GetChildren()) do
		local orbPart = getOrbPart(child)
		if orbPart and orbPart.Parent then
			local distance = (orbPart.Position - playerPos).Magnitude

			if distance <= COLLECT_RANGE then
				child:Destroy()
			elseif distance <= MAGNET_RANGE then
				if orbPart.Anchored then
					orbPart.Anchored = false
				end
				local direction = (playerPos - orbPart.Position).Unit
				orbPart.Position += direction * MOVE_SPEED * dt
			end
		end
	end
end)
