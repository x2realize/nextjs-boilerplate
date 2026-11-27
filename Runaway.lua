
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local SCRIPT_NAME    = "128B!t | Runaway"
local SCRIPT_VERSION = "v.1.0.0"

-- ============================================================================
-- LOAD OUROBOROS LIBRARY
-- ============================================================================
local Library, Window
do
    local ok, result = pcall(function()
        local url = "https://raw.githubusercontent.com/x2realize/Library/refs/heads/main/fetched.lua?cb=" .. tostring(os.time())
        local chunk, err = loadstring(game:HttpGet(url))
        if type(chunk) ~= "function" then
            error("library compile error: " .. tostring(err), 0)
        end
        local lib = chunk()
        if type(lib) ~= "table" then error("library did not return a table", 0) end
        return lib
    end)
    if not ok then error("Ouroboros load failed: " .. tostring(result), 0) end
    Library = result
end

Library:SetDefaultTheme("Mono")

Window = Library:CreateWindow({
    Name               = SCRIPT_NAME,
    LoadingSubtitle    = SCRIPT_VERSION,
    ToggleUIKeybind    = "RightControl",
    Logo = "rbxassetid://106838545453141",
    Icon = "rbxassetid://106838545453141",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "Realize_config",
        FileName   = "default",
    },
    ToggleButton = { Platform = "Mobile" },
    Home = {
        Title   = "Welcome to " .. SCRIPT_NAME .. "!",
        Tier    = SCRIPT_VERSION,
        Stats   = { "Players", "Session", "FPS", "Ping" },
    },
})

-- ============================================================================
-- TABS
-- ============================================================================
local AutoFarmTab  = Window:CreateTab({ Name = "Auto Farm",  Icon = "bot"            })
local CombatTab    = Window:CreateTab({ Name = "Combat",     Icon = "sword"          })
local MovementTab  = Window:CreateTab({ Name = "Movement",   Icon = "zap"            })
local LootTab      = Window:CreateTab({ Name = "Loot",       Icon = "package"        })
local VehicleTab   = Window:CreateTab({ Name = "Vehicle",    Icon = "car-front"      })
local ESPTab       = Window:CreateTab({ Name = "ESP",        Icon = "eye"            })
local GateTab      = Window:CreateTab({ Name = "Gate",       Icon = "door-open"      })
local SettingsTab  = Window:CreateTab({ Name = "Settings",   Icon = "settings"       })

-- ============================================================================
-- SERVICES + CORE REFS
-- ============================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")

local LP = Players.LocalPlayer
while not LP do task.wait(); LP = Players.LocalPlayer end

-- Wait for FlowClient
local flow
do
    local flowModule = ReplicatedStorage:WaitForChild("FlowClient", 30)
    if flowModule then
        pcall(function() flow = require(flowModule) end)
    end
    if not flow then
        pcall(function() flow = require(ReplicatedStorage:WaitForChild("FlowClient")) end)
    end
end

-- Wait for flow systems to initialize
if flow then
    local expires = os.clock() + 30
    while not (flow.GameManager or flow.Loot or flow.NPCs or flow.LobbyServer or flow.PlayerDataServer)
        and os.clock() < expires
    do
        task.wait(0.1)
    end
end

-- Data module
local data
pcall(function()
    data = require(ReplicatedStorage:WaitForChild("Data"))
end)

-- Loot data
local lootData = {}
local lootValueByName = {}
local dropCategoryByName = {}
local dropCategories = {}
local dropCategorySet = {}
local hiddenInventoryCategories = { BigElectronic = true, Cash = true, Painting = true, VehiclePart = true }
local maxLootValue = 0

if flow and flow.Loot then
    pcall(function()
        lootData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Loot"):WaitForChild("Data"))
        for _, entry in lootData do
            if entry.Item and entry.Category then
                dropCategoryByName[entry.Item] = entry.Category
                lootValueByName[entry.Item] = entry.Value
                maxLootValue = math.max(maxLootValue, tonumber(entry.Value) or 0)
                if not hiddenInventoryCategories[entry.Category] and not dropCategorySet[entry.Category] then
                    dropCategorySet[entry.Category] = true
                    dropCategories[#dropCategories + 1] = entry.Category
                end
            end
        end
        table.sort(dropCategories)
    end)
end

-- Loot folder
local lootFolder = workspace:FindFirstChild("Loot")
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Loot" then lootFolder = child end
end)

-- ============================================================================
-- HELPERS
-- ============================================================================
local function notify(msg, t)
    Library:Notify({ Title = SCRIPT_NAME, Content = tostring(msg), Type = t or "Info", Duration = 4 })
end

local function isLoot(item)
    if not lootFolder or item.Parent ~= lootFolder or not item:IsA("Model") then return false end
    local part = item.PrimaryPart
    return part
        and part:IsA("BasePart")
        and CollectionService:HasTag(item, "Draggable")
        and CollectionService:HasTag(item, "Equippable")
        and not CollectionService:HasTag(item, "BuyableLoot")
end

local function getLoot()
    local items, names, seen = {}, {}, {}
    if not lootFolder then return items, names end
    for _, item in lootFolder:GetChildren() do
        if isLoot(item) then
            items[#items + 1] = item
            if not seen[item.Name] then
                seen[item.Name] = true
                names[#names + 1] = item.Name
            end
        end
    end
    table.sort(items, function(a, b) return a.Name < b.Name end)
    table.sort(names)
    return items, names
end

local function getPickupCFrame(root, part)
    local offset = root.Position - part.Position
    local direction = Vector3.new(offset.X, 0, offset.Z)
    direction = direction.Magnitude > 0.1 and direction.Unit or Vector3.new(0, 0, 1)
    local excludes = { part:FindFirstAncestorWhichIsA("Model") or part }
    if root.Parent then excludes[#excludes + 1] = root.Parent end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    params.FilterDescendantsInstances = excludes
    local fallback
    for step = 0, 7 do
        local side = CFrame.fromAxisAngle(Vector3.yAxis, step * math.pi / 4):VectorToWorldSpace(direction)
        local pos = part.Position + side * 3 + Vector3.new(0, 2.5, 0)
        local cf = CFrame.lookAt(pos, Vector3.new(part.Position.X, pos.Y, part.Position.Z))
        fallback = fallback or cf
        if not workspace:Raycast(pos, part.Position - pos, params) then
            return cf
        end
    end
    return fallback
end

local function getHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getBackpackUsage()
    local backpack = LP:FindFirstChildOfClass("Backpack")
    local character = LP.Character
    if not backpack then return end
    local used = #backpack:GetChildren()
    if character and character:FindFirstChildOfClass("Tool") then used += 1 end
    local limits = {
        BackpackLarge  = data and data.Balance and data.Balance.MaxToolsLargeBackpack,
        BackpackMedium = data and data.Balance and data.Balance.MaxToolsMediumBackpack,
        BackpackSmall  = data and data.Balance and data.Balance.MaxToolsSmallBackpack,
    }
    for _, name in { "BackpackLarge", "BackpackMedium", "BackpackSmall" } do
        if (backpack:FindFirstChild(name) or character and character:FindFirstChild(name)) then
            return used, limits[name]
        end
    end
    return used, data and data.Balance and data.Balance.MaxTools
end

-- ============================================================================
-- TELEPORT SYSTEM (ported 1:1 from gg.txt)
-- ============================================================================
local teleports = {}
teleports.LastPosition = nil

function teleports:Stream(position)
    pcall(function() LP:RequestStreamAroundAsync(position, 5) end)
end

function teleports:GetEndZ()
    local flowModule = ReplicatedStorage:FindFirstChild("FlowClient")
    local gui        = flowModule and flowModule:FindFirstChild("Gui")
    local distModule = gui and gui:FindFirstChild("DistanceToBorderClient")
    if distModule then
        local ok, mod = pcall(require, distModule)
        if ok and type(mod) == "table" then
            local cb = mod.SetEndPos_event or mod.SetEndPos
            if type(cb) == "function" and debug and type(debug.getupvalues) == "function" then
                local read, upvalues = pcall(debug.getupvalues, cb)
                if read and type(upvalues) == "table" then
                    if type(upvalues[1]) == "number" then return upvalues[1] end
                    for _, v in pairs(upvalues) do
                        if type(v) == "number" and math.abs(v) > 1000 then return v end
                    end
                end
            end
        end
    end
    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, label in playerGui:GetDescendants() do
            if label:IsA("TextLabel") and label.Text:find("Mexico", 1, true) then
                local cur = label.Parent
                while cur and cur ~= playerGui do
                    local val = tonumber(cur.Name:match("^Border_(-?[%d%.]+)$"))
                    if val then return val end
                    cur = cur.Parent
                end
            end
        end
    end
end

function teleports:GetRoadNear(z)
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local best, bestDist, bestArea = nil, math.huge, 0
    for _, part in map:GetDescendants() do
        local name = part.Name:lower()
        local pname = part.Parent and part.Parent.Name:lower()
        if part:IsA("BasePart")
            and (name == "road" or name == "sideroad" or pname == "road")
            and not name:find("pathfinding", 1, true)
            and part.CanCollide and part.Transparency < 0.95
        then
            local dist = math.max(math.abs(part.Position.Z - z) - math.max(part.Size.X, part.Size.Z) * 0.5, 0)
            local area = part.Size.X * part.Size.Z
            if dist < bestDist or (dist == bestDist and area > bestArea) then
                best, bestDist, bestArea = part, dist, area
            end
        end
    end
    if bestDist <= 2000 then return best end
end

function teleports:GetEndPrompt()
    local map = workspace:FindFirstChild("Map")
    local buildings = map and map:FindFirstChild("Buildings")
    local customs = buildings and buildings:FindFirstChild("CustomsFinal")
    if not customs then return end
    local cb   = customs:FindFirstChild("CustomsBuilding")
    local fd   = cb and cb:FindFirstChild("FinalDoor")
    local cmd  = fd and fd:FindFirstChild("Command")
    local cbtn = cmd and cmd:FindFirstChild("CommandButton")
    local holder = cbtn and cbtn:FindFirstChild("Prompt")
    local prompt = holder and (holder:IsA("ProximityPrompt") and holder or holder:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then return prompt end
    local ok, candidates = pcall(customs.QueryDescendants, customs, "ProximityPrompt")
    if ok then
        for _, c in candidates do
            if c.ActionText == "Activate" and c:FindFirstAncestor("FinalDoor") then return c end
        end
    end
end

function teleports:GetEndAnchor(endZ, direction)
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local source = root and root.Position or Vector3.new(500, 2000, endZ)
    local map = workspace:FindFirstChild("Map")
    local buildings = map and map:FindFirstChild("Buildings")
    local best, bestDist = source, math.huge
    if buildings then
        for _, building in buildings:GetChildren() do
            if building:IsA("Model") then
                local ok, pivot = pcall(building.GetPivot, building)
                if ok then
                    if building.Name == "CustomsFinal" then
                        return pivot:PointToWorldSpace(Vector3.new(-44.4001, 4.65, -16.5))
                    end
                    local dist = math.abs(endZ - pivot.Position.Z)
                    local side = (endZ - pivot.Position.Z) * direction
                    if side >= -500 and dist < bestDist then
                        best, bestDist = pivot.Position, dist
                    end
                end
            end
        end
    end
    return Vector3.new(best.X, best.Y + 30, endZ - direction * 35)
end

function teleports:GetEndPromptDestination(prompt, direction)
    local holder = prompt and prompt.Parent
    local holderCF
    if holder and holder:IsA("Attachment") then holderCF = holder.WorldCFrame
    elseif holder and holder:IsA("BasePart") then holderCF = holder.CFrame end
    if not holderCF then return end
    local outward = holderCF.LookVector
    if outward.Z * direction > 0 then outward = -outward end
    if math.abs(outward.Z) < 0.25 then outward = Vector3.new(0, 0, -direction) end
    local position = holderCF.Position + outward * 4
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
    local result = workspace:Raycast(position + Vector3.yAxis * 20, Vector3.new(0, -60, 0), params)
    if result then position = Vector3.new(position.X, result.Position.Y + 3.25, position.Z) end
    return CFrame.lookAt(position, Vector3.new(holderCF.Position.X, position.Y, holderCF.Position.Z), Vector3.yAxis)
end

function teleports:GetStartCFrame()
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if not spawn or not spawn.Enabled then return end
    local excludes = { spawn }
    if LP.Character then excludes[#excludes + 1] = LP.Character end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excludes
    params.RespectCanCollide = true
    local result = workspace:Raycast(spawn.Position + Vector3.yAxis * 6, -Vector3.yAxis * 20, params)
    local y = result and result.Position.Y + 3.5 or spawn.Position.Y + 3
    return CFrame.new(spawn.Position.X, y, spawn.Position.Z) * spawn.CFrame.Rotation
end

function teleports:Move(destination, subject, saveLast)
    if typeof(destination) ~= "CFrame" then return false end
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    local root      = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not root or humanoid.Health <= 0 then return false end
    subject = subject or character
    local mover = subject == character and root or nil
    if not mover or not subject.Parent then return false end
    if saveLast ~= false then self.LastPosition = root.CFrame end
    local camera     = workspace.CurrentCamera
    local camCF      = camera and camera.CFrame
    local camSubject = camera and camera.CameraSubject
    local camType    = camera and camera.CameraType
    if camera then camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = camCF end
    local ok = pcall(function()
        if subject == character and humanoid.SeatPart then
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            RunService.Heartbeat:Wait()
        end
        subject:PivotTo(destination * mover.CFrame:Inverse() * subject:GetPivot())
        mover.AssemblyLinearVelocity  = Vector3.zero
        mover.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end)
    if camera and camera.Parent then
        camera.CameraSubject = camSubject
        camera.CameraType    = camType
        camera.CFrame        = camCF
    end
    return ok
end

-- ============================================================================
-- SHARED STATE
-- ============================================================================
local State = {
    Unloaded = false,
    -- Kill Aura
    KillAuraEnabled = false,
    KillAuraRadius  = 0,
    KillAuraToken   = nil,
    -- God Mode
    GodModeEnabled  = false,
    -- Noclip
    NoclipEnabled    = false,
    NoclipCollisions = nil,
    -- Safe Zone
    SafeZoneEnabled  = true,
    SafeCharacter    = nil,
    SafeCFrame       = nil,
    SafeRootAnchored = nil,
    -- Gate
    GateStartedAt = 0,
    GatePassage   = nil,
    GateText      = "--",
    GateTimeout   = 165,
    -- Auto Farm
    AutoFarmRunning = false,
    AutoFarmToken   = nil,
    AutoReplay      = true,
    LobbyDelay      = 3,
    RetryDelay      = 10,
    -- Stats
    Attempts  = 0, Completed = 0, Failed    = 0,
    Retries   = 0, NPCKills  = 0, Teleports = 0,
    Replays   = 0, StartedAt = 0, RunStartAt = 0,
    LastError = "None", Phase = "Idle", Detail = "Ready",
    -- session tracking
    LastGameJob   = "",
    ResultBusy    = false,
    Teleporting   = false,
    TeleportFailureGeneration  = 0,
    TeleportRecoveryGeneration = 0,
    TeleportRecovering         = false,
    TeleportRetryCount         = 0,
    TeleportRetryTarget        = 0,
    TeleportRetryOptions       = nil,
    TeleportRetryDelay         = 0,
    LastTeleportFailureAt      = 0,
    SessionId    = "",
    QueueJob     = nil,
    QueueStatus  = "Not armed",
    TransitionToken  = "",
    ExpectedPlaceId  = 0,
    TransitionAt     = 0,
    RunActive        = false,
    ActiveRunToken   = nil,
    RunHeartbeat     = 0,
    PendingFinish    = false,
    FinishCrossed    = false,
    PendingAt        = 0,
    ReplayRequested  = false,
    ResultFinalized  = false,
    RunCashStart     = 0,
    RunWinsStart     = 0,
    LastCredzBalance = nil,
    LastWins         = nil,
    PendingCredz     = 0,
    PendingWins      = 0,
    BalanceWarmupUntil = 0,
    LastPersistAt    = 0,
    LastEndScreenScanAt = 0,
    CrossCollisions  = nil,
    -- place IDs
    LobbyPlaceId = 118418618261207,
    GamePlaceId  = 117311404196294,
}

-- ============================================================================
-- SYSTEM 1 — KILL AURA (ported from gg.txt killAllNPCs)
-- ============================================================================
local function killAllNPCs(radius)
    local folder = workspace:FindFirstChild("NPCs")
    if not folder or not flow or not flow.NPCs or type(flow.NPCs.Damage) ~= "function" then return 0 end
    local character  = LP.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    local killed = 0
    for _, humanoid in folder:GetDescendants() do
        if humanoid:IsA("Humanoid") and humanoid.Health > 0 then
            local npc = humanoid:FindFirstAncestorWhichIsA("Model")
            local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
            local inRange = not radius or radius <= 0
                or (playerRoot and npcRoot and (npcRoot.Position - playerRoot.Position).Magnitude <= radius)
            if inRange then
                local ok = pcall(flow.NPCs.Damage, humanoid, humanoid.Health + 1)
                if ok then killed += 1 end
            end
        end
    end
    return killed
end

task.spawn(function()
    while true do
        task.wait(0.4)
        if State.KillAuraEnabled and not State.Unloaded then
            State.NPCKills += killAllNPCs(State.KillAuraRadius)
        end
    end
end)

-- ============================================================================
-- SYSTEM 2 — GOD MODE (ported from gg.txt applyGodMode)
-- ============================================================================
local humanoidStates = setmetatable({}, { __mode = "k" })
local blockedRemote = function() end

local function getHumanoidState(humanoid)
    local state = humanoidStates[humanoid]
    if not state then state = {}; humanoidStates[humanoid] = state end
    return state
end

local originalTakeDamage = flow and flow.PlayerDamage and flow.PlayerDamage.TakeDamage
local originalAbandon    = flow and flow.Passout and flow.Passout.Abandon

local function blockDamage(value)
    if flow and flow.PlayerDamage and type(originalTakeDamage) == "function" then
        flow.PlayerDamage.TakeDamage = value and blockedRemote or originalTakeDamage
    end
    if flow and flow.Passout and type(originalAbandon) == "function" then
        flow.Passout.Abandon = value and blockedRemote or originalAbandon
    end
end

local function applyGodMode(humanoid)
    local state = getHumanoidState(humanoid)
    if not state.GodMode then
        state.GodMode = {
            BreakJointsOnDeath = humanoid.BreakJointsOnDeath,
            RequiresNeck       = humanoid.RequiresNeck,
            DeadEnabled        = humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead),
        }
    end
    blockDamage(true)
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    humanoid.Health = humanoid.MaxHealth
    if humanoid:GetAttribute("Downed") == true then
        humanoid:SetAttribute("Downed", false)
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function restoreGodMode()
    blockDamage(false)
    for humanoid, state in humanoidStates do
        local original = state.GodMode
        if original then
            if humanoid.Parent then
                humanoid.BreakJointsOnDeath = original.BreakJointsOnDeath
                humanoid.RequiresNeck       = original.RequiresNeck
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, original.DeadEnabled)
            end
            state.GodMode = nil
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if State.GodModeEnabled and not State.Unloaded then
            local humanoid = getHumanoid()
            if humanoid and humanoid.Health > 0 then
                applyGodMode(humanoid)
            end
        end
    end
end)

-- ============================================================================
-- SYSTEM 3 — NOCLIP
-- ============================================================================
local collisionStates = setmetatable({}, { __mode = "k" })

local function setNoclip(value)
    State.NoclipEnabled = value
    local character = LP.Character
    if not character then return end
    if value then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                if collisionStates[part] == nil then
                    collisionStates[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        for part, canCollide in collisionStates do
            if part.Parent then part.CanCollide = canCollide end
        end
        table.clear(collisionStates)
    end
end

LP.CharacterAdded:Connect(function()
    if State.NoclipEnabled then
        task.wait(0.5)
        table.clear(collisionStates)
        setNoclip(true)
    end
end)

-- ============================================================================
-- SYSTEM 4 — MOVEMENT (speed/jump/gravity/FOV) — ported from gg.txt
-- ============================================================================
local movState = {
    SpeedEnabled  = false, SpeedValue   = 30,
    JumpEnabled   = false, JumpValue    = 60,
    GravEnabled   = false, GravValue    = 196,
    FOVEnabled    = false, FOVValue     = 70,
    InfJump       = false,
    AntiAFK       = false,
    AntiAFKConn   = nil,
    InfJumpConn   = nil,
    WalkSpeed     = nil,
    UseJumpPower  = nil, JumpPower = nil, JumpHeight = nil,
    Gravity       = nil,
    FOVOriginal   = nil,
}

local function applyMovement()
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if movState.SpeedEnabled then
        if movState.WalkSpeed == nil then movState.WalkSpeed = humanoid.WalkSpeed end
        humanoid.WalkSpeed = movState.SpeedValue
    end
    if movState.JumpEnabled then
        if movState.UseJumpPower == nil then
            movState.UseJumpPower = humanoid.UseJumpPower
            movState.JumpPower    = humanoid.JumpPower
            movState.JumpHeight   = humanoid.JumpHeight
        end
        humanoid.UseJumpPower = true
        humanoid.JumpPower    = movState.JumpValue
    end
    if movState.GravEnabled then
        if movState.Gravity == nil then movState.Gravity = workspace.Gravity end
        workspace.Gravity = movState.GravValue
    end
end

local function restoreMovement()
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and movState.WalkSpeed ~= nil then humanoid.WalkSpeed = movState.WalkSpeed end
    movState.WalkSpeed = nil
    if humanoid and movState.UseJumpPower ~= nil then
        humanoid.JumpPower    = movState.JumpPower
        humanoid.JumpHeight   = movState.JumpHeight
        humanoid.UseJumpPower = movState.UseJumpPower
    end
    movState.UseJumpPower = nil; movState.JumpPower = nil; movState.JumpHeight = nil
    if movState.Gravity ~= nil then workspace.Gravity = movState.Gravity end
    movState.Gravity = nil
end

-- PreSimulation step for movement
RunService.PreSimulation:Connect(function()
    applyMovement()
    if movState.FOVEnabled then
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = movState.FOVValue end
    end
end)

local function setAntiAFK(value)
    movState.AntiAFK = value
    if movState.AntiAFKConn then movState.AntiAFKConn:Disconnect(); movState.AntiAFKConn = nil end
    if value then
        local vu = game:GetService("VirtualUser")
        movState.AntiAFKConn = LP.Idled:Connect(function()
            pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.zero) end)
        end)
    end
end

local function setInfiniteJump(value)
    movState.InfJump = value
    if movState.InfJumpConn then movState.InfJumpConn:Disconnect(); movState.InfJumpConn = nil end
    if value then
        movState.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local character = LP.Character
            local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

-- ============================================================================
-- SYSTEM 5 — LOOT (ported from gg.txt collect/dropAllLoot/sellAllLoot)
-- ============================================================================
local busy = false

local function collect(filter)
    if busy then notify("Loot กำลังทำงานอยู่", "Warning"); return end
    if not flow or not flow.Loot or type(flow.Loot.LootEquip) ~= "function" then
        notify("LootEquip ไม่พร้อม", "Error"); return
    end
    busy = true
    task.spawn(function()
        local attempted, looted, failed, full = 0, 0, 0, false
        local character, root, startPivot, camera, camCF, camSubject, camType
        local ok, message = pcall(function()
            character = LP.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            root = character and character:FindFirstChild("HumanoidRootPart")
            if not character or not humanoid or not root or humanoid.Health <= 0 then
                error("Character ไม่พร้อม", 0)
            end
            if humanoid.SeatPart then error("ออกจากรถก่อน", 0) end
            local used, limit = getBackpackUsage()
            if not used or not limit then error("Backpack ไม่พร้อม", 0) end
            for _, item in getLoot() do
                if State.Unloaded then break end
                if not filter(item.Name) or not isLoot(item) then continue end
                local curUsed, curLimit = getBackpackUsage()
                if not curUsed or not curLimit then error("Backpack ไม่พร้อม", 0) end
                used = math.max(used, curUsed); limit = curLimit
                if used >= limit then full = true; break end
                attempted += 1
                local part = item.PrimaryPart
                local far = (root.Position - part.Position).Magnitude > 6
                if far then
                    if not startPivot then
                        startPivot = character:GetPivot()
                        camera = workspace.CurrentCamera
                        camCF = camera and camera.CFrame
                        camSubject = camera and camera.CameraSubject
                        camType = camera and camera.CameraType
                        if camera then camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = camCF end
                    end
                    character:PivotTo(getPickupCFrame(root, part))
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.18)
                end
                local callOk, result = pcall(flow.Loot.LootEquip, part)
                if far and (not callOk or result ~= "Success") and isLoot(item) then
                    task.wait(0.15)
                    callOk, result = pcall(flow.Loot.LootEquip, part)
                end
                if callOk and result == "Success" then looted += 1; used += 1
                else failed += 1 end
                task.wait(0.08)
            end
        end)
        if startPivot and character and character.Parent and root and root.Parent == character then
            character:PivotTo(startPivot)
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if camera and camera.Parent then
            camera.CameraSubject = camSubject
            camera.CameraType    = camType
            camera.CFrame        = camCF
        end
        busy = false
        if State.Unloaded then return end
        if not ok then notify("Loot ล้มเหลว: " .. tostring(message), "Error")
        elseif full then notify(string.format("Inventory เต็ม, เก็บได้ %d ชิ้น", looted), "Warning")
        elseif attempted == 0 then notify("ไม่มีของที่ตก", "Info")
        elseif failed == 0 then notify(string.format("เก็บได้ %d ชิ้น", looted), "Success")
        else notify(string.format("เก็บได้ %d, ล้มเหลว %d", looted, failed), "Warning") end
    end)
end

local function dropAllLoot()
    if busy then notify("กำลังทำงานอยู่", "Warning"); return end
    if not flow or not flow.Loot or type(flow.Loot.LootUnequip) ~= "function" then
        notify("LootUnequip ไม่พร้อม", "Error"); return
    end
    busy = true
    task.spawn(function()
        local dropped = 0
        local ok, message = pcall(function()
            local backpack = LP:FindFirstChildOfClass("Backpack")
            local character = LP.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not backpack or not character or not humanoid then error("Inventory ไม่พร้อม", 0) end
            local tools = {}
            for _, container in { backpack, character } do
                for _, tool in container:GetChildren() do
                    if tool:IsA("Tool") and not tool:HasTag("Undroppable") then
                        tools[#tools + 1] = tool
                    end
                end
            end
            humanoid:UnequipTools()
            for _, tool in tools do
                if tool.Parent == backpack or tool.Parent == character then
                    local callOk = pcall(flow.Loot.LootUnequip, tool, tool:HasTag("RemoteOnly"))
                    if callOk then dropped += 1 end
                    task.wait(0.05)
                end
            end
        end)
        busy = false
        if not ok then notify("Drop ล้มเหลว: " .. tostring(message), "Error")
        elseif dropped == 0 then notify("ไม่มีของที่จะทิ้ง", "Info")
        else notify(string.format("ทิ้งได้ %d ชิ้น", dropped), "Success") end
    end)
end

-- sell helper — uses PawnCounter tag like gg.txt
local function findNearestCounter()
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local best, bestDist = nil, math.huge
    for _, counter in CollectionService:GetTagged("PawnCounter") do
        local volume = counter:FindFirstChild("Volume", true)
        if volume and volume:IsA("BasePart") then
            local dist = (volume.Position - root.Position).Magnitude
            if dist < bestDist then best = counter; bestDist = dist end
        end
    end
    return best
end

local function getSellTools()
    local tools = {}
    for _, container in { LP:FindFirstChildOfClass("Backpack"), LP.Character } do
        if container then
            for _, tool in container:GetChildren() do
                if tool:IsA("Tool") and not tool:HasTag("Undroppable") and not tool:HasTag("Backpack") then
                    local value = lootValueByName[tool.Name]
                    if value and value > 0 then tools[#tools + 1] = tool end
                end
            end
        end
    end
    return tools
end

local function sellAllLoot()
    if busy then notify("กำลังทำงานอยู่", "Warning"); return end
    if not flow or not flow.Loot or type(flow.Loot.LootUnequip) ~= "function" then
        notify("LootUnequip ไม่พร้อม", "Error"); return
    end
    local counter = findNearestCounter()
    if not counter then notify("ไม่พบร้านรับซื้อในแผนที่", "Error"); return end
    if #getSellTools() == 0 then notify("ไม่มีของที่จะขาย", "Info"); return end
    busy = true
    task.spawn(function()
        local sold, failed = 0, 0
        local character, root, startPivot, camera, camCF, camSubject, camType
        local ok, message = pcall(function()
            character = LP.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            root = character and character:FindFirstChild("HumanoidRootPart")
            if not character or not humanoid or not root or humanoid.Health <= 0 then
                error("Character ไม่พร้อม", 0)
            end
            if humanoid.SeatPart then error("ออกจากรถก่อน", 0) end
            -- find counter parts
            local volume = counter:FindFirstChild("Volume", true)
            local bell   = counter:FindFirstChild("CallBell", true)
            local prompt = bell and bell:FindFirstChildWhichIsA("ProximityPrompt", true)
            if not volume or not bell or not prompt then error("ร้านรับซื้อไม่พร้อม", 0) end
            startPivot = character:GetPivot()
            camera    = workspace.CurrentCamera
            camCF     = camera and camera.CFrame
            camSubject = camera and camera.CameraSubject
            camType   = camera and camera.CameraType
            if camera then camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = camCF end
            -- move to counter
            local direction = bell.Position - volume.Position
            direction = Vector3.new(direction.X, 0, direction.Z)
            direction = direction.Magnitude > 0.1 and direction.Unit or -volume.CFrame.LookVector
            local pos = volume.Position + direction * 3.8
            pos = Vector3.new(pos.X, volume.Position.Y + 0.35, pos.Z)
            local stand = CFrame.lookAt(pos, Vector3.new(volume.Position.X, pos.Y, volume.Position.Z))
            local humanoid2 = character:FindFirstChildOfClass("Humanoid")
            if humanoid2 then humanoid2:UnequipTools() end
            character:PivotTo(stand)
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.35)
            -- drop tools
            local tools = getSellTools()
            local dropped = {}
            for _, tool in tools do
                local callOk = pcall(flow.Loot.LootUnequip, tool, tool:HasTag("RemoteOnly"))
                if callOk then dropped[#dropped + 1] = tool end
                task.wait(0.04)
            end
            task.wait(0.5)
            -- sell each
            local function press()
                if type(fireproximityprompt) == "function" then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.1)
                    prompt:InputHoldEnd()
                end
            end
            for _ = 1, #dropped do
                if not State.Unloaded and prompt.Parent and prompt.Enabled then
                    character:PivotTo(stand)
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    local sellOk = pcall(press)
                    if sellOk then sold += 1 end
                    task.wait(0.35)
                else
                    failed += 1
                end
            end
        end)
        if startPivot and character and character.Parent and root and root.Parent == character then
            character:PivotTo(startPivot)
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if camera and camera.Parent then
            camera.CameraSubject = camSubject
            camera.CameraType    = camType
            camera.CFrame        = camCF
        end
        busy = false
        if not ok then notify("ขายล้มเหลว: " .. tostring(message), "Error")
        elseif sold == 0 then notify("ไม่สามารถขายได้", "Warning")
        else notify(string.format("ขายได้ ~%d ชิ้น", sold), "Success") end
    end)
end

-- Loot Aura toggle
local lootAuraLoop = nil
local function setLootAura(value)
    lootAuraLoop = value and {} or nil
    local token = lootAuraLoop
    if not token then return end
    task.spawn(function()
        while lootAuraLoop == token and not State.Unloaded do
            if not busy and flow and flow.Loot and type(flow.Loot.LootEquip) == "function" then
                local character = LP.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root and lootFolder then
                    for _, item in lootFolder:GetChildren() do
                        if isLoot(item) then
                            local part = item.PrimaryPart
                            if part and (part.Position - root.Position).Magnitude <= 8 then
                                pcall(flow.Loot.LootEquip, part)
                            end
                        end
                    end
                end
            end
            task.wait(0.2)
        end
    end)
end

-- ============================================================================
-- SYSTEM 6 — CASH (ported from gg.txt GetCashDrops/Collect)
-- ============================================================================
local cashAuraToken = nil
local function setCashAura(value)
    cashAuraToken = value and {} or nil
    local token = cashAuraToken
    if not token then return end
    task.spawn(function()
        while cashAuraToken == token and not State.Unloaded do
            if flow and flow.Cash and type(flow.Cash.Collect) == "function" then
                local character = LP.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, cash in CollectionService:GetTagged("Cash") do
                        local holder = cash.Parent
                        local sensor = holder and holder:FindFirstChild("TouchSensor", true)
                        if sensor and sensor:IsA("BasePart") and cash:IsDescendantOf(workspace) then
                            if (sensor.Position - root.Position).Magnitude <= 7 then
                                pcall(flow.Cash.Collect, cash)
                            end
                        end
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

local function collectAllCash()
    if busy then notify("กำลังทำงานอยู่", "Warning"); return end
    if not flow or not flow.Cash or type(flow.Cash.Collect) ~= "function" then
        notify("Cash.Collect ไม่พร้อม", "Error"); return
    end
    busy = true
    task.spawn(function()
        local character = LP.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then
            notify("Character ไม่พร้อม", "Error"); busy = false; return
        end
        local startPivot = character:GetPivot()
        local camera = workspace.CurrentCamera
        local camCF = camera and camera.CFrame
        if camera then camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = camCF end
        local collected = 0
        for _, cash in CollectionService:GetTagged("Cash") do
            local holder = cash.Parent
            local sensor = holder and holder:FindFirstChild("TouchSensor", true)
            if sensor and sensor:IsA("BasePart") and cash:IsDescendantOf(workspace) and holder:IsA("Model") then
                local offset = root.Position - sensor.Position
                local dir = Vector3.new(offset.X, 0, offset.Z)
                dir = dir.Magnitude > 0.05 and dir.Unit or Vector3.xAxis
                local pos = sensor.Position + dir * 6 + Vector3.yAxis * 2.5
                character:PivotTo(CFrame.lookAt(pos, Vector3.new(sensor.Position.X, pos.Y, sensor.Position.Z)))
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.6)
                if cash:IsDescendantOf(workspace) then
                    pcall(flow.Cash.Collect, cash)
                    collected += 1
                end
                task.wait(0.1)
            end
        end
        character:PivotTo(startPivot)
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if camera and camera.Parent then camera.CameraType = Enum.CameraType.Custom; camera.CFrame = camCF end
        busy = false
        notify(string.format("เก็บเงิน %d รายการ", collected), collected > 0 and "Success" or "Warning")
    end)
end

local function doBreakSources(radius)
    if not flow or not flow.DamageToOpen or type(flow.DamageToOpen.Damage) ~= "function" then
        notify("DamageToOpen ไม่พร้อม", "Error"); return
    end
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local count = 0
    for _, source in CollectionService:GetTagged("DamageToOpen") do
        local health = source:FindFirstChild("Health")
        local maxHealth = source:FindFirstChild("MaxHealth")
        local part = source:IsA("Model") and (source.PrimaryPart or source:FindFirstChildWhichIsA("BasePart", true))
        if health and health:IsA("NumberValue") and health.Value > 0 and part then
            local inRange = not radius or not root or (part.Position - root.Position).Magnitude <= radius
            if inRange then
                pcall(flow.DamageToOpen.Damage, source, math.max(health.Value, maxHealth and maxHealth.Value or 0, 1) * 10, "melee")
                count += 1
            end
        end
    end
    notify(string.format("ทำลายแหล่งเงิน %d รายการ", count), count > 0 and "Success" or "Warning")
end

-- ============================================================================
-- SYSTEM 7 — VEHICLE MODS (ported from gg.txt)
-- ============================================================================
local vehicleAttributeNames = {
    "TopSpeedMPH", "Acceleration", "Torque",
    "BrakingPower", "TurningAngle", "TurningAngleSpeedFactor", "Downforce",
}
local vehicleCorners = { "fl", "fr", "rl", "rr" }
local vehicleStates  = setmetatable({}, { __mode = "k" })
local vehicleMods    = {
    TopSpeedMult  = 2,   AccelMult    = 3,
    TorqueMult    = 3,   BrakeMult    = 2,
    SteeringMult  = 1.5, DownforceMult = 1.5,
    TireGrip      = 0.6,
    PerfEnabled       = false,
    GripEnabled       = false,
    InfFuelEnabled    = false,
    Indestructible    = false,
}

local originalVehicleDamage = flow and flow.DamageVehicle and flow.DamageVehicle.Damage

local function getVehicleChassis(vehicle)
    local system = vehicle and vehicle:FindFirstChild("system")
    return system and system:FindFirstChild("chassis")
end

local function getCurrentVehicle()
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if not seat or not seat:IsA("VehicleSeat") or seat.Occupant ~= humanoid then return end
    local vehicle = seat:FindFirstAncestorOfClass("Model")
    if not vehicle or not vehicle:FindFirstChild("VehicleProperty") or not vehicle:FindFirstChild("system") then return end
    return vehicle
end

local function getMainVehicle()
    for _, vehicle in CollectionService:GetTagged("MainVehicle") do
        if vehicle:IsA("Model") and vehicle:IsDescendantOf(workspace) then return vehicle end
    end
end

local function getVehicleState(vehicle)
    local state = vehicleStates[vehicle]
    if state and state.Property.Parent then return state end
    local property = vehicle:FindFirstChild("VehicleProperty")
    if not property then return end
    state = { Property = property, Attributes = {}, Wheels = {}, PerformanceApplied = false, GripApplied = false, FuelApplied = false }
    for _, name in vehicleAttributeNames do state.Attributes[name] = property:GetAttribute(name) end
    local system = vehicle:FindFirstChild("system")
    for _, cornerName in vehicleCorners do
        local corner = system and system:FindFirstChild(cornerName)
        local wheel  = corner and corner:FindFirstChild("wheel_" .. cornerName)
        if wheel and wheel:IsA("BasePart") then
            state.Wheels[#state.Wheels + 1] = { Part = wheel, Properties = wheel.CustomPhysicalProperties }
        end
    end
    vehicleStates[vehicle] = state
    return state
end

local function applyVehiclePerformance(vehicle)
    local state = getVehicleState(vehicle)
    if not state then return end
    local prop = state.Property
    local attrs = state.Attributes
    local function setMul(name, mul)
        local v = attrs[name]; if type(v) == "number" then prop:SetAttribute(name, v * mul) end
    end
    setMul("TopSpeedMPH", vehicleMods.TopSpeedMult)
    setMul("Acceleration", vehicleMods.AccelMult)
    setMul("Torque", vehicleMods.TorqueMult)
    setMul("BrakingPower", vehicleMods.BrakeMult)
    setMul("TurningAngle", vehicleMods.SteeringMult)
    setMul("Downforce", vehicleMods.DownforceMult)
    if type(attrs.TurningAngleSpeedFactor) == "number" then
        prop:SetAttribute("TurningAngleSpeedFactor", math.clamp(attrs.TurningAngleSpeedFactor * vehicleMods.SteeringMult, 0, 1))
    end
    state.PerformanceApplied = true
end

local function restoreVehiclePerformance(vehicle)
    local state = vehicleStates[vehicle]
    if not state or not state.PerformanceApplied or not state.Property.Parent then return end
    for name, value in state.Attributes do state.Property:SetAttribute(name, value) end
    state.PerformanceApplied = false
end

local function applyVehicleGrip(vehicle)
    local state = getVehicleState(vehicle)
    if not state then return end
    local grip = vehicleMods.TireGrip
    for _, entry in state.Wheels do
        local wheel = entry.Part
        if wheel.Parent then
            local props = entry.Properties or wheel.CurrentPhysicalProperties
            wheel.CustomPhysicalProperties = PhysicalProperties.new(
                props.Density, grip, props.Elasticity, props.FrictionWeight, props.ElasticityWeight)
        end
    end
    state.GripApplied = true
end

local function restoreVehicleGrip(vehicle)
    local state = vehicleStates[vehicle]
    if not state or not state.GripApplied then return end
    for _, entry in state.Wheels do
        if entry.Part.Parent then entry.Part.CustomPhysicalProperties = entry.Properties end
    end
    state.GripApplied = false
end

local function applyVehicleFuel(vehicle)
    local state = getVehicleState(vehicle)
    local gas = vehicle and vehicle:FindFirstChild("gasLevel")
    local capacity = state and state.Property:GetAttribute("GasCapacity")
    if not state or not gas or not gas:IsA("NumberValue") or type(capacity) ~= "number" then return end
    if not state.FuelApplied then state.FuelValue = gas.Value end
    gas.Value = capacity
    state.FuelApplied = true
end

local function restoreVehicleFuel(vehicle)
    local state = vehicleStates[vehicle]
    if not state or not state.FuelApplied then return end
    local gas = vehicle and vehicle:FindFirstChild("gasLevel")
    if gas and gas:IsA("NumberValue") and state.FuelValue ~= nil then gas.Value = state.FuelValue end
    state.FuelApplied = false; state.FuelValue = nil
end

local function blockVehicleDamage(value)
    if not flow or not flow.DamageVehicle or type(originalVehicleDamage) ~= "function" then return end
    if value then
        flow.DamageVehicle.Damage = function(vehicle, ...)
            local protected = getCurrentVehicle() or getMainVehicle()
            if protected and vehicle == protected then return end
            return originalVehicleDamage(vehicle, ...)
        end
    elseif originalVehicleDamage then
        flow.DamageVehicle.Damage = originalVehicleDamage
    end
end

local activeVehicle
task.spawn(function()
    while true do
        task.wait(0.2)
        if State.Unloaded then break end
        local vehicle = getCurrentVehicle()
        if activeVehicle and activeVehicle ~= vehicle then
            restoreVehiclePerformance(activeVehicle)
            restoreVehicleGrip(activeVehicle)
            restoreVehicleFuel(activeVehicle)
        end
        activeVehicle = vehicle
        if vehicle then
            if vehicleMods.PerfEnabled    then applyVehiclePerformance(vehicle) else restoreVehiclePerformance(vehicle) end
            if vehicleMods.GripEnabled    then applyVehicleGrip(vehicle)        else restoreVehicleGrip(vehicle)        end
            if vehicleMods.InfFuelEnabled then applyVehicleFuel(vehicle)        else restoreVehicleFuel(vehicle)        end
        end
        blockVehicleDamage(vehicleMods.Indestructible)
    end
end)

-- ============================================================================
-- SYSTEM 8 — WEAPON MODS (ported from gg.txt)
-- ============================================================================
local weapMods = {
    InfiniteAmmo = false, NoCooldown = false,
    Automatic = false,    NoRecoil   = false,
    NoSpread  = false,    NoPushback = false,
}
local weaponConfigStates = setmetatable({}, { __mode = "k" })
local activeWeaponTool, activeWeaponConfig, activeWeaponRuntime

local originalCameraRecoil   = flow and flow.Camera and flow.Camera.Recoil
local originalViewmodelRecoil = flow and flow.Viewmodel and flow.Viewmodel.Recoil
local originalWeaponRaycast   = flow and flow.BulletsClient and flow.BulletsClient.raycast

local function getWeaponConfig(tool)
    if not tool or not tool:IsA("Tool") or not data then return end
    local name = tool:GetAttribute("BaseTool") or tool.Name
    local ok, config = pcall(data.Tools.GetToolConfig, name)
    if not ok or type(config) ~= "table" then return end
    if type(config.magCapacity) ~= "number" or type(config.maxRpm) ~= "number" then return end
    return config
end

local function getWeaponConfigState(config)
    local state = weaponConfigStates[config]
    if state then return state end
    state = {
        MaxRpm = config.maxRpm, HasMaxRpm = config.maxRpm ~= nil,
        Mode   = config.mode,   HasMode   = config.mode ~= nil,
        PushForce = config.pushForce, HasPushForce = config.pushForce ~= nil,
    }
    weaponConfigStates[config] = state
    return state
end

local function applyWeaponConfig(config, state)
    if state.HasMaxRpm then config.maxRpm = weapMods.NoCooldown and math.huge or state.MaxRpm end
    if state.HasMode   then config.mode   = weapMods.Automatic and "auto" or state.Mode end
    if weapMods.NoPushback then config.pushForce = nil
    elseif state.HasPushForce then config.pushForce = state.PushForce
    else config.pushForce = nil end
end

local function restoreWeaponConfigs()
    for config, state in weaponConfigStates do
        if state.HasMaxRpm then config.maxRpm = state.MaxRpm end
        if state.HasMode   then config.mode   = state.Mode   end
        if state.HasPushForce then config.pushForce = state.PushForce else config.pushForce = nil end
    end
end

local function installWeaponHooks()
    if flow and flow.Camera and type(originalCameraRecoil) == "function" then
        flow.Camera.Recoil = function(...) if not weapMods.NoRecoil then return originalCameraRecoil(...) end end
    end
    if flow and flow.Viewmodel and type(originalViewmodelRecoil) == "function" then
        flow.Viewmodel.Recoil = function(...) if not weapMods.NoRecoil then return originalViewmodelRecoil(...) end end
    end
end

local function restoreWeaponHooks()
    if flow and flow.Camera and type(originalCameraRecoil) == "function" then
        flow.Camera.Recoil = originalCameraRecoil
    end
    if flow and flow.Viewmodel and type(originalViewmodelRecoil) == "function" then
        flow.Viewmodel.Recoil = originalViewmodelRecoil
    end
    if flow and flow.BulletsClient and type(originalWeaponRaycast) == "function" then
        flow.BulletsClient.raycast = originalWeaponRaycast
    end
end

installWeaponHooks()

RunService.PreSimulation:Connect(function()
    local character = LP.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local config = getWeaponConfig(tool)
    if not config then tool = nil end
    if tool ~= activeWeaponTool then
        activeWeaponTool   = tool
        activeWeaponConfig = config
    end
    if config then
        local state = getWeaponConfigState(config)
        applyWeaponConfig(config, state)
        if weapMods.InfiniteAmmo and tool then
            local cap = math.max(tonumber(config.magCapacity) or 1, 1)
            if tool:GetAttribute("Ammo") ~= cap then
                pcall(function() tool:SetAttribute("Ammo", cap) end)
            end
        end
    end
end)

-- ============================================================================
-- SYSTEM 9 — ESP (ported from gg.txt, Drawing-based)
-- ============================================================================
local drawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"
local espEnabled = false
local espConfig = {
    Players  = { Toggle = false, Color = Color3.fromRGB(75, 210, 255),   Box = true,  Tracer = false, HealthBar = true,  MaxDist = 2500 },
    NPCs     = { Toggle = false, Color = Color3.fromRGB(255, 90, 90),    Box = true,  Tracer = false, HealthBar = true,  MaxDist = 2000 },
    Vehicles = { Toggle = false, Color = Color3.fromRGB(180, 110, 255),  Box = true,  Tracer = false, MaxDist = 5000 },
    Safes    = { Toggle = false, Color = Color3.fromRGB(255, 170, 60),   Box = true,  Tracer = false, MaxDist = 5000 },
}
local espVisuals = { Players = {}, NPCs = {}, Vehicles = {}, Safes = {} }

local function newEspObj(kind)
    if not drawingAvailable then return end
    local ok, obj = pcall(Drawing.new, kind)
    if not ok or not obj then return end
    obj.Visible = false
    return obj
end

local function removeEspObj(obj)
    if not obj then return end
    pcall(function() obj:Remove() end)
end

local function clearESP()
    for _, registry in espVisuals do
        for _, visual in registry do
            for _, obj in visual do removeEspObj(obj) end
        end
        table.clear(registry)
    end
end

local function hideVisual(visual)
    for _, obj in visual do if obj then obj.Visible = false end end
end

local function newVisual(hasHealth)
    return {
        Text       = newEspObj("Text"),
        Box        = newEspObj("Square"),
        Tracer     = newEspObj("Line"),
        HealthBack = hasHealth and newEspObj("Line") or nil,
        Health     = hasHealth and newEspObj("Line") or nil,
    }
end

local function projectBounds(camera, boxCF, boxSize)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
        local pt = camera:WorldToViewportPoint(boxCF:PointToWorldSpace(Vector3.new(boxSize.X * x, boxSize.Y * y, boxSize.Z * z) * 0.5))
        if pt.Z <= 0 then return end
        minX = math.min(minX, pt.X); minY = math.min(minY, pt.Y)
        maxX = math.max(maxX, pt.X); maxY = math.max(maxY, pt.Y)
    end end end
    local vp = camera.ViewportSize
    if maxX < 0 or maxY < 0 or minX > vp.X or minY > vp.Y then return end
    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

RunService:BindToRenderStep("LP10_ESP", Enum.RenderPriority.Camera.Value + 10, function()
    if not espEnabled or not drawingAvailable then
        for _, registry in espVisuals do for _, visual in registry do hideVisual(visual) end end
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local origin = root and root.Position or camera.CFrame.Position

    local function updateVisual(kind, target, part, humanoid, visual)
        local cfg = espConfig[kind]
        local pt, onScreen = camera:WorldToViewportPoint(part.Position)
        if pt.Z <= 0 or not onScreen then hideVisual(visual); return end
        local dist = (part.Position - origin).Magnitude
        if dist > cfg.MaxDist then hideVisual(visual); return end
        local color = cfg.Color
        local pos, size = Vector2.new(pt.X, pt.Y), Vector2.zero
        if cfg.Box then
            local model = target:IsA("Model") and target or nil
            local boxCF, boxSize = model and pcall(function() return model:GetBoundingBox() end) and model:GetBoundingBox() or part.CFrame, part.Size
            local p, s = projectBounds(camera, boxCF, boxSize)
            if not p then hideVisual(visual); return end
            pos = p; size = s
            if visual.Box then
                visual.Box.Position = pos; visual.Box.Size = size; visual.Box.Color = color
                visual.Box.Transparency = 1; visual.Box.Filled = false; visual.Box.Thickness = 1; visual.Box.Visible = true
            end
        elseif visual.Box then visual.Box.Visible = false end
        if visual.Text then
            local label = tostring(target.Name) .. " [" .. math.round(dist) .. "]"
            if humanoid then label = label .. " | " .. math.round(humanoid.Health) .. "HP" end
            visual.Text.Text = label
            visual.Text.Position = Vector2.new(pos.X + size.X * 0.5, math.max(0, pos.Y - 14))
            visual.Text.Size = 13; visual.Text.Color = color; visual.Text.Transparency = 1
            visual.Text.Center = true; visual.Text.Outline = true; visual.Text.Visible = true
        end
        if cfg.Tracer and visual.Tracer then
            visual.Tracer.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
            visual.Tracer.To = Vector2.new(pos.X + size.X * 0.5, pos.Y + size.Y)
            visual.Tracer.Color = color; visual.Tracer.Transparency = 1; visual.Tracer.Thickness = 1; visual.Tracer.Visible = cfg.Tracer
        elseif visual.Tracer then visual.Tracer.Visible = false end
        if visual.Health and humanoid and cfg.HealthBar then
            local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            local x = pos.X - 4; local bottom = pos.Y + size.Y
            visual.HealthBack.From = Vector2.new(x, bottom); visual.HealthBack.To = Vector2.new(x, pos.Y)
            visual.HealthBack.Color = Color3.new(0,0,0); visual.HealthBack.Transparency = 1
            visual.HealthBack.Thickness = 3; visual.HealthBack.Visible = true
            visual.Health.From = Vector2.new(x, bottom)
            visual.Health.To = Vector2.new(x, bottom - size.Y * ratio)
            visual.Health.Color = Color3.fromHSV(ratio * 0.33, 1, 1); visual.Health.Transparency = 1
            visual.Health.Thickness = 1; visual.Health.Visible = true
        elseif visual.Health then visual.Health.Visible = false; if visual.HealthBack then visual.HealthBack.Visible = false end end
    end

    -- Players
    if espConfig.Players.Toggle then
        for _, plr in Players:GetPlayers() do
            if plr ~= LP then
                local char = plr.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local r    = char and char:FindFirstChild("HumanoidRootPart")
                if r and hum and hum.Health > 0 then
                    local visual = espVisuals.Players[plr] or newVisual(true)
                    espVisuals.Players[plr] = visual
                    updateVisual("Players", char, r, hum, visual)
                else if espVisuals.Players[plr] then hideVisual(espVisuals.Players[plr]) end end
            end
        end
    else for _, v in espVisuals.Players do hideVisual(v) end end

    -- NPCs
    if espConfig.NPCs.Toggle then
        local folder = workspace:FindFirstChild("NPCs")
        if folder then
            local seen = {}
            for _, hum in folder:GetDescendants() do
                if hum:IsA("Humanoid") then
                    local npc  = hum:FindFirstAncestorWhichIsA("Model")
                    local r    = npc and npc:FindFirstChild("HumanoidRootPart")
                    if npc and r and not seen[npc] then
                        seen[npc] = true
                        local visual = espVisuals.NPCs[npc] or newVisual(true)
                        espVisuals.NPCs[npc] = visual
                        updateVisual("NPCs", npc, r, hum, visual)
                    end
                end
            end
        end
    else for _, v in espVisuals.NPCs do hideVisual(v) end end

    -- Vehicles
    if espConfig.Vehicles.Toggle then
        local folder = workspace:FindFirstChild("Vehicles")
        if folder then
            for _, vehicle in folder:GetChildren() do
                if vehicle:IsA("Model") then
                    local chassis = getVehicleChassis(vehicle)
                    local part = chassis or vehicle:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local visual = espVisuals.Vehicles[vehicle] or newVisual(false)
                        espVisuals.Vehicles[vehicle] = visual
                        updateVisual("Vehicles", vehicle, part, nil, visual)
                    end
                end
            end
        end
    else for _, v in espVisuals.Vehicles do hideVisual(v) end end

    -- Safes
    if espConfig.Safes.Toggle then
        for _, safe in CollectionService:GetTagged("Safe") do
            if safe:IsDescendantOf(workspace) then
                local part = safe:IsA("Model") and (safe.PrimaryPart or safe:FindFirstChildWhichIsA("BasePart", true))
                    or safe:IsA("BasePart") and safe
                if part then
                    local visual = espVisuals.Safes[safe] or newVisual(false)
                    espVisuals.Safes[safe] = visual
                    updateVisual("Safes", safe, part, nil, visual)
                end
            end
        end
    else for _, v in espVisuals.Safes do hideVisual(v) end end
end)

-- ============================================================================
-- SYSTEM 10 — SAFE ZONE + GATE SYSTEMS (ported from original LP10)
-- ============================================================================
local function releaseSafeZone()
    local character = State.SafeCharacter
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and State.SafeRootAnchored ~= nil then
        root.Anchored = State.SafeRootAnchored
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    State.SafeCFrame = nil; State.SafeCharacter = nil; State.SafeRootAnchored = nil
end

local function getSafeCFrame()
    local passage = State.GatePassage
    if not passage or typeof(passage.Position) ~= "Vector3" then return end
    local finalDoor = passage.FinalDoor
    local customsBuilding = finalDoor and finalDoor:FindFirstAncestor("CustomsBuilding")
    local prompt = teleports:GetEndPrompt()
    local holder = prompt and prompt.Parent
    local promptPos = (holder and holder:IsA("Attachment") and holder.WorldPosition)
        or (holder and holder:IsA("BasePart") and holder.Position)
        or passage.Position
    local bestFloor, bestDist = nil, math.huge
    if customsBuilding then
        for _, office in customsBuilding:GetChildren() do
            if office.Name == "CustomsOffice" then
                local floor = office:FindFirstChild("Floor", true)
                if floor and floor:IsA("BasePart") then
                    local d = (floor.Position - promptPos).Magnitude
                    if d < bestDist then bestFloor, bestDist = floor, d end
                end
            end
        end
    end
    if bestFloor then
        local pos = bestFloor.CFrame:PointToWorldSpace(Vector3.new(5, bestFloor.Size.Y * 0.5 + 3.25, 8))
        return CFrame.lookAt(pos, Vector3.new(promptPos.X, pos.Y, promptPos.Z), Vector3.yAxis)
    end
end

local function moveToSafeZone()
    if not State.SafeZoneEnabled then releaseSafeZone(); return true end
    local destination = getSafeCFrame()
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    local root      = character and character:FindFirstChild("HumanoidRootPart")
    if not destination or not humanoid or not root or humanoid.Health <= 0 then
        return false, "Safe position unavailable"
    end
    releaseSafeZone()
    State.SafeCharacter    = character
    State.SafeRootAnchored = root.Anchored
    State.SafeCFrame       = destination
    local moved = teleports:Move(destination, nil, false)
    if not moved then releaseSafeZone(); return false, "Move failed" end
    root.CFrame = destination
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true
    if flow and flow.PoliceHeli and type(flow.PoliceHeli.Despawn) == "function" then
        pcall(flow.PoliceHeli.Despawn)
    end
    return true
end

-- Teleport to gate
local function teleportToGate()
    local endZ = teleports:GetEndZ()
    if not endZ then notify("End Z unavailable", "Error"); return end
    local start     = teleports:GetStartCFrame()
    local direction = (not start or endZ >= start.Position.Z) and 1 or -1
    local anchor    = teleports:GetEndAnchor(endZ, direction)
    teleports:Stream(anchor)
    local prompt = teleports:GetEndPrompt()
    if prompt then
        local dest = teleports:GetEndPromptDestination(prompt, direction)
        if dest then
            teleports:Move(dest, nil, false)
            notify("Teleported to gate prompt", "Success"); return
        end
    end
    local road = teleports:GetRoadNear(endZ)
    local pos
    if road then
        pos = Vector3.new(road.Position.X, road.Position.Y + road.Size.Y * 0.5 + 5, endZ - direction * 30)
    else
        pos = Vector3.new(anchor.X, anchor.Y + 4, endZ - direction * 30)
    end
    teleports:Move(CFrame.lookAt(pos, pos + Vector3.new(0, 0, direction), Vector3.yAxis), nil, false)
    notify("Teleported near gate", "Warning")
end

-- Activate gate
local function activateGate()
    local endZ = teleports:GetEndZ()
    if not endZ then notify("End Z unavailable", "Error"); return end
    local start     = teleports:GetStartCFrame()
    local direction = (not start or endZ >= start.Position.Z) and 1 or -1
    local prompt    = teleports:GetEndPrompt()
    if not prompt then notify("Gate prompt not found", "Error"); return end
    local destination = teleports:GetEndPromptDestination(prompt, direction)
    if destination then teleports:Move(destination, nil, false); task.wait(0.4) end
    local fired = false
    if type(fireproximityprompt) == "function" then fired = pcall(fireproximityprompt, prompt) end
    if not fired then
        fired = pcall(function()
            local dur = prompt.HoldDuration
            prompt.HoldDuration = 0
            prompt:InputHoldBegin(); task.wait(0.1); prompt:InputHoldEnd()
            prompt.HoldDuration = dur
        end)
    end
    if fired then
        State.GateStartedAt = os.time()
        notify("Gate activated", "Success")
    else
        notify("Gate activation failed", "Error")
    end
end

-- ============================================================================
-- SYSTEM 11 — INSTANT PROMPT
-- ============================================================================
local instantPromptStates = setmetatable({}, { __mode = "k" })
local instantPromptActive = false

local function setInstantPrompt(value)
    instantPromptActive = value
    if value then
        for _, prompt in workspace:GetDescendants() do
            if prompt:IsA("ProximityPrompt") then
                if instantPromptStates[prompt] == nil then instantPromptStates[prompt] = prompt.HoldDuration end
                prompt.HoldDuration = 0
            end
        end
    else
        for prompt, duration in instantPromptStates do
            if prompt and prompt.Parent then prompt.HoldDuration = duration end
        end
        table.clear(instantPromptStates)
    end
end

workspace.DescendantAdded:Connect(function(inst)
    if instantPromptActive and inst:IsA("ProximityPrompt") then
        if instantPromptStates[inst] == nil then instantPromptStates[inst] = inst.HoldDuration end
        inst.HoldDuration = 0
    end
end)

-- ============================================================================
-- AUTO FARM BACKEND (ported from original LP10, unchanged from working version)
-- ============================================================================
local AF = {}
AF.LobbyPlaceId = State.LobbyPlaceId
AF.GamePlaceId  = State.GamePlaceId
AF.StatePath    = "MyScriptHub/RUNAWAYS/lp10_ouroboros.json"
AF.StateKey     = "LP10_RUNAWAYS_AF_STATE"
AF.EnabledKey   = "LP10_RUNAWAYS_AF_ENABLED"
AF.SessionKey   = "LP10_RUNAWAYS_AF_SESSION"
AF.TransitionKey = "LP10_RUNAWAYS_AF_TRANSITION"

function AF:GetQueueFunction()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if type(queueonteleport)   == "function" then return queueonteleport   end
    if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
end

function AF:GetTeleportLoader()
    return [==[
local src = nil
pcall(function() src = game:GetService("TeleportService"):GetTeleportSetting("LP10_AUTOMATION_SOURCE") end)
if type(src) ~= "string" or #src == 0 then
    if type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile("MyScriptHub/LP10_Ouroboros.lua") then
                src = readfile("MyScriptHub/LP10_Ouroboros.lua")
            end
        end)
    end
end
if type(src) == "string" and #src > 0 then
    local fn = loadstring(src)
    if type(fn) == "function" then fn() end
end
    ]==]
end

function AF:GetQueueError(targetPlaceId)
    if not tonumber(targetPlaceId)    then return "Target place unavailable" end
    if not self:GetQueueFunction()    then return "queue_on_teleport unavailable" end
    if self:GetTeleportLoader() == "" then return "Teleport loader not configured" end
end

function AF:GetContext()
    if game.PlaceId == AF.LobbyPlaceId then return "Lobby" end
    if game.PlaceId == AF.GamePlaceId  then return "Game"  end
    if flow and flow.LobbyServer and type(flow.LobbyServer.create) == "function" then return "Lobby" end
    if workspace:FindFirstChild("Map") and flow and flow.NPCs then return "Game" end
    return "Unsupported"
end

function AF:GetDataValue(name)
    if flow and flow.LocalData and type(flow.LocalData.Get) == "function" then
        local ok, value = pcall(flow.LocalData.Get, name)
        if ok and type(value) == "number" then return value end
    end
    if flow and flow.PlayerDataClient and type(flow.PlayerDataClient.getObserver) == "function" then
        local ok, observer = pcall(flow.PlayerDataClient.getObserver, name)
        if ok and observer and type(observer.get) == "function" then
            local read, value = pcall(observer.get, observer)
            if read and type(value) == "number" then return value end
        end
    end
end

function AF:GetCash() return self:GetDataValue("coins") end
function AF:GetWins() return self:GetDataValue("wins")  end

function AF:GetEffectiveCredz() return (tonumber(State.LastCredzBalance) or 0) + math.max(0, tonumber(State.PendingCredz) or 0) end
function AF:GetEffectiveWins()  return (tonumber(State.LastWins) or 0) + math.max(0, tonumber(State.PendingWins) or 0) end

function AF:SyncProgress(reset)
    local credz = self:GetCash()
    local wins  = self:GetWins()
    if type(credz) == "number" then
        if reset or type(State.LastCredzBalance) ~= "number" then
            State.LastCredzBalance = credz; State.PendingCredz = 0
        elseif credz > State.LastCredzBalance then
            local gained = credz - State.LastCredzBalance
            local accounted = math.min(gained, math.max(0, State.PendingCredz or 0))
            State.PendingCredz = math.max(0, State.PendingCredz - accounted)
            State.LastCredzBalance = credz
        end
    end
    if type(wins) == "number" then
        if reset or type(State.LastWins) ~= "number" then
            State.LastWins = wins; State.PendingWins = 0
        elseif wins > State.LastWins then
            local gained = wins - State.LastWins
            local accounted = math.min(gained, math.max(0, State.PendingWins or 0))
            State.PendingWins = math.max(0, State.PendingWins - accounted)
            State.LastWins = wins
        end
    end
    return credz, wins
end

function AF:SetPhase(phase, detail)
    State.Phase = phase; State.Detail = detail or ""
end

function AF:Persist()
    local snapshot = {
        Version = 1, UserId = LP.UserId,
        Enabled = State.AutoFarmRunning, SessionId = State.SessionId,
        TransitionToken = State.TransitionToken, ExpectedPlaceId = State.ExpectedPlaceId,
        TransitionAt = State.TransitionAt, Phase = State.Phase, UpdatedAt = os.time(),
        Config = {
            LobbyDelay = State.LobbyDelay, GateTimeout = State.GateTimeout,
            RetryDelay = State.RetryDelay, SafeGateWait = State.SafeZoneEnabled,
            AutoReplay = State.AutoReplay,
        },
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, snapshot)
    if not ok then return false end
    State.LastPersistAt = os.clock()
    pcall(TeleportService.SetTeleportSetting, TeleportService, AF.StateKey,      encoded)
    pcall(TeleportService.SetTeleportSetting, TeleportService, AF.EnabledKey,    State.AutoFarmRunning)
    pcall(TeleportService.SetTeleportSetting, TeleportService, AF.SessionKey,    State.SessionId)
    pcall(TeleportService.SetTeleportSetting, TeleportService, AF.TransitionKey, State.TransitionToken)
    if type(writefile) == "function" then
        if type(makefolder) == "function" then
            pcall(function() if type(isfolder) ~= "function" or not isfolder("MyScriptHub") then makefolder("MyScriptHub") end end)
            pcall(function() if type(isfolder) ~= "function" or not isfolder("MyScriptHub/RUNAWAYS") then makefolder("MyScriptHub/RUNAWAYS") end end)
        end
        pcall(writefile, AF.StatePath, encoded)
    end
    return true
end

function AF:QueueTeleport(reason, expectedPlaceId)
    expectedPlaceId = tonumber(expectedPlaceId)
    local queueError = self:GetQueueError(expectedPlaceId)
    if queueError then State.QueueStatus = queueError; return false, queueError end
    local queueFn = self:GetQueueFunction()
    local loader  = self:GetTeleportLoader()
    if State.QueueJob == game.JobId and State.TransitionToken ~= "" then
        State.ExpectedPlaceId = expectedPlaceId; State.TransitionAt = os.time()
        self:Persist(); State.QueueStatus = "Armed: " .. tostring(reason); return true
    end
    local transitionToken = table.concat({
        tostring(State.SessionId), game.JobId, tostring(expectedPlaceId),
        tostring(os.time()), tostring(math.random(100000, 999999)),
    }, ":")
    State.TransitionToken = transitionToken; State.ExpectedPlaceId = expectedPlaceId; State.TransitionAt = os.time()
    self:Persist()
    local snapshot = TeleportService:GetTeleportSetting(AF.StateKey) or ""
    local payload = string.format(
        "if not game:IsLoaded() then game.Loaded:Wait() end\n"
            .. "if game.PlaceId == %d or game.PlaceId == %d then\n"
            .. "local p = game:GetService(%q)\n"
            .. "while not p.LocalPlayer do task.wait() end\n"
            .. "local t = game:GetService(%q)\n"
            .. "local v = nil\n"
            .. "pcall(function() v = t:GetTeleportSetting(%q) end)\n"
            .. "if t:GetTeleportSetting(%q) ~= false and tostring(v or '') == %q then\n"
            .. "local e = getgenv and getgenv() or _G\n"
            .. "e.LP10RunawaysTransitionToken = %q\n"
            .. "e.LP10RunawaysQueuedState = %q\n"
            .. "%s\n"
            .. "end\n"
            .. "end",
        AF.LobbyPlaceId, AF.GamePlaceId,
        "Players", "TeleportService",
        AF.TransitionKey, AF.EnabledKey,
        transitionToken, transitionToken, snapshot, loader
    )
    local ok, message = pcall(queueFn, payload)
    if not ok then
        State.TransitionToken = ""; State.ExpectedPlaceId = 0; State.TransitionAt = 0
        State.QueueStatus = "Queue failed"; self:Persist(); return false, tostring(message)
    end
    State.QueueJob = game.JobId; State.QueueStatus = "Armed: " .. tostring(reason)
    return true
end

function AF:WaitForTeleport(token, duration, failGen)
    local expires = os.clock() + duration
    failGen = tonumber(failGen) or State.TeleportFailureGeneration
    if State.TeleportFailureGeneration ~= failGen then return false, "Teleport failed" end
    repeat
        if State.TeleportFailureGeneration ~= failGen then return false, "Teleport failed" end
        if State.Teleporting then return true, "Teleport started" end
        task.wait(0.25)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded
        or State.TeleportFailureGeneration ~= failGen or os.clock() >= expires
    if State.Teleporting and State.TeleportFailureGeneration == failGen then return true, "Teleport started" end
    return false, "Teleport timed out"
end

function AF:DismissTeleportError()
    pcall(function() game:GetService("GuiService"):ClearError() end)
    local promptGui  = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
    local overlay    = promptGui and promptGui:FindFirstChild("promptOverlay")
    local errorPrompt = overlay and (overlay:FindFirstChild("ErrorPrompt") or overlay:FindFirstChild("errorPrompt"))
    if not errorPrompt then return end
    local ok, buttons = pcall(errorPrompt.QueryDescendants, errorPrompt, "TextButton")
    if not ok then return end
    for _, button in buttons do
        local text = tostring(button.Text or ""):lower()
        if text == "ok" or text:find("reconnect", 1, true) then
            if type(firesignal) == "function" then pcall(firesignal, button.MouseButton1Click)
            else pcall(button.Activate, button) end
            break
        end
    end
end

function AF:StartTeleportRecovery(token)
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded then return end
    State.TeleportRecovering = true; State.TeleportRecoveryGeneration += 1
    local generation = State.TeleportRecoveryGeneration
    local attempt = math.max(1, State.TeleportRetryCount or 1)
    local delays = { 2, 5, 10, 20, 30 }
    local delay = State.TeleportRetryDelay > 0 and State.TeleportRetryDelay or delays[math.min(attempt, #delays)]
    State.TeleportRetryDelay = 0
    self:SetPhase("Teleport Recovery", "Rejoining in " .. delay .. "s | Attempt " .. attempt)
    self:Persist()
    task.spawn(function()
        local expires = os.clock() + delay
        repeat task.wait(0.25)
        until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded
            or State.TeleportRecoveryGeneration ~= generation or os.clock() >= expires
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded
            or State.TeleportRecoveryGeneration ~= generation then return end
        self:DismissTeleportError()
        local target = tonumber(State.TeleportRetryTarget)
        local retryOptions = State.TeleportRetryOptions
        local valid = target == AF.LobbyPlaceId or target == AF.GamePlaceId
        if not valid then target = State.AutoReplay and AF.GamePlaceId or AF.LobbyPlaceId end
        local exactRetry = attempt <= 3 and valid and typeof(retryOptions) == "Instance" and retryOptions:IsA("TeleportOptions")
        if not exactRetry then retryOptions = nil end
        State.QueueJob = nil; State.Teleporting = false
        local queued, queueErr = self:QueueTeleport("teleport recovery", target)
        if not queued then
            State.Retries += 1; State.TeleportRetryCount += 1; State.LastError = tostring(queueErr)
            self:StartTeleportRecovery(token); return
        end
        self:SetPhase(exactRetry and "Retrying Teleport" or target == AF.GamePlaceId and "Rejoining Game" or "Rejoining Lobby",
            "Recovery attempt " .. attempt)
        self:Persist()
        local sourceJob = game.JobId; local failGen = State.TeleportFailureGeneration
        local called, teleportErr = pcall(function()
            if exactRetry then TeleportService:TeleportAsync(target, { LP }, retryOptions)
            else TeleportService:Teleport(target, LP) end
        end)
        if not called then
            State.Teleporting = false; State.Retries += 1; State.TeleportRetryCount += 1
            State.LastError = tostring(teleportErr); self:StartTeleportRecovery(token); return
        end
        local timeout = os.clock() + 30
        repeat task.wait(0.25)
        until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded
            or State.TeleportRecoveryGeneration ~= generation or State.TeleportFailureGeneration ~= failGen
            or game.JobId ~= sourceJob or os.clock() >= timeout
        if State.AutoFarmRunning and State.AutoFarmToken == token and not State.Unloaded
            and State.TeleportRecoveryGeneration == generation and State.TeleportFailureGeneration == failGen
            and game.JobId == sourceJob then
            State.Teleporting = false; State.Retries += 1; State.TeleportRetryCount += 1
            State.LastError = "Teleport timed out"; self:StartTeleportRecovery(token)
        end
    end)
end

function AF:HandleTeleportFailure(result, message, targetPlaceId, teleportOptions)
    if not State.AutoFarmRunning or State.Unloaded then return end
    task.defer(self.DismissTeleportError, self)
    if os.clock() - State.LastTeleportFailureAt < 0.75 then return end
    State.LastTeleportFailureAt = os.clock()
    local target = tonumber(targetPlaceId)
    if target ~= AF.LobbyPlaceId and target ~= AF.GamePlaceId then target = tonumber(State.ExpectedPlaceId) end
    if target ~= AF.LobbyPlaceId and target ~= AF.GamePlaceId then
        target = self:GetContext() == "Game" and State.AutoReplay and AF.GamePlaceId or AF.LobbyPlaceId
    end
    State.TeleportFailureGeneration += 1; State.Teleporting = false; State.QueueJob = nil
    State.ReplayRequested = false; State.TeleportRetryCount += 1; State.TeleportRetryTarget = target
    State.TeleportRetryOptions = typeof(teleportOptions) == "Instance" and teleportOptions or nil
    State.TeleportRetryDelay = result == Enum.TeleportResult.Flooded and 15 or 0
    State.Retries += 1; State.LastError = tostring(message or result or "Teleport failed")
    releaseSafeZone(); setNoclip(false)
    self:SetPhase("Teleport Failed", State.LastError); self:Persist()
    self:StartTeleportRecovery(State.AutoFarmToken)
end

-- [remaining AF methods: GetEndScreen, HandleEndScreen, RunLobby, RunGame, etc.]
-- these are complex and unchanged from working LP10 — include full implementations

function AF:IsVisible(instance)
    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    local current = instance
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return current == playerGui
end

function AF:GetEndScreen()
    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    local endFrame = playerGui:FindFirstChild("EndFrame", true)
    local function visible(inst)
        local cur = inst
        while cur and cur ~= playerGui do
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("LayerCollector") and not cur.Enabled then return false end
            cur = cur.Parent
        end
        return cur == playerGui
    end
    local function layer(inst)
        local cur = inst
        while cur and cur ~= playerGui do
            if cur:IsA("LayerCollector") then return cur end
            cur = cur.Parent
        end
    end
    if endFrame and visible(endFrame) then
        for _, inst in endFrame:GetDescendants() do
            if inst:IsA("GuiObject") and visible(inst) then
                local name = inst.Name:lower()
                local text = (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text:lower() or ""
                if name:find("captured",1,true) or text:find("captured",1,true) then return endFrame, "Captured" end
                if name:find("escaped", 1,true) or text:find("escaped", 1,true) then return endFrame, "Escaped"  end
            end
        end
        return
    end
    if os.clock() - State.LastEndScreenScanAt < 1 then return end
    State.LastEndScreenScanAt = os.clock()
    for _, inst in playerGui:GetDescendants() do
        if inst:IsA("GuiObject") and visible(inst) then
            local name = inst.Name:lower()
            local text = (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text:lower() or ""
            if name:find("captured",1,true) or text:find("captured",1,true) then return layer(inst) or endFrame, "Captured" end
            if name:find("escaped", 1,true) or text:find("escaped", 1,true) then return layer(inst) or endFrame, "Escaped"  end
        end
    end
end

function AF:GetReplayButton(endFrame)
    if not endFrame then return end
    local function matches(button)
        if not button:IsA("GuiButton") or not self:IsVisible(button) then return false end
        local name = button.Name:lower()
        local text = button:IsA("TextButton") and tostring(button.Text or ""):lower() or ""
        if text == "" then
            local lbl = button:FindFirstChildWhichIsA("TextLabel", true)
            text = lbl and tostring(lbl.Text or ""):lower() or ""
        end
        return name:find("replay",1,true) ~= nil or text:find("replay",1,true) ~= nil
    end
    local direct = endFrame:FindFirstChild("Replay", true)
    if direct and matches(direct) then return direct end
    if direct then
        local nested = direct:FindFirstChildWhichIsA("GuiButton", true)
        if nested and matches(nested) then return nested end
    end
    for _, btn in endFrame:GetDescendants() do
        if matches(btn) then return btn end
    end
end

function AF:RequestReplay(button)
    if flow and flow.GameManager and type(flow.GameManager.Replay) == "function" then
        local called, result = pcall(flow.GameManager.Replay)
        if called and result ~= false then return true end
    end
    if button then
        if type(firesignal) == "function" then
            local clicked = pcall(firesignal, button.MouseButton1Click)
            if clicked then return true end
        else
            if pcall(button.Activate, button) then return true end
        end
    end
    return false, "Replay unavailable"
end

function AF:GetResultCredz(endFrame)
    local total = endFrame and endFrame:FindFirstChild("Total", true)
    if not total then return end
    for _, name in { "RobloxPlus", "Credz" } do
        local label = total:FindFirstChild(name, true)
        if label and (label:IsA("TextLabel") or label:IsA("TextButton")) and self:IsVisible(label) then
            local digits = tostring(label.Text or ""):gsub("[^%d]", "")
            local value  = tonumber(digits)
            if value then return value end
        end
    end
end

function AF:FinalizeRun(outcome, detail, reward)
    if State.ResultFinalized then return end
    local duration = State.RunStartAt > 0 and math.max(0, os.time() - State.RunStartAt) or 0
    local active = State.RunStartAt > 0
    self:SyncProgress()
    local effectiveCredz = self:GetEffectiveCredz()
    local effectiveWins  = self:GetEffectiveWins()
    local earned = math.max(0, effectiveCredz - (tonumber(State.RunCashStart) or effectiveCredz))
    local reported = tonumber(reward)
    if active and reported and reported > earned then
        local missing = reported - earned
        State.PendingCredz += missing; effectiveCredz += missing; earned = reported
    end
    releaseSafeZone(); State.ResultFinalized = true
    if active then State.Attempts = math.max(State.Attempts, State.Completed + State.Failed + 1) end
    if active and outcome == "Escaped" then
        State.Completed += 1
        if effectiveWins <= (tonumber(State.RunWinsStart) or effectiveWins) then
            State.PendingWins += 1; effectiveWins += 1
        end
    elseif active then State.Failed += 1 end
    State.PendingFinish = false; State.FinishCrossed = false; State.PendingAt = 0
    State.RunStartAt = 0; State.RunCashStart = effectiveCredz; State.RunWinsStart = effectiveWins
    State.GateStartedAt = 0; State.GatePassage = nil; State.GateText = "--"
    if outcome == "Escaped" then
        State.LastError = "None"
        self:SetPhase("Run Completed", (detail or "Finish confirmed") .. " | +" .. math.floor(earned) .. " Credz")
    else
        State.LastError = "Run captured"
        self:SetPhase("Run Captured", detail or "Preparing next run")
    end
    self:Persist()
end

function AF:HandleEndScreen(token)
    if State.ResultBusy then return false, "Result busy" end
    local endFrame, outcome = self:GetEndScreen()
    if not endFrame then return false, "No end screen" end
    State.ResultBusy = true; releaseSafeZone()
    if outcome == "Ended" then
        local exp = os.clock() + 2
        repeat task.wait(0.1); endFrame, outcome = self:GetEndScreen()
        until outcome ~= "Ended" or not endFrame or not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= exp
    end
    outcome = (outcome == "Escaped" or (outcome == "Ended" and State.FinishCrossed)) and "Escaped" or "Captured"
    local reward; local rewardExp = os.clock() + 3
    repeat
        reward = self:GetResultCredz(endFrame)
        if reward then break end
        task.wait(0.1)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= rewardExp
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded then
        State.ResultBusy = false; return true, "Stopped"
    end
    self:FinalizeRun(outcome, outcome == "Escaped" and "Finish confirmed" or "Captured before finish", reward)
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then
        State.ResultBusy = false; return true, "Stopped"
    end
    if State.AutoReplay then
        local replayStart = os.clock(); local replayExpires = replayStart + 45
        local nextReq = replayStart; local queued = false; local requests = 0
        State.ReplayRequested = true; self:SetPhase("Auto Replay", "Waiting for replay button")
        repeat
            State.RunHeartbeat = os.clock()
            if State.Teleporting then return true, "Teleporting" end
            local curFrame = self:GetEndScreen()
            if not curFrame then
                local curChar = LP.Character; local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
                if curHum and curHum.Health > 0 and os.clock() - replayStart >= 2 then
                    State.LastGameJob = ""; State.ReplayRequested = false; State.ResultBusy = false
                    State.QueueStatus = "Replay started"; self:Persist(); task.wait(1); return true, "Replay"
                end
            else
                endFrame = curFrame
                if os.clock() >= nextReq then
                    local replayBtn = self:GetReplayButton(endFrame)
                    if replayBtn or os.clock() - replayStart >= 8 then
                        if not queued then
                            local q, qErr = self:QueueTeleport("replay", AF.GamePlaceId)
                            if not q then State.LastError = tostring(qErr); nextReq = os.clock() + 3
                            else queued = true end
                        end
                        if queued and requests < 10 then
                            if requests == 0 then State.Replays += 1; self:SetPhase("Auto Replay", "Submitting vote"); self:Persist() end
                            if self:RequestReplay(replayBtn) then requests += 1; self:SetPhase("Auto Replay", "Vote submitted") end
                            nextReq = os.clock() + 2
                        elseif queued then nextReq = os.clock() + 3 end
                    else nextReq = os.clock() + 0.5 end
                end
            end
            task.wait(0.25)
        until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= replayExpires
        State.ReplayRequested = false
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded then
            State.ResultBusy = false; return true, "Stopped"
        end
        local q, qErr = self:QueueTeleport("replay recovery", AF.GamePlaceId)
        if not q then State.ResultBusy = false; return false, tostring(qErr) end
        self:SetPhase("Restarting Game", "Replay did not start")
        local failGen = State.TeleportFailureGeneration
        if not pcall(TeleportService.Teleport, TeleportService, AF.GamePlaceId, LP) then
            State.ResultBusy = false; return false, "Teleport call failed"
        end
        if self:WaitForTeleport(token, 30, failGen) then return true, "Teleporting" end
        State.ResultBusy = false; return false, "Game restart did not start"
    end
    State.ReplayRequested = false
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then
        State.ResultBusy = false; return true, "Stopped"
    end
    if not flow or not flow.GameManager or type(flow.GameManager.BackToLobby) ~= "function" then
        State.ResultBusy = false; return false, "Lobby return unavailable"
    end
    local q, qErr = self:QueueTeleport("lobby", AF.LobbyPlaceId)
    if not q then State.LastError = tostring(qErr) end
    local failGen = State.TeleportFailureGeneration
    if not pcall(flow.GameManager.BackToLobby) then State.ResultBusy = false; return false, "BackToLobby failed" end
    self:SetPhase("Returning to Lobby", "Replay unavailable")
    if self:WaitForTeleport(token, 30, failGen) then return true, "Teleporting" end
    State.ResultBusy = false; return false, "Lobby teleport did not start"
end

function AF:GetOwnedCar()
    if not flow or not flow.PlayerDataClient or type(flow.PlayerDataClient.getObserver) ~= "function" then return end
    local ok, observer = pcall(flow.PlayerDataClient.getObserver, "cars")
    if not ok or not observer or type(observer.get) ~= "function" then return end
    local read, cars = pcall(observer.get, observer)
    if not read or type(cars) ~= "table" then return end
    local names = {}
    for name in cars do names[#names + 1] = tostring(name) end
    table.sort(names)
    return names[1]
end

function AF:GetGateFinalDoor(prompt)
    local fd = prompt and prompt:FindFirstAncestor("FinalDoor")
    if fd then return fd end
    local map = workspace:FindFirstChild("Map")
    local bld = map and map:FindFirstChild("Buildings")
    local cus = bld and bld:FindFirstChild("CustomsFinal")
    return cus and cus:FindFirstChild("FinalDoor", true)
end

function AF:GetGateTimer(prompt)
    local fd = self:GetGateFinalDoor(prompt)
    if not fd then return end
    local ok, labels = pcall(fd.QueryDescendants, fd, "TextLabel")
    if not ok then labels = {}; for _, i in fd:GetDescendants() do if i:IsA("TextLabel") then labels[#labels+1] = i end end end
    for _, label in labels do
        local text = label.Text
        local m, s = text:match("(%d+)%sm%s(%d+)%ss")
        if not m then m, s = text:match("(%d+)%s:%s*(%d+)") end
        if m and s then return tonumber(m) * 60 + tonumber(s), text end
    end
end

function AF:GetGatePassage(prompt, direction, endZ)
    local fd = self:GetGateFinalDoor(prompt)
    local lh = fd and fd:FindFirstChild("DoorL")
    local rh = fd and fd:FindFirstChild("DoorR")
    local lDoor = lh and lh:FindFirstChild("Door", true)
    local rDoor = rh and rh:FindFirstChild("Door", true)
    local best, bestScore = nil, -math.huge
    if fd then
        local ok, parts = pcall(fd.QueryDescendants, fd, "BasePart")
        if not ok then parts = {}; for _, i in fd:GetDescendants() do if i:IsA("BasePart") then parts[#parts+1] = i end end end
        local cmd = fd:FindFirstChild("Command", true)
        for _, part in parts do
            if part.CanCollide and part.Transparency < 0.95 and part.Size.Y >= 4
                and (not cmd or not part:IsDescendantOf(cmd))
            then
                local name = part.Name:lower()
                local score = part.Size.X * part.Size.Y / math.max(part.Size.Z, 0.5)
                if name:find("door",1,true) or name:find("gate",1,true) then score += 1000000
                elseif name:find("wall",1,true) or name:find("frame",1,true) then score -= 1000000 end
                if score > bestScore then best, bestScore = part, score end
            end
        end
    end
    local road = teleports:GetRoadNear(endZ)
    local position = (lDoor and lDoor:IsA("BasePart") and rDoor and rDoor:IsA("BasePart")
        and (lDoor.Position + rDoor.Position) * 0.5)
        or (best and best.Position)
        or (road and Vector3.new(road.Position.X, road.Position.Y + road.Size.Y * 0.5 + 3.5, endZ))
    if not position then
        local holder = prompt and prompt.Parent
        if holder and holder:IsA("Attachment") then position = holder.WorldPosition
        elseif holder and holder:IsA("BasePart") then position = holder.Position end
    end
    if not position then return end
    local params = RaycastParams.new()
    local excludes = {}
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LP.Character then excludes[#excludes+1] = LP.Character end
    if fd then excludes[#excludes+1] = fd end
    params.FilterDescendantsInstances = excludes
    params.RespectCanCollide = true
    local result = workspace:Raycast(position + Vector3.yAxis * 30, -Vector3.yAxis * 80, params)
    if result then position = Vector3.new(position.X, result.Position.Y + 3.5, position.Z)
    elseif road then position = Vector3.new(position.X, road.Position.Y + road.Size.Y * 0.5 + 3.5, position.Z) end
    return { Position = position, Direction = direction, FinalDoor = fd, DoorL = lDoor, DoorR = rDoor }
end

function AF:IsGatePassageOpen(passage)
    if not passage or typeof(passage.Position) ~= "Vector3" then return false end
    local lDoor, rDoor = passage.DoorL, passage.DoorR
    if lDoor and lDoor.Parent and lDoor:IsA("BasePart") and rDoor and rDoor.Parent and rDoor:IsA("BasePart") then
        local diff = lDoor.Position - rDoor.Position
        if diff.Magnitude > 0.1 then
            local axis = diff.Unit
            local lHalf = math.abs(lDoor.CFrame.RightVector:Dot(axis)) * lDoor.Size.X * 0.5
                + math.abs(lDoor.CFrame.UpVector:Dot(axis)) * lDoor.Size.Y * 0.5
                + math.abs(lDoor.CFrame.LookVector:Dot(axis)) * lDoor.Size.Z * 0.5
            local rHalf = math.abs(rDoor.CFrame.RightVector:Dot(axis)) * rDoor.Size.X * 0.5
                + math.abs(rDoor.CFrame.UpVector:Dot(axis)) * rDoor.Size.Y * 0.5
                + math.abs(rDoor.CFrame.LookVector:Dot(axis)) * rDoor.Size.Z * 0.5
            local mid = (lDoor.Position + rDoor.Position) * 0.5
            passage.Position = Vector3.new(mid.X, passage.Position.Y, mid.Z)
            return diff.Magnitude - lHalf - rHalf >= 12
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = LP.Character and { LP.Character } or {}
    params.RespectCanCollide = true
    local dir = Vector3.new(0, 0, passage.Direction)
    local result = workspace:Raycast(passage.Position - dir * 10, dir * 20, params)
    return result == nil
end

function AF:IsGateWindowOpen()
    if flow and flow.CrimesGui and type(flow.CrimesGui.StartEndTimer_event) == "function"
        and debug and type(debug.getupvalues) == "function"
    then
        local ok, values = pcall(debug.getupvalues, flow.CrimesGui.StartEndTimer_event)
        if ok and type(values) == "table" then
            local opensAt  = tonumber(values[2])
            local closesAt = tonumber(values[3])
            local now      = workspace:GetServerTimeNow()
            if opensAt and closesAt and now >= opensAt and now < closesAt then return true end
        end
    end
    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    local hud = playerGui and playerGui:FindFirstChild("HudGui")
    local events = hud and hud:FindFirstChild("Events")
    local closing = events and events:FindFirstChild("Closing")
    if not closing or not closing.Visible then return false end
    local timer = closing:FindFirstChild("Timer")
    local text = timer and timer.Text or ""
    local m, s = text:match("(%d+)%s*:%s*(%d+)")
    return not m or tonumber(m) * 60 + tonumber(s) > 0
end

function AF:ReachGate(token)
    self:SetPhase("Traveling", "Teleporting to end gate")
    local endZ, expires = nil, os.clock() + 20
    repeat endZ = teleports:GetEndZ(); if not endZ then task.wait(0.25) end
    until endZ or not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= expires
    if not endZ then return nil, nil, nil, "End position unavailable" end
    local start = teleports:GetStartCFrame()
    local direction = (not start or endZ >= start.Position.Z) and 1 or -1
    local anchor = teleports:GetEndAnchor(endZ, direction)
    teleports:Stream(anchor)
    local prompt = teleports:GetEndPrompt()
    if not prompt then
        local road = teleports:GetRoadNear(endZ)
        local pos
        if road then pos = Vector3.new(road.Position.X, road.Position.Y + road.Size.Y * 0.5 + 5, endZ - direction * 30)
        else pos = Vector3.new(anchor.X, anchor.Y + 4, endZ - direction * 30) end
        teleports:Move(CFrame.lookAt(pos, pos + Vector3.new(0, 0, direction), Vector3.yAxis), nil, false)
        teleports:Stream(anchor)
    end
    expires = os.clock() + 20
    repeat
        prompt = teleports:GetEndPrompt()
        if prompt then
            local dest = teleports:GetEndPromptDestination(prompt, direction)
            if dest then
                teleports:Move(dest, nil, false); task.wait(0.4)
                local character = LP.Character
                local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
                local root      = character and character:FindFirstChild("HumanoidRootPart")
                if humanoid and root and humanoid.Health > 0
                    and (root.Position - dest.Position).Magnitude <= math.max(prompt.MaxActivationDistance + 5, 14)
                then
                    State.GatePassage = State.GatePassage or self:GetGatePassage(prompt, direction, endZ)
                    return prompt, direction, endZ
                end
            end
        end
        task.wait(0.25)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= expires
    if State.AutoFarmRunning and State.AutoFarmToken == token and State.GateStartedAt > 0 and State.LastGameJob == game.JobId then
        State.GatePassage = State.GatePassage or self:GetGatePassage(nil, direction, endZ)
        if State.GatePassage then
            local pos = State.GatePassage.Position - Vector3.new(0, 0, direction * 8)
            teleports:Move(CFrame.lookAt(pos, pos + Vector3.new(0, 0, direction), Vector3.yAxis), nil, false)
            return nil, direction, endZ, nil, true
        end
    end
    return nil, nil, nil, "End gate prompt not reached"
end

function AF:ActivateGateAF(prompt, direction, token)
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return false, {}, "AF stopped" end
    if State.GateStartedAt > 0 and State.LastGameJob == game.JobId then
        local seconds = self:GetGateTimer(prompt)
        if not prompt.Enabled or (seconds and seconds < 120) then return true, {} end
        State.GateStartedAt = 0
    end
    self:SetPhase("Activating Gate", "Starting 2-minute countdown")
    for attempt = 1, 3 do
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return false, {}, "AF stopped" end
        local dest = teleports:GetEndPromptDestination(prompt, direction)
        if dest then teleports:Move(dest, nil, false); task.wait(0.4) end
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return false, {}, "AF stopped" end
        local before = self:GetGateTimer(prompt)
        local fired = false
        if type(fireproximityprompt) == "function" then fired = pcall(fireproximityprompt, prompt) end
        if not fired then
            fired = pcall(function()
                local dur = prompt.HoldDuration; prompt.HoldDuration = 0
                prompt:InputHoldBegin(); task.wait(0.1); prompt:InputHoldEnd()
                prompt.HoldDuration = dur
            end)
        end
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return false, {}, "AF stopped" end
        if fired then
            local exp = os.clock() + 6
            repeat
                local seconds = self:GetGateTimer(prompt)
                local accepted = not prompt.Enabled or (seconds and before and seconds < before) or (seconds and seconds < 120)
                if accepted then
                    State.GateStartedAt = os.time() - (seconds and math.max(0, 120 - seconds) or 0)
                    self:Persist(); return true, {}
                end
                task.wait(0.25)
            until os.clock() >= exp or not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded
            if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return false, {}, "AF stopped" end
        end
        State.Retries += 1; task.wait(attempt)
    end
    State.GateStartedAt = 0; return false, {}, "Gate activation not confirmed"
end

function AF:WaitForGate(token, prompt)
    local timeout = State.GateTimeout
    local expires = os.clock() + timeout
    self:SetPhase("Waiting for Gate", "Safe zone + NPC clear active")
    repeat
        State.RunHeartbeat = os.clock()
        local endFrame = self:GetEndScreen()
        if endFrame then releaseSafeZone(); local _, result = self:HandleEndScreen(token); return false, result end
        local safe, safeErr = moveToSafeZone()
        if not safe then
            releaseSafeZone()
            local resultExp = os.clock() + 4
            repeat
                if self:GetEndScreen() then local _, result = self:HandleEndScreen(token); return false, result end
                task.wait(0.1)
            until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= resultExp
            return false, safeErr
        end
        local elapsed = math.max(0, os.time() - State.GateStartedAt)
        local seconds, text = self:GetGateTimer(prompt)
        State.GateText = text or string.format("%02d:%02d", math.floor(math.max(120-elapsed,0)/60), math.max(120-elapsed,0) % 60)
        local passOpen = pcall(self.IsGatePassageOpen, self, State.GatePassage) and self:IsGatePassageOpen(State.GatePassage)
        local winOpen  = self:IsGateWindowOpen()
        local timedOpen = State.GateStartedAt > 0 and elapsed >= 120
        if passOpen or winOpen or timedOpen then releaseSafeZone(); return true end
        if os.clock() - State.LastPersistAt >= 10 then self:Persist() end
        task.wait(0.5)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= expires
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then releaseSafeZone(); return false, "AF stopped" end
    releaseSafeZone(); return false, "Gate wait timed out"
end

function AF:SetCrossNoclip(value)
    if value then
        if State.CrossCollisions then return end
        State.CrossCollisions = {}
        local character = LP.Character
        if character then
            for _, part in character:GetDescendants() do
                if part:IsA("BasePart") then
                    State.CrossCollisions[part] = part.CanCollide; part.CanCollide = false
                end
            end
        end
    else
        for part, canCollide in State.CrossCollisions or {} do
            if part.Parent then part.CanCollide = canCollide end
        end
        State.CrossCollisions = nil
    end
end

function AF:WaitForFinishResult(token, duration)
    local expires = os.clock() + duration
    repeat
        if State.Teleporting then return true, "Teleporting" end
        local endFrame = self:GetEndScreen()
        if endFrame then self:SetCrossNoclip(false); return self:HandleEndScreen(token) end
        task.wait(0.2)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded or os.clock() >= expires
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return true, "Stopped" end
    return false, "Finish result did not appear"
end

function AF:CrossGate(token, prompt, direction, endZ)
    releaseSafeZone(); self:SetPhase("Entering Finish", "Crossing opened gate")
    self:SetCrossNoclip(true)
    local character = LP.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    local root      = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then self:SetCrossNoclip(false); return false, "Character unavailable" end
    local passage = State.GatePassage or self:GetGatePassage(prompt, direction, endZ)
    if not passage then self:SetCrossNoclip(false); return false, "Gate passage unavailable" end
    self:IsGatePassageOpen(passage); teleports:Stream(passage.Position); task.wait(0.4)
    local finishOffset = math.max(12, (tonumber(endZ) and (endZ - passage.Position.Z) * direction or 0) + 12)
    for _, offset in { -10, -3, 6, finishOffset, finishOffset + 24, finishOffset + 50, finishOffset + 85 } do
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token or State.Unloaded then
            self:SetCrossNoclip(false); return false, "AF stopped"
        end
        local pos = passage.Position + Vector3.new(0, 0, direction * offset)
        teleports:Move(CFrame.lookAt(pos, pos + Vector3.new(0, 0, direction), Vector3.yAxis), nil, false)
        local crossedEnd = (tonumber(endZ) and (pos.Z - endZ) * direction >= 0) or offset >= 6
        if crossedEnd and not State.FinishCrossed then State.FinishCrossed = true; self:Persist() end
        task.wait(0.4)
        if State.Teleporting then self:SetCrossNoclip(false); return true, "Teleporting" end
        if self:GetEndScreen() then self:SetCrossNoclip(false); return self:HandleEndScreen(token) end
    end
    local humanoid2 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if humanoid2 then humanoid2:MoveTo(passage.Position + Vector3.new(0, 0, direction * 110)) end
    local handled, result = self:WaitForFinishResult(token, 35)
    if handled then return true, result end
    self:SetCrossNoclip(false); return false, result
end

function AF:RunLobby(token)
    if not flow or not flow.LobbyServer
        or type(flow.LobbyServer.play) ~= "function"
        or type(flow.LobbyServer.create) ~= "function"
        or type(flow.LobbyServer.exit) ~= "function"
    then return false, "Lobby API unavailable" end
    self:SetPhase("Lobby", "Waiting before next game")
    local delay = State.LobbyDelay
    local exp = os.clock() + delay
    repeat task.wait(0.1) until not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= exp
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return true end
    local car = self:GetOwnedCar()
    if not car then return false, "No owned vehicle" end
    local playerGui  = LP:FindFirstChildOfClass("PlayerGui")
    local createGui  = playerGui and (playerGui:FindFirstChild("CreateLobbyGui") or playerGui:WaitForChild("CreateLobbyGui", 10))
    if not createGui then return false, "Create lobby UI unavailable" end
    local queued, qErr = self:QueueTeleport("game", AF.GamePlaceId)
    if not queued then return false, qErr end
    for attempt = 1, 2 do
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return true end
        local createFrame = createGui:FindFirstChild("Frame")
        local exitFrame   = createGui:FindFirstChild("Exit")
        if exitFrame and exitFrame.Visible then
            pcall(flow.LobbyServer.exit)
            local leaveExp = os.clock() + 5
            repeat task.wait(0.1) until not exitFrame.Visible or not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= leaveExp
            if exitFrame.Visible then State.Retries += 1; task.wait(attempt); continue end
        end
        if not createFrame or not createFrame.Visible then
            pcall(flow.LobbyServer.play)
            local selExp = os.clock() + 10
            repeat
                if State.Teleporting then return true end
                task.wait(0.2)
            until not State.AutoFarmRunning or State.AutoFarmToken ~= token
                or (createFrame and createFrame.Visible) or (exitFrame and exitFrame.Visible) or os.clock() >= selExp
        end
        if exitFrame and exitFrame.Visible then State.Retries += 1; pcall(flow.LobbyServer.exit); task.wait(attempt * 1.5); continue end
        if not createFrame or not createFrame.Visible then State.Retries += 1; task.wait(attempt); continue end
        self:SetPhase("Creating Game", "Vehicle: " .. car)
        createFrame.Visible = false
        local failGen = State.TeleportFailureGeneration
        if not pcall(flow.LobbyServer.create, { maxPlayers = 1, permissions = "Friends", car = car }) then
            return false, "Create failed"
        end
        local joinExp = os.clock() + 5
        repeat task.wait(0.2) until State.Teleporting or (exitFrame and exitFrame.Visible)
            or not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= joinExp
        local started = State.Teleporting or (function() local ok, r = self:WaitForTeleport(token, 20, failGen); return ok end)()
        if started then return true end
        if State.TeleportRecovering then return false, "Teleport recovery active" end
        State.Retries += 1
        pcall(flow.LobbyServer.exit)
        if flow.LobbyClient and type(flow.LobbyClient.forceLeave_event) == "function" then
            pcall(flow.LobbyClient.forceLeave_event)
        end
        task.wait(attempt * 2)
    end
    self:SetPhase("Refreshing Lobby", "Game creation timed out")
    if not self:QueueTeleport("lobby retry", AF.LobbyPlaceId) then return false, "Lobby retry failed" end
    local failGen = State.TeleportFailureGeneration
    pcall(TeleportService.Teleport, TeleportService, AF.LobbyPlaceId, LP)
    if self:WaitForTeleport(token, 30, failGen) then return true, "Teleporting" end
    return false, "Lobby refresh did not start"
end

function AF:RunGame(token)
    if State.PendingFinish and State.LastGameJob ~= "" and State.LastGameJob ~= game.JobId then
        if State.FinishCrossed and State.PendingAt > 0 and os.time() - State.PendingAt <= 600 then
            self:FinalizeRun("Escaped", "Replay transition confirmed")
        else
            State.PendingFinish = false; State.FinishCrossed = false; State.PendingAt = 0
        end
    end
    if self:GetEndScreen() then return self:HandleEndScreen(token) end
    if State.LastGameJob ~= game.JobId then
        releaseSafeZone(); State.BalanceWarmupUntil = os.clock() + 10
        self:SyncProgress(); State.LastGameJob = game.JobId
        State.RunStartAt = os.time(); State.RunCashStart = self:GetEffectiveCredz()
        State.RunWinsStart = self:GetEffectiveWins(); State.GateStartedAt = 0
        State.GatePassage = nil; State.PendingFinish = false; State.FinishCrossed = false
        State.PendingAt = 0; State.ResultBusy = false; State.ResultFinalized = false
        State.ReplayRequested = false; State.Attempts += 1; self:Persist()
    end
    self:SetPhase("Loading Game", "Waiting for character and map")
    local exp = os.clock() + 30
    repeat
        local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 and workspace:FindFirstChild("Map") then break end
        task.wait(0.25)
    until not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= exp
    if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return true end
    do
        local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not r or h.Health <= 0 or not workspace:FindFirstChild("Map") then
            return false, "Gameplay did not finish loading"
        end
    end
    local prompt, direction, endZ, reachErr, gateAlreadyActivated = self:ReachGate(token)
    if not prompt and not gateAlreadyActivated then return false, reachErr end
    local activated, _, activationErr = self:ActivateGateAF(prompt, direction, token)
    if not activated then return false, activationErr end
    local opened, gateErr = self:WaitForGate(token, prompt)
    if not opened then
        if gateErr == "Replay" or gateErr == "Teleporting" or gateErr == "Stopped" then return true, gateErr end
        return false, gateErr
    end
    State.PendingFinish = true; State.FinishCrossed = true; State.PendingAt = os.time(); self:Persist()
    local nextPlaceId = State.AutoReplay and AF.GamePlaceId or AF.LobbyPlaceId
    local queued, queueErr = self:QueueTeleport(State.AutoReplay and "replay" or "lobby", nextPlaceId)
    if not queued then
        State.PendingFinish = false; State.FinishCrossed = false; State.PendingAt = 0; return false, queueErr
    end
    for attempt = 1, 3 do
        local crossed, crossErr = self:CrossGate(token, prompt, direction, endZ)
        if crossed then return true, crossErr end
        if not State.AutoFarmRunning or State.AutoFarmToken ~= token then return true end
        State.Retries += 1; State.LastError = crossErr; task.wait(attempt * 2)
    end
    State.PendingFinish = false; State.FinishCrossed = false; State.PendingAt = 0; releaseSafeZone()
    return false, "Could not enter finish"
end

function AF:ReleaseRun(token)
    if State.ActiveRunToken ~= token then return end
    State.RunActive = false; State.ActiveRunToken = nil
    if State.AutoFarmRunning and State.AutoFarmToken and State.AutoFarmToken ~= token and not State.Unloaded then
        task.spawn(self.Run, self, State.AutoFarmToken)
    end
end

function AF:Run(token)
    if State.RunActive then return end
    State.RunActive = true; State.ActiveRunToken = token; State.RunHeartbeat = os.clock()
    local failures = 0
    while State.AutoFarmRunning and State.AutoFarmToken == token and not State.Unloaded do
        State.RunHeartbeat = os.clock()
        if State.TeleportRecovering then task.wait(0.25); continue end
        local executed, ok, message = xpcall(function()
            local context = self:GetContext()
            if context == "Lobby" then return self:RunLobby(token) end
            if context == "Game"  then return self:RunGame(token)  end
            return false, "Unsupported place: " .. tostring(game.PlaceId)
        end, function(msg)
            if type(debug) == "table" and type(debug.traceback) == "function" then
                local read, trace = pcall(debug.traceback, tostring(msg), 2)
                if read and type(trace) == "string" then return trace end
            end
            return tostring(msg)
        end)
        if not executed then
            message = ok; ok = false; releaseSafeZone(); self:SetCrossNoclip(false)
            State.ResultBusy = false; State.ReplayRequested = false
        end
        if State.TeleportRecovering then failures = 0; task.wait(0.25); continue end
        if ok and message == "Replay" and not State.Teleporting and State.AutoFarmRunning and State.AutoFarmToken == token then
            failures = 0; task.wait(1); continue
        end
        if ok or State.Teleporting or not State.AutoFarmRunning or State.AutoFarmToken ~= token then
            self:ReleaseRun(token); return
        end
        failures += 1; State.Retries += 1; State.LastError = tostring(message or "Unknown error")
        self:SetPhase("Retrying", State.LastError); self:Persist()
        local retryDelay = State.RetryDelay
        local retryExp = os.clock() + math.min(retryDelay * failures, 30)
        repeat State.RunHeartbeat = os.clock(); task.wait(0.25)
        until not State.AutoFarmRunning or State.AutoFarmToken ~= token or os.clock() >= retryExp
    end
    self:ReleaseRun(token)
end

function AF:Start()
    if State.AutoFarmRunning then return end
    if not flow then notify("FlowClient unavailable", "Error"); return end
    State.SessionId = tostring(LP.UserId) .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    State.AutoFarmRunning = true; State.RunActive = false; State.ActiveRunToken = nil
    State.Teleporting = false; State.TeleportRecoveryGeneration += 1; State.TeleportRetryCount = 0
    State.TeleportRetryDelay = 0; State.TeleportRetryTarget = 0; State.TeleportRetryOptions = nil
    State.TeleportRecovering = false; State.LastTeleportFailureAt = 0; State.QueueJob = nil
    State.ResultBusy = false; State.ResultFinalized = false; State.ReplayRequested = false
    State.RunHeartbeat = os.clock(); State.TransitionToken = ""; State.ExpectedPlaceId = 0; State.TransitionAt = 0
    State.AutoFarmToken = {}; State.QueueStatus = "Not armed"; State.StartedAt = os.time()
    State.Attempts = 0; State.Completed = 0; State.Failed = 0
    State.Retries = 0; State.Replays = 0; State.Teleports = 0
    self:Persist(); self:SetPhase("Starting", "Preparing Auto Farm")
    local qErr = self:GetQueueError(self:GetContext() == "Lobby" and AF.GamePlaceId or AF.LobbyPlaceId)
    if qErr then
        State.AutoFarmRunning = false; State.AutoFarmToken = nil; State.LastError = tostring(qErr)
        self:SetPhase("Start Failed", State.LastError); self:Persist(); notify("Auto Farm: " .. qErr, "Error"); return
    end
    task.spawn(function()
        local token = State.AutoFarmToken
        while State.AutoFarmRunning and State.AutoFarmToken == token and not State.Unloaded do
            if self:GetContext() == "Game" and not State.ResultBusy and not State.RunActive then
                local endFrame = self:GetEndScreen()
                if endFrame then
                    releaseSafeZone(); self:SetCrossNoclip(false)
                    State.RunActive = false; State.ActiveRunToken = nil; State.RunHeartbeat = os.clock()
                    self:SetPhase("Recovering", "Handling result screen")
                    task.spawn(self.Run, self, token)
                end
            end
            task.wait(0.5)
        end
    end)
    task.spawn(self.Run, self, State.AutoFarmToken)
    notify("Auto Farm started", "Success")
end

function AF:Stop()
    if not State.AutoFarmRunning then return end
    State.AutoFarmRunning = false; State.AutoFarmToken = nil; State.RunActive = false
    State.ActiveRunToken = nil; State.Teleporting = false; State.TeleportRecoveryGeneration += 1
    State.TeleportRetryCount = 0; State.TeleportRetryDelay = 0; State.TeleportRetryTarget = 0
    State.TeleportRetryOptions = nil; State.TeleportRecovering = false; State.QueueJob = nil
    State.TransitionToken = ""; State.ExpectedPlaceId = 0; State.TransitionAt = 0
    State.PendingFinish = false; State.FinishCrossed = false; State.PendingAt = 0
    State.ResultBusy = false; State.ResultFinalized = false; State.ReplayRequested = false
    State.LastGameJob = ""; State.RunStartAt = 0; State.GateStartedAt = 0
    State.GatePassage = nil; State.GateText = "--"; State.QueueStatus = "Disabled"
    releaseSafeZone(); setNoclip(false); self:DismissTeleportError()
    pcall(function()
        TeleportService:SetTeleportSetting(AF.EnabledKey, false)
        TeleportService:SetTeleportSetting(AF.TransitionKey, "")
    end)
    self:SetPhase("Stopped", "Auto Farm disabled"); self:Persist()
    notify("Auto Farm stopped", "Info")
end

-- Teleport events
LP.OnTeleport:Connect(function(state_)
    if not State.AutoFarmRunning then return end
    if state_ == Enum.TeleportState.Started or state_ == Enum.TeleportState.InProgress then
        if not State.Teleporting then State.Teleports += 1 end
        State.Teleporting = true; AF:SetPhase("Teleporting", "Moving to next server"); AF:Persist()
    end
end)

TeleportService.TeleportInitFailed:Connect(function(failedPlayer, result, message, targetPlaceId, teleportOptions)
    if failedPlayer ~= LP then return end
    AF:HandleTeleportFailure(result, message, targetPlaceId, teleportOptions)
end)

-- Kill aura in AF game context
task.spawn(function()
    while true do
        task.wait(0.4)
        if State.Unloaded then break end
        if State.AutoFarmRunning and AF:GetContext() == "Game" then
            State.NPCKills += killAllNPCs()
        end
    end
end)

-- ============================================================================
-- LOOT DROPDOWN REFRESH SYSTEM (key fix — runs every second like gg.txt)
-- ============================================================================
local lootDropdownNames = {}
local lootDropdownSig   = ""
local lootDropdownOpt   = nil  -- set after UI creation
local lootAllSelected   = false

local function refreshLootDropdown(force)
    local _, names = getLoot()
    local sig = table.concat(names, "\0")
    if not force and sig == lootDropdownSig then return end
    lootDropdownSig = sig
    lootDropdownNames = names
    if lootDropdownOpt then
        local prevValue = lootDropdownOpt.Value
        -- Ouroboros SetValues
        local ok = pcall(function() lootDropdownOpt:SetValues(names) end)
        if not ok then
            -- fallback: rebuild dropdown state table
            local kept = {}
            for name in prevValue do
                for _, n in names do if n == name then kept[name] = true; break end end
            end
            pcall(function() lootDropdownOpt:SetValue(kept) end)
        end
    end
end

-- ============================================================================
-- OUROBOROS UI — BUILD
-- ============================================================================

-- === AUTO FARM TAB ===
local AFGroup  = AutoFarmTab:AddLeftGroupbox({ Name = "Auto Farm",     Icon = "bot"                    })
local AFConfig = AutoFarmTab:AddRightGroupbox({ Name = "Configuration", Icon = "sliders-horizontal"     })
local AFStatus = AutoFarmTab:AddLeftGroupbox({ Name = "Status",        Icon = "activity"               })

AFGroup:CreateToggle({
    Name = "Auto Farm", Description = "เปิดใช้งาน Auto Farm สำหรับ RUNAWAYS",
    CurrentValue = false, Flag = "AutoFarmEnabled",
    Callback = function(v) if v then AF:Start() else AF:Stop() end end,
})
AFGroup:CreateToggle({
    Name = "Auto Replay", Description = "รีเพลย์เกมอัตโนมัติหลังจบ run",
    CurrentValue = true, Flag = "AutoReplay",
    Callback = function(v) State.AutoReplay = v end,
})
AFGroup:CreateToggle({
    Name = "Safe Gate Wait", Description = "ซ่อน character ใน customs office ระหว่างรอประตูเปิด",
    CurrentValue = true, Flag = "SafeGateWait",
    Callback = function(v) State.SafeZoneEnabled = v; if not v then releaseSafeZone() end end,
})

AFConfig:CreateSlider({ Name = "Lobby Delay (s)", Range = {0,30}, Increment = 1, CurrentValue = 3,   Flag = "LobbyDelay",   Callback = function(v) State.LobbyDelay = v end })
AFConfig:CreateSlider({ Name = "Gate Timeout (s)", Range = {60,240}, Increment = 5, CurrentValue = 165, Flag = "GateTimeout", Callback = function(v) State.GateTimeout = v end })
AFConfig:CreateSlider({ Name = "Retry Delay (s)", Range = {3,30}, Increment = 1, CurrentValue = 10,  Flag = "RetryDelay",   Callback = function(v) State.RetryDelay = v end })

AFStatus:CreateStatusList({
    Name = "Farm Status", MaxRows = 7, UpdateRate = 1,
    Update = function()
        local elapsed    = State.StartedAt > 0 and os.time() - State.StartedAt or 0
        local runElapsed = State.RunStartAt > 0 and os.time() - State.RunStartAt or 0
        local function fmt(v)
            v = math.max(0, math.floor(tonumber(v) or 0))
            return string.format("%02d:%02d:%02d", math.floor(v/3600), math.floor(v%3600/60), v%60)
        end
        return {
            { Text = "Phase",    Value = State.Phase                                  },
            { Text = "Detail",   Value = State.Detail                                 },
            { Text = "Session",  Value = fmt(elapsed)                                 },
            { Text = "Runs",     Value = State.Completed .. "/" .. State.Attempts     },
            { Text = "Current",  Value = fmt(runElapsed)                              },
            { Text = "Gate",     Value = State.GateText                               },
            { Text = "Error",    Value = State.LastError                              },
            { Text = "Queue",    Value = State.QueueStatus                            },
            { Text = "Kills",    Value = tostring(State.NPCKills)                     },
            { Text = "Replays",  Value = tostring(State.Replays)                      },
        }
    end,
})

-- === COMBAT TAB ===
local CombatGroup = CombatTab:AddLeftGroupbox({ Name = "Kill Aura", Icon = "sword" })
local GodGroup    = CombatTab:AddRightGroupbox({ Name = "God Mode + Aggro", Icon = "shield" })
local WeapGroup      = CombatTab:AddLeftGroupbox({ Name = "Weapon Mods", Icon = "crosshair" })
local SilentAimGroup = CombatTab:AddRightGroupbox({ Name = "Silent Aim",  Icon = "target"    })

CombatGroup:CreateToggle({
    Name = "Kill Aura", Description = "ฆ่า NPC ทั้งหมดในระยะทุก 0.4s",
    CurrentValue = false, Flag = "KillAura",
    Callback = function(v) State.KillAuraEnabled = v end,
})
CombatGroup:CreateSlider({ Name = "Kill Radius (0=ไม่จำกัด)", Range = {0,500}, Increment = 10, CurrentValue = 0, Flag = "KillRadius", Callback = function(v) State.KillAuraRadius = v end })
CombatGroup:CreateButton({ Name = "Kill All NPCs ทันที", Icon = "zap", Callback = function()
    local killed = killAllNPCs(State.KillAuraRadius)
    notify("ฆ่า NPC ได้ " .. killed .. " ตัว", "Success")
end })

GodGroup:CreateToggle({
    Name = "God Mode", Description = "ล็อค HP เต็มและป้องกัน death state",
    CurrentValue = false, Flag = "GodMode",
    Callback = function(v) if not v then restoreGodMode() end; State.GodModeEnabled = v end,
})
GodGroup:CreateSlider({ Name = "Aggro Radius", Range = {10,500}, Increment = 10, CurrentValue = 150, Flag = "AggroRadius", Callback = function() end })
GodGroup:CreateButton({ Name = "Aggro Nearby NPCs", Icon = "alert-triangle", Callback = function()
    local radius = Library.Options and Library.Options.AggroRadius and Library.Options.AggroRadius.Value or 150
    if not flow or not flow.NPCs or type(flow.NPCs.Threaten) ~= "function" then
        notify("Threaten ไม่พร้อม", "Error"); return
    end
    local folder = workspace:FindFirstChild("NPCs")
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not folder or not root then notify("ไม่พบ NPCs", "Warning"); return end
    local count = 0
    for _, npc in folder:GetChildren() do
        local humanoid = npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid")
        local npcRoot  = npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart")
        if humanoid and humanoid.Health > 0 and npcRoot and (npcRoot.Position - root.Position).Magnitude <= radius then
            pcall(flow.NPCs.Threaten, npc); count += 1
        end
    end
    notify(string.format("Aggro NPC: %d ตัว", count), count > 0 and "Success" or "Warning")
end })


WeapGroup:CreateToggle({ Name = "Infinite Ammo",  CurrentValue = false, Flag = "WeapInfAmmo",      Callback = function(v) weapMods.InfiniteAmmo = v end })
WeapGroup:CreateToggle({ Name = "No Cooldown",    CurrentValue = false, Flag = "WeapNoCooldown",   Callback = function(v) weapMods.NoCooldown   = v end })
WeapGroup:CreateToggle({ Name = "Automatic Fire", CurrentValue = false, Flag = "WeapAutomatic",    Callback = function(v) weapMods.Automatic    = v end })
WeapGroup:CreateToggle({ Name = "No Recoil",      CurrentValue = false, Flag = "WeapNoRecoil",     Callback = function(v) weapMods.NoRecoil     = v end })
WeapGroup:CreateToggle({ Name = "No Spread",      CurrentValue = false, Flag = "WeapNoSpread",     Callback = function(v) weapMods.NoSpread     = v end })
WeapGroup:CreateToggle({ Name = "No Pushback",    CurrentValue = false, Flag = "WeapNoPushback",   Callback = function(v) weapMods.NoPushback   = v end })
WeapGroup:CreateButton({ Name = "Reset Weapon Mods", Icon = "refresh-cw", Callback = function()
    weapMods.InfiniteAmmo = false; weapMods.NoCooldown = false; weapMods.Automatic = false
    weapMods.NoRecoil = false; weapMods.NoSpread = false; weapMods.NoPushback = false
    restoreWeaponConfigs(); restoreWeaponHooks(); installWeaponHooks()
    notify("รีเซ็ต weapon mods แล้ว", "Success")
end })

-- Silent Aim (ported from gg.txt)
local silentAim = {
    Enabled = false, FOVRadius = 150, HitChance = 100,
    ShowFOV = true, TargetPart = "HumanoidRootPart",
    Circle = nil, LastScan = 0, Targets = {},
}

local function refreshSilentTargets()
    if os.clock() - silentAim.LastScan < 0.35 then return end
    silentAim.LastScan = os.clock(); table.clear(silentAim.Targets)
    for _, npc in CollectionService:GetTagged("NPC") do
        if npc:IsA("Model") and npc:IsDescendantOf(workspace) then
            silentAim.Targets[#silentAim.Targets + 1] = npc
        end
    end
end

if flow and flow.BulletsClient and type(originalWeaponRaycast) == "function" then
    flow.BulletsClient.raycast = function(arguments, shooter)
        if silentAim.Enabled and type(arguments) == "table" and type(arguments.config) == "table" then
            if math.random(0, 100) <= silentAim.HitChance then
                local camera = workspace.CurrentCamera
                if camera then
                    refreshSilentTargets()
                    local center = camera.ViewportSize * 0.5
                    local origin = typeof(arguments.from) == "Vector3" and arguments.from or camera.CFrame.Position
                    local bestPart, bestDist
                    for _, model in silentAim.Targets do
                        local hum  = model:FindFirstChildOfClass("Humanoid")
                        local part = model:FindFirstChild(silentAim.TargetPart) or model:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and part then
                            local pt, onScreen = camera:WorldToViewportPoint(part.Position)
                            if onScreen and pt.Z > 0 then
                                local dist = (Vector2.new(pt.X, pt.Y) - center).Magnitude
                                if dist <= silentAim.FOVRadius and (not bestDist or dist < bestDist) then
                                    bestPart = part; bestDist = dist
                                end
                            end
                        end
                    end
                    if bestPart then
                        local redirected = table.clone(arguments)
                        if typeof(arguments.to) == "Vector3" then
                            redirected.to = bestPart.Position
                        else
                            local dir = bestPart.Position - origin
                            if dir.Magnitude > 0 then
                                local range = type(arguments.length) == "number" and arguments.length or dir.Magnitude
                                redirected.from = origin; redirected.direction = dir.Unit * range; redirected.rayLength = nil
                            end
                        end
                        arguments = redirected
                    end
                end
            end
        end
        return originalWeaponRaycast(arguments, shooter)
    end
end

RunService:BindToRenderStep("LP10_SilentAimFOV", Enum.RenderPriority.Camera.Value + 11, function()
    if silentAim.Enabled and silentAim.ShowFOV and drawingAvailable then
        if not silentAim.Circle then
            local ok, c = pcall(Drawing.new, "Circle")
            if ok and c then silentAim.Circle = c; c.Filled = false; c.NumSides = 64; c.ZIndex = 4 end
        end
        if silentAim.Circle then
            local cam = workspace.CurrentCamera
            silentAim.Circle.Position    = cam and cam.ViewportSize * 0.5 or Vector2.new(400, 300)
            silentAim.Circle.Radius      = silentAim.FOVRadius
            silentAim.Circle.Color       = Color3.new(1,1,1)
            silentAim.Circle.Transparency = 1
            silentAim.Circle.Thickness   = 1
            silentAim.Circle.Visible     = true
        end
    else
        if silentAim.Circle then silentAim.Circle.Visible = false end
    end
end)

SilentAimGroup:CreateToggle({ Name = "Silent Aim", CurrentValue = false, Flag = "SilentAimEnabled", Callback = function(v) silentAim.Enabled = v end })
SilentAimGroup:CreateToggle({ Name = "Show FOV Circle", CurrentValue = true, Flag = "SilentAimShowFOV",
    Callback = function(v) silentAim.ShowFOV = v; if not v and silentAim.Circle then silentAim.Circle.Visible = false end end })
SilentAimGroup:CreateSlider({ Name = "FOV Radius", Range = {25,500}, Increment = 5, CurrentValue = 150, Flag = "SilentAimFOV", Callback = function(v) silentAim.FOVRadius = v end })
SilentAimGroup:CreateSlider({ Name = "Hit Chance (%)", Range = {0,100}, Increment = 5, CurrentValue = 100, Flag = "SilentAimHitChance", Callback = function(v) silentAim.HitChance = v end })
SilentAimGroup:CreateDropdown({ Name = "Target Part", Options = { "HumanoidRootPart", "Head" }, CurrentOption = "HumanoidRootPart",
    AllowNone = false, Flag = "SilentAimPart", Callback = function(v) silentAim.TargetPart = type(v) == "table" and v[1] or v end })

-- === MOVEMENT TAB ===
local NoclipGroup  = MovementTab:AddLeftGroupbox({ Name = "Noclip + Teleport", Icon = "ghost" })
local SpeedGroup   = MovementTab:AddRightGroupbox({ Name = "Speed & Jump", Icon = "zap" })
local WorldGroup   = MovementTab:AddLeftGroupbox({ Name = "World & Camera", Icon = "camera" })

NoclipGroup:CreateToggle({
    Name = "Noclip", Description = "ปิด collision ของ character ทั้งหมด",
    CurrentValue = false, Flag = "Noclip",
    Callback = function(v) setNoclip(v) end,
})
NoclipGroup:CreateButton({ Name = "Teleport to Gate", Icon = "map-pin", Callback = function() task.spawn(teleportToGate) end })
NoclipGroup:CreateButton({ Name = "Teleport to Spawn", Icon = "home", Callback = function()
    local cf = teleports:GetStartCFrame()
    if cf then teleports:Move(cf, nil, false); notify("Teleported to spawn", "Success")
    else notify("Spawn location unavailable", "Error") end
end })
NoclipGroup:CreateButton({ Name = "Return to Last Position", Icon = "history", Callback = function()
    if teleports.LastPosition then teleports:Move(teleports.LastPosition, nil, false); notify("Returned to last position", "Success")
    else notify("No last position saved", "Warning") end
end })

SpeedGroup:CreateToggle({
    Name = "Speed Boost", CurrentValue = false, Flag = "SpeedBoostEnabled",
    Callback = function(v)
        movState.SpeedEnabled = v
        if not v then
            local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and movState.WalkSpeed ~= nil then h.WalkSpeed = movState.WalkSpeed end
            movState.WalkSpeed = nil
        end
    end,
})
SpeedGroup:CreateSlider({ Name = "Walk Speed", Range = {15,150}, Increment = 1, CurrentValue = 30, Flag = "SpeedValue", Callback = function(v) movState.SpeedValue = v end })
SpeedGroup:CreateToggle({
    Name = "Jump Power Override", CurrentValue = false, Flag = "JumpEnabled",
    Callback = function(v)
        movState.JumpEnabled = v
        if not v then
            local c = LP.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and movState.UseJumpPower ~= nil then
                h.JumpPower = movState.JumpPower; h.JumpHeight = movState.JumpHeight; h.UseJumpPower = movState.UseJumpPower
            end
            movState.UseJumpPower = nil; movState.JumpPower = nil; movState.JumpHeight = nil
        end
    end,
})
SpeedGroup:CreateSlider({ Name = "Jump Power", Range = {25,200}, Increment = 5, CurrentValue = 60, Flag = "JumpValue", Callback = function(v) movState.JumpValue = v end })
SpeedGroup:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfiniteJump", Callback = setInfiniteJump })
SpeedGroup:CreateToggle({ Name = "Anti AFK", CurrentValue = true, Flag = "AntiAFK", Callback = setAntiAFK })

WorldGroup:CreateToggle({
    Name = "FOV Override", CurrentValue = false, Flag = "FOVEnabled",
    Callback = function(v)
        movState.FOVEnabled = v
        if not v then
            local cam = workspace.CurrentCamera
            if cam and movState.FOVOriginal ~= nil then cam.FieldOfView = movState.FOVOriginal end
            movState.FOVOriginal = nil
        else
            local cam = workspace.CurrentCamera
            if cam then movState.FOVOriginal = cam.FieldOfView end
        end
    end,
})
WorldGroup:CreateSlider({ Name = "Field of View", Range = {30,120}, Increment = 1, CurrentValue = 70, Flag = "FOVValue", Callback = function(v) movState.FOVValue = v end })
WorldGroup:CreateToggle({
    Name = "Gravity Override", CurrentValue = false, Flag = "GravEnabled",
    Callback = function(v)
        movState.GravEnabled = v
        if not v then
            if movState.Gravity ~= nil then workspace.Gravity = movState.Gravity end
            movState.Gravity = nil
        end
    end,
})
WorldGroup:CreateSlider({ Name = "Gravity", Range = {0,300}, Increment = 5, CurrentValue = 196, Flag = "GravValue", Callback = function(v) movState.GravValue = v end })

-- === LOOT TAB ===
local LootGroup   = LootTab:AddLeftGroupbox({ Name = "Loot Items",    Icon = "package"           })
local SellGroup   = LootTab:AddRightGroupbox({ Name = "Sell & Money", Icon = "badge-dollar-sign" })
local CashGroup   = LootTab:AddRightGroupbox({ Name = "Cash",         Icon = "coins"             })
local BreakGroup  = LootTab:AddRightGroupbox({ Name = "Cash Sources", Icon = "hammer"            })

-- Multi-select dropdown for loot (fixed with refresh loop)
local lootDropdownElement = LootGroup:CreateDropdown({
    Name         = "เลือกไอเทม",
    Options      = lootDropdownNames,
    CurrentOption = {},
    MultipleAllowed = true,
    Flag         = "LootItemsSelected",
    Callback     = function() end,
})
lootDropdownOpt = lootDropdownElement  -- save ref for refresh

LootGroup:CreateToggle({ Name = "Loot Aura", Description = "เก็บไอเทมใกล้ตัวอัตโนมัติ", CurrentValue = false, Flag = "LootAura", Callback = setLootAura })
LootGroup:CreateToggle({ Name = "Instant Prompt", Description = "ยกเลิก HoldDuration ของ ProximityPrompt", CurrentValue = false, Flag = "InstantPrompt", Callback = setInstantPrompt })
LootGroup:CreateButton({ Name = "Loot Selected", Icon = "package-check", Callback = function()
    local selected = {}
    if lootDropdownOpt and type(lootDropdownOpt.Value) == "table" then
        for _, name in lootDropdownOpt.Value do selected[name] = true end
    elseif lootDropdownOpt and type(lootDropdownOpt.Value) == "string" then
        selected[lootDropdownOpt.Value] = true
    end
    if not next(selected) then notify("เลือกไอเทมก่อน", "Warning"); return end
    collect(function(name) return selected[name] == true end)
end })
LootGroup:CreateButton({ Name = "Loot All", Icon = "package-open", Callback = function()
    collect(function() return true end)
end })
LootGroup:CreateButton({ Name = "Drop All Loot", Icon = "trash-2", Callback = dropAllLoot })

SellGroup:CreateButton({ Name = "Sell All Loot", Icon = "store", Callback = sellAllLoot })
SellGroup:CreateLabel("ต้องอยู่ใกล้ร้านรับซื้อ (PawnCounter)")

CashGroup:CreateButton({ Name = "Collect All Cash", Icon = "dollar-sign", Callback = collectAllCash })
CashGroup:CreateToggle({ Name = "Cash Aura", Description = "เก็บเงินสดรอบตัวอัตโนมัติ", CurrentValue = false, Flag = "CashAura", Callback = setCashAura })

BreakGroup:CreateSlider({ Name = "Break Radius", Range = {10,500}, Increment = 10, CurrentValue = 100, Flag = "BreakRadius", Callback = function() end })
BreakGroup:CreateButton({ Name = "Break Cash Sources", Icon = "hammer", Callback = function()
    local radius = Library.Options and Library.Options.BreakRadius and Library.Options.BreakRadius.Value or 100
    doBreakSources(radius)
end })

-- === VEHICLE TAB ===
local VehPerfGroup = VehicleTab:AddLeftGroupbox({ Name = "Performance", Icon = "gauge" })
local VehUtilGroup = VehicleTab:AddRightGroupbox({ Name = "Utility",    Icon = "wrench" })

VehPerfGroup:CreateToggle({ Name = "Performance Mods", CurrentValue = false, Flag = "VehPerfEnabled", Callback = function(v)
    vehicleMods.PerfEnabled = v
    if not v then for vehicle in vehicleStates do restoreVehiclePerformance(vehicle) end end
end })
VehPerfGroup:CreateSlider({ Name = "Top Speed", Range = {1,5}, Increment = 0.5, CurrentValue = 2, Flag = "VehTopSpeed", Callback = function(v) vehicleMods.TopSpeedMult = v end })
VehPerfGroup:CreateSlider({ Name = "Acceleration", Range = {1,10}, Increment = 0.5, CurrentValue = 3, Flag = "VehAccel", Callback = function(v) vehicleMods.AccelMult = v end })
VehPerfGroup:CreateSlider({ Name = "Torque", Range = {1,10}, Increment = 0.5, CurrentValue = 3, Flag = "VehTorque", Callback = function(v) vehicleMods.TorqueMult = v end })
VehPerfGroup:CreateSlider({ Name = "Brake Power", Range = {1,10}, Increment = 0.5, CurrentValue = 2, Flag = "VehBrake", Callback = function(v) vehicleMods.BrakeMult = v end })
VehPerfGroup:CreateSlider({ Name = "Steering", Range = {0.5,3}, Increment = 0.5, CurrentValue = 1.5, Flag = "VehSteering", Callback = function(v) vehicleMods.SteeringMult = v end })
VehPerfGroup:CreateToggle({ Name = "Drift Mode", CurrentValue = false, Flag = "VehGripEnabled", Callback = function(v)
    vehicleMods.GripEnabled = v
    if not v then for vehicle in vehicleStates do restoreVehicleGrip(vehicle) end end
end })
VehPerfGroup:CreateSlider({ Name = "Drift Grip", Range = {0.1,2}, Increment = 0.1, CurrentValue = 0.6, Flag = "VehGrip", Callback = function(v) vehicleMods.TireGrip = v end })

VehUtilGroup:CreateToggle({ Name = "Infinite Fuel", CurrentValue = false, Flag = "VehInfFuel", Callback = function(v)
    vehicleMods.InfFuelEnabled = v
    if not v then for vehicle in vehicleStates do restoreVehicleFuel(vehicle) end end
end })
VehUtilGroup:CreateToggle({ Name = "Indestructible", CurrentValue = false, Flag = "VehIndestructible", Callback = function(v) vehicleMods.Indestructible = v end })
VehUtilGroup:CreateButton({ Name = "Stop Vehicle", Icon = "square", Callback = function()
    local v = getCurrentVehicle()
    if not v then notify("ไม่ได้ขับรถอยู่", "Warning"); return end
    local chassis = getVehicleChassis(v)
    if chassis then
        local token = {}
        task.spawn(function()
            local expires = os.clock() + 1.5
            while v.Parent and chassis.Parent and os.clock() < expires do
                chassis.AssemblyLinearVelocity  = Vector3.zero
                chassis.AssemblyAngularVelocity = Vector3.zero
                RunService.PreSimulation:Wait()
            end
        end)
        notify("หยุดรถแล้ว", "Success")
    end
end })
VehUtilGroup:CreateButton({ Name = "Flip Vehicle", Icon = "rotate-ccw", Callback = function()
    local vehicle = getCurrentVehicle()
    if not vehicle then notify("ไม่ได้ขับรถอยู่", "Warning"); return end
    local chassis = getVehicleChassis(vehicle)
    local system  = vehicle:FindFirstChild("system")
    local seats   = system and system:FindFirstChild("seats")
    local seat    = seats and seats:FindFirstChildWhichIsA("VehicleSeat")
    if not chassis or not seat then notify("ไม่พบชิ้นส่วนรถ", "Error"); return end
    local forward = Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z)
    if forward.Magnitude < 0.1 then forward = Vector3.new(0, 0, -1) else forward = forward.Unit end
    local pos = seat.Position + Vector3.new(0, 3, 0)
    vehicle:PivotTo(CFrame.lookAt(pos, pos + forward, Vector3.yAxis) * seat.CFrame:Inverse() * vehicle:GetPivot())
    chassis.AssemblyLinearVelocity  = Vector3.zero
    chassis.AssemblyAngularVelocity = Vector3.zero
    notify("พลิกรถแล้ว", "Success")
end })
VehUtilGroup:CreateButton({ Name = "Reset All Mods", Icon = "refresh-cw", Callback = function()
    vehicleMods.PerfEnabled = false; vehicleMods.GripEnabled = false
    vehicleMods.InfFuelEnabled = false; vehicleMods.Indestructible = false
    for vehicle in vehicleStates do restoreVehiclePerformance(vehicle); restoreVehicleGrip(vehicle); restoreVehicleFuel(vehicle) end
    blockVehicleDamage(false); notify("รีเซ็ต mods รถแล้ว", "Success")
end })

-- === ESP TAB ===
local ESPCtrlGroup  = ESPTab:AddLeftGroupbox({ Name = "ESP Control", Icon = "eye" })
local ESPPlayGroup  = ESPTab:AddRightGroupbox({ Name = "Players",    Icon = "user" })
local ESPNPCGroup   = ESPTab:AddLeftGroupbox({ Name = "NPCs",        Icon = "users" })
local ESPWorldGroup = ESPTab:AddRightGroupbox({ Name = "World",      Icon = "map-pin" })

ESPCtrlGroup:CreateToggle({ Name = "ESP Enabled", CurrentValue = false, Flag = "ESPEnabled", Callback = function(v)
    espEnabled = v; if not v then clearESP() end
end })

ESPPlayGroup:CreateToggle({ Name = "Player ESP",    CurrentValue = false, Flag = "ESPPlayers",      Callback = function(v) espConfig.Players.Toggle    = v end })
ESPPlayGroup:CreateToggle({ Name = "Player Boxes",  CurrentValue = true,  Flag = "ESPPlayerBox",    Callback = function(v) espConfig.Players.Box        = v end })
ESPPlayGroup:CreateToggle({ Name = "Player Tracers",CurrentValue = false, Flag = "ESPPlayerTracer", Callback = function(v) espConfig.Players.Tracer      = v end })
ESPPlayGroup:CreateToggle({ Name = "Player Health", CurrentValue = true,  Flag = "ESPPlayerHealth", Callback = function(v) espConfig.Players.HealthBar   = v end })
ESPPlayGroup:CreateSlider({ Name = "Player Max Distance", Range = {100,5000}, Increment = 100, CurrentValue = 2500, Flag = "ESPPlayerMaxDist", Callback = function(v) espConfig.Players.MaxDist = v end })

ESPNPCGroup:CreateToggle({ Name = "NPC ESP",    CurrentValue = false, Flag = "ESPNPCs",       Callback = function(v) espConfig.NPCs.Toggle    = v end })
ESPNPCGroup:CreateToggle({ Name = "NPC Boxes",  CurrentValue = true,  Flag = "ESPNPCBox",     Callback = function(v) espConfig.NPCs.Box        = v end })
ESPNPCGroup:CreateToggle({ Name = "NPC Tracers",CurrentValue = false, Flag = "ESPNPCTracer",  Callback = function(v) espConfig.NPCs.Tracer      = v end })
ESPNPCGroup:CreateToggle({ Name = "NPC Health", CurrentValue = true,  Flag = "ESPNPCHealth",  Callback = function(v) espConfig.NPCs.HealthBar   = v end })
ESPNPCGroup:CreateSlider({ Name = "NPC Max Distance", Range = {100,5000}, Increment = 100, CurrentValue = 2000, Flag = "ESPNPCMaxDist", Callback = function(v) espConfig.NPCs.MaxDist = v end })

ESPWorldGroup:CreateToggle({ Name = "Vehicle ESP",    CurrentValue = false, Flag = "ESPVehicles",      Callback = function(v) espConfig.Vehicles.Toggle = v end })
ESPWorldGroup:CreateToggle({ Name = "Vehicle Boxes",  CurrentValue = true,  Flag = "ESPVehicleBox",    Callback = function(v) espConfig.Vehicles.Box    = v end })
ESPWorldGroup:CreateToggle({ Name = "Vehicle Tracers",CurrentValue = false, Flag = "ESPVehicleTracer", Callback = function(v) espConfig.Vehicles.Tracer  = v end })
ESPWorldGroup:CreateSlider({ Name = "Vehicle Max Dist", Range = {100,10000}, Increment = 500, CurrentValue = 5000, Flag = "ESPVehicleMaxDist", Callback = function(v) espConfig.Vehicles.MaxDist = v end })
ESPWorldGroup:CreateToggle({ Name = "Safe ESP",    CurrentValue = false, Flag = "ESPSafes",       Callback = function(v) espConfig.Safes.Toggle = v end })
ESPWorldGroup:CreateToggle({ Name = "Safe Boxes",  CurrentValue = true,  Flag = "ESPSafeBox",     Callback = function(v) espConfig.Safes.Box    = v end })
ESPWorldGroup:CreateToggle({ Name = "Safe Tracers",CurrentValue = false, Flag = "ESPSafeTracer",  Callback = function(v) espConfig.Safes.Tracer  = v end })
ESPWorldGroup:CreateSlider({ Name = "Safe Max Dist", Range = {100,10000}, Increment = 500, CurrentValue = 5000, Flag = "ESPSafeMaxDist", Callback = function(v) espConfig.Safes.MaxDist = v end })

-- === GATE TAB ===
local GateGroup  = GateTab:AddLeftGroupbox({ Name = "Gate",       Icon = "door-open" })
local SafeGroup  = GateTab:AddRightGroupbox({ Name = "Safe Zone", Icon = "anchor"   })
local GateStatus = GateTab:AddLeftGroupbox({ Name = "Gate Status", Icon = "clock"   })

GateGroup:CreateButton({ Name = "Activate Gate", Icon = "play", Callback = function() task.spawn(activateGate) end })
GateGroup:CreateButton({ Name = "Teleport to Gate", Icon = "map-pin", Callback = function() task.spawn(teleportToGate) end })
GateGroup:CreateToggle({ Name = "Cross Gate (Noclip)", CurrentValue = false, Flag = "CrossNoclip", Callback = function(v) setNoclip(v) end })

SafeGroup:CreateToggle({ Name = "Safe Zone Wait", Description = "ซ่อน character ใน customs office", CurrentValue = true, Flag = "SafeZoneWait",
    Callback = function(v) State.SafeZoneEnabled = v; if not v then releaseSafeZone() end end })
SafeGroup:CreateButton({ Name = "Move to Safe Zone", Icon = "anchor", Callback = function()
    local ok, err = moveToSafeZone()
    if ok then notify("Moved to safe zone", "Success") else notify(tostring(err), "Error") end
end })
SafeGroup:CreateButton({ Name = "Release Safe Zone", Icon = "unlock", Callback = function()
    releaseSafeZone(); notify("Safe zone released", "Info")
end })

GateStatus:CreateStatusList({ Name = "Gate Info", MaxRows = 3, UpdateRate = 1, Update = function()
    local elapsed = State.GateStartedAt > 0 and os.time() - State.GateStartedAt or 0
    return {
        { Text = "Timer",   Value = State.GateText                          },
        { Text = "Elapsed", Value = tostring(math.floor(elapsed)) .. "s"    },
        { Text = "Passage", Value = State.GatePassage and "Found" or "None" },
    }
end })

-- === SETTINGS TAB ===
local MenuGroup = SettingsTab:AddLeftGroupbox({ Name = "Menu", Icon = "monitor" })
MenuGroup:CreateKeybind({ Name = "Toggle UI", CurrentKeybind = "RightControl", Flag = "ToggleUIKey",
    Callback = function() end, OnChanged = function(key) Window:SetKeybind(key) end })
MenuGroup:CreateDropdown({ Name = "Toggle Button", Options = { "Mobile only", "Mobile & PC" }, CurrentOption = "Mobile only",
    AllowNone = false, Flag = "ToggleButtonPlatform",
    Callback = function(option)
        local choice = type(option) == "table" and option[1] or option
        Window:SetToggleButtonPlatform(choice == "Mobile & PC" and "Both" or "Mobile")
    end })
MenuGroup:CreateButton({ Name = "Unload Script", Icon = "power", Callback = function()
    Library:Confirm({ Title = "Unload?", ConfirmText = "Unload", Callback = function()
        State.Unloaded = true; AF:Stop(); setNoclip(false); releaseSafeZone()
        State.KillAuraEnabled = false; State.GodModeEnabled = false
        movState.SpeedEnabled = false; movState.JumpEnabled = false
        movState.GravEnabled  = false; movState.FOVEnabled  = false
        restoreMovement(); setInfiniteJump(false); setAntiAFK(false)
        vehicleMods.PerfEnabled = false; vehicleMods.GripEnabled = false
        vehicleMods.InfFuelEnabled = false; vehicleMods.Indestructible = false
        for vehicle in vehicleStates do restoreVehiclePerformance(vehicle); restoreVehicleGrip(vehicle); restoreVehicleFuel(vehicle) end
        blockVehicleDamage(false); restoreWeaponConfigs(); restoreWeaponHooks()
        espEnabled = false; clearESP()
        RunService:UnbindFromRenderStep("LP10_ESP")
        RunService:UnbindFromRenderStep("LP10_SilentAimFOV")
        silentAim.Enabled = false
        if silentAim.Circle then pcall(function() silentAim.Circle:Remove() end); silentAim.Circle = nil end
        lootAuraLoop = nil; cashAuraToken = nil
        setInstantPrompt(false); restoreGodMode()
        Window:Destroy()
    end })
end })

SettingsTab:CreateConfigManager({ Name = "Configs", Side = "Left"  })
SettingsTab:CreateThemeManager({ Name = "Themes",  Side = "Right" })

-- ============================================================================
-- MAIN UPDATE LOOP (1 second tick — refreshes loot dropdown + ESP targets)
-- ============================================================================
task.spawn(function()
    while not State.Unloaded do
        task.wait(1)
        if not State.Unloaded then
            refreshLootDropdown(false)
        end
    end
end)

-- ============================================================================
-- RESTORE SAVED SETTINGS
-- ============================================================================
Window:LoadAutoload()

-- Initial loot dropdown populate
refreshLootDropdown(true)

Library:Notify({
    Title    = SCRIPT_NAME,
    Content  = "Realize | RUNAWAYS",
    Type     = "Success",
    Duration = 4,
})
