
local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local folder = workspace:WaitForChild("HalloweenCandy")
local root = (player.Character or player.CharacterAdded:Wait())
    :WaitForChild("HumanoidRootPart")

local HOME = root.CFrame
local activePrompts = {}

PPS.PromptShown:Connect(function(prompt)
    activePrompts[prompt] = true
    print("[E FOUND]", prompt:GetFullName())
    print("Hold:", prompt.HoldDuration)
end)

PPS.PromptHidden:Connect(function(prompt)
    activePrompts[prompt] = nil
end)

local function getPart(candy)
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return candy.PrimaryPart
            or candy:FindFirstChildWhichIsA("BasePart", true)
    end
end

local candies = {}

for _, candy in ipairs(folder:GetChildren()) do
    if candy.Name:match("^Candy_") then
        local part = getPart(candy)
        if part then
            table.insert(candies, {
                candy = candy,
                part = part
            })
        end
    end
end

print("Candies found:", #candies)

for i, info in ipairs(candies) do
    local character = player.Character
    if not character then break end

    character:PivotTo(
        CFrame.new(info.part.Position + Vector3.new(0, 2, 0))
    )

    print("Teleport:", i, info.candy.Name)

    task.wait(1)

    local found = false

    for prompt in pairs(activePrompts) do
        if prompt.Parent and prompt.Enabled then
            found = true

            print("Trying E:", prompt:GetFullName())

            local triggered = false
            local connection = prompt.Triggered:Connect(function()
                triggered = true
            end)

            prompt:InputHoldBegin()

            local duration = prompt.HoldDuration
            local start = os.clock()

            while os.clock() - start < duration + 0.2 do
                task.wait(0.03)
            end

            prompt:InputHoldEnd()
            task.wait(0.3)

            print("Triggered:", triggered)
            connection:Disconnect()
            break
        end
    end

    if not found then
        warn("No visible ProximityPrompt near:", info.candy.Name)
    end

    task.wait(0.3)
end

if player.Character then
    player.Character:PivotTo(HOME)
end

print("Candy test completed")
