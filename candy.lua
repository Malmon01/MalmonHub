local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local collectibleSpawner = Workspace:WaitForChild("CollectibleSpawner")

local isRunning = false
local collectedItems = {}

-- UI ปุ่มเปิด/ปิด
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

-- ฟังก์ชันดึง Part สำหรับวาร์ป
local function getTargetPart(item)
	if item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
	elseif item:IsA("BasePart") then
		return item
	end
	return nil
end

-- ลูปหลักสำหรับเก็บ Candy ทั้งหมดในโฟลเดอร์
task.spawn(function()
	while true do
		if isRunning then
			character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				humanoidRootPart = character.HumanoidRootPart
				
				local foundAny = false
				local allChildren = collectibleSpawner:GetChildren() -- ดึงไอเทมทั้งหมดในโฟลเดอร์ ณ ตอนนั้น[cite: 1]
				
				for _, item in ipairs(allChildren) do
					if not isRunning then break end
					
					-- เช็คชื่อวัตถุตามโครงสร้างภาพ[cite: 1]
					if (string.find(item.Name, "SPOOK") or string.find(item.Name, "Spookfest")) and not collectedItems[item] then
						local targetPart = getTargetPart(item)
						
						if targetPart then
							collectedItems[item] = true
							foundAny = true
							
							-- เทเลพอร์ตไปตำแหน่งวัตถุ
							humanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
							task.wait(0.3) -- รอรับไอเทมเล็กน้อย
						end
					end
				end
				
				-- หากเก็บครบทุกชิ้นที่มองเห็น ณ ตอนนั้นแล้ว ให้รีเซ็ตประวัติเพื่อรอบันทึกชิ้นใหม่
				if not foundAny then
					table.clear(collectedItems)
				end
			end
		end
		task.wait(0.3)
	end
end)
