-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- สร้าง ScreenGui และ UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PumpkinFarmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 160, 0, 50)
toggleButton.Position = UDim2.new(0.5, -80, 0.1, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง (ปิดอยู่)
toggleButton.Text = "Farm Pumpkins: OFF"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 16
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui

-- ทำมุมปุ่มให้โค้งมน
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

-- สถานะการทำงาน
local isRunning = false

-- ฟังก์ชันจำลองการคลิกซ้าย
local function simulateClick()
	pcall(function()
		VirtualUser:Button1Down(Vector2.new(0,0))
		task.wait(0.05)
		VirtualUser:Button1Up(Vector2.new(0,0))
	end)
end

-- ฟังก์ชันหลักในการฟาร์ม Pumpkin
local function startFarming()
	task.spawn(function()
		while isRunning do
			local character = player.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			
			-- เข้าถึงโฟลเดอร์ Workspace -> Event -> Pumpkins (อ้างอิงตามรูปภาพของคุณ)
			local eventFolder = Workspace:FindFirstChild("Event")
			local pumpkinsFolder = eventFolder and eventFolder:FindFirstChild("Pumpkins")
			
			if humanoidRootPart and pumpkinsFolder then
				local pumpkins = pumpkinsFolder:GetChildren()
				local foundTarget = false
				
				for _, pumpkin in ipairs(pumpkins) do
					if not isRunning then break end
					
					-- ตรวจสอบว่ามีส่วนที่เป็น BasePart หรือ Model ที่มี PrimaryPart/Pivot
					local targetPart = nil
					if pumpkin:IsA("BasePart") then
						targetPart = pumpkin
					elseif pumpkin:IsA("Model") then
						targetPart = pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart")
					end
					
					if targetPart then
						foundTarget = true
						-- เทเลพอร์ตไปใกล้ๆ ฟักทอง
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
						
						-- จำลองการคลิกซ้ายรัวๆ จนกว่าฟักทองจะหายไปหรือย้ายเป้าหมาย
						local startTime = tick()
						while isRunning and pumpkin.Parent and (tick() - startTime < 1.5) do
							simulateClick()
							task.wait(0.2)
						end
					end
				end
				
				-- ถ้าไม่มีฟักทองเหลืออยู่ ให้รอสักครู่แล้วลองใหม่
				if not foundTarget then
					task.wait(1)
				end
			else
				task.wait(1)
			end
			
			task.wait(0.1)
		end
	end)
end

-- กดปุ่มเพื่อ เปิด/ปิด
toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	
	if isRunning then
		toggleButton.Text = "Farm Pumpkins: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- สีเขียว (เปิดอยู่)
		startFarming()
	else
		toggleButton.Text = "Farm Pumpkins: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง (ปิดอยู่)
	end
end)
