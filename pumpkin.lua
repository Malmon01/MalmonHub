-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

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

-- ฟังก์ชันโจมตีโดยใช้ Tool:Activate() และจำลองคลิกเมาส์
local function attackPumpkin(targetPart)
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		-- หันหน้ามองไปที่ฟักทอง
		humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetPart.Position)
	end
	
	-- บังคับใช้งาน Tool ที่ถืออยู่ (เรียกใช้งานฟังก์ชันตีของค้อนโดยตรง)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end
	
	-- จำลองการคลิกซ้ายผ่าน VirtualUser เพื่อให้เกมรับรู้การกดตี
	pcall(function()
		VirtualUser:Button1Down(Vector2.new(400, 300))
		task.wait(0.05)
		VirtualUser:Button1Up(Vector2.new(400, 300))
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
				-- ป้องกันตัวละครล้ม
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
					if pumpkin:IsA("BasePart")  then
						targetPart = pumpkin
					elseif pumpkin:IsA("Model") then
						targetPart = pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart")
					end
					
					if targetPart then
						foundTarget = true
						
						-- เคลียร์แรงเหวี่ยงและวาร์ปไปยืนระยะประชิดที่เหมาะสมด้านหน้าฟักทอง
						humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, -4)
						task.wait(0.05)
						
						-- ล็อกตำแหน่งตัวละครให้อยู่กับที่ขณะตี
						humanoidRootPart.Anchored = true
						
						-- ตัวแปรนับเวลาป้องกันกรณีตีนานเกินไปแล้วฟักทองไม่ยอมแตก (เช่น 4 วินาที ข้ามไปลูกอื่นทันที)
						local attackStartTime = tick()
						
						-- วนลูปตีจนกว่าฟักทองจะถูกทำลาย (หายไปจากโฟลเดอร์)
						while isRunning and pumpkin.Parent == pumpkinsFolder and (tick() - attackStartTime < 4) do
							equipHammer()
							attackPumpkin(targetPart)
							task.wait(0.3) -- หน่วงเวลาการตีไม่ให้รัวเกินไปจนเกมบล็อก
						end
						
						-- ปลดล็อกตัวละครเพื่อเปลี่ยนเป้าหมาย
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
		
		-- คืนค่าเมื่อปิดสคริปต์
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
