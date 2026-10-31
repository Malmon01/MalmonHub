-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- เข้าถึง Remote Event สำหรับ Swing
local eventAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EventAction")

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

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

-- สถานะการทำงาน
local isRunning = false

-- ฟังก์ชันหลักในการฟาร์ม Pumpkin
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
						-- เทเลพอร์ตไปหาฟักทองลูกนี้
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
						
						-- วนลูปตีด้วย Remote Event "Swing" จนกว่าฟักทองลูกนี้จะถูกทำลาย (หายไปจาก Workspace)
						while isRunning and pumpkin.Parent == pumpkinsFolder do
							pcall(function()
								eventAction:InvokeServer("Swing")
							end)
							task.wait(0.2) -- หน่วงเวลาการโจมตีไม่ให้ส่งถี่เกินไป
						end
						
						-- รอสักนิดหลังฟักทองแตก ก่อนจะเปลี่ยนเป้าหมายไปลูกถัดไป
						task.wait(0.1)
					end
				end
				
				-- ถ้าไม่มีฟักทองเหลือในโฟลเดอร์ ให้รอสั้นๆ แล้วเช็คใหม่
				if not foundTarget then
					task.wait(0.5)
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
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- สีเขียว
		startFarming()
	else
		toggleButton.Text = "Farm Pumpkins: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง
	end
end)
