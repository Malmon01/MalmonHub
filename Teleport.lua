local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAP_NAME = "Arcade by D4niel_Foxy"
local RED = Color3.fromRGB(255, 60, 60)
local BLUE = Color3.fromRGB(70, 180, 255)
local GREEN = Color3.fromRGB(60, 255, 100)

local container = Instance.new("Folder")
container.Name = "RoleHighlights"
container.Parent = Workspace

local markers = {}

local function isBeast(player, character)
	local stats = player:FindFirstChild("TempPlayerStatsModule")
	local flag = stats and stats:FindFirstChild("IsBeast")

	-- Prefer the explicit role flag.
	if flag and flag:IsA("BoolValue") then
		return flag.Value
	end

	-- Fallback while player stats are unavailable.
	local cave = Workspace:FindFirstChild("BeastCave")
	return cave ~= nil
		and character:IsDescendantOf(cave)
		and (
			character:FindFirstChild("BeastPowers") ~= nil
			or character:FindFirstChild("BeastPower") ~= nil
		)
end

local function updateMarker(target, color, nameText)
	local marker = markers[target]

	if not marker then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RoleHighlight"
		highlight.Adornee = target
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 0.65
		highlight.OutlineTransparency = 0
		highlight.Parent = container

		marker = { highlight = highlight }
		markers[target] = marker
	end

	marker.highlight.FillColor = color
	marker.highlight.OutlineColor = color

	if nameText then
		local head = target:FindFirstChild("Head")
		local anchor = head or target:FindFirstChild("HumanoidRootPart")

		if anchor and anchor:IsA("BasePart") then
			if not marker.gui then
				local gui = Instance.new("BillboardGui")
				gui.Name = "PlayerName"
				gui.Size = UDim2.fromOffset(240, 48)
				gui.StudsOffset = Vector3.new(0, 3, 0)
				gui.AlwaysOnTop = true
				gui.Parent = container

				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBold
				label.TextSize = 15
				label.TextStrokeTransparency = 0.25
				label.Parent = gui

				marker.gui = gui
				marker.label = label
			end

			marker.gui.Adornee = anchor
			marker.gui.Enabled = true
			marker.label.Text = nameText
			marker.label.TextColor3 = color
		elseif marker.gui then
			marker.gui.Enabled = false
		end
	end
end

while script:IsDescendantOf(game) do
	local active = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character

		if character and character:IsDescendantOf(Workspace) then
			local beast = isBeast(player, character)
			local role = beast and "BEAST" or "SURVIVOR"
			local text = string.format(
				"%s (@%s)\n%s",
				player.DisplayName,
				player.Name,
				role
			)

			active[character] = true
			updateMarker(character, beast and RED or BLUE, text)
		end
	end

	local map = Workspace:FindFirstChild(MAP_NAME)

	if map then
		for _, object in ipairs(map:GetDescendants()) do
			if object.Name == "ComputerTable"
				and (object:IsA("Model") or object:IsA("BasePart")) then
				active[object] = true
				updateMarker(object, GREEN)
			end
		end
	end

	-- Remove markers for old characters or unloaded objects.
	for target, marker in pairs(markers) do
		if not active[target] then
			marker.highlight:Destroy()
			if marker.gui then
				marker.gui:Destroy()
			end
			markers[target] = nil
		end
	end

	task.wait(0.5)
end

container:Destroy()
