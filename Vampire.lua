local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MULTIPLIER = 5
local TRANSPARENCY = 0.6

local function ExpandHitbox(player)
    if player == LocalPlayer then return end

    local function Apply(character)
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root then return end

        local originalSize = root.Size

        root.Size = Vector3.new(
            originalSize.X * MULTIPLIER,
            originalSize.Y,
            originalSize.Z * MULTIPLIER
        )

        root.Transparency = TRANSPARENCY
        root.CanCollide = false
    end

    player.CharacterAdded:Connect(Apply)

    if player.Character then
        Apply(player.Character)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    ExpandHitbox(player)
end

Players.PlayerAdded:Connect(ExpandHitbox)
