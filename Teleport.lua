local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local orbsFolder = Workspace:WaitForChild("ClientOrbs")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = false
local TP_DELAY = 0.2          -- ความเร็วรอบการวาร์ป (ยิ่งน้อยยิ่งวาร์ปไว 0.15 - 0.3 กำลังดี)
local WALK_SPEED_BOOST = 28   -- ความเร็วในการจำลองการเดินหน้าต่อเนื่อง
local HEIGHT_OFFSET = 2.5     -- ความสูงตอนวาร์ปเหนือ Orb
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)
local runToken = 0

local oldGui = playerGui:FindFirstChild("OrbTpGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbTpGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 9999
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local btn = Instance.new("TextButton")
btn.Name = "ToggleTpButton"
btn.Size = UDim2.new(0, 176, 0, 40)
btn.Position = UDim2.new(0.5, -88, 0, 16)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.BorderSizePixel = 0
btn.ZIndex = 999
btn.Parent = screenGui

Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", btn)
stroke.Color = Color3.fromRGB(15, 15, 15)
stroke.Thickness = 2

local function getCharParts()
	local char = player.Character
	if not char then return nil, nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart", true)
	return humanoid, root
end

local function stopAllMovement()
	local humanoid, root = getCharParts()
	pcall(function()
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			if root and root:IsA("BasePart") then
				humanoid:MoveTo(root.Position)
			end
		end
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

local function setState(state)
	isEnabled = (state == true)
	runToken += 1

	if isEnabled then
		btn.Text = "TP ORB: ON"
		btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
	else
		btn.Text = "TP ORB: OFF"
		btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		stopAllMovement()
	end
end

setState(isEnabled)

btn.MouseButton1Click:Connect(function()
	setState(not isEnabled)
end)

-- เดินหน้าต่อเนื่องตลอดเวลาที่กดเปิด (กันสคริปต์เกมตัดจังหวะให้เดินๆ หยุดๆ)
RunService.Heartbeat:Connect(function(dt)
	if not isEnabled then return end
	if type(dt) ~= "number" or dt <= 0 then return end

	local humanoid, root = getCharParts()
	if not root or not root:IsA("BasePart") then return end

	pcall(function()
		if humanoid then
			humanoid:Move(Vector3.new(0, 0, -1), true)
		end

		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if forward.Magnitude > 0.001 then
			forward = forward.Unit
			local step = forward * (WALK_SPEED_BOOST * dt)
			root.CFrame = root.CFrame + step
		end
	end)
end)

local function getOrbPosition(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then
		return obj.Position
	elseif obj:IsA("Model") then
		return obj:GetPivot().Position
	else
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position or nil
	end
end

local function teleportToOrb(orbPos)
	local _, root = getCharParts()
	if not root or not root:IsA("BasePart") then return end

	local tpPos = orbPos + Vector3.new(0, HEIGHT_OFFSET, 0)
	local lookTarget = Vector3.new(orbPos.X, tpPos.Y, orbPos.Z)
	local lookCFrame = (lookTarget - tpPos).Magnitude > 0.01
		and CFrame.lookAt(tpPos, lookTarget)
		or CFrame.new(tpPos)

	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = lookCFrame
	end)
end

-- ลูปวาร์ปไปหา Orb ใน ClientOrbs แบบต่อเนื่องไม่ติดระยะสแกนแคบ
task.spawn(function()
	while true do
		if isEnabled then
			local token = runToken
			local children = orbsFolder:GetChildren()

			for _, child in ipairs(children) do
				if not isEnabled or token ~= runToken then
					break
				end

				local orbPos = getOrbPosition(child)
				if orbPos then
					teleportToOrb(orbPos)
					local waited = 0
					while waited < TP_DELAY do
						if not isEnabled or token ~= runToken then
							break
						end
						task.wait(0.05)
						waited += 0.05
					end
				end
			end

			task.wait(0.05)
		else
			stopAllMovement()
			task.wait(0.2)
		end
	end
end)
