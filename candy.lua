local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local collectibleSpawner = Workspace:WaitForChild("CollectibleSpawner")

local isRunning = false
local collectedItems = {}

-- กำหนดพิกัดจุดสำคัญ (Waypoints) ครอบคลุมทั่วแมพ เพื่อบังคับให้เกมโหลดพื้นที่
-- (คุณสามารถปรับเปลี่ยนพิกัด Vector3 ตามความกว้างของแมพในเกมได้ครับ)
local patrolPoints = {
	Vector3.new(0, 50, 0),       -- จุดกลางแมพ
	Vector3.new(500, 50, 500),   -- โซนขวาบน
	Vector3.new(-500, 50, 500),  -- โซนซ้ายบน
	Vector3.new(500, 50, -500),  -- โซนขวาล่าง
	Vector3.new(-500, 50, -500), -- โซนซ้ายล่าง
	Vector3.new(0, 50, 1000),    -- โซนเกาะหรือขอบแมพไกลๆ
}

-- สร้าง GUI ปุ่มเปิด/ปิด
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CandyTeleportGui"
screenGui.Parent = CoreGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 180, 0, 50)
toggleButton.Position = UDim2.new(0, 50, 0, 50)
toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 18
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Text = "Auto Teleport: OFF"
toggleButton.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning
	if isRunning then
		toggleButton.Text = "Auto Teleport: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	else
		toggleButton.Text = "Auto Teleport: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		table.clear(collectedItems)
	end
end)

local function getTargetPart(item)
	if item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
	elseif item:IsA("BasePart") then
		return item
	end
	return nil
end

-- ลูปหลักสำหรับฟาร์มทั่วแมพ
task.spawn(function()
	while true do
		if isRunning then
			character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				humanoidRootPart = character.HumanoidRootPart
				
				local foundAny = false
				local allChildren = collectibleSpawner:GetChildren()
				
				-- 1. วาร์ปเก็บไอเทมที่มองเห็นในรอบนี้ก่อน
				for _, item in ipairs(allChildren) do
					if not isRunning then break end
					
					if (string.find(item.Name, "SPOOK") or string.find(item.Name, "Spookfest")) and not collectedItems[item] then
						local targetPart = getTargetPart(item)
						
						if targetPart then
							collectedItems[item] = true
							foundAny = true
							
							humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
							task.wait(0.25)
						end
					end
				end
				
				-- 2. ถ้าหากเก็บในรัศมีนี้หมดแล้ว ให้ตัวละครวาร์ปสเกาท์ไปตามจุดพิกัดหลัก (Patrol Points) เพื่อบังคับโหลดแมพส่วนที่เหลือ
				if not foundAny then
					for _, point in ipairs(patrolPoints) do
						if not isRunning then break end
						humanoidRootPart.CFrame = CFrame.new(point)
						task.wait(0.5) -- รอให้เกมโหลด Chunk / Object ในโซนนั้นๆ
						
						-- เช็คอีกรอบว่ามีไอเทมโผล่มาไหมหลังวาร์ปมาโซนนี้
						local newCheck = collectibleSpawner:GetChildren()
						for _, item in ipairs(newCheck) do
							if (string.find(item.Name, "SPOOK") or string.find(item.Name, "Spookfest")) and not collectedItems[item] then
								local targetPart = getTargetPart(item)
								if targetPart then
									collectedItems[item] = true
									humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
									task.wait(0.25)
								end
							end
						end
					end
					
					-- ล้างประวัติเพื่อวนลูปสำรวจใหม่รอบถัดไป
					table.clear(collectedItems)
				end
			end
		end
		task.wait(0.3)
	end
end)
