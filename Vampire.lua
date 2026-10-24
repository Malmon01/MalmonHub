local Players = game:GetService("Players")
local W = game:GetService("Workspace")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("_MazeTileMenu")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "_MazeTileMenu"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(310, 370)
frame.Position = UDim2.new(1, -325, 0.5, -185)
frame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
frame.Parent = gui

local title = Instance.new("TextButton")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "MazeTile — Hide"
title.Parent = frame

local refresh = Instance.new("TextButton")
refresh.Position = UDim2.fromOffset(8, 42)
refresh.Size = UDim2.new(1, -16, 0, 32)
refresh.BackgroundColor3 = Color3.fromRGB(45, 90, 130)
refresh.TextColor3 = Color3.new(1, 1, 1)
refresh.Text = "Refresh"
refresh.TextSize = 14
refresh.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(8, 78)
status.Size = UDim2.new(1, -16, 0, 30)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextSize = 12
status.TextWrapped = true
status.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(8, 112)
list.Size = UDim2.new(1, -16, 1, -120)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromOffset(0, 0)
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local expanded = true

title.Activated:Connect(function()
	expanded = not expanded
	refresh.Visible = expanded
	status.Visible = expanded
	list.Visible = expanded
	frame.Size = UDim2.fromOffset(310, expanded and 370 or 36)
	title.Text = expanded and "MazeTile — Hide" or "MazeTile — Show"
end)

local function teleport(tile)
	if not tile:IsDescendantOf(W) then
		status.Text = "Tile removed — press Refresh"
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		status.Text = "Character not ready"
		return
	end

	local cf, size = tile.CFrame, tile.Size
	local halfHeight =
		math.abs(cf.RightVector.Y) * size.X / 2
		+ math.abs(cf.UpVector.Y) * size.Y / 2
		+ math.abs(cf.LookVector.Y) * size.Z / 2

	local position = tile.Position + Vector3.new(
		0,
		halfHeight + humanoid.HipHeight + root.Size.Y / 2 + 1,
		0
	)

	local destination = CFrame.new(position) * root.CFrame.Rotation
	local offset = root.CFrame:ToObjectSpace(character:GetPivot())

	character:PivotTo(destination * offset)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	status.Text = "Moved to selected MazeTile"
	print("MazeTile destination:", tile:GetFullName())
end

local function roomName(tile)
	local ancestor = tile.Parent
	while ancestor and ancestor ~= W do
		if ancestor:IsA("Model") then
			return ancestor.Name
		end
		ancestor = ancestor.Parent
	end
	return tile.Parent and tile.Parent.Name or "MazeTile"
end

local function rebuild()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local tiles = {}

	for _, object in ipairs(W:GetDescendants()) do
		if object:IsA("BasePart")
			and object.Name:lower() == "mazetile" then
			table.insert(tiles, {
				tile = object,
				room = roomName(object),
				distance = root
					and (object.Position - root.Position).Magnitude
					or 0,
			})
		end
	end

	table.sort(tiles, function(a, b)
		return a.distance < b.distance
	end)

	for index, entry in ipairs(tiles) do
		local tile = entry.tile
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -8, 0, 52)
		button.LayoutOrder = index
		button.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
		button.TextColor3 = Color3.fromRGB(255, 225, 90)
		button.Font = Enum.Font.Gotham
		button.TextSize = 12
		button.TextWrapped = true
		button.Text = string.format(
			"%d. %s\nDistance: %.0f studs",
			index, entry.room, entry.distance
		)
		button.Parent = list

		button.Activated:Connect(function()
			teleport(tile)
		end)
	end

	list.CanvasPosition = Vector2.zero
	status.Text = string.format("Found %d MazeTiles", #tiles)
end

refresh.Activated:Connect(rebuild)
rebuild()
