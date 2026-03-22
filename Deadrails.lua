--[[
    ╔══════════════════════════════════════════╗
    ║       H4LL0 W0RLD HUB V4               ║
    ║          Dead Rails  •  v2.0            ║
    ║     KEYLESS + AIMBOT TARGET SELECT     ║
    ╚══════════════════════════════════════════╝
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Debris           = game:GetService("Debris")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local C = {
    BG_Main    = Color3.fromRGB(8,   3,  3),
    BG_Side    = Color3.fromRGB(15,  5,  5),
    BG_Content = Color3.fromRGB(18,  6,  6),
    BG_Card    = Color3.fromRGB(25,  8,  8),
    Accent     = Color3.fromRGB(180, 20, 20),
    AccentDim  = Color3.fromRGB(100, 10, 10),
    AccentGlow = Color3.fromRGB(220, 40, 40),
    ON         = Color3.fromRGB(200, 30, 30),
    OFF        = Color3.fromRGB(45,  15, 15),
    TextMain   = Color3.fromRGB(220, 180, 180),
    TextSub    = Color3.fromRGB(150, 100, 100),
    TextDim    = Color3.fromRGB(80,  50,  50),
    Border     = Color3.fromRGB(80,  20,  20),
    Blood      = Color3.fromRGB(140, 10,  10),
    Green      = Color3.fromRGB(50,  200, 120),
    Gold       = Color3.fromRGB(255, 200, 50),
    Purple     = Color3.fromRGB(168, 85,  247),
    Blue       = Color3.fromRGB(50,  120, 255),
    Orange     = Color3.fromRGB(255, 140, 50),
}

local Toggles = {
    ESP      = false,
    Aimbot   = false,
    AutoFarm = false,
    ESPItem  = false,
    InfAmmo  = false,
    SpeedHack= false,
    GodMode  = false,
    AutoWin  = false,
    AutoBonds= false,
    InfJump  = false,
    Noclip   = false,
    Fly      = false,
}

local Settings = {
    FlySpeed   = 40,
    AimSpeed   = 8,
    FOV        = 150,
    AimTarget  = "Player", -- Player / NPC / Animal / All
}

local Connections = {}
local Minimized   = false
local LastFarm    = 0
local LastBond    = 0

-- NPC & Animal name keywords
local NPC_NAMES = {
    "zombie","undead","bandit","enemy","outlaw","sheriff","cowboy",
    "skeleton","ghost","creature","mob","bot","npc","guard","soldier"
}
local ANIMAL_NAMES = {
    "horse","cow","sheep","wolf","bear","deer","pig","chicken",
    "animal","beast","dog","cat","bird","eagle","snake","spider"
}

local function New(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    if parent then obj.Parent = parent end
    return obj
end

local function Corner(p, r)
    return New("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p)
end

local function Stroke(p, col, th)
    return New("UIStroke", {Color = col or C.Border, Thickness = th or 1}, p)
end

local function Tween(obj, props, t)
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(t or 0.25, Enum.EasingStyle.Quart), props):Play()
    end)
end

local function GetChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function StopAll()
    for k, c in pairs(Connections) do
        pcall(function() c:Disconnect() end)
        Connections[k] = nil
    end
end

local function SafeTP(hrp, pos)
    pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
end

local function ClearESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local bb = root:FindFirstChild("ESP_BB")
                if bb then pcall(function() bb:Destroy() end) end
            end
            local hl = plr.Character:FindFirstChild("ESP_HL")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local bb = obj:FindFirstChild("ITEM_BB")
        if bb then pcall(function() bb:Destroy() end) end
    end
end

-- Check if model is NPC
local function IsNPC(model)
    local name = model.Name:lower()
    for _, kw in ipairs(NPC_NAMES) do
        if name:find(kw) then return true end
    end
    return false
end

-- Check if model is Animal
local function IsAnimal(model)
    local name = model.Name:lower()
    for _, kw in ipairs(ANIMAL_NAMES) do
        if name:find(kw) then return true end
    end
    return false
end

-- Get all valid aimbot targets based on setting
local function GetAimTargets()
    local targets = {}
    local mode = Settings.AimTarget

    -- Players
    if mode == "Player" or mode == "All" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local head = plr.Character:FindFirstChild("Head")
                if head then table.insert(targets, head) end
            end
        end
    end

    -- NPCs & Animals
    if mode == "NPC" or mode == "Animal" or mode == "All" then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrpObj = obj:FindFirstChild("HumanoidRootPart")
                local head = obj:FindFirstChild("Head")
                if hum and hum.Health > 0 and hrpObj and head then
                    local isNPC = IsNPC(obj)
                    local isAnimal = IsAnimal(obj)
                    if (mode == "NPC" and isNPC) or
                       (mode == "Animal" and isAnimal) or
                       (mode == "All" and (isNPC or isAnimal)) then
                        table.insert(targets, head)
                    end
                end
            end
        end
    end

    return targets
end

local function ApplyFeature(key, val)
    local char, hrp, hum = GetChar()

    if key == "ESP" then
        if val then
            Connections.ESP = RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local root = plr.Character:FindFirstChild("HumanoidRootPart")
                        if root and not root:FindFirstChild("ESP_BB") then
                            pcall(function()
                                local bb = New("BillboardGui", {
                                    Name="ESP_BB", Size=UDim2.new(0,110,0,24),
                                    StudsOffset=Vector3.new(0,3.5,0), AlwaysOnTop=true,
                                }, root)
                                New("TextLabel", {
                                    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
                                    Text="💀 "..plr.Name,
                                    TextColor3=C.AccentGlow, TextSize=12,
                                    Font=Enum.Font.GothamBold,
                                }, bb)
                                local hl = Instance.new("Highlight")
                                hl.Name="ESP_HL"
                                hl.FillColor=Color3.fromRGB(180,20,20)
                                hl.OutlineColor=Color3.fromRGB(255,50,50)
                                hl.FillTransparency=0.5
                                hl.Adornee=plr.Character
                                hl.Parent=plr.Character
                            end)
                        end
                    end
                end
            end)
        else
            if Connections.ESP then
                pcall(function() Connections.ESP:Disconnect() end)
                Connections.ESP = nil
            end
            ClearESP()
        end

    elseif key == "Aimbot" then
        if val then
            Connections.Aimbot = RunService.RenderStepped:Connect(function()
                local targets = GetAimTargets()
                if #targets == 0 then return end

                local closest, dist = nil, math.huge
                for _, head in ipairs(targets) do
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                        local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if d < Settings.FOV and d < dist then
                            dist = d; closest = head
                        end
                    end
                end

                if closest then
                    pcall(function()
                        local camPos = Camera.CFrame.Position
                        local targetCF = CFrame.lookAt(camPos, closest.Position)
                        Camera.CFrame = Camera.CFrame:Lerp(targetCF,
                            math.clamp(Settings.AimSpeed/100, 0.02, 0.25))
                    end)
                end
            end)
        else
            if Connections.Aimbot then
                pcall(function() Connections.Aimbot:Disconnect() end)
                Connections.Aimbot = nil
            end
        end

    elseif key == "AutoFarm" then
        if val then
            Connections.AutoFarm = RunService.Heartbeat:Connect(function()
                local now = tick()
                if now - LastFarm < 2 then return end
                LastFarm = now
                if not hrp then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") then
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        local r = obj:FindFirstChild("HumanoidRootPart")
                        if h and h.Health > 0 and r and (IsNPC(obj) or IsAnimal(obj)) then
                            local d = (r.Position - hrp.Position).Magnitude
                            if d < 60 then
                                SafeTP(hrp, r.Position)
                                break
                            end
                        end
                    end
                end
            end)
        else
            if Connections.AutoFarm then
                pcall(function() Connections.AutoFarm:Disconnect() end)
                Connections.AutoFarm = nil
            end
        end

    elseif key == "ESPItem" then
        if val then
            Connections.ESPItem = RunService.Heartbeat:Connect(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj:FindFirstChild("ITEM_BB") then
                        local name = obj.Name:lower()
                        if name:find("ammo") or name:find("bond") or name:find("gold") or
                           name:find("loot") or name:find("chest") or name:find("supply") or
                           name:find("weapon") or name:find("gun") or name:find("rifle") or
                           name:find("medkit") or name:find("health") then
                            pcall(function()
                                local bb = New("BillboardGui", {
                                    Name="ITEM_BB", Size=UDim2.new(0,110,0,22),
                                    StudsOffset=Vector3.new(0,2,0), AlwaysOnTop=true,
                                }, obj)
                                New("TextLabel", {
                                    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
                                    Text="📦 "..obj.Name,
                                    TextColor3=C.Gold, TextSize=11,
                                    Font=Enum.Font.GothamBold,
                                }, bb)
                            end)
                        end
                    end
                end
            end)
        else
            if Connections.ESPItem then
                pcall(function() Connections.ESPItem:Disconnect() end)
                Connections.ESPItem = nil
            end
            for _, obj in ipairs(workspace:GetDescendants()) do
                local bb = obj:FindFirstChild("ITEM_BB")
                if bb then pcall(function() bb:Destroy() end) end
            end
        end

    elseif key == "InfAmmo" then
        if val then
            Connections.InfAmmo = RunService.Heartbeat:Connect(function()
                if not char then return end
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        for _, v in ipairs(tool:GetDescendants()) do
                            if v.Name:lower():find("ammo") or v.Name:lower():find("bullet") then
                                pcall(function()
                                    if v:IsA("IntValue") or v:IsA("NumberValue") then
                                        v.Value = 9999
                                    end
                                end)
                            end
                        end
                    end
                end
            end)
        else
            if Connections.InfAmmo then
                pcall(function() Connections.InfAmmo:Disconnect() end)
                Connections.InfAmmo = nil
            end
        end

    elseif key == "SpeedHack" then
        if hum then
            hum.WalkSpeed = val and (58 + math.random(0,4)) or 16
        end

    elseif key == "GodMode" then
        if val then
            Connections.GodMode = RunService.Heartbeat:Connect(function()
                local _, _, h = GetChar()
                if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
            end)
        else
            if Connections.GodMode then
                pcall(function() Connections.GodMode:Disconnect() end)
                Connections.GodMode = nil
            end
        end

    elseif key == "AutoWin" then
        if val then
            Connections.AutoWin = RunService.Heartbeat:Connect(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and (IsNPC(obj) or IsAnimal(obj)) then
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h and h.Health > 0 then
                            pcall(function() h.Health = 0 end)
                        end
                    end
                end
            end)
        else
            if Connections.AutoWin then
                pcall(function() Connections.AutoWin:Disconnect() end)
                Connections.AutoWin = nil
            end
        end

    elseif key == "AutoBonds" then
        if val then
            Connections.AutoBonds = RunService.Heartbeat:Connect(function()
                local now = tick()
                if now - LastBond < 1.5 then return end
                LastBond = now
                if not hrp then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and (
                        obj.Name:lower():find("bond") or
                        obj.Name:lower():find("gold") or
                        obj.Name:lower():find("coin") or
                        obj.Name:lower():find("money")
                    ) then
                        local d = (obj.Position - hrp.Position).Magnitude
                        if d < 60 then SafeTP(hrp, obj.Position); break end
                    end
                end
            end)
        else
            if Connections.AutoBonds then
                pcall(function() Connections.AutoBonds:Disconnect() end)
                Connections.AutoBonds = nil
            end
        end

    elseif key == "InfJump" then
        if val then
            Connections.InfJump = UserInputService.JumpRequest:Connect(function()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if Connections.InfJump then
                pcall(function() Connections.InfJump:Disconnect() end)
                Connections.InfJump = nil
            end
        end

    elseif key == "Noclip" then
        if val then
            Connections.Noclip = RunService.Stepped:Connect(function()
                local c = LocalPlayer.Character
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then
                            pcall(function() p.CanCollide = false end)
                        end
                    end
                end
            end)
        else
            if Connections.Noclip then
                pcall(function() Connections.Noclip:Disconnect() end)
                Connections.Noclip = nil
            end
        end

    elseif key == "Fly" then
        if val then
            pcall(function()
                if not hrp then return end
                local bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
                bg.P = 1e4; bg.Parent = hrp
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.zero
                bv.MaxForce = Vector3.new(1e9,1e9,1e9)
                bv.Parent = hrp
                Connections.Fly = RunService.Heartbeat:Connect(function()
                    if Toggles.Aimbot then bv.Velocity = Vector3.zero; return end
                    local cam = workspace.CurrentCamera
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        bv.Velocity = cam.CFrame.LookVector * Settings.FlySpeed
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        bv.Velocity = -cam.CFrame.LookVector * Settings.FlySpeed
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        bv.Velocity = Vector3.new(0, Settings.FlySpeed, 0)
                    else
                        bv.Velocity = Vector3.zero
                    end
                    bg.CFrame = cam.CFrame
                end)
            end)
        else
            if Connections.Fly then
                pcall(function() Connections.Fly:Disconnect() end)
                Connections.Fly = nil
            end
            if hrp then
                for _, obj in ipairs(hrp:GetChildren()) do
                    if obj:IsA("BodyGyro") or obj:IsA("BodyVelocity") then
                        pcall(function() obj:Destroy() end)
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════
--      LOADING SCREEN
-- ═══════════════════════════
local GUI = New("ScreenGui", {
    Name="H4ll0V4", ResetOnSpawn=false,
    DisplayOrder=999, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
}, game.CoreGui)

local LoadFrame = New("Frame", {
    Size=UDim2.new(1,0,1,0), BackgroundColor3=C.BG_Main, BorderSizePixel=0,
}, GUI)

for i = 1, 14 do
    local drip = New("Frame", {
        Size=UDim2.new(0,math.random(3,9),0,math.random(20,90)),
        Position=UDim2.new(math.random(),0,0,0),
        BackgroundColor3=C.Blood, BackgroundTransparency=0.35, BorderSizePixel=0,
    }, LoadFrame)
    Corner(drip, 3)
end

local flickLbl = New("TextLabel", {
    Size=UDim2.new(0,90,0,90), Position=UDim2.new(0.5,-45,0.12,0),
    BackgroundTransparency=1, Text="💀", TextSize=68, Font=Enum.Font.GothamBold,
}, LoadFrame)

New("TextLabel", {
    Size=UDim2.new(0,440,0,44), Position=UDim2.new(0.5,-220,0.32,0),
    BackgroundTransparency=1, Text="H4LL0 W0RLD HUB V4",
    TextColor3=C.Accent, TextSize=28, Font=Enum.Font.GothamBold,
}, LoadFrame)

New("TextLabel", {
    Size=UDim2.new(0,440,0,24), Position=UDim2.new(0.5,-220,0.42,0),
    BackgroundTransparency=1, Text="DEAD RAILS  •  KEYLESS",
    TextColor3=C.TextSub, TextSize=12, Font=Enum.Font.Gotham,
}, LoadFrame)

local BarBG = New("Frame", {
    Size=UDim2.new(0,340,0,10), Position=UDim2.new(0.5,-170,0.56,0),
    BackgroundColor3=C.BG_Card, BorderSizePixel=0,
}, LoadFrame)
Corner(BarBG, 9)
local BarFill = New("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=C.Accent, BorderSizePixel=0}, BarBG)
Corner(BarFill, 9)
local BarPct = New("TextLabel", {
    Size=UDim2.new(0,340,0,20), Position=UDim2.new(0.5,-170,0.59,0),
    BackgroundTransparency=1, Text="0%", TextColor3=C.Accent,
    TextSize=11, Font=Enum.Font.GothamBold,
}, LoadFrame)
local BarStatus = New("TextLabel", {
    Size=UDim2.new(0,340,0,20), Position=UDim2.new(0.5,-170,0.64,0),
    BackgroundTransparency=1, Text="Initializing...",
    TextColor3=C.TextSub, TextSize=11, Font=Enum.Font.Gotham,
}, LoadFrame)

local function LoadStep(txt, pct, w)
    BarStatus.Text = txt
    Tween(BarFill, {Size=UDim2.new(pct,0,1,0)}, 0.5)
    local target = math.floor(pct*100)
    local cur = tonumber(BarPct.Text:match("%d+")) or 0
    for i = cur, target, 3 do BarPct.Text = i.."%"; task.wait(0.01) end
    BarPct.Text = target.."%"; task.wait(w or 0.5)
end

task.spawn(function()
    while flickLbl and flickLbl.Parent do
        task.wait(math.random(2,5))
        for _ = 1,2 do
            flickLbl.TextTransparency=0.7; task.wait(0.08)
            flickLbl.TextTransparency=0; task.wait(0.08)
        end
    end
end)

-- ═══════════════════════════
--        MAIN GUI
-- ═══════════════════════════
local function BuildMain()

    local Win = New("Frame", {
        Size=UDim2.new(0,580,0,440),
        Position=UDim2.new(0.5,-290,0.5,-220),
        BackgroundColor3=C.BG_Main, BorderSizePixel=0, Active=true,
    }, GUI)
    Corner(Win,12); Stroke(Win,C.Blood,1.5)

    local drag,dStart,dPos=false,nil,nil
    Win.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true; dStart=i.Position; dPos=Win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dStart
            Win.Position=UDim2.new(dPos.X.Scale,dPos.X.Offset+d.X,dPos.Y.Scale,dPos.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)

    local Top=New("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.BG_Side,BorderSizePixel=0,ZIndex=5},Win)
    Corner(Top,12)
    New("Frame",{Size=UDim2.new(1,0,0.5,0),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=C.BG_Side,BorderSizePixel=0,ZIndex=4},Top)
    New("TextLabel",{Size=UDim2.new(0,30,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text="💀",TextSize=20,ZIndex=6},Top)
    New("TextLabel",{Size=UDim2.new(0,280,1,0),Position=UDim2.new(0,40,0,0),BackgroundTransparency=1,Text="H4ll0 W0rld Hub V4",TextColor3=C.Accent,TextXAlignment=Enum.TextXAlignment.Left,TextSize=14,Font=Enum.Font.GothamBold,ZIndex=6},Top)

    local badge=New("Frame",{Size=UDim2.new(0,65,0,20),Position=UDim2.new(0,326,0.5,-10),BackgroundColor3=Color3.fromRGB(10,30,10),BorderSizePixel=0,ZIndex=6},Top)
    Corner(badge,5); Stroke(badge,C.Green,1)
    New("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="✅ KEYLESS",TextColor3=C.Green,TextSize=9,Font=Enum.Font.GothamBold,ZIndex=7},badge)

    local MinBtn=New("TextButton",{Size=UDim2.new(0,26,0,20),Position=UDim2.new(1,-60,0.5,-10),BackgroundColor3=C.BG_Card,Text="─",TextColor3=C.TextMain,TextSize=13,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=6},Top)
    Corner(MinBtn,5)
    local CloseBtn=New("TextButton",{Size=UDim2.new(0,26,0,20),Position=UDim2.new(1,-28,0.5,-10),BackgroundColor3=C.Blood,Text="✕",TextColor3=Color3.fromRGB(255,200,200),TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=6},Top)
    Corner(CloseBtn,5)

    CloseBtn.MouseButton1Click:Connect(function()
        StopAll(); ClearESP()
        Tween(Win,{Size=UDim2.new(0,580,0,0)},0.3)
        task.wait(0.35); GUI:Destroy()
    end)
    MinBtn.MouseButton1Click:Connect(function()
        Minimized=not Minimized
        if Minimized then Tween(Win,{Size=UDim2.new(0,580,0,40)},0.3); MinBtn.Text="□"
        else Tween(Win,{Size=UDim2.new(0,580,0,440)},0.3); MinBtn.Text="─" end
    end)

    local CH=New("Frame",{Size=UDim2.new(1,0,1,-40),Position=UDim2.new(0,0,0,40),BackgroundTransparency=1,ClipsDescendants=true},Win)
    local Side=New("Frame",{Size=UDim2.new(0,130,1,0),BackgroundColor3=C.BG_Side,BorderSizePixel=0},CH)
    Stroke(Side,C.Border,1)
    New("UIListLayout",{Padding=UDim.new(0,4)},Side)
    New("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)},Side)

    local CA=New("Frame",{Size=UDim2.new(1,-130,1,0),Position=UDim2.new(0,130,0,0),BackgroundColor3=C.BG_Content,BorderSizePixel=0,ClipsDescendants=true},CH)
    New("UIPadding",{PaddingAll=UDim.new(0,10)},CA)

    local Pages,TabBtns={},{}

    local function MakePage(name)
        local pg=New("ScrollingFrame",{Name=name,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Accent,CanvasSize=UDim2.new(0,0,0,0),Visible=false},CA)
        local ll=New("UIListLayout",{Padding=UDim.new(0,6)},pg)
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            pg.CanvasSize=UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+16)
        end)
        Pages[name]=pg; return pg
    end

    local function SetTab(name)
        for n,pg in pairs(Pages) do pg.Visible=(n==name) end
        for n,btn in pairs(TabBtns) do
            if n==name then
                Tween(btn,{BackgroundColor3=C.AccentDim},0.2)
                btn.BackgroundTransparency=0; btn.TextColor3=C.Accent
            else
                btn.BackgroundTransparency=1; btn.TextColor3=C.TextSub
            end
        end
    end

    for _,t in ipairs({{"Combat","💀"},{"Farm","🌾"},{"ESP","👁"},{"Player","🏃"},{"Spawner","📦"},{"Settings","⚙"}}) do
        MakePage(t[1])
        local btn=New("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,BackgroundColor3=C.BG_Side,Text=t[2].."  "..t[1],TextColor3=C.TextSub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},Side)
        Corner(btn,7); New("UIPadding",{PaddingLeft=UDim.new(0,8)},btn)
        TabBtns[t[1]]=btn
        btn.MouseButton1Click:Connect(function() SetTab(t[1]) end)
    end

    local function Section(parent,txt,col)
        local f=New("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1},parent)
        New("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="  ▸  "..txt,TextColor3=col or C.Accent,TextXAlignment=Enum.TextXAlignment.Left,TextSize=10,Font=Enum.Font.GothamBold},f)
    end

    local function Toggle(parent,label,key,desc,col)
        local card=New("Frame",{Size=UDim2.new(1,0,0,desc and 52 or 40),BackgroundColor3=C.BG_Card,BorderSizePixel=0},parent)
        Corner(card,8); Stroke(card,C.Border,1)
        New("TextLabel",{Size=UDim2.new(1,-70,0,20),Position=UDim2.new(0,10,0,5),BackgroundTransparency=1,Text=label,TextColor3=C.TextMain,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,Font=Enum.Font.GothamBold},card)
        if desc then New("TextLabel",{Size=UDim2.new(1,-70,0,16),Position=UDim2.new(0,10,0,26),BackgroundTransparency=1,Text=desc,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextSize=10,Font=Enum.Font.Gotham},card) end
        local onCol=col or C.ON
        local tb=New("TextButton",{Size=UDim2.new(0,46,0,22),Position=UDim2.new(1,-54,0.5,-11),BackgroundColor3=C.OFF,Text="",BorderSizePixel=0},card)
        Corner(tb,11)
        local circ=New("Frame",{Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0.5,-8),BackgroundColor3=Color3.fromRGB(255,220,220),BorderSizePixel=0},tb)
        Corner(circ,8)
        tb.MouseButton1Click:Connect(function()
            Toggles[key]=not Toggles[key]
            Tween(tb,{BackgroundColor3=Toggles[key] and onCol or C.OFF},0.2)
            Tween(circ,{Position=Toggles[key] and UDim2.new(0,27,0.5,-8) or UDim2.new(0,3,0.5,-8)},0.2)
            pcall(function() ApplyFeature(key,Toggles[key]) end)
        end)
    end

    local function Btn(parent,label,col,fn)
        local b=New("TextButton",{Size=UDim2.new(1,0,0,34),BackgroundColor3=col or C.BG_Card,Text=label,TextColor3=col and Color3.fromRGB(255,200,200) or C.TextMain,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},parent)
        Corner(b,8); if not col then Stroke(b,C.Border,1) end
        b.MouseButton1Click:Connect(function()
            pcall(fn); b.BackgroundColor3=C.Green
            task.wait(0.5); b.BackgroundColor3=col or C.BG_Card
        end)
        return b
    end

    local function Slider(parent,label,min,max,def,fn,suffix)
        local card=New("Frame",{Size=UDim2.new(1,0,0,62),BackgroundColor3=C.BG_Card,BorderSizePixel=0},parent)
        Corner(card,8); Stroke(card,C.Border,1)
        New("TextLabel",{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,10,0,5),BackgroundTransparency=1,Text=label,TextColor3=C.TextMain,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,Font=Enum.Font.GothamBold},card)
        local vl=New("TextLabel",{Size=UDim2.new(0,60,0,20),Position=UDim2.new(1,-65,0,5),BackgroundTransparency=1,Text=tostring(def)..(suffix or ""),TextColor3=C.Gold,TextXAlignment=Enum.TextXAlignment.Right,TextSize=11,Font=Enum.Font.GothamBold},card)
        local pct=(def-min)/(max-min)
        local bg=New("Frame",{Size=UDim2.new(1,-20,0,8),Position=UDim2.new(0,10,0,36),BackgroundColor3=C.BG_Main,BorderSizePixel=0},card); Corner(bg,4)
        local fill=New("Frame",{Size=UDim2.new(pct,0,1,0),BackgroundColor3=C.Accent,BorderSizePixel=0},bg); Corner(fill,4)
        local thumb=New("Frame",{Size=UDim2.new(0,16,0,16),Position=UDim2.new(pct,-8,0.5,-8),BackgroundColor3=Color3.fromRGB(255,200,200),BorderSizePixel=0},bg); Corner(thumb,8)
        local sliding=false
        bg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
        UserInputService.InputChanged:Connect(function(i)
            if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                local rel=math.clamp((i.Position.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1)
                local v=math.floor(min+(max-min)*rel)
                vl.Text=tostring(v)..(suffix or ""); fill.Size=UDim2.new(rel,0,1,0); thumb.Position=UDim2.new(rel,-8,0.5,-8)
                pcall(fn,v)
            end
        end)
    end

    -- ══════════════════
    --   💀 COMBAT TAB
    -- ══════════════════
    local CP=Pages["Combat"]
    Section(CP,"AIMBOT")
    Toggle(CP,"Aimbot","Aimbot","Camera-only, body tidak gerak")

    -- Aimbot Target Selector
    local aimCard=New("Frame",{Size=UDim2.new(1,0,0,68),BackgroundColor3=C.BG_Card,BorderSizePixel=0},CP)
    Corner(aimCard,8); Stroke(aimCard,C.Border,1)
    New("TextLabel",{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,10,0,4),BackgroundTransparency=1,Text="🎯 Aimbot Target",TextColor3=C.TextMain,TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,Font=Enum.Font.GothamBold},aimCard)

    local aimStatus=New("TextLabel",{Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,10,0,24),BackgroundTransparency=1,Text="Target: PLAYER 👤",TextColor3=C.Gold,TextXAlignment=Enum.TextXAlignment.Left,TextSize=10,Font=Enum.Font.GothamBold},aimCard)

    -- 4 target buttons
    local targetBtns = {}
    local targets = {
        {"Player", "👤", C.Accent,   UDim2.new(0,10,0,44)},
        {"NPC",    "🧟", C.Blood,    UDim2.new(0,82,0,44)},
        {"Animal", "🐎", C.Orange,   UDim2.new(0,154,0,44)},
        {"All",    "🌐", C.Purple,   UDim2.new(0,226,0,44)},
    }
    for _, t in ipairs(targets) do
        local b=New("TextButton",{Size=UDim2.new(0,66,0,20),Position=t[4],BackgroundColor3=t[1]=="Player" and t[3] or C.BG_Card,Text=t[2].." "..t[1],TextColor3=t[1]=="Player" and Color3.fromRGB(255,200,200) or C.TextSub,TextSize=10,Font=Enum.Font.GothamBold,BorderSizePixel=0},aimCard)
        Corner(b,5)
        if t[1]~="Player" then Stroke(b,C.Border,1) end
        targetBtns[t[1]]=b
        b.MouseButton1Click:Connect(function()
            Settings.AimTarget=t[1]
            aimStatus.Text="Target: "..t[1]:upper().." "..t[2]
            for k,btn in pairs(targetBtns) do
                if k==t[1] then
                    btn.BackgroundColor3=t[3]
                    btn.TextColor3=Color3.fromRGB(255,200,200)
                else
                    btn.BackgroundColor3=C.BG_Card
                    btn.TextColor3=C.TextSub
                end
            end
        end)
    end

    Slider(CP,"🎯 FOV Radius",50,500,150,function(v) Settings.FOV=v end," px")
    Slider(CP,"⚡ Aim Speed",1,30,8,function(v) Settings.AimSpeed=v end,"")

    Section(CP,"SURVIVAL")
    Toggle(CP,"God Mode","GodMode","HP selalu penuh",C.Green)
    Toggle(CP,"Infinite Ammo","InfAmmo","Ammo tidak habis",C.Gold)
    Toggle(CP,"Auto Win","AutoWin","Auto bunuh semua NPC/enemy",C.Blood)

    -- ══════════════════
    --   🌾 FARM TAB
    -- ══════════════════
    local FP=Pages["Farm"]
    Section(FP,"AUTO FARM")
    Toggle(FP,"Auto Farm","AutoFarm","Auto farm NPC/enemy (2s cooldown)")
    Toggle(FP,"Auto Collect Bonds","AutoBonds","Auto ambil bonds/gold (1.5s cooldown)",C.Gold)
    Btn(FP,"💰 Collect All Bonds Now",C.AccentDim,function()
        local _,hrp2,_=GetChar(); if not hrp2 then return end
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:lower():find("bond") or obj.Name:lower():find("gold") or obj.Name:lower():find("coin")) then
                SafeTP(hrp2,obj.Position); task.wait(0.3)
            end
        end
    end)
    Btn(FP,"⚔️ Kill All Enemies Now",C.Blood,function()
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (IsNPC(obj) or IsAnimal(obj)) then
                local h=obj:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 then pcall(function() h.Health=0 end) end
            end
        end
    end)

    -- ══════════════════
    --   👁 ESP TAB
    -- ══════════════════
    local EP=Pages["ESP"]
    Section(EP,"PLAYER ESP")
    Toggle(EP,"Player ESP","ESP","Highlight + nama semua player")
    Section(EP,"ITEM ESP",C.Gold)
    Toggle(EP,"Item / Loot ESP","ESPItem","Label item, ammo, chest, weapon",C.Gold)

    -- ══════════════════
    --   🏃 PLAYER TAB
    -- ══════════════════
    local PP=Pages["Player"]
    Section(PP,"MOVEMENT")
    Toggle(PP,"Speed Hack","SpeedHack","WalkSpeed anti detect")
    Toggle(PP,"Infinite Jump","InfJump","Loncat tanpa batas")
    Toggle(PP,"Noclip","Noclip","Tembus tembok")
    Toggle(PP,"Fly","Fly","Terbang (W/S/Space) — pause saat Aimbot")
    Slider(PP,"✈️ Fly Speed",10,150,40,function(v) Settings.FlySpeed=v end,"")
    Btn(PP,"🔄 Restore Defaults",C.AccentDim,function()
        local _,_,hum=GetChar()
        if hum then hum.WalkSpeed=16; hum.JumpPower=50 end
        workspace.Gravity=196.2; Camera.FieldOfView=70
    end)

    -- ══════════════════
    --   📦 SPAWNER TAB
    -- ══════════════════
    local SPW=Pages["Spawner"]
    Section(SPW,"ITEM SPAWNER  [ VISUAL ]",C.Gold)
    local spawnItems={
        {"🔫 Rifle",C.TextMain},{"🔫 Shotgun",C.TextMain},
        {"💣 Dynamite",C.Accent},{"💊 Medkit",C.Green},
        {"💰 Gold Bonds",C.Gold},{"🧲 Ammo Box",C.Blue},
        {"🛡️ Armor",C.Purple},{"🐴 Horse",C.Gold},
    }
    for _,item in ipairs(spawnItems) do
        local card=New("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.BG_Card,BorderSizePixel=0},SPW)
        Corner(card,8); Stroke(card,C.Border,1)
        New("TextLabel",{Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text=item[1],TextColor3=item[2],TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,Font=Enum.Font.GothamBold},card)
        local sb=New("TextButton",{Size=UDim2.new(0,62,0,26),Position=UDim2.new(1,-72,0.5,-13),BackgroundColor3=C.Accent,Text="Spawn",TextColor3=Color3.fromRGB(255,200,200),TextSize=11,Font=Enum.Font.GothamBold,BorderSizePixel=0},card)
        Corner(sb,6)
        sb.MouseButton1Click:Connect(function()
            sb.Text="✓ Done"; sb.BackgroundColor3=C.Green
            task.wait(1.5); sb.Text="Spawn"; sb.BackgroundColor3=C.Accent
        end)
    end
    New("TextLabel",{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,Text="⚠️  Spawner bersifat VISUAL ONLY",TextColor3=C.Gold,TextSize=10,Font=Enum.Font.Gotham},SPW)

    -- ══════════════════
    --   ⚙ SETTINGS TAB
    -- ══════════════════
    local SETP=Pages["Settings"]
    Section(SETP,"PERFORMANCE")
    Btn(SETP,"🚀 Boost FPS",C.AccentDim,function()
        for _,obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled=false
                end
            end)
        end
    end)
    Btn(SETP,"☀️ Full Bright",C.AccentDim,function()
        local L=game:GetService("Lighting")
        L.Brightness=10; L.ClockTime=14; L.FogEnd=1e6; L.GlobalShadows=false
    end)
    Section(SETP,"SERVER")
    Btn(SETP,"🔄 Rejoin Server",C.AccentDim,function()
        game:GetService("TeleportService"):Teleport(game.PlaceId,LocalPlayer)
    end)
    Section(SETP,"ABOUT")
    local about=New("Frame",{Size=UDim2.new(1,0,0,80),BackgroundColor3=C.BG_Card,BorderSizePixel=0},SETP)
    Corner(about,8); Stroke(about,C.Blood,1.5)
    New("TextLabel",{Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text="💀  H4ll0 W0rld Hub V4  v2.0\nGame   : Dead Rails\nStatus : Keyless ✅\nDiscord: discord.gg/xCV9Tf4y5N",TextColor3=C.TextSub,TextXAlignment=Enum.TextXAlignment.Left,TextSize=11,TextWrapped=true,Font=Enum.Font.Gotham},about)

    local stopBtn=New("TextButton",{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.Blood,Text="⛔  Stop All Features",TextColor3=Color3.fromRGB(255,200,200),TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},SETP)
    Corner(stopBtn,8)
    stopBtn.MouseButton1Click:Connect(function()
        StopAll(); ClearESP()
        for k in pairs(Toggles) do Toggles[k]=false end
        stopBtn.Text="✅ All Stopped"; task.wait(2); stopBtn.Text="⛔  Stop All Features"
    end)

    SetTab("Combat")
end

-- ═══════════════════════════
--      RUN LOADING
-- ═══════════════════════════
task.spawn(function()
    LoadStep("💀 Initializing...",        0.15, 0.4)
    LoadStep("🔗 Loading Dead Rails...",  0.35, 0.4)
    LoadStep("🎯 Setting up aimbot...",   0.60, 0.4)
    LoadStep("⚡ Almost ready...",         0.85, 0.35)
    LoadStep("✅  Ready!",                 1.00, 0.3)

    for _,obj in ipairs(LoadFrame:GetDescendants()) do
        pcall(function()
            if obj:IsA("TextLabel") then Tween(obj,{TextTransparency=1},0.4) end
            if obj:IsA("Frame") then Tween(obj,{BackgroundTransparency=1},0.4) end
        end)
    end
    Tween(LoadFrame,{BackgroundTransparency=1},0.4)
    task.wait(0.5)
    LoadFrame:Destroy()
    BuildMain()
end)
