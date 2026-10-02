-- AUTO HUNTER HIT-LOCK FARM
-- Priority: hit reliability, not long range.
-- Uses current combat system:
-- ReplicatedStorage.Funções.Game15Fists.CombatRemote:FireServer("Attack")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ENV = _G
pcall(function()
	if getgenv then ENV = getgenv() end
end)

if ENV.AutoHunterFarmStop then
	pcall(ENV.AutoHunterFarmStop)
end

local old = PlayerGui:FindFirstChild("AutoHunterFarmGUI")
if old then old:Destroy() end

local NPCS = workspace:FindFirstChild("NPCS")
local HUNTERS = NPCS and NPCS:FindFirstChild("HUNTERS")
local DROPPED_MONEY = workspace:FindFirstChild("DroppedMoney")

local LEVEL_PRESETS = {
	{Name="100-300", Min=100, Max=300},
	{Name="400-900", Min=400, Max=900},
	{Name="1000-3000", Min=1000, Max=3000},
}

local SelectedPreset = 1
local Enabled = false
local Running = true
local CurrentTarget = nil

-- Hit reliability settings
local FOLLOW_DISTANCE = 2.45
local MIN_FOLLOW_DISTANCE = 1.80
local MAX_FOLLOW_DISTANCE = 3.00
local FOLLOW_STEP = 0.10

local MAX_ATTACK_DISTANCE = 2.95
local ATTACK_INTERVAL = 0.47
local REQUIRED_STABLE_FRAMES = 3
local TARGET_RECHECK_INTERVAL = 0.15
local EQUIP_CHECK_INTERVAL = 0.12

local AUTO_MONEY = true
local MONEY_SCAN_INTERVAL = 0.35
local MONEY_TOUCH_COOLDOWN = 0.40

local LastAttack = 0
local LastTargetRecheck = 0
local LastEquipCheck = 0
local LastMoneyScan = 0
local LastCombatResolve = 0
local StableFrames = 0
local LastTargetHealth = nil
local MoneyAttempt = setmetatable({}, {__mode="k"})

local CombatRemote = nil

local function ResolveCombatRemote()
	local f = ReplicatedStorage:FindFirstChild("Fun\195\167\195\181es")
	local g = f and f:FindFirstChild("Game15Fists")
	local r = g and g:FindFirstChild("CombatRemote")

	if r and r:IsA("RemoteEvent") then
		CombatRemote = r
		return r
	end

	CombatRemote = nil
	return nil
end

ResolveCombatRemote()

local function GetCharacter()
	local c = Player.Character or Player.CharacterAdded:Wait()
	return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function SetCharacterCFrame(root, cf)
	if not root or not root.Parent or not cf then
		return false
	end

	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function GetHunterRoot(h)
	if not h then return nil end
	return h:FindFirstChild("HumanoidRootPart")
		or h:FindFirstChild("UpperTorso")
		or h:FindFirstChild("Torso")
		or h.PrimaryPart
end

local function GetHunterLevel(h)
	if not h then return nil end

	for _, n in ipairs({"Level","Lvl","level","lvl"}) do
		local v = h:GetAttribute(n)
		if typeof(v) == "number" then return math.floor(v) end
		if typeof(v) == "string" and tonumber(v) then return math.floor(tonumber(v)) end
	end

	for _, o in ipairs(h:GetDescendants()) do
		if o:IsA("IntValue") or o:IsA("NumberValue") or o:IsA("StringValue") then
			local n = string.lower(o.Name)
			if n == "level" or n == "lvl" then
				local v = tonumber(o.Value)
				if v then return math.floor(v) end
			end
		end
	end

	for _, o in ipairs(h:GetDescendants()) do
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			local t = tostring(o.Text)
			local lv = string.match(t, "[Ll][Vv]%s*%.?%s*(%d+)")
				or string.match(t, "[Ll]evel%s*(%d+)")
			if lv then return tonumber(lv) end
		end
	end

	return nil
end

local function IsValidHunter(h)
	if not h or not h:IsA("Model") or h.Name ~= "Hunter" then return false end

	local hum = h:FindFirstChildOfClass("Humanoid")
	local root = GetHunterRoot(h)
	if not hum or hum.Health <= 0 or not root then return false end

	local lv = GetHunterLevel(h)
	if not lv then return false end

	local p = LEVEL_PRESETS[SelectedPreset]
	return lv >= p.Min and lv <= p.Max
end

local function FindNearestHunter(playerRoot)
	if not HUNTERS or not playerRoot then return nil end

	local best, bestDist = nil, math.huge

	for _, h in ipairs(HUNTERS:GetChildren()) do
		if IsValidHunter(h) then
			local r = GetHunterRoot(h)
			if r then
				local d = (r.Position - playerRoot.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = h
				end
			end
		end
	end

	return best
end

local function EquipFists(c, hum)
	if not c or not hum or hum.Health <= 0 then return nil end

	local fists = c:FindFirstChild("Fists")
	if fists and fists:IsA("Tool") then return fists end

	local bp = Player:FindFirstChild("Backpack")
	fists = bp and bp:FindFirstChild("Fists")

	if fists and fists:IsA("Tool") then
		pcall(function() hum:EquipTool(fists) end)
		task.wait(0.015)
		return c:FindFirstChild("Fists")
	end

	return nil
end

local function RearCFrame(target)
	local root = GetHunterRoot(target)
	if not root then return nil end

	-- +Z local = directly behind Hunter.
	local pos = (root.CFrame * CFrame.new(0, 0, FOLLOW_DISTANCE)).Position
	return CFrame.lookAt(pos, root.Position)
end

local function FireAttack()
	local r = CombatRemote
	if not r or not r.Parent then
		r = ResolveCombatRemote()
	end
	if not r then return false end

	return pcall(function()
		r:FireServer("Attack")
	end)
end

local function GetMoneyPart(bag)
	if bag:IsA("BasePart") then return bag end
	if bag:IsA("Model") and bag.PrimaryPart then return bag.PrimaryPart end
	return bag:FindFirstChildWhichIsA("BasePart", true)
end

local function CollectMoney(playerRoot)
	if not AUTO_MONEY or not DROPPED_MONEY or not playerRoot then return end
	if type(firetouchinterest) ~= "function" then return end

	for _, bag in ipairs(DROPPED_MONEY:GetChildren()) do
		if bag.Name == "KillMoneyBag" then
			local part = GetMoneyPart(bag)
			if part then
				local now = os.clock()
				if not MoneyAttempt[bag] or now - MoneyAttempt[bag] >= MONEY_TOUCH_COOLDOWN then
					MoneyAttempt[bag] = now
					pcall(function()
						firetouchinterest(playerRoot, part, 0)
						task.wait()
						firetouchinterest(playerRoot, part, 1)
					end)
				end
			end
		end
	end
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoHunterFarmGUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local open = Instance.new("TextButton")
open.Size = UDim2.fromOffset(145,44)
open.Position = UDim2.new(0,15,0.5,-22)
open.BackgroundColor3 = Color3.fromRGB(24,24,30)
open.Text = "HUNTER HIT LOCK"
open.TextColor3 = Color3.new(1,1,1)
open.Font = Enum.Font.GothamBold
open.TextSize = 13
open.Parent = gui
Instance.new("UICorner",open).CornerRadius = UDim.new(0,10)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(410,430)
frame.Position = UDim2.new(0.5,-205,0.5,-215)
frame.BackgroundColor3 = Color3.fromRGB(18,18,24)
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,0,50)
title.Position = UDim2.fromOffset(18,2)
title.BackgroundTransparency = 1
title.Text = "Auto Hunter Hit Lock"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(40,40)
close.Position = UDim2.new(1,-48,0,7)
close.BackgroundColor3 = Color3.fromRGB(180,55,55)
close.Text = "×"
close.TextColor3 = Color3.new(1,1,1)
close.Font = Enum.Font.GothamBold
close.TextSize = 27
close.Parent = frame
Instance.new("UICorner",close).CornerRadius = UDim.new(0,10)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1,-36,0,46)
toggle.Position = UDim2.fromOffset(18,58)
toggle.TextColor3 = Color3.new(1,1,1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 16
toggle.Parent = frame
Instance.new("UICorner",toggle).CornerRadius = UDim.new(0,10)

local lt = Instance.new("TextLabel")
lt.Size = UDim2.new(1,0,0,28)
lt.Position = UDim2.fromOffset(0,112)
lt.BackgroundTransparency = 1
lt.Text = "Hunter Level"
lt.TextColor3 = Color3.new(1,1,1)
lt.Font = Enum.Font.GothamBold
lt.TextSize = 15
lt.Parent = frame

local levelButtons = {}

for i,p in ipairs(LEVEL_PRESETS) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0,115,0,38)
	b.Position = UDim2.fromOffset(21 + ((i-1)*124),143)
	b.Text = p.Name
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Parent = frame
	Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
	levelButtons[i] = b
end

local dt = Instance.new("TextLabel")
dt.Size = UDim2.new(1,0,0,28)
dt.Position = UDim2.fromOffset(0,194)
dt.BackgroundTransparency = 1
dt.Text = "Hit-Lock Distance"
dt.TextColor3 = Color3.new(1,1,1)
dt.Font = Enum.Font.GothamBold
dt.TextSize = 15
dt.Parent = frame

local minus = Instance.new("TextButton")
minus.Size = UDim2.fromOffset(62,42)
minus.Position = UDim2.fromOffset(70,224)
minus.BackgroundColor3 = Color3.fromRGB(65,65,75)
minus.Text = "−"
minus.TextColor3 = Color3.new(1,1,1)
minus.Font = Enum.Font.GothamBold
minus.TextSize = 26
minus.Parent = frame
Instance.new("UICorner",minus).CornerRadius = UDim.new(0,8)

local dvalue = Instance.new("TextLabel")
dvalue.Size = UDim2.fromOffset(110,42)
dvalue.Position = UDim2.new(0.5,-55,0,224)
dvalue.BackgroundTransparency = 1
dvalue.TextColor3 = Color3.new(1,1,1)
dvalue.Font = Enum.Font.GothamBold
dvalue.TextSize = 22
dvalue.Parent = frame

local plus = Instance.new("TextButton")
plus.Size = UDim2.fromOffset(62,42)
plus.Position = UDim2.new(1,-132,0,224)
plus.BackgroundColor3 = Color3.fromRGB(45,155,80)
plus.Text = "+"
plus.TextColor3 = Color3.new(1,1,1)
plus.Font = Enum.Font.GothamBold
plus.TextSize = 26
plus.Parent = frame
Instance.new("UICorner",plus).CornerRadius = UDim.new(0,8)

local moneyBtn = Instance.new("TextButton")
moneyBtn.Size = UDim2.new(1,-36,0,42)
moneyBtn.Position = UDim2.fromOffset(18,286)
moneyBtn.TextColor3 = Color3.new(1,1,1)
moneyBtn.Font = Enum.Font.GothamBold
moneyBtn.TextSize = 14
moneyBtn.Parent = frame
Instance.new("UICorner",moneyBtn).CornerRadius = UDim.new(0,9)

local remoteStatus = Instance.new("TextLabel")
remoteStatus.Size = UDim2.new(1,-20,0,27)
remoteStatus.Position = UDim2.fromOffset(10,342)
remoteStatus.BackgroundTransparency = 1
remoteStatus.TextColor3 = Color3.fromRGB(135,190,230)
remoteStatus.Font = Enum.Font.GothamBold
remoteStatus.TextSize = 12
remoteStatus.Parent = frame

local hitStatus = Instance.new("TextLabel")
hitStatus.Size = UDim2.new(1,-20,0,27)
hitStatus.Position = UDim2.fromOffset(10,369)
hitStatus.BackgroundTransparency = 1
hitStatus.Text = "Hit status: waiting"
hitStatus.TextColor3 = Color3.fromRGB(175,200,145)
hitStatus.Font = Enum.Font.GothamBold
hitStatus.TextSize = 12
hitStatus.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-20,0,42)
status.Position = UDim2.new(0,10,1,-48)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(160,215,165)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Parent = frame

local function UpdateGUI()
	toggle.Text = Enabled and "AUTO HUNTER : ON" or "AUTO HUNTER : OFF"
	toggle.BackgroundColor3 =
		Enabled
		and Color3.fromRGB(45,155,80)
		or Color3.fromRGB(170,55,55)

	for i,b in ipairs(levelButtons) do
		b.BackgroundColor3 =
			(i == SelectedPreset)
			and Color3.fromRGB(45,145,80)
			or Color3.fromRGB(60,60,70)
	end

	dvalue.Text = string.format("%.2f", FOLLOW_DISTANCE)

	moneyBtn.Text =
		AUTO_MONEY
		and "AUTO MONEY : ON"
		or "AUTO MONEY : OFF"

	moneyBtn.BackgroundColor3 =
		AUTO_MONEY
		and Color3.fromRGB(180,135,45)
		or Color3.fromRGB(65,65,75)

	remoteStatus.Text =
		(CombatRemote and CombatRemote.Parent)
		and "CombatRemote: READY | strict distance check"
		or "CombatRemote: NOT FOUND"
end

for i,b in ipairs(levelButtons) do
	b.MouseButton1Click:Connect(function()
		SelectedPreset = i
		CurrentTarget = nil
		StableFrames = 0
		LastTargetHealth = nil
		UpdateGUI()
	end)
end

toggle.MouseButton1Click:Connect(function()
	Enabled = not Enabled
	CurrentTarget = nil
	StableFrames = 0
	LastTargetHealth = nil

	if Enabled then
		ResolveCombatRemote()
		local c,h = GetCharacter()
		EquipFists(c,h)
		status.Text = "Searching Hunter..."
	else
		status.Text = "Stopped"
	end

	UpdateGUI()
end)

minus.MouseButton1Click:Connect(function()
	FOLLOW_DISTANCE =
		math.clamp(
			FOLLOW_DISTANCE - FOLLOW_STEP,
			MIN_FOLLOW_DISTANCE,
			MAX_FOLLOW_DISTANCE
		)
	UpdateGUI()
end)

plus.MouseButton1Click:Connect(function()
	FOLLOW_DISTANCE =
		math.clamp(
			FOLLOW_DISTANCE + FOLLOW_STEP,
			MIN_FOLLOW_DISTANCE,
			MAX_FOLLOW_DISTANCE
		)
	UpdateGUI()
end)

moneyBtn.MouseButton1Click:Connect(function()
	AUTO_MONEY = not AUTO_MONEY
	UpdateGUI()
end)

open.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)

close.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Respawn
Player.CharacterAdded:Connect(function(c)
	CurrentTarget = nil
	StableFrames = 0
	LastTargetHealth = nil

	if Enabled then
		c:WaitForChild("Humanoid",10)
		c:WaitForChild("HumanoidRootPart",10)
		task.wait(0.6)
		local hum = c:FindFirstChildOfClass("Humanoid")
		EquipFists(c,hum)
	end
end)

-- Remote recovery
task.spawn(function()
	while Running and gui.Parent do
		local now = os.clock()
		if (not CombatRemote or not CombatRemote.Parent)
			and now - LastCombatResolve >= 1 then

			LastCombatResolve = now
			ResolveCombatRemote()
			UpdateGUI()
		end
		task.wait(0.25)
	end
end)

-- Money
task.spawn(function()
	while Running and gui.Parent do
		if Enabled and AUTO_MONEY then
			local now = os.clock()
			if now - LastMoneyScan >= MONEY_SCAN_INTERVAL then
				LastMoneyScan = now
				local _,hum,root = GetCharacter()
				if hum and hum.Health > 0 and root then
					CollectMoney(root)
				end
			end
		end
		task.wait(0.08)
	end
end)

-- Main Heartbeat tracking
local HeartbeatConnection

HeartbeatConnection = RunService.Heartbeat:Connect(function()
	if not Running or not gui.Parent or not Enabled then return end

	local c,hum,root = GetCharacter()
	if not hum or hum.Health <= 0 or not root then return end

	local now = os.clock()

	if now - LastEquipCheck >= EQUIP_CHECK_INTERVAL then
		LastEquipCheck = now
		EquipFists(c,hum)
	end

	if not IsValidHunter(CurrentTarget) then
		CurrentTarget = nil
		StableFrames = 0
		LastTargetHealth = nil
	end

	if not CurrentTarget
		and now - LastTargetRecheck >= TARGET_RECHECK_INTERVAL then

		LastTargetRecheck = now
		CurrentTarget = FindNearestHunter(root)

		if CurrentTarget then
			local th = CurrentTarget:FindFirstChildOfClass("Humanoid")
			LastTargetHealth = th and th.Health or nil
		end
	end

	if not CurrentTarget then
		local p = LEVEL_PRESETS[SelectedPreset]
		status.Text = "No Hunter Lv "..p.Name
		hitStatus.Text = "Hit status: waiting"
		return
	end

	local rear = RearCFrame(CurrentTarget)
	if rear then
		SetCharacterCFrame(root,rear)
	end

	local targetRoot = GetHunterRoot(CurrentTarget)
	local targetHum = CurrentTarget:FindFirstChildOfClass("Humanoid")

	if not targetRoot or not targetHum or targetHum.Health <= 0 then
		CurrentTarget = nil
		return
	end

	-- Confirm actual HP drop.
	if LastTargetHealth and targetHum.Health < LastTargetHealth then
		hitStatus.Text = "Hit status: CONFIRMED"
	end
	LastTargetHealth = targetHum.Health

	-- Actual distance after following.
	local realDistance = (targetRoot.Position - root.Position).Magnitude

	if realDistance <= MAX_ATTACK_DISTANCE then
		StableFrames += 1
	else
		StableFrames = 0
	end

	local lv = GetHunterLevel(CurrentTarget)

	status.Text =
		"Hunter Lv "
		.. tostring(lv or "?")
		.. " | HP "
		.. tostring(math.floor(targetHum.Health))
		.. " | Dist "
		.. string.format("%.2f",realDistance)

	if StableFrames >= REQUIRED_STABLE_FRAMES
		and now - LastAttack >= ATTACK_INTERVAL then

		local fists = EquipFists(c,hum)
		if not fists then return end

		if not CombatRemote or not CombatRemote.Parent then
			ResolveCombatRemote()
			if not CombatRemote then
				remoteStatus.Text = "CombatRemote: NOT FOUND"
				return
			end
		end

		-- One more strict range check immediately before FireServer.
		realDistance = (targetRoot.Position - root.Position).Magnitude

		if realDistance <= MAX_ATTACK_DISTANCE then
			LastAttack = now
			hitStatus.Text = "Hit status: attacking..."
			FireAttack()
		end
	end
end)

-- Drag GUI
do
	local dragging = false
	local dragStart
	local startPos

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then

			local d = input.Position - dragStart
			frame.Position =
				UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset+d.X,
					startPos.Y.Scale,
					startPos.Y.Offset+d.Y
				)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			dragging = false
		end
	end)
end

local function Stop()
	Running = false
	Enabled = false

	if HeartbeatConnection then
		pcall(function()
			HeartbeatConnection:Disconnect()
		end)
		HeartbeatConnection = nil
	end

	if gui then gui:Destroy() end
	print("[Auto Hunter Hit Lock] stopped")
end

ENV.AutoHunterFarmStop = Stop

UpdateGUI()

print("==============================================")
print(" AUTO HUNTER HIT LOCK READY")
print(" Priority: HIT RELIABILITY")
print(" Follow distance:", FOLLOW_DISTANCE)
print(" Attack only <=", MAX_ATTACK_DISTANCE)
print(" Stable frames:", REQUIRED_STABLE_FRAMES)
print(" Attack interval:", ATTACK_INTERVAL)
print("==============================================")
