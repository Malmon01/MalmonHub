local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RED = Color3.fromRGB(255, 50, 50)
local BLUE = Color3.fromRGB(50, 180, 255)
local GREEN = Color3.fromRGB(50, 255, 80)

-- A new run stops the previous loop.
local key = "_RoleHighlightRun"
local runId = (Players.LocalPlayer:GetAttribute(key) or 0) + 1
Players.LocalPlayer:SetAttribute(key, runId)

local function highlight(target, color)
	local h = target:FindFirstChild("_LiveRoleHighlight")

	if not h then
		h = Instance.new("Highlight")
		h.Name = "_LiveRoleHighlight"
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.35
		h.OutlineTransparency = 0
		h.Parent = target
	end

	h.FillColor = color
	h.OutlineColor = color
	h.Enabled = true
end

local function nameTag(character, player, beast, color)
	local head = character:FindFirstChild("Head")
	if not head then return end

	local gui = head:FindFirstChild("_LiveRoleName")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "_LiveRoleName"
		gui.Adornee = head
		gui.Size = UDim2.fromOffset(250, 50)
		gui.StudsOffset = Vector3.new(0, 2.5, 0)
		gui.AlwaysOnTop = true
		gui.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end

	gui.Label.Text = player.DisplayName .. " (@" .. player.Name .. ")\n"
		.. (beast and "BEAST" or "SURVIVOR")
	gui.Label.TextColor3 = color
end

-- Remove effects created by the previous examples.
local previous = Workspace:FindFirstChild("_RoleHighlightEffects")
if previous then previous:Destroy() end

previous = Workspace:FindFirstChild("RoleHighlights")
if previous then previous:Destroy() end

local computers = {}

local function registerComputer(object)
	if object.Name:lower() == "computertable"
		and (object:IsA("Model") or object:IsA("BasePart")) then
		computers[object] = true
	end
end

local added = Workspace.DescendantAdded:Connect(registerComputer)

for _, object in ipairs(Workspace:GetDescendants()) do
	registerComputer(object)
end

task.spawn(function()
	while Players.LocalPlayer:GetAttribute(key) == runId do
		local ok, err = pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character

				if character and character:IsDescendantOf(Workspace) then
					for _, name in ipairs({
						"HighlightTest",
						"_DiagnosticHighlight",
					}) do
						local old = character:FindFirstChild(name)
						if old then old:Destroy() end
					end

					local stats = player:FindFirstChild("TempPlayerStatsModule")
					local flag = stats and stats:FindFirstChild("IsBeast")

					if flag and flag:IsA("BoolValue") then
						local beast = flag.Value
						local color = beast and RED or BLUE

						highlight(character, color)
						nameTag(character, player, beast, color)
					end
				end
			end

			for computer in pairs(computers) do
				if computer:IsDescendantOf(Workspace) then
					highlight(computer, GREEN)
				else
					computers[computer] = nil
				end
			end
		end)

		if not ok then
			warn("RoleHighlight error:", err)
		end

		task.wait(0.5)
	end

	added:Disconnect()
end)

print("RoleHighlight started: RED beast / BLUE survivors / GREEN computers")
