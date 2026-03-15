local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local Config = {
    MagicBullet = {
        Enabled = true,
        Speed = 200,
        Gravity = Vector3.new(0, -workspace.Gravity, 0),
        Visualize = true,
        LifeTime = 5
    },
    FOV = {
        Enabled = true,
        Target = 130,
        Speed = 700
    },
    ESP = {
        Enabled = true,
        MaxDistance = 2000
    },
    World = {
        NoGrass = false,
        NoFog = false,
        NoShadow = false
    }
}

local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DevToolsUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 300, 0, 360)
    frame.Position = UDim2.new(0, 12, 0, 12)
    frame.BackgroundTransparency = 0.15
    frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    frame.BorderSizePixel = 0

    local function makeLabel(text, y)
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1, -12, 0, 24)
        lbl.Position = UDim2.new(0, 6, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.new(1,1,1)
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 16
        return lbl
    end

    local function makeToggle(text, y, initial, callback)
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(1, -12, 0, 30)
        btn.Position = UDim2.new(0, 6, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 16
        btn.Text = text .. (initial and " : ON" or " : OFF")
        btn.MouseButton1Click:Connect(function()
            initial = not initial
            btn.Text = text .. (initial and " : ON" or " : OFF")
            callback(initial)
        end)
        return btn
    end

    local function makeSlider(text, y, min, max, initial, callback)
        local lbl = makeLabel(text .. ": " .. tostring(initial), y)
        local bar = Instance.new("Frame", frame)
        bar.Size = UDim2.new(1, -12, 0, 20)
        bar.Position = UDim2.new(0, 6, 0, y + 26)
        bar.BackgroundColor3 = Color3.fromRGB(70,70,70)
        local fill = Instance.new("Frame", bar)
        fill.Size = UDim2.new((initial-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(140,140,140)
        local dragging = false
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
            end
        end)
        bar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                local value = min + (max - min) * rel
                fill.Size = UDim2.new(rel, 0, 1, 0)
                lbl.Text = text .. ": " .. math.floor(value)
                callback(value)
            end
        end)
        return bar
    end

    makeLabel("Developer Visual Tools", 8)
    makeSlider("FOV Target", 36, 10, 200, Config.FOV.Target, function(v) Config.FOV.Target = v end)
    makeSlider("FOV Speed", 84, 10, 1000, Config.FOV.Speed, function(v) Config.FOV.Speed = v end)
    makeToggle("Enable FOV", 132, Config.FOV.Enabled, function(v) Config.FOV.Enabled = v end)
    makeToggle("Magic Bullet Visual", 172, Config.MagicBullet.Visualize, function(v) Config.MagicBullet.Visualize = v end)
    makeSlider("Bullet Speed", 212, 50, 1000, Config.MagicBullet.Speed, function(v) Config.MagicBullet.Speed = v end)
    makeToggle("ESP for NPCs", 252, Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    makeToggle("No Grass", 292, Config.World.NoGrass, function(v) Config.World.NoGrass = v if v then applyWorldSettings() else restoreWorldSettings() end end)
    makeToggle("No Fog", 332, Config.World.NoFog, function(v) Config.World.NoFog = v applyWorldSettings() end)
    makeToggle("No Shadow", 372, Config.World.NoShadow, function(v) Config.World.NoShadow = v applyWorldSettings() end)

    return screenGui
end

local originalLighting = {
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    ShadowSoftness = Lighting.ShadowSoftness
}

local modifiedParts = {}

function applyWorldSettings()
    if Config.World.NoFog then
        Lighting.FogStart = 1e6
        Lighting.FogEnd = 1e7
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
    end
    Lighting.GlobalShadows = not Config.World.NoShadow and originalLighting.GlobalShadows or false
    Lighting.ShadowSoftness = Config.World.NoShadow and 0 or originalLighting.ShadowSoftness
    if Config.World.NoGrass then
        for _,v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                if v.Material == Enum.Material.Grass or tostring(v.Name):lower():find("grass") then
                    if not modifiedParts[v] then
                        modifiedParts[v] = {Transparency = v.Transparency, CanCollide = v.CanCollide}
                        v.Transparency = 1
                        v.CanCollide = false
                    end
                end
            end
        end
    else
        for part,props in pairs(modifiedParts) do
            if part and part.Parent then
                part.Transparency = props.Transparency
                part.CanCollide = props.CanCollide
            end
            modifiedParts[part] = nil
        end
    end
end

function restoreWorldSettings()
    Lighting.FogStart = originalLighting.FogStart
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.ShadowSoftness = originalLighting.ShadowSoftness
    for part,props in pairs(modifiedParts) do
        if part and part.Parent then
            part.Transparency = props.Transparency
            part.CanCollide = props.CanCollide
        end
        modifiedParts[part] = nil
    end
end

local function spawnProjectile(origin, direction)
    local speed = Config.MagicBullet.Speed
    local lifetime = Config.MagicBullet.LifeTime
    local step = 0.05
    local position = origin
    local velocity = direction.Unit * speed
    local gravity = Config.MagicBullet.Gravity
    local t = 0
    while t < lifetime do
        local nextPos = position + velocity * step + gravity * (t + step) * step
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Blacklist
        ray.FilterDescendantsInstances = {LocalPlayer.Character or LocalPlayer}
        local result = Workspace:Raycast(position, (nextPos - position), ray)
        if Config.MagicBullet.Visualize then
            local p = Instance.new("Part")
            p.Size = Vector3.new(0.2,0.2,0.2)
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 120, 80)
            p.CFrame = CFrame.new(nextPos)
            p.Parent = Workspace
            Debris:AddItem(p, 1)
        end
        if result and result.Instance then
            local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
            if hitModel and hitModel:FindFirstChildOfClass("Humanoid") then
                local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
                humanoid:TakeDamage(15)
                return
            else
                return
            end
        end
        position = nextPos
        t = t + step
        wait(step)
    end
end

local function onActivate()
    local mouse = LocalPlayer:GetMouse()
    local origin = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    spawnProjectile(origin + unitRay.Direction.Unit * 2, unitRay.Direction)
end

local function setupInput()
    local uis = UserInputService
    uis.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Config.MagicBullet.Enabled then
                spawnProjectile(Camera.CFrame.Position, Camera.CFrame.LookVector)
            end
        end
    end)
end

local espFolder = Instance.new("Folder", Workspace)
espFolder.Name = "DevESPFolder"

local function createESPFor(model)
    if not model or not model.Parent then return end
    if model:FindFirstChild("DevESPMarker") then return end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if not root then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DevESPMarker"
    billboard.Size = UDim2.new(0,150,0,50)
    billboard.Adornee = root
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = espFolder
    local frame = Instance.new("Frame", billboard)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.5
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    local nameLabel = Instance.new("TextLabel", frame)
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 14
    local hpLabel = Instance.new("TextLabel", frame)
    hpLabel.Size = UDim2.new(1, 0, 0.4, 0)
    hpLabel.Position = UDim2.new(0,0,0.6,0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.new(1,1,1)
    hpLabel.Font = Enum.Font.SourceSans
    hpLabel.TextSize = 12
    local function update()
        if not humanoid or not humanoid.Parent then
            billboard:Destroy()
            return
        end
        nameLabel.Text = tostring(model.Name)
        hpLabel.Text = "HP: " .. math.floor(humanoid.Health)
    end
    RunService.Heartbeat:Connect(function()
        if Config.ESP.Enabled then
            update()
        else
            if billboard.Parent then billboard.Parent = nil end
        end
    end)
end

local function scanForNPCs()
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            local playersCharacter = false
            for _,plr in ipairs(Players:GetPlayers()) do
                if plr.Character == v then playersCharacter = true break end
            end
            if not playersCharacter then
                createESPFor(v)
            end
        end
    end
end

local function startFOVLoop()
    RunService.RenderStepped:Connect(function(dt)
        if Config.FOV.Enabled then
            local current = Camera.FieldOfView
            local target = Config.FOV.Target
            local speed = Config.FOV.Speed
            local t = 1 - math.exp(-speed * dt)
            Camera.FieldOfView = current + (target - current) * t
        end
    end)
end

createUI()
applyWorldSettings()
setupInput()
scanForNPCs()
startFOVLoop()

Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") and desc:FindFirstChildOfClass("Humanoid") then
        local playersCharacter = false
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr.Character == desc then playersCharacter = true break end
        end
        if not playersCharacter then
            createESPFor(desc)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    for _,child in ipairs(espFolder:GetChildren()) do
        if child:IsA("BillboardGui") and child.Adornee and child.Adornee.Parent == p.Character then
            child:Destroy()
        end
    end
end)
