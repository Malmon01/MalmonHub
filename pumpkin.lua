-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- เข้าถึง Remote Event สำหรับ Swing
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

-- ฟังก์ชันบังคับถือค้อน
local function equipHammer()
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if character and backpack then
		local currentTool = character:FindFirstChildOfClass("Tool")
		if not currentTool then
			local tool = backpack:FindFirstChildOfClass("Tool")
			if tool then
				character.Humanoid:EquipTool(tool)
			end
		end
	end
end

-- ฟังก์ชันโจมตี (ส่ง Object ของฟักทองไปกับ Server ด้วย)
local function attackTarget(targetPart, pumpkinInstance)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character.HumanoidRootPart.CFrame = CFrame.new(character.HumanoidRootPart.Position, targetPart.Position)
	end

	-- ส่งชื่อคำสั่งและตัวฟักทองไปให้ Server ประมวลผล
	pcall(function()
		eventAction:InvokeServer("Swing", pumpkinInstance)
	end)
	
	-- จำลองการคลิกซ้ายเผื่อไว้
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
			local humanoid = character and character:FindFirstChild("Humanoid")
			
			local eventFolder = Workspace:FindFirstChild("Event")
			local pumpkinsFolder = eventFolder and eventFolder:FindFirstChild("Pumpkins")
			
			if humanoidRootPart and humanoid and pumpkinsFolder then
				-- ป้องกันตัวละครล้ม (ปิดสถานะล้มกลิ้งทั้งหมด)
				pcall(function()
					humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end)
				
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
						
						-- รีเซ็ตความเร็วและลอยตัวให้อยู่ห่างจากจุดปะทะ
						humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 4, -5)
						task.wait(0.05)
						
						-- ล็อกตำแหน่งชั่วคราวให้ยืนตีโดยไม่ขยับ
						humanoidRootPart.Anchored = true
						
						-- วนลูปตีจนกว่าฟักทองจะถูกทำลาย
						while isRunning and pumpkin.Parent == pumpkinsFolder do
							equipHammer()
							attackTarget(targetPart, pumpkin)
							task.wait(0.2)
						end
						
						-- ปลดล็อกตัวละครเพื่อไปลูกถัดไป
						humanoidRootPart.Anchored = false
						task.wait(0.1)
					end
				end
				
				if humanoidRootPart.Anchored then
					humanoidRootPart.Anchored = false
				end
				
				if not foundTarget then
					task.wait(0.5)
				end
			else
				task.wait(1)
			end
			
			task.wait(0.1)
		end
		
		-- คืนค่าเมื่อปิด
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			character.HumanoidRootPart.Anchored = false
		end
	end)
end

-- ปุ่มเปิด/ปิด ระบบ
toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	
	if isRunning then
		toggleButton.Text = "Pumpkin Farm: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		startFarming()
	else
		toggleButton.Text = "Pumpkin Farm: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			character.HumanoidRootPart.Anchored = false
		end
	end
end)
