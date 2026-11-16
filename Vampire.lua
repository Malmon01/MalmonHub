--// Orb Auto Collect (SandOrbs / VoidOrbs) - Nearest First
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Settings = {
	SandOrb = false,
	VoidOrb = false,
}

local FOLDERS = {
	SandOrb = "SandOrbs",
	VoidOrb = "VoidOrbs",
}

local COLLECT_TIMEOUT = 1.5   -- รอให้ orb หายไปสูงสุดกี่วินาที
local DELAY_BETWEEN   = 0.15  -- หน่วงระหว่างวาร์ปแต่ละครั้ง
local SKIP_COOLDOWN   = 5     -- ถ้าเก็บแล้ว orb ไม่หาย จะข้ามอันนั้นกี่วินาที

local recentlyVisited = setmetatable({}, { __mode = "k" })
local running = false

-- หา HumanoidRootPart
local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- หา Part หลักของ orb (รองรับทั้ง Model และ Part)
local function getOrbPart(orb)
	if orb:IsA("BasePart") then
		return orb
	elseif orb:IsA("Model") then
		return orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart", true)
	end
end

-- รวบรวม orb จากโฟลเดอร์ที่เปิดอยู่
local function getOrbs()
	local list = {}
	local now = tick()
	for key, enabled in pairs(Settings) do
		if enabled then
			local folder = workspace:FindFirstChild(FOLDERS[key])
			if folder then
				for _, orb in ipairs(folder:GetChildren()) do
					local part = getOrbPart(orb)
					local last = recentlyVisited[orb]
					if part and not (last and now - last < SKIP_COOLDOWN) then
						table.insert(list, { orb = orb, part = part })
					end
				end
			end
		end
	end
	return list
end

-- เลือก orb ที่ใกล้ที่สุด
local function getNearest(root, list)
	local best, bestDist = nil, math.huge
	for _, data in ipairs(list) do
		local dist = (data.part.Position - root.Position).Magnitude
		if dist < bestDist then
			best, bestDist = data, dist
		end
	end
	return best
end

-- วาร์ปไปเก็บ
local function collect(root, data)
	local orb, part = data.orb, data.part
	root.CFrame = CFrame.new(part.Position)

	-- กรณีเก็บด้วยการแตะ
	if firetouchinterest then
		for _, p in ipairs(orb:IsA("BasePart") and { orb } or orb:GetDescendants()) do
			if p:IsA("BasePart") then
				firetouchinterest(root, p, 0)
				firetouchinterest(root, p, 1)
			end
		end
	end

	-- กรณีเก็บด้วย ProximityPrompt
	local prompt = orb:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		fireproximityprompt(prompt)
	end

	-- รอจน orb หายไป หรือหมดเวลา
	local t = tick()
	while orb.Parent and tick() - t < COLLECT_TIMEOUT do
		task.wait()
	end
	if orb.Parent then
		recentlyVisited[orb] = tick() -- ยังไม่หาย ข้ามไปก่อน
	end
end

-- ลูปหลัก (ใช้ร่วมกันทั้ง 2 ตัวเลือก)
local function startLoop()
	if running then return end
	running = true
	task.spawn(function()
		while Settings.SandOrb or Settings.VoidOrb do
			local root = getRoot()
			if root then
				local target = getNearest(root, getOrbs())
				if target then
					collect(root, target)
					task.wait(DELAY_BETWEEN)
				else
					task.wait(0.5) -- ไม่มี orb รอ spawn
				end
			else
				task.wait(1) -- ตัวละครยังไม่เกิด
			end
		end
		running = false
	end)
end

--================ ฟังก์ชันเปิด/ปิด ================--

function ToggleSandOrb(state)
	if state == nil then state = not Settings.SandOrb end
	Settings.SandOrb = state
	print("[SandOrb]", state and "ON" or "OFF")
	if state then startLoop() end
	return state
end

function ToggleVoidOrb(state)
	if state == nil then state = not Settings.VoidOrb end
	Settings.VoidOrb = state
	print("[VoidOrb]", state and "ON" or "OFF")
	if state then startLoop() end
	return state
end

--================ ปุ่ม GUI ง่าย ๆ ================--

local gui = Instance.new("ScreenGui")
gui.Name = "OrbCollector"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function makeButton(text, y, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 160, 0, 36)
	btn.Position = UDim2.new(0, 20, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = text .. ": OFF"
	btn.Parent = gui
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		local on = callback()
		btn.Text = text .. (on and ": ON" or ": OFF")
		btn.BackgroundColor3 = on and Color3.fromRGB(50, 170, 80) or Color3.fromRGB(170, 50, 50)
	end)
end

makeButton("SandOrb", 200, function() return ToggleSandOrb() end)
makeButton("VoidOrb", 245, function() return ToggleVoidOrb() end)
