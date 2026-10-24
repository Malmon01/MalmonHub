local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RED = Color3.fromRGB(255, 50, 50)
local BLUE = Color3.fromRGB(50, 180, 255)
local GREEN = Color3.fromRGB(50, 255, 80)

-- Re-running replaces this script's previous effects.
local ROOT_NAME = "_RoleHighlightEffects"
local oldRoot = Workspace:FindFirstChild(ROOT_NAME)
if oldRoot then oldRoot:Destroy() end

local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = Workspace

local tracked = {}

-- Remove the green test highlight.
local me = Players.LocalPlayer
local myCharacter = me and me.Character
local test = myCharacter and myCharacter:FindFirstChild("HighlightTest")
if test then test:Destroy() end

local function mark(target, color, text)
	local entry = tracked[target]

	if not entry then
		local h = Instance.new("Highlight")
		h.Adornee = target
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.4
		h.OutlineTransparency = 0
		h.Parent = root

		entry = { highlight = h }
		tracked[target] = entry
	end

	entry.highlight.FillColor = color
	entry.highlight.OutlineColor = color

	if text then
		local head = target:FindFirstChild("Head")
			or target:FindFirstChild("HumanoidRootPart")

