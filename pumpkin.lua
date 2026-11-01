-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- สร้าง ScreenGui และ UI เปิด/ปิด
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PumpkinFarmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 160, 0, 50)
toggleButton.Position = UDim2.new(0.5, -80, 0.1, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง (ปิดอยู่)
toggleButton.Text = "Local Farm: OFF"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 16
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

-- สถานะการทำงาน
local isRunning = false

-- ฟังก์ชันจำลองการคลิกซ้ายสมจริงผ่าน VirtualInputManager
local function simulateMouseClick()
	pcall(function()
		local vim = VirtualInputManager
		-- จำลองการกดคลิกซ้ายที่ตำแหน่งกลางจอ
		local vimX, vimY = 400, 300
		vim:SendMouseButtonEvent(vimX, vimY, 0, true, game, 0)  -- กดลง
		task.wait(0.05)
		vim:SendMouseButtonEvent(vimX, vimY, 0, false, game, 0) -- ปล่อย
	end)
end

-- ฟังก์ชันหลักในการฟาร์ม
local function startFarming()
	task.spawn(function()
		while isRunning do
			local character = player.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			
			local eventFolder = Workspace:FindFirstChild("Event")
			local pumpkinsFolder = eventFolder and eventFolder:FindFirstChild("Pumpkins")
			
			if humanoidRootPart and pumpkinsFolder then
				local pumpkins = pumpkinsFolder:GetChildren()
				local foundTarget = false
				
				for _, pumpkin in ipairs(pumpkins) do
					if not isRunning then break end
					
					local targetPart = nil
					if pumpkin:IsA("BasePart") then
						targetPart = pumpkin
					elseif pumpkin:IsA("Model") then
						targetPart = pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart")
					end
					
					if targetPart then
						foundTarget = true
						
						-- 1. วาร์ปไปหาฟักทอง
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
						
						-- 2. หันหน้ามองไปที่ฟักทองเพื่อให้ตัวละครหรือกล้องเล็งตรง
						humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetPart.Position)
						
						-- 3. วนลูปจำลองคลิกซ้ายรัวๆ จนกว่าฟักทองลูกนี้จะถูกทำลาย (หายไปจากโฟลเดอร์)
						while isRunning and pumpkin.Parent == pumpkinsFolder do
							simulateMouseClick()
							task.wait(0.25) -- หน่วงเวลาการคลิกไม่ให้ถี่จนเกินไป
						end
						
						task.wait(0.1)
					end
				end
				
				if not foundTarget then
					task.wait(0.5) -- หากไม่มีฟักทองเหลือ ให้รอสักครู่แล้วเช็คใหม่
				end
			else
				task.wait(1)
			end
			
			task.wait(0.1)
		end
	end)
end

-- กดปุ่มเพื่อ เปิด/ปิด ระบบ
toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	
	if isRunning then
		toggleButton.Text = "Local Farm: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- สีเขียว
		startFarming()
	else
		toggleButton.Text = "Local Farm: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง
	end
end)
