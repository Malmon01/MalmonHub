
-- Roblox Map Export
-- Client-side objects only
-- Excludes script source

print("[MAP] Starting export...")

if type(saveinstance) ~= "function" then
    warn("[MAP] Executor does not support saveinstance")
    return
end

local success, err = pcall(function()
    saveinstance({
        noscripts = true
    })
end)

if success then
    print("[MAP] Export request completed!")
    print("[MAP] Check your executor folder")
else
    warn("[MAP] Export failed:", err)
end
