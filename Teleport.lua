local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = true
local TOGGLE_KEY = Enum.KeyCode.E
local MAGNET_RANGE = 120
local COLLECT_RANGE = 8
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)

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

Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", toggleBtn)
stroke.Color = Color3.fromRGB(15, 15, 15)
stroke.Thickness = 2

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
	return (root and root:IsA("BasePart")) and root.Position or nil
end

local function getOrbPart(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	if not isEnabled then return end
	local playerPos = getCharacterPos()
	if not playerPos then return end

	for _, child in ipairs(orbsFolder:GetChildren()) do
		local part = getOrbPart(child)
		if part and part.Parent then
			local orbPos = child:IsA("Model") and child:GetPivot().Position or part.Position
			local dist = (orbPos - playerPos).Magnitude

			if dist <= COLLECT_RANGE then
				pcall(function()
					child:Destroy()
				end)
			elseif dist <= MAGNET_RANGE then
				pcall(function()
					if child:IsA("Model") then
						child:PivotTo(CFrame.new(playerPos))
					else
						part.CFrame = CFrame.new(playerPos)
					end
				end)
			end
		end
	end
end)
