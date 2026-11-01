-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- เข้าถึง Remote Event สำหรับ Swing ตามที่คุณเคยแจ้งมา
local eventAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EventAction")

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
toggleButton.Text = "Pumpkin Farm: OFF"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 16
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

-- สถานะการทำงาน
local isRunning = false

-- ฟังก์ชันบังคับถืออุปกรณ์ (Tool) ใน Backpack ให้มาอยู่ที่ตัวละคร
local function equipHammer()
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if character and backpack then
		-- เช็คว่าตัวละครถือ tool อยู่แล้วหรือยัง
		local currentTool = character:FindFirstChildOfClass("Tool")
		if not currentTool then
			local tool = backpack:FindFirstChildOfClass("Tool")
			if tool then
				character.Humanoid:EquipTool(tool)
			end
		end
	end
end

-- ฟังก์ชันโจมตี (ส่ง Remote Event + จำลองคลิกซ้ายเผื่อไว้)
local function attackTarget(targetPart)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		-- หันหน้าไปหาฟักทองเสมอเวลากดตี
		character.HumanoidRootPart.CFrame = CFrame.new(character.HumanoidRootPart.Position, targetPart.Position)
	end

	-- 1. เรียก Remote Event ตามที่เกมใช้
	pcall(function()
		eventAction:InvokeServer("Swing")
	end)
	
	-- 2. จำลองการคลิกซ้ายผ่าน VirtualInputManager เผื่อเกมเช็ค Input ฝั่ง Client
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(400, 300, 0, true, game, 0)
		task.wait(0.02)
		VirtualInputManager:SendMouseButtonEvent(400, 300, 0, false, game, 0)
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
				-- บังคับถือค้อนก่อนเริ่มหาฟักทอง
				equipHammer()
				
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
						
						-- วาร์ปไปใกล้ๆ ฟักทอง (ลอยเหนือหัวเล็กน้อยหรือชิดด้านข้าง)
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
						task.wait(0.1)
						
						-- วนลูปตีซ้ำๆ จนกว่าฟักทองลูกนี้จะถูกทำลาย (หายไปจากโฟลเดอร์ Pumpkins)
						while isRunning and pumpkin.Parent == pumpkinsFolder do
							equipHammer() -- เช็คและถือค้อนซ้ำกันหลุดมือ
							attackTarget(targetPart)
							task.wait(0.25) -- หน่วงเวลาจังหวะการตี
						end
						
						task.wait(0.1)
					end
				end
				
				if not foundTarget then
					task.wait(0.5) -- ถ้ายัังไม่มีฟักทองเกิดใหม่ ให้รอสักครู่
				end
			else
				task.wait(1)
			end
			
			task.wait(0.1)
		end
	end)
end

-- ปุ่มเปิด/ปิด ระบบ
toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	
	if isRunning then
		toggleButton.Text = "Pumpkin Farm: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- สีเขียว
		startFarming()
	else
		toggleButton.Text = "Pumpkin Farm: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- สีแดง
	end
end)
