local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
	Players.PlayerAdded:Wait()
	player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui")

-- ================= ตั้งค่า =================
local DEFAULT_ENABLED = false
local TP_DELAY = 1.35
local MAX_SCAN_DISTANCE = 95
local MIN_TP_DISTANCE = 2.0
local DISTANCE_PENALTY = 18
local HEIGHT_OFFSET = 0.5
local AUTO_REBIRTH_ENABLED = true
local REBIRTH_COOLDOWN = 2.0
-- ==========================================

local isEnabled = (DEFAULT_ENABLED == true)
local runToken = 0
local lastRebirthTime = 0

pcall(function()
	local oldGui = playerGui:FindFirstChild("OrbTpGui")
	if oldGui then
		oldGui:Destroy()
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbTpGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 2147483647
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
btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
btn.Text = "TP ORB: OFF"
btn.BorderSizePixel = 0
btn.Active = true
btn.AutoButtonColor = true
btn.ZIndex = 2147483647
btn.Parent = screenGui

pcall(function()
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(15, 15, 15)
	stroke.Thickness = 2
end)

local function refreshButtonVisual()
	pcall(function()
		if isEnabled then
			btn.Text = "TP ORB: ON"
			btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
		else
			btn.Text = "TP ORB: OFF"
			btn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
		end
	end)
end

local function toggleState()
	isEnabled = not isEnabled
	runToken += 1
	refreshButtonVisual()
end

refreshButtonVisual()
btn.MouseButton1Click:Connect(toggleState)
btn.Activated:Connect(toggleState)

local function getCharRoot()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart", true)
end

local function isGuiReallyVisible(guiObj)
	local current = guiObj
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function clickGuiCenter(guiObj)
	local absPos = guiObj.AbsolutePosition
	local absSize = guiObj.AbsoluteSize
	if absSize.X <= 1 or absSize.Y <= 1 then return false end

	local inset = GuiService:GetGuiInset()
	local x = absPos.X + (absSize.X * 0.5) + inset.X
	local y = absPos.Y + (absSize.Y * 0.5) + inset.Y

	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
	end)
	return true
end

local function tryAutoRebirth()
	if not AUTO_REBIRTH_ENABLED or not isEnabled then return end
	if os.clock() - lastRebirthTime < REBIRTH_COOLDOWN then return end

	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui ~= screenGui and gui:IsA("ScreenGui") and gui.Enabled then
			for _, desc in ipairs(gui:GetDescendants()) do
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					local upperText = string.upper(desc.Text or "")
					if string.find(upperText, "REBIRTH", 1, true) and isGuiReallyVisible(desc) then
						local clickable = nil
						if desc:IsA("GuiButton") and desc.Active then
							clickable = desc
						elseif desc.Parent and desc.Parent:IsA("GuiButton") and desc.Parent.Active then
							clickable = desc.Parent
						end

						if clickable and clickable.AbsoluteSize.X > 20 then
							lastRebirthTime = os.clock()
							clickGuiCenter(clickable)
							pcall(function()
								VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
								task.wait(0.05)
								VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
							end)
							return
						end
					end
				end
			end
		end
	end
end

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

local function parseAbbreviatedNumber(raw)
	if type(raw) == "number" then return raw end
	if type(raw) ~= "string" then return nil end
	local cleaned = string.gsub(raw, ",", "")
	local numPart, suffix = string.match(cleaned, "^%s*([%d%.]+)%s*([KkMmBbTt]?)%s*$")
	if not numPart then return nil end
	local n = tonumber(numPart)
	if not n then return nil end
	local mult = 1
	local s = string.upper(suffix or "")
	if s == "K" then mult = 1e3
	elseif s == "M" then mult = 1e6
	elseif s == "B" then mult = 1e9
	elseif s == "T" then mult = 1e12
	end
	return n * mult
end

local function isExpKeyword(nameStr)
	local lower = string.lower(nameStr or "")
	return string.find(lower, "exp", 1, true)
		or string.find(lower, "xp", 1, true)
		or string.find(lower, "val", 1, true)
		or string.find(lower, "amt", 1, true)
		or string.find(lower, "amount", 1, true)
		or string.find(lower, "power", 1, true)
		or string.find(lower, "reward", 1, true)
		or string.find(lower, "size", 1, true)
		or string.find(lower, "tier", 1, true)
end

local function getOrbExpScore(obj)
	if not obj or not obj.Parent then return 0 end

	local bestScore = 0
	local foundExplicitValue = false

	local function scanAttributes(inst)
		for attrName, attrVal in pairs(inst:GetAttributes()) do
			if isExpKeyword(attrName) then
				local parsed = parseAbbreviatedNumber(attrVal)
				if parsed and parsed > 0 then
					foundExplicitValue = true
					if parsed > bestScore then
						bestScore = parsed
					end
				end
			end
		end
	end

	scanAttributes(obj)
	for _, desc in ipairs(obj:GetDescendants()) do
		scanAttributes(desc)
		if desc:IsA("NumberValue") or desc:IsA("IntValue") or desc:IsA("StringValue") then
			if isExpKeyword(desc.Name) then
				local parsed = parseAbbreviatedNumber(desc.Value)
				if parsed and parsed > 0 then
					foundExplicitValue = true
					if parsed > bestScore then
						bestScore = parsed
					end
				end
			end
		end
	end

	if foundExplicitValue then
		return bestScore
	end

	if obj:IsA("BasePart") then
		local s = obj.Size
		return s.X * s.Y * s.Z
	elseif obj:IsA("Model") then
		local _, size = obj:GetBoundingBox()
		return size.X * size.Y * size.Z
	else
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local s = part.Size
			return s.X * s.Y * s.Z
		end
	end

	return 1
end

local function findBestOrbPos(currentPos)
	local orbsFolder = Workspace:FindFirstChild("ClientOrbs")
	if not orbsFolder then return nil end

	local bestPos = nil
	local bestWeightedScore = -math.huge

	for _, child in ipairs(orbsFolder:GetChildren()) do
		local orbPos = getOrbPosition(child)
		if orbPos then
			local dist = (orbPos - currentPos).Magnitude
			if dist >= MIN_TP_DISTANCE and dist <= MAX_SCAN_DISTANCE then
				local rawScore = math.max(1, getOrbExpScore(child))
				local weightedScore = rawScore / (1 + (dist / DISTANCE_PENALTY))
				if weightedScore > bestWeightedScore then
					bestWeightedScore = weightedScore
					bestPos = orbPos
				end
			end
		end
	end

	return bestPos
end

local function waitInterruptible(seconds, token)
	local elapsed = 0
	while elapsed < seconds do
		if not isEnabled or token ~= runToken then
			return false
		end
		local step = math.min(0.1, seconds - elapsed)
		task.wait(step)
		elapsed += step
	end
	return isEnabled and (token == runToken)
end

local function teleportToOrb(orbPos)
	local root = getCharRoot()
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

task.spawn(function()
	while true do
		if isEnabled then
			pcall(tryAutoRebirth)
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		if isEnabled then
			local token = runToken
			pcall(function()
				local root = getCharRoot()
				if root and root:IsA("BasePart") then
					local targetPos = findBestOrbPos(root.Position)
					if targetPos then
						teleportToOrb(targetPos)
					end
				end
			end)
			waitInterruptible(TP_DELAY, token)
		else
			task.wait(0.2)
		end
	end
end)
