print("HL: START")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local function mark(object, color)
	local h = object:FindFirstChild("_DiagnosticHighlight")

	if not h then
		h = Instance.new("Highlight")
		h.Name = "_DiagnosticHighlight"
		h.Parent = object
	end

	h.Adornee = object
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.3
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = true
end

for _, player in ipairs(Players:GetPlayers()) do
	local character = player.Character
	local stats = player:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")

	if character and flag and flag:IsA("BoolValue") then
		-- Remove highlights from earlier tests on this character.
		for _, name in ipairs({"HighlightTest", "_LiveRoleHighlight"}) do
			local old = character:FindFirstChild(name)
			if old then old:Destroy() end
		end

		local color = flag.Value
			and Color3.fromRGB(255, 50, 50)
			or Color3.fromRGB(50, 180, 255)

		mark(character, color)
		print("HL: PLAYER", player.Name, "BEAST", flag.Value)
	end
end

print("HL: PLAYERS DONE")

local count = 0
for _, object in ipairs(Workspace:GetDescendants()) do
	if object.Name == "ComputerTable"
		and (object:IsA("Model") or object:IsA("BasePart")) then
		local old = object:FindFirstChild("_LiveRoleHighlight")
		if old then old:Destroy() end

		mark(object, Color3.fromRGB(50, 255, 80))
		count = count + 1
	end
end

print("HL: COMPUTERS", count)
print("HL: DONE")
