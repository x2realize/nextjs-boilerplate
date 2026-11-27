--@ArceusMetadata:OnAmITwnMCUUXjByOwNfMHZAY1JnAENqY3QAeHsQWAheAxEaZ0BDRQcQPF1nCgt/QkcKR39jTkxoFyAjKAwWZkJSEU11WFQzNyIxPDwxdQxVfGlnTQBsbEl4SHFCGTwhIldrcUQOUF1eRgBzUQ8aQAMATS1fSm1JDBsfMDweVn4Xc3p9VklxS0MCADwbVnY2Imd5cSokUxYCNHFOBWRlSnJUawJEYXplViQqHFVLU0VSRTY=
-- ============================================================
-- 128B!t | MM2  –  Stellar Library Edition
-- PlaceId: 142823291
-- ============================================================
if game.PlaceId ~= 142823291 then return end
if not game:IsLoaded() then game.Loaded:Wait() end

-- ============================================================
-- LOAD LIBRARY  (Stellar / sametexe001)
-- ============================================================
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/x2realize/128Bit.Libary/refs/heads/main/Library.lua"
))()

-- ============================================================
-- SERVICES
-- ============================================================
local playersService    = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService        = game:GetService("RunService")
local userInputService  = game:GetService("UserInputService")
local tweenService      = game:GetService("TweenService")
local collectionService = game:GetService("CollectionService")
local insertService     = game:GetService("InsertService")

local localPlayer   = playersService.LocalPlayer
local character     = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local root          = character:WaitForChild("HumanoidRootPart")
local currentCamera = workspace.CurrentCamera

localPlayer.CharacterAdded:Connect(function(char)
    character = char
    root      = char:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- GLOBALS
-- ============================================================
getgenv().ESP_ENABLED    = false
getgenv().GunEsp         = false
getgenv().AutoShoot      = false
getgenv().ShootMode      = "Wallbang"
getgenv().AGG            = false
getgenv().InfiniteJump   = false
getgenv().Noclip         = false
getgenv().AutoFarmCoins  = false
getgenv().FarmSpeed      = 21
getgenv().AntiFling      = false
getgenv().FOVSize        = 150
getgenv().Walkspeed      = 16
getgenv().Jumppower      = 50
getgenv().timeout        = 2.5
getgenv().AimlockEnabled = false
getgenv().AimlockPart    = "HumanoidRootPart"

-- ============================================================
-- MOBILE BUTTONS  (Onyx-style: dark glass, clean minimal)
-- ============================================================
local function createStylishButton(name, text, position, imageId)
    local gui             = Instance.new("ScreenGui")
    gui.Name              = name .. "Gui"
    gui.ResetOnSpawn      = false
    gui.IgnoreGuiInset    = true
    gui.DisplayOrder      = 999
    gui.Parent            = (gethui and gethui()) or game:GetService("CoreGui")
    gui.Enabled           = false

    -- outer container (draggable, glass-dark)
    local btn                       = Instance.new("TextButton")
    btn.Name                        = name .. "Button"
    btn.Parent                      = gui
    btn.AnchorPoint                 = Vector2.new(0.5, 0.5)
    btn.Position                    = position
    btn.Size                        = UDim2.fromOffset(68, 72)
    btn.BackgroundColor3            = Color3.fromRGB(14, 14, 18)
    btn.BackgroundTransparency      = 0.18
    btn.AutoButtonColor             = false
    btn.Text                        = ""
    btn.Active                      = true
    btn.Draggable                   = true
    btn.ZIndex                      = 10

    -- rounded
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 16)

    -- thin border stroke (Onyx accent purple-ish)
    local stroke             = Instance.new("UIStroke", btn)
    stroke.Thickness         = 1.2
    stroke.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
    stroke.Color             = Color3.fromRGB(120, 90, 200)
    stroke.Transparency      = 0.3

    -- subtle vertical gradient on background
    local bgGrad         = Instance.new("UIGradient", btn)
    bgGrad.Rotation      = 90
    bgGrad.Color         = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(30, 28, 44)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 16, 28)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(12, 10, 20)),
    }

    -- icon (centered upper)
    local icon                      = Instance.new("ImageLabel")
    icon.Name                       = "Icon"
    icon.Parent                     = btn
    icon.BackgroundTransparency     = 1
    icon.AnchorPoint                = Vector2.new(0.5, 0)
    icon.Position                   = UDim2.new(0.5, 0, 0, 10)
    icon.Size                       = UDim2.fromOffset(36, 36)
    icon.Image                      = "rbxassetid://" .. tostring(imageId)
    icon.ScaleType                  = Enum.ScaleType.Fit
    icon.ImageColor3                = Color3.fromRGB(230, 220, 255)
    icon.ZIndex                     = 11

    -- label (centered lower)
    local label                     = Instance.new("TextLabel")
    label.Name                      = "Label"
    label.Parent                    = btn
    label.BackgroundTransparency    = 1
    label.AnchorPoint               = Vector2.new(0.5, 1)
    label.Position                  = UDim2.new(0.5, 0, 1, -7)
    label.Size                      = UDim2.new(1, -6, 0, 14)
    label.Font                      = Enum.Font.GothamBold
    label.Text                      = text
    label.TextColor3                = Color3.fromRGB(200, 185, 240)
    label.TextSize                  = 9
    label.TextXAlignment            = Enum.TextXAlignment.Center
    label.TextTransparency          = 0.1
    label.ZIndex                    = 11

    -- press highlight effect
    btn.MouseButton1Down:Connect(function()
        tweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.05,
        }):Play()
        tweenService:Create(stroke, TweenInfo.new(0.08), {
            Color = Color3.fromRGB(160, 130, 255),
            Transparency = 0,
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        tweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.18,
        }):Play()
        tweenService:Create(stroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(120, 90, 200),
            Transparency = 0.3,
        }):Play()
    end)

    return gui, btn
end

local shootGui,  shootButton  = createStylishButton("Shoot",   "SHOOT",    UDim2.new(0.5,-125,0.8,0), 97594928468157)
local throwGui,  throwButton  = createStylishButton("Throw",   "THROW",    UDim2.new(0.5,-35, 0.8,0), 17689682126)
local killGui,   killButton   = createStylishButton("KillAll", "KILL ALL", UDim2.new(0.5, 55, 0.8,0), 137278198363013)

-- ============================================================
-- HELPERS
-- ============================================================
local function getHumanoid(plr)
    local char = plr.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function getRoot(plr)
    local char = plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getGunDrop()
    return workspace:FindFirstChild("GunDrop", true)
end
local function getRoles()
    local remote = replicatedStorage:FindFirstChild("GetPlayerData", true)
    if not remote then return {} end
    local ok, res = pcall(function() return remote:InvokeServer() end)
    if not ok then return {} end
    local roles = {}
    for plrName, data in pairs(res) do
        if not data.Dead then roles[plrName] = data.Role end
    end
    return roles
end
local function getMurdererHead()
    local roles = getRoles()
    for plrName, role in pairs(roles) do
        if role == "Murderer" then
            local t = playersService:FindFirstChild(plrName)
            if t and t ~= localPlayer and t.Character
                and t.Character:FindFirstChild("Head")
                and t.Character:FindFirstChild("Humanoid")
                and t.Character.Humanoid.Health > 0
            then
                return t.Character.Head, t
            end
        end
    end
    return nil, nil
end
local function getClosestMurderer()
    local roles  = getRoles()
    local vp     = currentCamera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local bestTarget, bestHead, bestDist = nil, nil, math.huge
    for plrName, role in pairs(roles) do
        if role == "Murderer" then
            local t = playersService:FindFirstChild(plrName)
            if t and t ~= localPlayer and t.Character
                and t.Character:FindFirstChild("Head")
                and t.Character:FindFirstChild("Humanoid")
                and t.Character.Humanoid.Health > 0
            then
                local head = t.Character.Head
                local pos, visible = currentCamera:WorldToViewportPoint(head.Position)
                if visible then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist <= getgenv().FOVSize and dist < bestDist then
                        bestDist = dist; bestTarget = t; bestHead = head
                    end
                end
            end
        end
    end
    return bestTarget, bestHead
end

-- ============================================================
-- COMBAT ACTIONS
-- ============================================================
local function shootMurdererAction()
    local _, targetPlayer = getMurdererHead()
    if not targetPlayer or not targetPlayer.Character
        or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local gun = localPlayer.Character:FindFirstChild("Gun") or localPlayer.Backpack:FindFirstChild("Gun")
    if not gun then return end
    local shootRemote = gun:FindFirstChild("Shoot"); if not shootRemote then return end
    local hrp       = targetPlayer.Character.HumanoidRootPart
    local targetPos = hrp.Position
    local velocity  = hrp.AssemblyLinearVelocity
    local isJumping = velocity.Y > 1
    if getgenv().ShootMode == "Wallbang" then
        local predictOffset = velocity * 0.08
        local predictedPos  = targetPos + predictOffset
        local jumpOffset    = isJumping and Vector3.new(0, math.abs(velocity.Y)*0.1, 0) or Vector3.zero
        for _, pos in ipairs({ predictedPos+jumpOffset, predictedPos+jumpOffset+Vector3.new(0,1,0), predictedPos+jumpOffset-Vector3.new(0,1,0) }) do
            shootRemote:FireServer(CFrame.new(pos+(-hrp.CFrame.LookVector*3), pos), CFrame.new(pos))
        end
    elseif getgenv().ShootMode == "Silent Aim" then
        local myChar = localPlayer.Character; if not myChar then return end
        local myHRP  = myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
        local predictOffset = velocity * 0.1
        local predictedPos  = targetPos + predictOffset
        local jumpOffset    = isJumping and Vector3.new(0, math.abs(velocity.Y)*0.1, 0) or Vector3.zero
        local finalTarget   = predictedPos + jumpOffset
        for _, pos in ipairs({ finalTarget, finalTarget+Vector3.new(0,1,0), finalTarget-Vector3.new(0,0.5,0) }) do
            shootRemote:FireServer(CFrame.new(myHRP.Position, pos), CFrame.new(pos))
        end
    end
end
shootButton.MouseButton1Click:Connect(shootMurdererAction)

local function throwKnifeAction()
    local myChar = localPlayer.Character; if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart"); if not myRoot then return end
    local closest, shortest = nil, math.huge
    for _, plr in ipairs(playersService:GetPlayers()) do
        if plr ~= localPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (plr.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                if dist < shortest then shortest = dist; closest = plr end
            end
        end
    end
    if not closest then return end
    local knife = myChar:FindFirstChild("Knife")
    if not knife then
        local bpKnife = localPlayer.Backpack:FindFirstChild("Knife")
        if bpKnife then myChar:FindFirstChildOfClass("Humanoid"):EquipTool(bpKnife); task.wait(0.15); knife = myChar:FindFirstChild("Knife") end
    end
    if not knife then return end
    local events     = knife:FindFirstChild("Events");     if not events     then return end
    local throwRemote = events:FindFirstChild("KnifeThrown"); if not throwRemote then return end
    local targetPos  = closest.Character.HumanoidRootPart.Position
    throwRemote:FireServer(CFrame.new(myRoot.Position, targetPos), CFrame.new(targetPos))
end
throwButton.MouseButton1Click:Connect(throwKnifeAction)

killButton.MouseButton1Click:Connect(function()
    local myChar = localPlayer.Character; if not myChar then return end
    local knife = myChar:FindFirstChild("Knife")
    if not knife then
        local bpKnife = localPlayer.Backpack:FindFirstChild("Knife")
        if bpKnife then myChar:FindFirstChildOfClass("Humanoid"):EquipTool(bpKnife); task.wait(0.15); knife = myChar:FindFirstChild("Knife") end
    end
    if not knife or not knife:FindFirstChild("Handle") then return end
    for _, plr in pairs(playersService:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                knife:Activate()
                for _, part in pairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        firetouchinterest(knife.Handle, part, 0)
                        firetouchinterest(knife.Handle, part, 1)
                    end
                end
            end
        end
    end
    killButton.Text = "KILLED!"; task.wait(0.5); killButton.Text = "KILL ALL"
end)

local function sHubFling(targetPlayer)
    local myChar = localPlayer.Character; if not myChar then return end
    local myHum  = myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myHum and myHum.RootPart
    if not myRoot or not myHum then return end
    local tChar     = targetPlayer.Character; if not tChar then return end
    local tHumanoid = tChar:FindFirstChildOfClass("Humanoid")
    local tRootPart = tHumanoid and tHumanoid.RootPart
    local tHead     = tChar:FindFirstChild("Head")
    local accessory = tChar:FindFirstChildOfClass("Accessory")
    local handle    = accessory and accessory:FindFirstChild("Handle")
    if not (tRootPart or tHead or handle) then return end
    local oldPos = myRoot.CFrame
    repeat task.wait()
        workspace.CurrentCamera.CameraSubject = tHead or handle or tHumanoid
    until workspace.CurrentCamera.CameraSubject == (tHead or handle or tHumanoid)
    local function fPos(basePart, pos, ang)
        local targetCF = CFrame.new(basePart.Position) * pos * ang
        myRoot.CFrame = targetCF; myChar:SetPrimaryPartCFrame(targetCF)
        myRoot.Velocity = Vector3.new(9e7, 9e8, 9e7)
        myRoot.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    local function sfBasePart(basePart)
        local start = tick(); local angle = 0
        repeat
            if myRoot and tHumanoid then
                angle = angle + 100
                for _, offset in ipairs({ CFrame.new(0,1.5,0), CFrame.new(0,-1.5,0), CFrame.new(2.25,1.5,-2.25), CFrame.new(-2.25,-1.5,2.25) }) do
                    fPos(basePart, offset + tHumanoid.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                end
            end
        until basePart.Velocity.Magnitude > 500 or tick() - start > getgenv().timeout
    end
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(9e8,9e8,9e8); bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge); bv.Parent = myRoot
    myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    local target = tRootPart or tHead or handle
    if target then sfBasePart(target) end
    bv:Destroy()
    myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    repeat task.wait()
        workspace.CurrentCamera.CameraSubject = myHum
    until workspace.CurrentCamera.CameraSubject == myHum
    repeat
        local cf = oldPos * CFrame.new(0, 0.5, 0)
        myRoot.CFrame = cf; myChar:SetPrimaryPartCFrame(cf)
        myHum:ChangeState("GettingUp")
        for _, part in ipairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then part.Velocity = Vector3.zero; part.RotVelocity = Vector3.zero end
        end
        task.wait()
    until (myRoot.Position - oldPos.Position).Magnitude < 25
end

-- ============================================================
-- ESP HELPERS
-- ============================================================
local function removeRoleESP(name)
    for _, plr in pairs(playersService:GetPlayers()) do
        if plr.Character then
            local hl   = plr.Character:FindFirstChild(name.."_HL")
            local bill = plr.Character:FindFirstChild(name.."_BILL")
            if hl   then hl:Destroy()   end
            if bill then bill:Destroy() end
        end
    end
end
local function createRoleESP(plr, color, text, espName)
    if not plr.Character or plr == localPlayer then return end
    local char = plr.Character; local head = char:FindFirstChild("Head"); if not head then return end
    local hl = char:FindFirstChild(espName.."_HL")
    if not hl then
        hl = Instance.new("Highlight"); hl.Name = espName.."_HL"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0; hl.Parent = char
    end
    hl.FillColor = color; hl.OutlineColor = Color3.new(1,1,1)
    local bill = char:FindFirstChild(espName.."_BILL")
    if not bill then
        bill = Instance.new("BillboardGui"); bill.Name = espName.."_BILL"; bill.Size = UDim2.new(0,100,0,22)
        bill.StudsOffset = Vector3.new(0,2.5,0); bill.AlwaysOnTop = true; bill.Adornee = head; bill.Parent = char
        local txt = Instance.new("TextLabel", bill); txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1
        txt.TextScaled = true; txt.Font = Enum.Font.GothamBold; txt.TextStrokeTransparency = 0
    end
    local txt = bill:FindFirstChildOfClass("TextLabel"); txt.Text = text; txt.TextColor3 = color
end

-- Anti-fling
local antiFlingConn, antiFlingCharConn = nil, nil
local function applyAntiFling()
    local char = localPlayer.Character; if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            for _, plr in ipairs(playersService:GetPlayers()) do
                if plr ~= localPlayer and plr.Character then
                    for _, enemyPart in ipairs(plr.Character:GetDescendants()) do
                        if enemyPart:IsA("BasePart") then
                            local nc = Instance.new("NoCollisionConstraint")
                            nc.Part0 = part; nc.Part1 = enemyPart; nc.Parent = char
                        end
                    end
                end
            end
        end
    end
end
local function clearAntiFling()
    local char = localPlayer.Character; if not char then return end
    for _, v in ipairs(char:GetDescendants()) do if v:IsA("NoCollisionConstraint") then v:Destroy() end end
end

-- Notify helper
local notificationBusy      = false
local notificationsSilenced = false
local function notify(title, content, notifType, duration)
    if notificationsSilenced or notificationBusy then return end
    notificationBusy = true
    Library:Notify({ Title = title, Content = content, Type = notifType or "Info", Duration = duration or 4 })
    task.delay(duration or 4, function() notificationBusy = false end)
end

-- ============================================================
-- WINDOW + WATERMARK
-- ============================================================
local Window    = Library:Window({ Name = "128B!t | OFFICIAL", SubName = "MM2 | v4.5", Logo = "rbxassetid://97177675697505", UIMode = "Mobile" ,Background = "rbxassetid://109431613356049",
    PanelTransparency = 0.5, ElementTransparency = 0.55})
local Watermark = Library:Watermark("128B!t OFFICIAL", "rbxassetid://97177675697505")

-- ============================================================
-- PAGES
-- ============================================================
local generalPage  = Window:Page({ Name = "General",      Icon = "rbxassetid://127961652457612" })
local combatPage   = Window:Page({ Name = "Combat",       Icon = "sword" })
local espPage      = Window:Page({ Name = "ESP",          Icon = "eye" })
local audioPage    = Window:Page({ Name = "Music/Audio",  Icon = "audio" })
local skinPage     = Window:Page({ Name = "Weapon Skin",  Icon = "star" })
local localPage    = Window:Page({ Name = "Local Player", Icon = "user" })
local teleportPage = Window:Page({ Name = "Teleport",     Icon = "rbxassetid://6723742952" })

-- ============================================================
-- GENERAL PAGE
-- ============================================================
local infoSection = generalPage:Section({ Name = "Info", Side = 1 })

infoSection:Button({ Name = "Copy Discord", Callback = function() setclipboard("https://discord.gg/E6ft5s7Ddu") end })

local autoSection = generalPage:Section({ Name = "Automatic", Side = 1 })

autoSection:Toggle({
    Name = "AutoFarm Coin", Flag = "AutoFarmCoins",
    Desc = "ฟาร์มเหรียญ",
    Callback = function(state)
        getgenv().AutoFarmCoins = state
        if not state then return end
        task.spawn(function()
            local visited = {}
            while getgenv().AutoFarmCoins do
                local char    = localPlayer.Character or localPlayer.CharacterAdded:Wait()
                local humPart = char:FindFirstChild("HumanoidRootPart")
                if humPart then
                    local closest, dist = nil, math.huge
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Name == "Coin_Server" and not visited[obj] then
                            local d = (obj.Position - humPart.Position).Magnitude
                            if d < dist and d <= 250 then closest = obj; dist = d end
                        end
                    end
                    if closest and closest.Parent then
                        visited[closest] = true
                        local tw = tweenService:Create(humPart, TweenInfo.new(dist/getgenv().FarmSpeed, Enum.EasingStyle.Linear), { CFrame = CFrame.new(closest.Position) })
                        tw:Play(); tw.Completed:Wait()
                    end
                end
                task.wait(0.1)
            end
        end)
    end,
})
autoSection:Slider({
    Name = "Farm Speed", Flag = "FarmSpeed",
    Desc = "ความเร็วฟาร์ม",
    Default = 21, Min = 10, Max = 30, Suffix = "",
    Callback = function(v) getgenv().FarmSpeed = v end,
})
autoSection:Toggle({
    Name = "Anti Fling", Flag = "AntiFling",
    Desc = "กันโดนดีด",
    Callback = function(v)
        getgenv().AntiFling = v
        if v then
            applyAntiFling()
            antiFlingConn = playersService.PlayerAdded:Connect(function(plr)
                plr.CharacterAdded:Connect(function() task.wait(1); if getgenv().AntiFling then applyAntiFling() end end)
            end)
            antiFlingCharConn = localPlayer.CharacterAdded:Connect(function() task.wait(0.5); if getgenv().AntiFling then applyAntiFling() end end)
        else
            clearAntiFling()
            if antiFlingConn     then antiFlingConn:Disconnect();     antiFlingConn     = nil end
            if antiFlingCharConn then antiFlingCharConn:Disconnect(); antiFlingCharConn = nil end
        end
    end,
})
autoSection:Button({ Name = "Unlock Camera Zoom", Callback = function()
    localPlayer.CameraMinZoomDistance = 0
    localPlayer.CameraMaxZoomDistance = math.huge
end })
autoSection:Button({ Name = "Unlock All Emotes", Callback = function()
    local ok2, err = pcall(function()
        local emotes    = require(replicatedStorage.Database.Sync).Emotes
        local changeInv = replicatedStorage.Remotes.Inventory.ChangeInventoryItem
        local count = 0
        for i in pairs(emotes) do firesignal(changeInv.OnClientEvent, "Emotes", i, 1); count += 1 end
        notify("Emotes Unlocked!", "ปลดล็อคสำเร็จ " .. count .. " ท่า", "Success", 3)
    end)
    if not ok2 then notify("Error!", tostring(err), "Error", 3) end
end })

local flingSection = generalPage:Section({ Name = "Fling", Side = 2 })
flingSection:Slider({
    Name = "Fling Timeout", Flag = "FlingTimeout",
Desc = "ระยะเวลาดีด",
    Default = 3, Min = 1, Max = 10, Suffix = "s",
    Callback = function(v) getgenv().timeout = v end,
})

local playerList     = {}
local selectedPlayer = nil
for _, plr in pairs(playersService:GetPlayers()) do
    if plr ~= localPlayer then table.insert(playerList, plr.Name) end
end

flingSection:Dropdown({
    Name = "Select Player", Flag = "FlingTarget",
Desc = "เลือกผู้เล่น",
    Items = playerList, Default = playerList[1] or "",
    Multi = false,
    Callback = function(v) selectedPlayer = v end,
})
flingSection:Button({ Name = "Fling Selected", Callback = function()
    if not selectedPlayer then return end
    local target = playersService:FindFirstChild(selectedPlayer)
    if target and target ~= localPlayer then sHubFling(target) end
end })
flingSection:Button({ Name = "Fling All Players", Callback = function()
    for _, plr in ipairs(playersService:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                task.spawn(function() sHubFling(plr) end)
                task.wait(getgenv().timeout + 0.5)
            end
        end
    end
end })
flingSection:Button({ Name = "Fling Murderer",Desc = "ดีดฆาตกร", Callback = function()
    for plr, role in pairs(getRoles()) do
        if role == "Murderer" then
            local target = playersService:FindFirstChild(plr)
            if target and target ~= localPlayer then sHubFling(target); break end
        end
    end
end })
flingSection:Button({ Name = "Fling Sheriff/Hero",Desc = "ดีดนายอำเภอ", Callback = function()
    for plr, role in pairs(getRoles()) do
        if role == "Sheriff" or role == "Hero" then
            local target = playersService:FindFirstChild(plr)
            if target and target ~= localPlayer then sHubFling(target); break end
        end
    end
end })

-- ============================================================
-- COMBAT PAGE
-- ============================================================
local murderSection = combatPage:Section({ Name = "Murder Operations", Side = 1 })

local auraEnabled = false
murderSection:Toggle({
    Name = "Kill All", Flag = "KillAll",
Desc = "ฆ่าทั้งหมด",
    Callback = function(v) auraEnabled = v end,
})

runService.RenderStepped:Connect(function()
    if not auraEnabled then return end
    local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool or not tool:FindFirstChild("Handle") then return end
    for _, plr in pairs(playersService:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            tool:Activate()
            for _, part in pairs(plr.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    firetouchinterest(tool.Handle, part, 0)
                    firetouchinterest(tool.Handle, part, 1)
                end
            end
        end
    end
end)

local function killSheriffHeroAction()
    if not root then return end
    local myChar = localPlayer.Character; if not myChar then return end
    local knife = myChar:FindFirstChild("Knife")
    if not knife then
        local bpKnife = localPlayer.Backpack:FindFirstChild("Knife")
        if bpKnife then myChar:FindFirstChildOfClass("Humanoid"):EquipTool(bpKnife); task.wait(0.15) end
    end
    for plr, role in pairs(getRoles()) do
        if role == "Sheriff" or role == "Hero" then
            local target = playersService:FindFirstChild(plr)
            if target and target ~= localPlayer and target.Character then
                local enemyRoot = target.Character:FindFirstChild("HumanoidRootPart")
                if enemyRoot then
                    enemyRoot.CFrame = root.CFrame * CFrame.new(0, 0, -3)
                    task.spawn(function()
                        for _ = 1, 15 do
                            if enemyRoot and root then enemyRoot.CFrame = root.CFrame * CFrame.new(0, 0, -3) end
                            task.wait(0.03)
                        end
                    end)
                end
            end
        end
    end
end

murderSection:Button({ Name = "Kill Sheriff/Hero",Desc = "ฆ่านายอำเภอ", Callback = killSheriffHeroAction })
murderSection:Toggle({ Name = "Show Kill All Button", Flag = "ShowKillBtn", Desc = "ปุ่มฆ่าทั้งหมด", Callback = function(v) killGui.Enabled = v end })
murderSection:Toggle({ Name = "Show Throw Button",    Flag = "ShowThrowBtn", Desc = "ปุ่มปามีด",Callback = function(v) throwGui.Enabled = v end })

local sheriffSection = combatPage:Section({ Name = "Sheriff Operations", Side = 2 })

local aimlockConn = nil
sheriffSection:Dropdown({
    Name = "Aimlock Target Part", Flag = "AimlockPart",
Desc = "เลือกจุดล็อค",
    Items = { "HumanoidRootPart", "Head", "UpperTorso", "RightArm", "LeftArm" },
    Default = "HumanoidRootPart", Multi = false,
    Callback = function(v) getgenv().AimlockPart = v end,
})
sheriffSection:Toggle({
    Name = "Aimlock Murder", Flag = "AimlockEnabled",
Desc = "ล็อคฆ่าตกร",
    Callback = function(v)
        getgenv().AimlockEnabled = v
        if v then
            aimlockConn = runService.RenderStepped:Connect(function()
                if not getgenv().AimlockEnabled then return end
                local _, targetPlayer = getMurdererHead(); if not targetPlayer or not targetPlayer.Character then return end
                local targetPart = targetPlayer.Character:FindFirstChild(getgenv().AimlockPart) or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not targetPart then return end
                local cf = workspace.CurrentCamera.CFrame
                workspace.CurrentCamera.CFrame = cf:Lerp(CFrame.new(cf.Position, targetPart.Position), 1)
            end)
        else
            if aimlockConn then aimlockConn:Disconnect(); aimlockConn = nil end
        end
    end,
})
sheriffSection:Button({ Name = "Grab Gun",Desc = "เก็บปืน", Callback = function()
    local gun = getGunDrop(); if gun and localPlayer.Character then localPlayer.Character:PivotTo(gun.CFrame) end
end })
sheriffSection:Toggle({
    Name = "Auto Grab Gun", Flag = "AutoGrabGun",
Desc = "เก็บปืนออโต้",
    Callback = function(v)
        getgenv().AGG = v
        if not v then return end
        task.spawn(function()
            while getgenv().AGG do
                local gun = getGunDrop(); local r = getRoot(localPlayer)
                if gun and r then firetouchinterest(r, gun, 0); firetouchinterest(r, gun, 1) end
                task.wait(0.1)
            end
        end)
    end,
})

local shootSection = combatPage:Section({ Name = "Shoot", Side = 2 })
shootSection:Toggle({ Name = "Show Shoot Button", Flag = "ShowShootBtn", Desc = "ปุ่มยิง",Callback = function(v) shootGui.Enabled = v end })
shootSection:Dropdown({
    Name = "Shoot Mode", Flag = "ShootMode",
Desc = "โหมดยิง",
    Items = { "Wallbang", "Silent Aim" }, Default = "Wallbang", Multi = false,
    Callback = function(v) getgenv().ShootMode = v end,
})

local keybindSection = combatPage:Section({ Name = "Keybinds", Side = 1 })
keybindSection:Label("Shoot Murderer"):Keybind({
    Name = "Shoot Murderer", Flag = "KeyShoot", Mode = "Toggle", Default = Enum.KeyCode.E,
    Callback = shootMurdererAction,
})
keybindSection:Label("Kill All"):Keybind({
    Name = "Kill All", Flag = "KeyKillAll", Mode = "Toggle", Default = Enum.KeyCode.Q,
    Callback = function() auraEnabled = not auraEnabled end,
})
keybindSection:Label("Throw Knife"):Keybind({
    Name = "Throw Knife", Flag = "KeyThrow", Mode = "Toggle", Default = Enum.KeyCode.F,
    Callback = throwKnifeAction,
})
keybindSection:Label("Kill Sheriff/Hero"):Keybind({
    Name = "Kill Sheriff/Hero", Flag = "KeyKillSheriff", Mode = "Toggle", Default = Enum.KeyCode.R,
    Callback = killSheriffHeroAction,
})
keybindSection:Label("Grab Gun"):Keybind({
    Name = "Grab Gun", Flag = "KeyGrabGun", Mode = "Toggle", Default = Enum.KeyCode.G,
    Callback = function()
        local gun = getGunDrop(); if gun and localPlayer.Character then localPlayer.Character:PivotTo(gun.CFrame) end
    end,
})

-- ============================================================
-- ESP PAGE
-- ============================================================
local espSection = espPage:Section({ Name = "ESP", Side = 1 })

espSection:Toggle({
    Name = "ESP Player", Flag = "ESPEnabled",
Desc = "มองผู้เล่น",
    Callback = function(value)
        getgenv().ESP_ENABLED = value
        local roleColors = {
            Murderer = Color3.fromRGB(255,0,0), Sheriff = Color3.fromRGB(0,170,255),
            Hero = Color3.fromRGB(255,255,0), Innocent = Color3.fromRGB(0,255,0), Default = Color3.fromRGB(180,180,180),
        }
        local function clearESP()
            for _, plr in pairs(playersService:GetPlayers()) do
                if plr.Character then local hl = plr.Character:FindFirstChild("MM2_ROLE_HL"); if hl then hl:Destroy() end end
            end
        end
        if value then
            task.spawn(function()
                while getgenv().ESP_ENABLED do
                    local roles = getRoles()
                    for _, plr in pairs(playersService:GetPlayers()) do
                        if plr ~= localPlayer and plr.Character then
                            local role = roles[plr.Name] or "Default"
                            local existing = plr.Character:FindFirstChild("MM2_ROLE_HL")
                            if not existing then
                                local hl = Instance.new("Highlight"); hl.Name = "MM2_ROLE_HL"
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency = 0.45
                                hl.OutlineTransparency = 0; hl.Parent = plr.Character; existing = hl
                            end
                            existing.FillColor = roleColors[role] or roleColors.Default
                            existing.OutlineColor = Color3.new(1,1,1)
                        end
                    end
                    task.wait(0.25)
                end
                clearESP()
            end)
        else clearESP() end
    end,
})
espSection:Toggle({
    Name = "ESP Murderer", Flag = "ESPMurder",
Desc = "มองฆาตกร",
    Callback = function(v)
        getgenv().MurderESP = v
        if v then
            task.spawn(function()
                while getgenv().MurderESP do
                    local roles = getRoles()
                    for plrName, role in pairs(roles) do
                        if role == "Murderer" then
                            local plr = playersService:FindFirstChild(plrName)
                            if plr then createRoleESP(plr, Color3.fromRGB(255,0,0), "MURDER", "MURDER") end
                        end
                    end
                    task.wait(0.3)
                end
                removeRoleESP("MURDER")
            end)
        else removeRoleESP("MURDER") end
    end,
})
espSection:Toggle({
    Name = "ESP Sheriff/Hero", Flag = "ESPSheriff",
Desc = "มองนายอำเภอ",
    Callback = function(v)
        getgenv().SheriffESP = v
        if v then
            task.spawn(function()
                while getgenv().SheriffESP do
                    local roles = getRoles()
                    for plrName, role in pairs(roles) do
                        if role == "Sheriff" or role == "Hero" then
                            local plr = playersService:FindFirstChild(plrName)
                            if plr then createRoleESP(plr, Color3.fromRGB(0,170,255), "SHERIFF", "SHERIFF") end
                        end
                    end
                    task.wait(0.3)
                end
                removeRoleESP("SHERIFF")
            end)
        else removeRoleESP("SHERIFF") end
    end,
})
espSection:Toggle({
    Name = "ESP Gun Drop", Flag = "ESPGun",
Desc = "มองปืน",
    Callback = function(v)
        getgenv().GunEsp = v
        local function clearGunESP()
            local gun = getGunDrop(); if gun then
                local hl = gun:FindFirstChild("Gun_HL"); local bill = gun:FindFirstChild("Gun_BILL")
                if hl then hl:Destroy() end; if bill then bill:Destroy() end
            end
        end
        if v then
            task.spawn(function()
                while getgenv().GunEsp do
                    local gun = getGunDrop()
                    if gun then
                        if not gun:FindFirstChild("Gun_HL") then
                            local hl = Instance.new("Highlight"); hl.Name = "Gun_HL"; hl.FillColor = Color3.fromRGB(255,255,0)
                            hl.OutlineColor = Color3.new(1,1,1); hl.FillTransparency = 0.35; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = gun
                        end
                        if not gun:FindFirstChild("Gun_BILL") then
                            local bill = Instance.new("BillboardGui"); bill.Name = "Gun_BILL"; bill.Size = UDim2.new(0,100,0,22)
                            bill.StudsOffset = Vector3.new(0,1.5,0); bill.AlwaysOnTop = true; bill.Parent = gun
                            local txt = Instance.new("TextLabel", bill); txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1
                            txt.TextScaled = true; txt.Font = Enum.Font.GothamBold; txt.TextStrokeTransparency = 0
                            txt.Text = "GUN DROP"; txt.TextColor3 = Color3.fromRGB(255,255,0)
                        end
                    end
                    task.wait(0.5)
                end
                clearGunESP()
            end)
        else clearGunESP() end
    end,
})

-- ESP Tagname
local espTagFolder = Instance.new("Folder")
espTagFolder.Name   = "MM2_ESPTag"
espTagFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local tagObjects = {}
local TAG_COLORS = {
    Murderer = Color3.fromRGB(255,50,50), Sheriff = Color3.fromRGB(50,100,255),
    Hero = Color3.fromRGB(255,255,0), Innocent = Color3.fromRGB(0,255,0), Default = Color3.fromRGB(255,255,255)
}
local function getAvatarImage(userId)
    local ok2, res2 = pcall(function() return playersService:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
    return ok2 and res2 or ""
end
local function createTag(player)
    if player == localPlayer or tagObjects[player] then return end
    local billboard = Instance.new("BillboardGui"); billboard.Name = "Tag_"..player.Name; billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0,220,0,36); billboard.StudsOffset = Vector3.new(0,3.5,0); billboard.LightInfluence = 0; billboard.Parent = espTagFolder
    local tagFrame = Instance.new("Frame", billboard); tagFrame.BackgroundColor3 = Color3.fromRGB(20,20,20); tagFrame.BackgroundTransparency = 0.5
    tagFrame.AutomaticSize = Enum.AutomaticSize.X; tagFrame.Size = UDim2.new(0,0,1,0); tagFrame.Position = UDim2.new(0.5,0,0.05,0); tagFrame.AnchorPoint = Vector2.new(0.5,0)
    Instance.new("UICorner", tagFrame).CornerRadius = UDim.new(0,8)
    local padding = Instance.new("UIPadding", tagFrame); padding.PaddingLeft = UDim.new(0,6); padding.PaddingRight = UDim.new(0,8); padding.PaddingTop = UDim.new(0,3); padding.PaddingBottom = UDim.new(0,3)
    local ll = Instance.new("UIListLayout", tagFrame); ll.FillDirection = Enum.FillDirection.Horizontal; ll.VerticalAlignment = Enum.VerticalAlignment.Center; ll.Padding = UDim.new(0,5); ll.SortOrder = Enum.SortOrder.LayoutOrder
    local stroke = Instance.new("UIStroke", tagFrame); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Instance.new("UIGradient", stroke).Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, Color3.fromRGB(180,0,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,150)) }
    local avatarImg = Instance.new("ImageLabel", tagFrame); avatarImg.LayoutOrder = 1; avatarImg.BackgroundTransparency = 1; avatarImg.Size = UDim2.new(0,24,0,24); avatarImg.Image = getAvatarImage(player.UserId)
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1,0)
    local nameLabel = Instance.new("TextLabel", tagFrame); nameLabel.LayoutOrder = 2; nameLabel.BackgroundTransparency = 1; nameLabel.AutomaticSize = Enum.AutomaticSize.X; nameLabel.Size = UDim2.new(0,0,1,0)
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextSize = 12; nameLabel.TextColor3 = Color3.fromRGB(255,255,255); nameLabel.TextXAlignment = Enum.TextXAlignment.Left; nameLabel.Text = player.Name
    tagObjects[player] = { Billboard = billboard, NameLabel = nameLabel }
end
local function removeTag(player)
    local data = tagObjects[player]; if data then if data.Billboard then data.Billboard:Destroy() end; tagObjects[player] = nil end
end
local tagConnection, tagPlayerAdded, tagPlayerRemoving = nil, nil, nil
local espTagEnabled = false
espSection:Toggle({
    Name = "ESP Tagname", Flag = "ESPTag",
Desc = "มองชื่อบนหัวแบบแท็ก",
    Callback = function(v)
        espTagEnabled = v
        if v then
            for _, plr in ipairs(playersService:GetPlayers()) do createTag(plr) end
            tagConnection = runService.RenderStepped:Connect(function()
                if not espTagEnabled then return end
                local roles = getRoles()
                for _, plr in ipairs(playersService:GetPlayers()) do
                    if plr == localPlayer then continue end
                    local data = tagObjects[plr]; if not data then createTag(plr); data = tagObjects[plr] end; if not data then continue end
                    local char = plr.Character; local head = char and char:FindFirstChild("Head"); local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if head and hum and hum.Health > 0 then
                        data.Billboard.Adornee = head; data.Billboard.Enabled = true
                        local role = roles[plr.Name]; local color = TAG_COLORS.Default; local labelText = plr.Name
                        if role then color = TAG_COLORS[role] or TAG_COLORS.Default; labelText = plr.Name.." | "..role end
                        data.NameLabel.TextColor3 = color; data.NameLabel.Text = labelText
                    else data.Billboard.Enabled = false end
                end
            end)
            tagPlayerAdded    = playersService.PlayerAdded:Connect(function(plr) if espTagEnabled then task.wait(1); if espTagEnabled then createTag(plr) end end end)
            tagPlayerRemoving = playersService.PlayerRemoving:Connect(function(plr) removeTag(plr) end)
        else
            if tagConnection     then tagConnection:Disconnect();     tagConnection     = nil end
            if tagPlayerAdded    then tagPlayerAdded:Disconnect();    tagPlayerAdded    = nil end
            if tagPlayerRemoving then tagPlayerRemoving:Disconnect(); tagPlayerRemoving = nil end
            for plr in pairs(tagObjects) do removeTag(plr) end
            for _, obj in pairs(espTagFolder:GetChildren()) do obj:Destroy() end
            table.clear(tagObjects)
        end
    end,
})

-- ============================================================
-- AUDIO PAGE
-- ============================================================
local audioSection = audioPage:Section({ Name = "BoomBox / FE Radio", Side = 1 })
local musicId = ""; local radioMode = "FE Radio"; local localSound = nil

local function stopLocalSound() if localSound then localSound:Stop(); localSound:Destroy(); localSound = nil end end
local function playLocalSound(id)
    stopLocalSound()
    local s = Instance.new("Sound"); s.Name = "MM2_LocalRadio"; s.SoundId = "rbxassetid://"..id
    s.Volume = 0.5; s.Looped = true; s.RollOffMaxDistance = 0; s.Parent = workspace.CurrentCamera; s:Play(); localSound = s
end

audioSection:Textbox({
    Name = "Sound ID", Placeholder = "เช่น 1234567890", Numeric = true, Finished = true, Flag = "MusicId",
    Callback = function(v) musicId = tostring(v):match("%d+") or "" end,
})
audioSection:Dropdown({
    Name = "Radio Mode", Flag = "RadioMode",
Desc = "โหมดเปิดเพลง",
    Items = { "FE Radio", "Local" }, Default = "FE Radio", Multi = false,
    Callback = function(v) radioMode = v end,
})
audioSection:Slider({
    Name = "Local Volume", Flag = "LocalVolume",
Desc = "ระดับเสียง",
    Default = 50, Min = 0, Max = 100, Suffix = "%",
    Callback = function(v) if localSound then localSound.Volume = v/100 end end,
})
audioSection:Toggle({
    Name = "Loop Local Radio", Flag = "LoopRadio",
Desc = "ลูปป",
    Callback = function(v) if localSound then localSound.Looped = v end end,
})
audioSection:Button({ Name = "Play Radio", Callback = function()
    if musicId == "" then notify("Error", "ใส่ Sound ID ก่อนนะ!", "Error", 2); return end
    if radioMode == "FE Radio" then
        stopLocalSound()
        pcall(function() replicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("PlaySong"):FireServer("https://www.roblox.com/asset/?id="..musicId) end)
        notify("FE Radio", "กำลังเล่น ID: "..musicId, "Success", 3)
    elseif radioMode == "Local" then
        pcall(function() replicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("PlaySong"):FireServer("") end)
        playLocalSound(musicId)
        notify("Local Radio", "เล่นเฉพาะคุณ ID: "..musicId, "Success", 3)
    end
end })
audioSection:Button({ Name = "Stop Radio", Callback = function()
    stopLocalSound()
    pcall(function() replicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("PlaySong"):FireServer("") end)
    notify("Radio", "หยุดเพลงแล้ว", "Info", 2)
end })

-- ============================================================
-- LOCAL PLAYER PAGE
-- ============================================================
local moveSection = localPage:Section({ Name = "Movement", Side = 1 })

local speedEnabled = false; local speedValue = 16

moveSection:Toggle({
    Name = "Speed Boost", Flag = "SpeedBoost",
Desc = "เพิ่มความเร็ว",
    Callback = function(v)
        speedEnabled = v
        local hum = getHumanoid(localPlayer); if hum then hum.WalkSpeed = v and speedValue or 16 end
    end,
})
moveSection:Slider({
    Name = "Speed Value", Flag = "SpeedValue",
    Default = 16, Min = 16, Max = 1000, Suffix = "",
    Callback = function(v)
        speedValue = v
        local hum = getHumanoid(localPlayer); if speedEnabled and hum then hum.WalkSpeed = v end
    end,
})
localPlayer.CharacterAdded:Connect(function(char)
    character = char; root = char:WaitForChild("HumanoidRootPart")
    if speedEnabled then local hum = char:WaitForChild("Humanoid"); hum.WalkSpeed = speedValue end
end)
moveSection:Slider({
    Name = "JumpPower", Flag = "JumpPower",
    Default = 50, Min = 50, Max = 500, Suffix = "",
    Callback = function(v) getgenv().Jumppower = v; local hum = getHumanoid(localPlayer); if hum then hum.JumpPower = v end end,
})
moveSection:Toggle({
    Name = "Infinite Jump", Flag = "InfiniteJump",
Desc = "กระโดดไม่จำกัด",
    Callback = function(v) getgenv().InfiniteJump = v end,
})
userInputService.JumpRequest:Connect(function()
    if getgenv().InfiniteJump then local hum = getHumanoid(localPlayer); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)
moveSection:Toggle({
    Name = "Noclip", Flag = "Noclip",
Desc = "ทะลุกำแพง",
    Callback = function(v)
        getgenv().Noclip = v
        if not v then return end
        task.spawn(function()
            while getgenv().Noclip do
                local char = localPlayer.Character
                if char then for _, part in pairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end end
                runService.Stepped:Wait()
            end
        end)
    end,
})

-- ============================================================
-- TELEPORT PAGE
-- ============================================================
local tpSection = teleportPage:Section({ Name = "Teleport", Side = 1 })

local tpSelectedPlayer = nil
local function getPlayerList()
    local tbl = {}
    for _, plr in ipairs(playersService:GetPlayers()) do if plr ~= localPlayer then table.insert(tbl, plr.Name) end end
    return tbl
end

local playerTPDropdown = tpSection:Dropdown({
    Name = "Select Player", Flag = "TPTarget",
Desc = "เลือกผู้เล่น",
    Items = getPlayerList(), Default = "", Multi = false,
    Callback = function(v) tpSelectedPlayer = v end,
})
playersService.PlayerAdded:Connect(function()   task.wait(1); if playerTPDropdown and playerTPDropdown.Refresh then playerTPDropdown:Refresh(getPlayerList()) end end)
playersService.PlayerRemoving:Connect(function() task.wait();  if playerTPDropdown and playerTPDropdown.Refresh then playerTPDropdown:Refresh(getPlayerList()) end end)

tpSection:Button({ Name = "TP To Player", Desc = "วาร์ปหาผู้เล่น",Callback = function()
    local target = playersService:FindFirstChild(tpSelectedPlayer)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        localPlayer.Character:PivotTo(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
    end
end })
tpSection:Button({ Name = "TP To Murderer",Desc = "วาร์ปหาฆ่าตกร", Callback = function()
    for plr, role in pairs(getRoles()) do
        if role == "Murderer" then
            local target = playersService:FindFirstChild(plr)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                localPlayer.Character:PivotTo(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)); break
            end
        end
    end
end })
tpSection:Button({ Name = "TP To Sheriff/Hero", Desc = "วาร์ปหานายอำเภอ",Callback = function()
    for plr, role in pairs(getRoles()) do
        if role == "Sheriff" or role == "Hero" then
            local target = playersService:FindFirstChild(plr)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                localPlayer.Character:PivotTo(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)); break
            end
        end
    end
end })

local mapSection = teleportPage:Section({ Name = "Map Teleports", Side = 2 })
mapSection:Button({ Name = "TP To Map",Desc = "วาร์ปไปแมพปัจจุบัน", Callback = function()
    local map = workspace:FindFirstChild("CoinContainer", true)
    if map and map.Parent then
        local part = map:FindFirstChildWhichIsA("BasePart", true) or map.Parent:FindFirstChildWhichIsA("BasePart", true)
        if part and character then character:PivotTo(part.CFrame * CFrame.new(0, 2, 0)) end
    end
end })
mapSection:Button({ Name = "TP To Lobby",Desc = "วาร์ปกลับล็อบบี้", Callback = function()
    if character then character:PivotTo(CFrame.new(13.8190517, 504.787109, -56.5267372, 0.998816371, 2.53511145e-09, -0.0486397929, -2.1081259e-09, 1, 8.82982043e-09, 0.0486397929, -8.71683081e-09, 0.998816371)) end
end })

-- ============================================================
-- WEAPON SKIN PAGE  (MM2Viz — Onyx port)
-- ============================================================
local MM2Viz = { active=false, conns={}, guiRef=nil }

local function mm2vizDestroy()
    MM2Viz.active = false
    for _, c in ipairs(MM2Viz.conns) do pcall(function() c:Disconnect() end) end
    MM2Viz.conns = {}
    if MM2Viz.guiRef then pcall(function() MM2Viz.guiRef:Destroy() end); MM2Viz.guiRef = nil end
end

local function mm2vizStart()
    if MM2Viz.active then mm2vizDestroy() end
    MM2Viz.active = true

    local ok_eq, EquipService   = pcall(function() return require(replicatedStorage:WaitForChild("ClientServices"):WaitForChild("EquipService")) end)
    local ok_sy, Sync           = pcall(function() return require(replicatedStorage:WaitForChild("Database"):WaitForChild("Sync")) end)
    local ok_pd, ProfileData    = pcall(function() return require(replicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData")) end)
    local ok_rc, invDataChanged = pcall(function() return replicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("InventoryDataChanged") end)

    if not (ok_eq and ok_sy and ok_pd and ok_rc) then
        notify("MM2Viz", "โหลด services ไม่ได้ — เข้าเกมก่อนนะ", "Error", 5)
        MM2Viz.active = false; return
    end
    local weapons = Sync.Weapons

    -- fetch mesh data
    local function httpGet(url)
        local ok2, r2 = pcall(function() return game:HttpGet(url, true) end)
        if ok2 and type(r2)=="string" and #r2>0 then return r2 end
        local req = syn and syn.request or request or http_request or (http and http.request)
        if not req then return nil end
        local ok3, r3 = pcall(req, { Url=url, Method="GET" })
        if ok3 and type(r3)=="table" and type(r3.Body)=="string" and #r3.Body>0 then return r3.Body end
        return nil
    end

    local lua_src
    if isfile and readfile and pcall(isfile,"128bit/weapon.lua") and isfile("128bit/weapon.lua") then
        local ok2,r2 = pcall(readfile,"128bit/weapon.lua")
        if ok2 and type(r2)=="string" and #r2>100000 then lua_src=r2 end
    end
    if not lua_src then lua_src = httpGet("https://raw.githubusercontent.com/kroxn/visual/refs/heads/main/weapon.lua") end
    if not lua_src then notify("MM2Viz","โหลด mesh data ไม่ได้","Error",5); MM2Viz.active=false; return end

    local chunk,err = loadstring(lua_src.."\nreturn MESHES_FULL")
    if not chunk then notify("MM2Viz","compile error: "..tostring(err),"Error",5); MM2Viz.active=false; return end

    if writefile then pcall(function()
        if makefolder and isfolder and not isfolder("128bit") then makefolder("128bit") end
        writefile("128bit/weapon.lua", lua_src)
    end) end

    local MESHES_RAW = chunk()
    if type(MESHES_RAW)~="table" or not next(MESHES_RAW) then
        notify("MM2Viz","weapon.lua ได้ตาราง empty","Error",5); MM2Viz.active=false; return
    end

    local tblAll = {}
    for k,v in pairs(MESHES_RAW) do tblAll[k]=v end
    -- SweetChroma → Sweet patch
    local sc = tblAll.SweetChroma
    if sc and sc.Model and not tblAll.Sweet then
        local function cloneNode(n)
            local t2={Class=n.Class,Id=n.Id,Name=n.Name,Props=n.Props,Tags=n.Tags}
            if n.Children then t2.Children={}
                for _,c in ipairs(n.Children) do
                    if not(c.Class=="Decal" and c.Name=="Chroma") then t2.Children[#t2.Children+1]=cloneNode(c) end
                end
            end; return t2
        end
        local m2={}; for k2,v2 in pairs(sc.Meta or {}) do m2[k2]=v2 end; m2.Chroma=nil
        tblAll.Sweet={Complete=false,Meta=m2,Model=cloneNode(sc.Model)}
    end

    local rarityOk={Godly=true,Ancient=true}
    local MESHES={}
    for k,v in pairs(tblAll) do
        local wd=weapons[k]
        if type(wd)=="table" and (wd.ItemType=="Knife" or wd.ItemType=="Gun") and rarityOk[wd.Rarity] and wd.ItemName and wd.ItemName~="" then
            MESHES[k]=v
        end
    end

    -- helpers
    local identCF = CFrame.identity
    local chromaColors={Color3.fromRGB(255,0,0),Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(0,0,255),Color3.fromRGB(255,0,255)}
    local chromaTex="rbxassetid://18363392181"
    local function chromaLerp(t) local n=#chromaColors; local p=t%n; local i=math.floor(p); return chromaColors[i+1]:Lerp(chromaColors[(i+1)%n+1],p-i) end
    local function isChromaSkin(key,sd) return (sd.Meta and sd.Meta.Chroma==true) or (key:sub(-6)=="Chroma") end
    local function trimStr(s) return type(s)=="string" and s:gsub("^%s+",""):gsub("%s+$","") or s end

    local function applyProps(inst,props,skip)
        for k,v in pairs(props) do
            if not(skip and skip[k]) then
                if k=="MeshId" or k=="TextureId" or k=="TextureID" or k=="Texture" then v=trimStr(v) end
                pcall(function() inst[k]=v end)
            end
        end
    end
    local function makeMeshPart(meshId,size)
        local id=trimStr(meshId or ""); local mp
        pcall(function() mp=insertService:CreateMeshPartAsync(id,Enum.CollisionFidelity.Box,Enum.RenderFidelity.Precise) end)
        if mp then pcall(function() mp.Size=size end); return mp end
        local p=Instance.new("Part"); p.Size=size or Vector3.one
        local sm=Instance.new("SpecialMesh"); sm.MeshType=Enum.MeshType.FileMesh; pcall(function() sm.MeshId=id end); sm.Parent=p; return p
    end

    local chromaTags={ChromaPart="part",ChromaDecal="decal",ChromaFire="fire"}
    local function tagChroma(inst,node) if not(inst and node.Tags) then return end for _,tag in ipairs(node.Tags) do local a=chromaTags[tag]; if a then pcall(function() inst:SetAttribute("MM2Chroma",a) end) end end end

    local function startChroma(root2)
        local parts,decals,fires={},{},{}
        for _,d in ipairs(root2:GetDescendants()) do
            local a=d:GetAttribute("MM2Chroma")
            if a then
                if a=="part" then parts[#parts+1]=d
                elseif a=="decal" and d:IsA("Decal") then pcall(function() d.Texture=chromaTex end); decals[#decals+1]=d
                elseif a=="fire" then fires[#fires+1]=d end
            end
        end
        if #parts==0 and #decals==0 and #fires==0 then return nil end
        return runService.Heartbeat:Connect(function()
            local col=chromaLerp(os.clock())
            for _,d in ipairs(decals) do d.Color3=col end
            local ni=math.floor(os.clock()*1.8)
            for i,p in ipairs(parts) do p.Color=chromaColors[(ni+i-1)%#chromaColors+1] end
            for _,f in ipairs(fires) do if f:IsA("Fire") then f.Color=col elseif f:IsA("BasePart") then f.Color=col end end
        end)
    end

    local weldClasses={WeldConstraint=true,Weld=true,Motor6D=true,RigidConstraint=true,Bone=true,Snap=true,ManualWeld=true,Rotate=true,RotateP=true,RotateV=true}
    local function buildNode(nd)
        if weldClasses[nd.Class] then return nil end
        local inst
        if nd.Class=="MeshPart" then
            inst=makeMeshPart(nd.Props.MeshId,nd.Props.Size); applyProps(inst,nd.Props,{MeshId=true,Size=true,RelCF=true,CanCollide=true})
        else
            local ok2,r2=pcall(Instance.new,nd.Class); if not ok2 or not r2 then return nil end
            inst=r2; applyProps(inst,nd.Props,{RelCF=true})
        end
        if nd.Name then pcall(function() inst.Name=nd.Name end) end
        tagChroma(inst,nd); return inst
    end

    local function buildChildren(nd,parentInst,container,idMap,parts_list,beams_list)
        for _,child in ipairs(nd.Children or {}) do
            local inst=buildNode(child)
            if inst then
                idMap[child.Id]=inst
                if inst:IsA("BasePart") then
                    inst.Anchored=false;inst.CanCollide=false;inst.CanQuery=false;inst.CanTouch=false;inst.Massless=true
                    parts_list[#parts_list+1]={inst=inst,relcf=child.Props.RelCF}; inst.Parent=container
                    buildChildren(child,inst,container,idMap,parts_list,beams_list)
                elseif inst:IsA("Attachment") then
                    if child.Props.RelCF then pcall(function() inst.CFrame=child.Props.RelCF end) end
                    inst.Parent=container; buildChildren(child,inst,container,idMap,parts_list,beams_list)
                elseif inst:IsA("Beam") or inst:IsA("Trail") then
                    inst.Parent=parentInst; beams_list[#beams_list+1]={inst=inst,a0=child.Att0,a1=child.Att1}
                    buildChildren(child,inst,container,idMap,parts_list,beams_list)
                else inst.Parent=parentInst; buildChildren(child,inst,container,idMap,parts_list,beams_list) end
            else buildChildren(child,parentInst,container,idMap,parts_list,beams_list) end
        end
    end

    local function buildFromModel(sd)
        local model=sd.Model; if not model then return nil end
        local root_part
        if model.Class=="MeshPart" then root_part=makeMeshPart(model.Props.MeshId,model.Props.Size); applyProps(root_part,model.Props,{MeshId=true,Size=true,RelCF=true,CanCollide=true})
        else root_part=Instance.new("Part"); applyProps(root_part,model.Props,{RelCF=true,CanCollide=true}) end
        if model.Name then pcall(function() root_part.Name=model.Name end) end
        tagChroma(root_part,model)
        root_part.Anchored=false;root_part.CanCollide=false;root_part.CanQuery=false;root_part.CanTouch=false;root_part.Massless=true
        local idMap={[model.Id]=root_part}; local parts_list,beams_list={},{}
        buildChildren(model,root_part,root_part,idMap,parts_list,beams_list)
        for _,beam in ipairs(beams_list) do
            if beam.a0 and idMap[beam.a0] then pcall(function() beam.inst.Attachment0=idMap[beam.a0] end) end
            if beam.a1 and idMap[beam.a1] then pcall(function() beam.inst.Attachment1=idMap[beam.a1] end) end
        end
        return {root=root_part,parts=parts_list}
    end

    local function buildFromDisplay(sd)
        local display=sd.Display or {}; local rootDef,specMeshes,decals,effects=nil,{},{},{}
        for _,item in ipairs(display) do
            if item.Path=="(root)" then rootDef=item
            elseif item.Class=="SpecialMesh" then specMeshes[#specMeshes+1]=item
            elseif item.Class=="Decal" or item.Class=="Texture" then decals[#decals+1]=item
            elseif ({ParticleEmitter=true,Fire=true,Smoke=true,Sparkles=true})[item.Class] then effects[#effects+1]=item end
        end
        if not rootDef then return nil end
        local root_part
        if rootDef.Class=="MeshPart" then root_part=makeMeshPart(rootDef.Props.MeshId,rootDef.Props.Size); applyProps(root_part,rootDef.Props,{MeshId=true,Size=true,CanCollide=true})
        else
            root_part=Instance.new("Part"); root_part.Size=rootDef.Props.Size or Vector3.one; applyProps(root_part,rootDef.Props,{Size=true,CanCollide=true})
            for _,sm in ipairs(specMeshes) do local mesh=Instance.new("SpecialMesh"); mesh.MeshType=Enum.MeshType.FileMesh; applyProps(mesh,sm.Props); mesh.Parent=root_part end
        end
        root_part.Anchored=false;root_part.CanCollide=false;root_part.CanQuery=false;root_part.CanTouch=false;root_part.Massless=true
        if rootDef.Name then pcall(function() root_part.Name=rootDef.Name end) end
        for _,d in ipairs(decals) do local dec=Instance.new("Decal"); applyProps(dec,d.Props); if d.Name then pcall(function() dec.Name=d.Name end) end; dec.Parent=root_part end
        for _,eff in ipairs(effects) do local ok2,inst=pcall(Instance.new,eff.Class); if ok2 and inst then applyProps(inst,eff.Props); if eff.Name then pcall(function() inst.Name=eff.Name end) end; inst.Parent=root_part end end
        return {root=root_part,parts={}}
    end

    local function buildSkinModel(sd)
        if sd.Model   then return buildFromModel(sd)   end
        if sd.Display then return buildFromDisplay(sd) end
        return nil
    end

    local function placeAndWeld(built,cf)
        pcall(function() built.root.CFrame=cf end)
        for _,p in ipairs(built.parts) do
            if p.relcf then pcall(function() p.inst.CFrame=cf*p.relcf end) end
            local wc=Instance.new("WeldConstraint"); wc.Part0=p.inst; wc.Part1=built.root; wc.Parent=p.inst
        end
        return built.root
    end

    local function hideInst(list,inst)
        if inst:IsA("BasePart") or inst:IsA("Decal") then list[#list+1]={inst=inst,prop="Transparency",val=inst.Transparency}; pcall(function() inst.Transparency=1 end)
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            list[#list+1]={inst=inst,prop="Enabled",val=inst.Enabled}; pcall(function() inst.Enabled=false end) end
    end
    local function restoreHidden(list) for _,h in ipairs(list) do pcall(function() h.inst[h.prop]=h.val end) end end
    local function lockHidden(list)
        local conns={}
        for _,h in ipairs(list) do
            local inst,prop=h.inst,h.prop
            conns[#conns+1]=inst:GetPropertyChangedSignal(prop):Connect(function()
                if prop=="Enabled" then if inst.Enabled then inst.Enabled=false end
                elseif inst.Transparency~=1 then inst.Transparency=1 end
            end)
        end; return conns
    end
    local function disconnectConns(c) for _,v in ipairs(c or {}) do pcall(function() v:Disconnect() end) end end

    local function getSkinMeshId(sd)
        if sd.Model then
            local m=sd.Model; if m.Class=="MeshPart" then return trimStr(m.Props.MeshId or "") end
            for _,c in ipairs(m.Children or {}) do if c.Class=="SpecialMesh" then return trimStr(c.Props.MeshId or "") end end
            return ""
        end
        for _,d in ipairs(sd.Display or {}) do
            if d.Path=="(root)" and d.Class=="MeshPart" then return trimStr(d.Props.MeshId or "") end
            if d.Class=="SpecialMesh" then return trimStr(d.Props.MeshId or "") end
        end; return ""
    end
    local function getMeshId(part)
        if not part then return "" end
        if part:IsA("MeshPart") then return trimStr(part.MeshId or "") end
        local sm=part:FindFirstChildWhichIsA("SpecialMesh",true); return sm and trimStr(sm.MeshId or "") or ""
    end

    local gripOffsets={
        Gun_ZYX=CFrame.new(0.12991,-3e-05,0.075,1,0,0,0,0.70713,0.70708,0,-0.70708,0.70713),
        Gun_ZXY=CFrame.new(0.12991,0,0.07501,2e-05,-0.5,-0.86603,1,-4e-05,5e-05,-6e-05,-0.86603,0.5),
        Gun_XYZ=CFrame.new(-0.22989,0.09821,0.1,1e-05,0.98481,-0.17362,-1e-05,0.17362,0.98481,1,-1e-05,1e-05),
        Knife_YXZ=CFrame.new(0,0,0,-0.0446,-0.00031,-0.99901,0.03549,0.99937,-0.00189,0.99837,-0.03553,-0.04456),
        Knife_ZYX=CFrame.new(0.00151,-0.12701,-0.15448,-0.99867,0.03727,0.03568,-0.04098,-0.15276,-0.98741,-0.03135,-0.98756,0.15409),
        Knife_ZXY=CFrame.new(0.00151,-0.12701,-0.15448,-0.99867,0.03727,0.03568,-0.04098,-0.15276,-0.98741,-0.03135,-0.98756,0.15409),
    }
    local function sortAxes(sVec)
        if not sVec then return nil end
        local a={{sVec.X,"X"},{sVec.Y,"Y"},{sVec.Z,"Z"}}; table.sort(a,function(x,y) return x[1]>y[1] end)
        return a[1][2]..a[2][2]..a[3][2]
    end
    local function getSkinSize(sd)
        if sd.Model then return sd.Model.Props and sd.Model.Props.Size end
        for _,d in ipairs(sd.Display or {}) do if d.Path=="(root)" then return d.Props and d.Props.Size end end
    end
    local function findCustomAttCF(node)
        for _,c in ipairs(node.Children or {}) do
            if c.Class=="Attachment" and c.Name=="CustomAttachment" and c.Props and c.Props.RelCF then return c.Props.RelCF end
            local r=findCustomAttCF(c); if r then return r end
        end
    end
    local learnedGrips=_G.__MM2VizLearned or {}; _G.__MM2VizLearned=learnedGrips
    local function learnGrip(part)
        local mid=getMeshId(part); local att=part:FindFirstChild("CustomAttachment") or part:FindFirstChildWhichIsA("Attachment")
        if mid~="" and att then learnedGrips[mid]=att.CFrame end
    end
    local function getGripOffset(key,sd,slotType)
        if sd.Model then return findCustomAttCF(sd.Model) or identCF end
        local smid=getSkinMeshId(sd)
        if smid~="" and learnedGrips[smid] then return learnedGrips[smid] end
        local ax=sortAxes(getSkinSize(sd)); return ax and gripOffsets[(type(weapons[key])=="table" and weapons[key].ItemType or slotType).."_"..ax] or identCF
    end
    local function getDisplayGripCF(dispRef,gripOff)
        local att=dispRef:FindFirstChild("CustomAttachment") or dispRef:FindFirstChildWhichIsA("Attachment")
        return dispRef.CFrame*(att and att.CFrame or identCF)*gripOff:Inverse()
    end

    local overlayState={}; local equippedSkins={}; local slotVer={Knife=0,Gun=0}

    local function clearSlot(slotType)
        local st=overlayState[slotType]; if not st then return end
        if st.chroma then pcall(function() st.chroma:Disconnect() end) end
        if st.overlay then pcall(function() st.overlay:Destroy() end) end
        disconnectConns(st.guards); restoreHidden(st.hidden); overlayState[slotType]=nil
    end

    local function getDisplayRef(slotType)
        local c2=localPlayer.Character; if not c2 then return nil end
        local ov=c2:FindFirstChild("DisplayRef"..slotType); return ov and ov.Value or nil
    end
    local function waitDisplayRef(slotType,t)
        local dl=os.clock()+(t or 1.5)
        while os.clock()<dl do local d=getDisplayRef(slotType); if d then return d end; task.wait(0.05) end
        return getDisplayRef(slotType)
    end

    local function applyOverlay(slotType,skinKey)
        if overlayState[slotType] and equippedSkins[slotType]==skinKey and skinKey~=nil then return end
        slotVer[slotType]=(slotVer[slotType] or 0)+1; local ver=slotVer[slotType]
        clearSlot(slotType); equippedSkins[slotType]=skinKey
        local sd=skinKey and MESHES[skinKey]; if not sd then return end
        local dr=getDisplayRef(slotType) or waitDisplayRef(slotType,1.5)
        if slotVer[slotType]~=ver then return end; if not dr then return end
        learnGrip(dr)
        if getMeshId(dr)==getSkinMeshId(sd) and getMeshId(dr)~="" then return end
        local gripCF=getGripOffset(skinKey,sd,slotType)
        local hidden={}; hideInst(hidden,dr); for _,d in ipairs(dr:GetDescendants()) do hideInst(hidden,d) end
        local built=buildSkinModel(sd)
        if not built or not built.root or slotVer[slotType]~=ver or not dr.Parent then restoreHidden(hidden); if built and built.root then built.root:Destroy() end; return end
        local placed=placeAndWeld(built,getDisplayGripCF(dr,gripCF))
        placed:SetAttribute("MM2VizOverlay",true); placed:SetAttribute("MM2VizSlot",slotType); placed.Parent=dr.Parent or dr
        local wc=Instance.new("WeldConstraint"); wc.Part0=placed; wc.Part1=dr; wc.Parent=placed
        local cc=isChromaSkin(skinKey,sd) and startChroma(placed) or nil
        overlayState[slotType]={overlay=placed,hidden=hidden,chroma=cc,guards=lockHidden(hidden)}
    end

    -- tool handle overlay
    local toolOverState={}
    local function applyToolOverlay(tool,slotType)
        if toolOverState[tool] then return end
        local handle=tool:FindFirstChild("Handle") or tool:WaitForChild("Handle",5); if not handle then return end
        local sk=ProfileData.Weapons.Equipped[slotType]; local sd=sk and MESHES[sk]; if not sd then return end
        learnGrip(handle)
        local built=buildSkinModel(sd); if not built or not built.root then return end
        local hidden={}; hideInst(hidden,handle); for _,d in ipairs(handle:GetDescendants()) do hideInst(hidden,d) end
        placeAndWeld(built,handle.CFrame*getGripOffset(sk,sd,slotType)); built.root.Parent=handle
        local wc=Instance.new("WeldConstraint"); wc.Part0=built.root; wc.Part1=handle; wc.Parent=built.root
        local cc=isChromaSkin(sk,sd) and startChroma(built.root) or nil
        toolOverState[tool]={overlay=built.root,hidden=hidden,chroma=cc,guards=lockHidden(hidden)}
    end
    local function removeToolOverlay(tool)
        local st=toolOverState[tool]; if not st then return end
        if st.chroma then pcall(function() st.chroma:Disconnect() end) end
        if st.overlay then pcall(function() st.overlay:Destroy() end) end
        disconnectConns(st.guards); restoreHidden(st.hidden); toolOverState[tool]=nil
    end
    local function isLocalTool(tool)
        if tool:IsDescendantOf(localPlayer) then return true end
        local c2=localPlayer.Character; return c2~=nil and tool:IsDescendantOf(c2)
    end

    -- baseline
    if not _G.__MM2VizBaseline then
        local bl={}; for k,v in pairs(ProfileData.Weapons.Owned) do bl[k]=v end; _G.__MM2VizBaseline=bl
    end
    if not _G.__MM2VizBaselineEq then _G.__MM2VizBaselineEq={Knife=ProfileData.Weapons.Equipped.Knife,Gun=ProfileData.Weapons.Equipped.Gun} end
    local mM2VizBaseline=_G.__MM2VizBaseline; local mM2VizBaselineEq=_G.__MM2VizBaselineEq

    local function spawnSkin(key,n)
        local owned=ProfileData.Weapons.Owned; owned[key]=(owned[key] or 0)+(n or 1)
        pcall(function() invDataChanged:Fire("Weapons",key,owned[key]) end)
    end
    local function despawnAll()
        local owned=ProfileData.Weapons.Owned
        for k in pairs(MESHES) do local bl=mM2VizBaseline[k]; if owned[k]~=bl then owned[k]=bl; pcall(function() invDataChanged:Fire("Weapons",k,owned[k] or 0) end) end end
        for _,slotType in ipairs({"Knife","Gun"}) do
            local eq=ProfileData.Weapons.Equipped[slotType]
            if eq and owned[eq]==nil then
                local fb=mM2VizBaselineEq[slotType]
                if not(fb and owned[fb]) then fb=nil; for k in pairs(owned) do local wd=weapons[k]; if type(wd)=="table" and wd.ItemType==slotType then fb=k; break end end end
                if not fb then fb=slotType=="Knife" and "DefaultKnife" or "DefaultGun" end
                ProfileData.Weapons.Equipped[slotType]=fb; pcall(function() EquipService.EquippedChanged:Fire(slotType,fb) end)
            end
        end
    end

    -- sorted list
    local skinList={}
    for k in pairs(MESHES) do
        local wd=weapons[k]; skinList[#skinList+1]={key=k,name=type(wd)=="table" and wd.ItemName or k,type=type(wd)=="table" and wd.ItemType or "",rarity=type(wd)=="table" and wd.Rarity or "",chroma=isChromaSkin(k,MESHES[k])}
    end
    table.sort(skinList,function(a,b) if a.type~=b.type then return a.type<b.type end; if a.rarity~=b.rarity then return a.rarity<b.rarity end; return a.name:lower()<b.name:lower() end)

    -- ---- MM2Spawner GUI (Onyx-style dark glass) ----
    local spawnerGui=Instance.new("ScreenGui"); spawnerGui.Name="MM2Spawner"; spawnerGui.ResetOnSpawn=false
    spawnerGui.IgnoreGuiInset=true; spawnerGui.DisplayOrder=999999
    pcall(function() spawnerGui.Parent=gethui and gethui() or game:GetService("CoreGui") end)
    if not spawnerGui.Parent then spawnerGui.Parent=localPlayer:WaitForChild("PlayerGui") end
    MM2Viz.guiRef=spawnerGui

    local mainFrame=Instance.new("Frame"); mainFrame.Size=UDim2.fromOffset(290,420); mainFrame.Position=UDim2.new(0,20,0.5,-210)
    mainFrame.BackgroundColor3=Color3.fromRGB(14,14,19); mainFrame.BorderSizePixel=0; mainFrame.Active=true; mainFrame.Draggable=true; mainFrame.Parent=spawnerGui
    Instance.new("UICorner",mainFrame).CornerRadius=UDim.new(0,14)
    local mfGrad=Instance.new("UIGradient",mainFrame); mfGrad.Rotation=90
    mfGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(22,20,36)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,10,20))}
    local mfStroke=Instance.new("UIStroke",mainFrame); mfStroke.Thickness=1.2; mfStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; mfStroke.Color=Color3.fromRGB(100,80,180); mfStroke.Transparency=0.3

    local titleLbl=Instance.new("TextLabel"); titleLbl.Size=UDim2.new(1,-30,0,28); titleLbl.Position=UDim2.fromOffset(14,8)
    titleLbl.BackgroundTransparency=1; titleLbl.Text="128B!t  ·  Weapon Skins"; titleLbl.Font=Enum.Font.GothamBold
    titleLbl.TextSize=13; titleLbl.TextColor3=Color3.fromRGB(210,195,255); titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=mainFrame

    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.fromOffset(20,20); closeBtn.Position=UDim2.new(1,-26,0,8)
    closeBtn.BackgroundColor3=Color3.fromRGB(50,20,20); closeBtn.Text="✕"; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=10
    closeBtn.TextColor3=Color3.fromRGB(220,100,100); closeBtn.BorderSizePixel=0; closeBtn.Parent=mainFrame
    Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(1,0)
    closeBtn.MouseButton1Click:Connect(function() spawnerGui.Enabled=false end)

    local spawnAllBtn=Instance.new("TextButton"); spawnAllBtn.Size=UDim2.new(0.5,-16,0,26); spawnAllBtn.Position=UDim2.fromOffset(12,38)
    spawnAllBtn.BackgroundColor3=Color3.fromRGB(30,55,40); spawnAllBtn.BorderSizePixel=0; spawnAllBtn.Font=Enum.Font.GothamBold; spawnAllBtn.TextSize=11
    spawnAllBtn.TextColor3=Color3.fromRGB(160,235,185); spawnAllBtn.Text="Spawn All"; spawnAllBtn.Parent=mainFrame
    Instance.new("UICorner",spawnAllBtn).CornerRadius=UDim.new(0,8)
    local saBorder=Instance.new("UIStroke",spawnAllBtn); saBorder.Thickness=1; saBorder.Color=Color3.fromRGB(80,160,110); saBorder.Transparency=0.4

    local despawnAllBtn=Instance.new("TextButton"); despawnAllBtn.Size=UDim2.new(0.5,-16,0,26); despawnAllBtn.Position=UDim2.new(0.5,4,0,38)
    despawnAllBtn.BackgroundColor3=Color3.fromRGB(55,28,32); despawnAllBtn.BorderSizePixel=0; despawnAllBtn.Font=Enum.Font.GothamBold; despawnAllBtn.TextSize=11
    despawnAllBtn.TextColor3=Color3.fromRGB(235,160,170); despawnAllBtn.Text="Despawn All"; despawnAllBtn.Parent=mainFrame
    Instance.new("UICorner",despawnAllBtn).CornerRadius=UDim.new(0,8)
    local daBorder=Instance.new("UIStroke",despawnAllBtn); daBorder.Thickness=1; daBorder.Color=Color3.fromRGB(160,80,90); daBorder.Transparency=0.4

    local statusLbl=Instance.new("TextLabel"); statusLbl.Size=UDim2.new(1,-20,0,14); statusLbl.Position=UDim2.fromOffset(12,68)
    statusLbl.BackgroundTransparency=1; statusLbl.Text="Ready"; statusLbl.Font=Enum.Font.Gotham; statusLbl.TextSize=10
    statusLbl.TextColor3=Color3.fromRGB(160,155,185); statusLbl.TextXAlignment=Enum.TextXAlignment.Left; statusLbl.Parent=mainFrame
    local function setStatus(msg,col) statusLbl.Text=msg; statusLbl.TextColor3=col or Color3.fromRGB(160,155,185) end

    local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,-20,1,-86); scroll.Position=UDim2.fromOffset(10,80)
    scroll.BackgroundColor3=Color3.fromRGB(10,10,16); scroll.BackgroundTransparency=0.4; scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=5; scroll.ScrollBarImageColor3=Color3.fromRGB(100,80,170); scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=mainFrame
    Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,8)
    local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,2); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Parent=scroll
    local lp=Instance.new("UIPadding"); lp.PaddingTop=UDim.new(0,3); lp.PaddingBottom=UDim.new(0,3); lp.PaddingLeft=UDim.new(0,3); lp.PaddingRight=UDim.new(0,3); lp.Parent=scroll

    local rarityCol={Godly=Color3.fromRGB(220,100,180),Ancient=Color3.fromRGB(140,80,220)}

    task.spawn(function()
        for i,item in ipairs(skinList) do
            local isbtn=Instance.new("TextButton"); isbtn.Size=UDim2.new(1,-6,0,24)
            isbtn.BackgroundColor3=Color3.fromRGB(18,16,28); isbtn.BackgroundTransparency=0.2
            isbtn.Font=Enum.Font.Gotham; isbtn.TextSize=11; isbtn.TextColor3=Color3.fromRGB(220,215,240)
            isbtn.TextXAlignment=Enum.TextXAlignment.Left; isbtn.TextTruncate=Enum.TextTruncate.AtEnd
            isbtn.Text="  "..item.name..(item.chroma and "  ✦" or "").."  —  "..item.rarity.." "..item.type
            isbtn.LayoutOrder=i; isbtn.Parent=scroll
            Instance.new("UICorner",isbtn).CornerRadius=UDim.new(0,5)
            local isbtnStroke=Instance.new("UIStroke",isbtn); isbtnStroke.Thickness=1
            isbtnStroke.Color=rarityCol[item.rarity] or Color3.fromRGB(80,75,110); isbtnStroke.Transparency=0.55
            local key=item.key
            isbtn.MouseButton1Click:Connect(function()
                spawnSkin(key,1); setStatus("Spawned: "..item.name,Color3.fromRGB(140,220,165))
                local orig=isbtn.BackgroundColor3; isbtn.BackgroundColor3=Color3.fromRGB(0,80,50)
                task.delay(0.2,function() if isbtn.Parent then isbtn.BackgroundColor3=orig end end)
            end)
            isbtn.MouseButton1Down:Connect(function() tweenService:Create(isbtn,TweenInfo.new(0.07),{BackgroundTransparency=0}):Play() end)
            isbtn.MouseButton1Up:Connect(function() tweenService:Create(isbtn,TweenInfo.new(0.12),{BackgroundTransparency=0.2}):Play() end)
            if i%60==0 then task.wait() end
        end
    end)

    spawnAllBtn.MouseButton1Click:Connect(function()
        if spawnAllBtn.Text~="Spawn All" then return end; spawnAllBtn.Text="..."
        task.spawn(function()
            for i,item in ipairs(skinList) do spawnSkin(item.key,1); if i%25==0 then task.wait() end end
            spawnAllBtn.Text="Spawn All"; setStatus("All skins spawned!",Color3.fromRGB(140,220,165))
        end)
    end)
    despawnAllBtn.MouseButton1Click:Connect(function()
        if despawnAllBtn.Text~="Despawn All" then return end; despawnAllBtn.Text="..."
        task.spawn(function() despawnAll(); despawnAllBtn.Text="Despawn All"; setStatus("Skins removed.",Color3.fromRGB(220,160,110)) end)
    end)

    -- equip polling
    local pollState={Knife=nil,Gun=nil}
    pcall(function() pollState.Knife=ProfileData.Weapons.Equipped.Knife; pollState.Gun=ProfileData.Weapons.Equipped.Gun end)

    task.spawn(function()
        for _,slotType in ipairs({"Knife","Gun"}) do
            local sk=ProfileData.Weapons.Equipped[slotType]; if sk then task.spawn(applyOverlay,slotType,sk) end
        end
        while MM2Viz.active do
            for _,slotType in ipairs({"Knife","Gun"}) do
                local sk; pcall(function() sk=ProfileData.Weapons.Equipped[slotType] end)
                if sk~=pollState[slotType] then
                    pollState[slotType]=sk; task.spawn(applyOverlay,slotType,sk)
                    for _,tool in ipairs(collectionService:GetTagged(slotType=="Gun" and "Weapon_Gun" or "Weapon_Knife")) do
                        if isLocalTool(tool) then task.spawn(function() removeToolOverlay(tool); applyToolOverlay(tool,slotType) end) end
                    end
                end
            end
            task.wait(0.1)
        end
    end)

    local connEq=EquipService.EquippedChanged.Event:Connect(function(slotType,skinKey)
        if slotType=="Knife" or slotType=="Gun" then pollState[slotType]=skinKey; task.spawn(applyOverlay,slotType,skinKey) end
    end)
    table.insert(MM2Viz.conns,connEq)

    local function watchChar(char2)
        local c2=char2.ChildAdded:Connect(function(child)
            if child.Name=="DisplayRefKnife" or child.Name=="DisplayRefGun" then
                local slotType=child.Name=="DisplayRefKnife" and "Knife" or "Gun"
                task.delay(0.2,function()
                    local sk=equippedSkins[slotType]; if sk then overlayState[slotType]=nil; applyOverlay(slotType,sk) end
                end)
            end
        end); table.insert(MM2Viz.conns,c2)
    end
    if localPlayer.Character then watchChar(localPlayer.Character) end
    local connChar=localPlayer.CharacterAdded:Connect(function(char2)
        for _,slotType in ipairs({"Knife","Gun"}) do
            local st=overlayState[slotType]; if st and st.overlay then pcall(function() st.overlay:Destroy() end) end; overlayState[slotType]=nil
        end; toolOverState={}; watchChar(char2)
        task.delay(1,function() for _,slotType in ipairs({"Knife","Gun"}) do local sk=equippedSkins[slotType]; if sk then applyOverlay(slotType,sk) end end end)
    end)
    table.insert(MM2Viz.conns,connChar)

    for _,tag in ipairs({"Weapon_Gun","Weapon_Knife"}) do
        local slotType=tag=="Weapon_Gun" and "Gun" or "Knife"
        for _,tool in ipairs(collectionService:GetTagged(tag)) do if isLocalTool(tool) then task.spawn(applyToolOverlay,tool,slotType) end end
        table.insert(MM2Viz.conns,collectionService:GetInstanceAddedSignal(tag):Connect(function(tool) if isLocalTool(tool) then task.spawn(applyToolOverlay,tool,slotType) end end))
        table.insert(MM2Viz.conns,collectionService:GetInstanceRemovedSignal(tag):Connect(function(tool) removeToolOverlay(tool) end))
    end

    setStatus("โหลดแล้ว "..#skinList.." สกิน",Color3.fromRGB(140,220,165))
    notify("MM2Viz","โหลดสำเร็จ! "..#skinList.." สกิน Godly/Ancient","Success",4)
end

-- WEAPON SKIN PAGE  (Stellar Library tab)
local skinSection1 = skinPage:Section({ Name = "Weapon Visualizer", Side = 1 })
local skinSection2 = skinPage:Section({ Name = "About",             Side = 2 })

skinSection1:Toggle({
    Name = "Enable MM2Viz", Flag = "MM2VizEnabled",
    Callback = function(v)
        if v then notify("MM2Viz","กำลังโหลด mesh data...","Info",3); task.spawn(mm2vizStart)
        else mm2vizDestroy(); notify("MM2Viz","ปิด Weapon Visualizer","Info",3) end
    end,
})
skinSection1:Button({ Name = "เปิด Skin Browser", Callback = function()
    if MM2Viz.guiRef then MM2Viz.guiRef.Enabled=not MM2Viz.guiRef.Enabled
    else notify("MM2Viz","เปิด MM2Viz ก่อนนะ","Warning",3) end
end })
skinSection1:Button({ Name = "Spawn All Skins", Callback = function()
    if not MM2Viz.guiRef then notify("MM2Viz","เปิด MM2Viz ก่อนนะ","Warning",3); return end
    local f=MM2Viz.guiRef:FindFirstChildOfClass("Frame"); if f then for _,b in ipairs(f:GetChildren()) do if b:IsA("TextButton") and b.Text=="Spawn All" then b:Activate() end end end
end })
skinSection1:Button({ Name = "Despawn All Skins", Callback = function()
    if not MM2Viz.guiRef then notify("MM2Viz","เปิด MM2Viz ก่อนนะ","Warning",3); return end
    local f=MM2Viz.guiRef:FindFirstChildOfClass("Frame"); if f then for _,b in ipairs(f:GetChildren()) do if b:IsA("TextButton") and b.Text=="Despawn All" then b:Activate() end end end
end })

skinSection2:Label({ Name = "• Godly / Ancient เท่านั้น" })
skinSection2:Label({ Name = "• Spawn → เพิ่ม inventory" })
skinSection2:Label({ Name = "• Equip ผ่านเกม → overlay" })
skinSection2:Label({ Name = "• Chroma = สีรุ้งหมุน" })
skinSection2:Label({ Name = "• Client-side เท่านั้น" })

-- ============================================================
-- DONE
-- ============================================================
Library:Notify({ Title = "128B!t | MM2 Loaded", Content = "Welcome " .. localPlayer.Name, Type = "Success", Duration = 5 })
