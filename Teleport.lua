local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า (ห้ามปล่อยว่าง/nil) =================
local DEFAULT_ENABLED = true
local TOGGLE_KEY = Enum.KeyCode.E -- ตั้งเป็น nil ได้เฉพาะตรงนี้ เพราะมีเช็ก if TOGGLE_KEY then
local MAGNET_RANGE = 45
local COLLECT_RANGE = 5
local MOVE_SPEED = 75
-- ============================================================

local isEnabled = (DEFAULT_ENABLED == true)

-- ล้าง GUI เดิมก่อนสร้างใหม่ ป้องกันปุ่มซ้อน
local existingGui = playerGui:FindFirstChild("OrbMagnetLocalGui")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbMagnetLocalGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(0, 176, 0, 40)
toggleBtn.Position = UDim2.new(0.5, -88, 0, 16)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 999
toggleBtn.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = toggleBtn

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(15, 15, 15)
stroke.Thickness = 2
stroke.Parent = toggleBtn

local function updateButton()
	if isEnabled then
		toggleBtn.Text = "ORB MAGNET: ON"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
	else
		toggleBtn.Text = "ORB MAGNET: OFF"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
	end
end

updateButton()

toggleBtn.MouseButton1Click:Connect(function()
	isEnabled = not isEnabled
	updateButton()
end)

if TOGGLE_KEY then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == TOGGLE_KEY then
			isEnabled = not isEnabled
			updateButton()
		end
	end)
end

local function getCharacterPos()
	local char = player.Character
	if not char then return nil end

	local root = char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart", true)

	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function getOrbBasePart(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then
		return obj
	elseif obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt)
	if not isEnabled then return end
	if type(dt) ~= "number" or dt <= 0 then return end

	local playerPos = getCharacterPos()
	if not playerPos then return end

	local children = orbsFolder:GetChildren()
	for i = 1, #children do
		local child = children[i]
		local part = getOrbBasePart(child)

		if part and part.Parent then
			local orbPos = child:IsA("Model") and child:GetPivot().Position or part.Position
			local delta = playerPos - orbPos
			local dist = delta.Magnitude

			if dist <= COLLECT_RANGE then
				pcall(function()
					child:Destroy()
				end)
			elseif dist <= MAGNET_RANGE and dist > 0.001 then
				pcall(function()
					if part.Anchored then
						part.Anchored = false
					end
					local step = math.min(MOVE_SPEED * dt, dist)
					local nextPos = orbPos + (delta.Unit * step)
					if child:IsA("Model") then
						child:PivotTo(CFrame.new(nextPos))
					else
						part.CFrame = CFrame.new(nextPos)
					end
				end)
			end
		end
	end
end)
