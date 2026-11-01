-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

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
local currentTween = nil

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

-- ฟังก์ชันเคลื่อนที่แบบ Smooth (Tween) ไปหาเป้าหมาย
local function tweenToTarget(humanoidRootPart, targetCFrame, duration)
	if currentTween then
		currentTween:Cancel()
	end
	
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)
	
	currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {CFrame = targetCFrame})
	currentTween:Play()
	currentTween.Completed:Wait()
end

-- ฟังก์ชันโจมตีอัตโนมัติ
local function attackPumpkin(targetPart)
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and targetPart then
		-- ล็อกหน้าให้หันมองฟักทองเสมอขณะตี
		humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetPart.Position)
	end
	
	-- ใช้ Tool:Activate() เพื่อตี
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end
	
	-- จำลองคลิกซ้าย
	pcall(function()
		VirtualUser:Button1Down(Vector2.new(400, 300))
		task.wait(0.02)
		VirtualUser:Button1Up(Vector2.new(400, 300))
	end)
end

-- ฟังก์ชันหลักในการฟาร์มแบบออโต้ต่อเนื่อง
local function startFarming()
	task.spawn(function()
		while isRunning do
			local character = player.Character
			local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChild("Humanoid")
			
			local eventFolder = Workspace:FindFirstChild("Event")
			local pumpkinsFolder = eventFolder and eventFolder:FindFirstChild("Pumpkins")
			
			if humanoidRootPart and humanoid and pumpkinsFolder then
				pcall(function()
					humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end)
				
				equipHammer()
				
				local pumpkins = pumpkinsFolder:GetChildren()
				local foundTarget = false
				
				-- วนลูปเช็คฟักทองทีละลูกในโฟลเดอร์
				for _, pumpkin in ipairs(pumpkins) do
					if not isRunning then break end
					
					-- เช็คว่าฟักทองลูกนั้นยังมีตัวตนอยู่จริงไหม (ไม่ได้ถูกทำลายไปแล้ว)
					if pumpkin and pumpkin.Parent == pumpkinsFolder then
						local targetPart = nil
						if pumpkin:IsA("BasePart") then
							targetPart = pumpkin
						elseif pumpkin:IsA("Model") then
							targetPart = pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart")
						end
						
						if targetPart then
							foundTarget = true
							
							-- คำนวณตำแหน่งยืนด้านหน้าฟักทอง
							local destCFrame = targetPart.CFrame * CFrame.new(0, 3, -6)
							
							-- พุ่งตัวไปหาฟักทองลูกนี้แบบสมูท
							tweenToTarget(humanoidRootPart, destCFrame, 0.15)
							task.wait(0.05)
							
							-- ตัวแปรจับเวลา Timeout ป้องกันกรณีฟักทองค้าง (4 วินาที)
							local attackStartTime = tick()
							
							-- ตีรัวๆ อัตโนมัติจนกว่าฟักทองลูกนี้จะถูกทำลาย (หายไปจากโฟลเดอร์)
							while isRunning and pumpkin.Parent == pumpkinsFolder and (tick() - attackStartTime < 4) do
								equipHammer()
								attackPumpkin(targetPart)
								task.wait(0.15) -- ความเร็วในการตีรัว (ปรับค่าน้อยลงจะตีเร็วขึ้น)
							end
							
							task.wait(0.05)
						end
					end
				end
				
				-- ถ้ากวาดฟักทองหมดทุกอันในโฟลเดอร์แล้ว ให้รอสักครู่แล้วสแกนหาใหม่ทันที
				if not foundTarget then
					task.wait(0.5)
				end
			else
				task.wait(1)
			end
			
			task.wait(0.05)
		end
		
		if currentTween then
			currentTween:Cancel()
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
		if currentTween then
			currentTween:Cancel()
		end
	end
end)
