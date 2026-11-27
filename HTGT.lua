-- Hunting Together | logic by @x2zu (deobfuscated) | UI ported to Ouroboros UI
-- Single-file: CONFIG on top, game logic in the middle, UI at the bottom.

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--==================================================================--
-- CONFIG
--==================================================================--
local SCRIPT_NAME = "128b!t OFFICIAL"
local SCRIPT_VERSION = "v1.0"
local GAME_NAME = "Hunting Together"
local GAME_KEY = "HuntingTogether"
local UI_THEME = "Mono"
local UI_TOGGLE_KEY = "RightControl"

local UI_URL = "https://raw.githubusercontent.com/4rise-Dev/Library/refs/heads/main/fetched.lua"
--==================================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local unloaded = false
local connections = {}
local workers = {}
local Library

local Flags = {
    AutoFarm = false,
    FarmMobs = {},
    FarmDistance = 8,
    FarmPosition = "Front",
    FarmPriority = "Selection Order",
    Leveling = false,
    LevelQuests = true,
    LevelBosses = true,
    FarmOrder = {},
    AutoSkills = false,
    Skills = {},
    AutoPotions = false,
    Potions = {},
    HpPercent = 50,
    SpPercent = 30,
    AutoRewards = false,
    AutoGear = false,
    AutoCards = false,
    AutoStats = false,
    StatChoice = nil,
    AutoDrops = false,
    AutoBoxes = false,
    AutoRefine = false,
    RefineWeapons = {},
    RefineTarget = 4,
    RefineSafeOnly = true,
    RefineGoldReserve = 0,
    RefineProtect = false,
    RefineLucky = false,
    RefineDelay = 1,
    AutoSell = false,
    SellTrigger = "Bag Full %",
    SellBagPercent = 90,
    SellInterval = 120,
    SellKinds = {},
    SellKeep = {},
    SellKeepAmount = 0,
    SellKeepRefined = true,
    SellJunk = true,
    WalkSpeedEnabled = false,
    WalkSpeed = 32,
    InfJump = false,
    NoClip = false,
    InstantProximityPrompt = false,
    Fly = false,
    FlySpeed = 60,
    AutoReconnect = false,
    Disable3DRendering = false,
    FpsBoost = false,
}

local walkSpeedRestore = {}
local noclipRestore = {}
local promptRestore = {}
local fpsRestore = {}
local flyState = nil
local infJumpConn = nil
local noclipConn = nil
local promptConn = nil
local fpsConn = nil
local reconnectConn = nil
local reconnectFailedConn = nil
local reconnectToken = 0
local renderBacking = nil
local sprintConn = nil
local sprintRestore = nil

local Game = {
    target = nil,
    busy = false,
    lastTargetFire = 0,
    lastTravel = 0,
    levelPlan = nil,
    levelTravel = nil,
    levelStatus = "Idle",
    blockedZones = {},
    questWait = 0,
    travelIndex = 0,
    followConn = nil,
    skillIndex = 0,
    buffUsed = {},
    potionApplied = {},
    gearSetByUs = false,
}

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)

local function loadData(name)
    local mod = Shared and Shared:FindFirstChild(name)
    if not mod then
        return nil
    end
    local ok, result = pcall(require, mod)
    return ok and result or nil
end

local ItemData = loadData("ItemData")
local BuildData = loadData("BuildData")
local GameConfig = loadData("GameConfig")
local GearUtil = loadData("GearUtil")
local GearData = loadData("GearData")
local RefineConfig = type(GearData) == "table" and type(GearData.Refine) == "table" and GearData.Refine or {}

local function fire(name, ...)
    local r = Remotes and Remotes:FindFirstChild(name)
    if r then
        r:FireServer(...)
        return true
    end
    return false
end

local function track(conn)
    if conn then
        table.insert(connections, conn)
    end
    return conn
end

local function getRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
        return humanoid, root
    end
    return nil, nil
end

local function startWorker(key, interval, step)
    if workers[key] then
        return
    end
    workers[key] = true
    task.spawn(function()
        while workers[key] and not unloaded do
            local ok, err = pcall(step)
            if not ok then
                warn("[HuntingTogether] " .. key .. ": " .. tostring(err))
            end
            task.wait(interval)
        end
        workers[key] = nil
    end)
end

local function stopWorker(key)
    workers[key] = false
end

local function setWorker(key, enabled, interval, step)
    if enabled then
        startWorker(key, interval, step)
    else
        stopWorker(key)
    end
end

local function readJson(attr)
    local raw = LocalPlayer:GetAttribute(attr)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return ok and data or nil
end

local function itemDef(id)
    if type(ItemData) ~= "table" then
        return nil
    end
    local src = type(ItemData.Items) == "table" and ItemData.Items or ItemData
    local def = src[id]
    return type(def) == "table" and def or nil
end

local function mobName(model)
    local display = model:GetAttribute("DisplayName")
    return type(display) == "string" and display ~= "" and display or model.Name
end

local function mobAlive(model)
    return model ~= nil
        and model.Parent ~= nil
        and CollectionService:HasTag(model, "Monster")
        and (tonumber(model:GetAttribute("HP")) or 0) > 0
        and model.PrimaryPart ~= nil
end

local MobZones = {}
local MobInfo = {}

local function buildMobZones()
    local mapData, monsterData = loadData("MapData"), loadData("MonsterData")
    if type(mapData) ~= "table" or type(monsterData) ~= "table" then
        return
    end
    local monsters = type(monsterData.Monsters) == "table" and monsterData.Monsters or monsterData
    for zoneId, zone in pairs(mapData) do
        if type(zone) == "table" and type(zone.Spawns) == "table" then
            for _, spawn in pairs(zone.Spawns) do
                local def = type(spawn) == "table" and monsters[spawn.Id]
                local name = type(def) == "table" and def.Name
                if type(name) == "string" then
                    local order = tonumber(zone.Order) or 99
                    local info = MobInfo[name]
                    if not info or order < info.order then
                        MobInfo[name] = { order = order, level = zone.LevelText or "", zone = zone.DisplayName or zoneId }
                    end
                    MobZones[name] = MobZones[name] or {}
                    if not table.find(MobZones[name], zoneId) then
                        table.insert(MobZones[name], zoneId)
                    end
                end
            end
        end
    end
end

buildMobZones()

local function mobLabel(name)
    local info = MobInfo[name]
    if not info then
        return name
    end
    return ("%s | %s %s"):format(name, info.level, info.zone)
end

local function labelToName(label)
    return tostring(label):match("^(.-) | ") or tostring(label)
end

local function mobNames()
    local seen, names = {}, {}
    for name in pairs(MobZones) do
        seen[name] = true
        table.insert(names, name)
    end
    for _, model in ipairs(CollectionService:GetTagged("Monster")) do
        if model:IsA("Model") and model.Name ~= "TrainingDummy" then
            local name = mobName(model)
            if not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names, function(a, b)
        local oa = MobInfo[a] and MobInfo[a].order or 999
        local ob = MobInfo[b] and MobInfo[b].order or 999
        if oa ~= ob then
            return oa < ob
        end
        return a < b
    end)
    local out = {}
    for _, name in ipairs(names) do
        table.insert(out, mobLabel(name))
    end
    return out
end

local function wantedMob(model)
    if model.Name == "TrainingDummy" then
        return false
    end
    if Flags.Leveling then
        local plan = Game.levelPlan
        return plan ~= nil and plan.mobIds[model:GetAttribute("MonsterId")] == true
    end
    if next(Flags.FarmMobs) == nil then
        return true
    end
    return Flags.FarmMobs[mobName(model)] == true
end

local function priorityRank(model)
    if Flags.Leveling then
        local plan = Game.levelPlan
        return plan and plan.prefer and model:GetAttribute("MonsterId") == plan.prefer and 0 or 1
    end
    local mode = Flags.FarmPriority
    if mode == "Selection Order" then
        return table.find(Flags.FarmOrder, mobName(model)) or #Flags.FarmOrder + 1
    elseif mode == "Highest Level" then
        return -(tonumber(model:GetAttribute("Level")) or 0)
    elseif mode == "Lowest Level" then
        return tonumber(model:GetAttribute("Level")) or 0
    elseif mode == "Lowest HP" then
        return tonumber(model:GetAttribute("HP")) or 0
    end
    return 0
end

local function findTarget(root)
    local best, bestRank, bestDist = nil, math.huge, math.huge
    for _, model in ipairs(CollectionService:GetTagged("Monster")) do
        if mobAlive(model) and wantedMob(model) then
            local rank = priorityRank(model)
            local dist = (model.PrimaryPart.Position - root.Position).Magnitude
            if rank < bestRank or (rank == bestRank and dist < bestDist) then
                best, bestRank, bestDist = model, rank, dist
            end
        end
    end
    local current = Game.target
    if mobAlive(current) and wantedMob(current) then
        if Flags.FarmPriority ~= "Selection Order" or not best or priorityRank(current) <= bestRank then
            return current
        end
    end
    return best
end

local function standNear(root, position, distance)
    local flat = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
    local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
    local spot = position + dir * distance
    root.CFrame = CFrame.lookAt(spot, Vector3.new(position.X, spot.Y, position.Z))
    root.AssemblyLinearVelocity = Vector3.zero
end

local function setCurrentTarget(model)
    local value = LocalPlayer:FindFirstChild("CurrentTarget")
    if value and value:IsA("ObjectValue") and value.Value ~= model then
        value.Value = model
    end
end

local function goalCFrame(target)
    local radius = tonumber(target:GetAttribute("Radius")) or 1.5
    local range = tonumber(LocalPlayer:GetAttribute("AttackRange")) or 3
    local distance = math.clamp(math.min(Flags.FarmDistance, range - 1), 2, 40) + radius
    local pivot = target.PrimaryPart.CFrame
    local pos = pivot.Position
    local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
    look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
    local mode = Flags.FarmPosition
    local spot
    if mode == "Behind" then
        spot = pos - look * distance
    elseif mode == "Above" then
        spot = pos + Vector3.new(0, distance, 0)
    elseif mode == "Below" then
        spot = pos - Vector3.new(0, distance, 0)
    elseif mode == "Orbit" then
        local angle = os.clock() * 1.5
        spot = pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
    else
        spot = pos + look * distance
    end
    local dir = pos - spot
    if dir.Magnitude < 0.05 then
        return CFrame.new(spot)
    end
    local flat = Vector3.new(dir.X, 0, dir.Z)
    local up = flat.Magnitude < 0.1 and Vector3.zAxis or Vector3.yAxis
    return CFrame.lookAt(spot, pos, up)
end

local function followStep(dt)
    if unloaded or not Flags.AutoFarm or Game.busy then
        return
    end
    local target = Game.target
    if not mobAlive(target) then
        return
    end
    local _, root = getRoot()
    if not root then
        return
    end
    local goal = goalCFrame(target)
    if (root.Position - goal.Position).Magnitude > 25 then
        root.CFrame = goal
    else
        root.CFrame = root.CFrame:Lerp(goal, math.clamp(dt * 12, 0, 1))
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function zoneCenter(zoneId)
    local gates = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Gates")
    if not gates then
        return nil
    end
    local gate = gates:FindFirstChild("Gate_" .. zoneId)
    if not gate then
        return nil
    end
    local pos = gate:GetPivot().Position
    local nextZ = nil
    for _, other in ipairs(gates:GetChildren()) do
        local z = other:GetPivot().Position.Z
        if z < pos.Z - 1 and (not nextZ or z > nextZ) then
            nextZ = z
        end
    end
    local centerZ = nextZ and (pos.Z + nextZ) / 2 or pos.Z - 100
    return Vector3.new(pos.X, pos.Y + 5, centerZ)
end

local function travelToWanted(root)
    if next(Flags.FarmMobs) == nil or os.clock() - Game.lastTravel < 6 then
        return
    end
    local zones = {}
    for _, name in ipairs(Flags.FarmOrder) do
        for _, zoneId in ipairs(MobZones[name] or {}) do
            if not table.find(zones, zoneId) then
                table.insert(zones, zoneId)
            end
        end
    end
    if #zones == 0 then
        return
    end
    Game.travelIndex = Game.travelIndex % #zones + 1
    local center = zoneCenter(zones[Game.travelIndex])
    if not center then
        return
    end
    Game.lastTravel = os.clock()
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(center, 5)
    end)
    root.CFrame = CFrame.new(center)
    root.AssemblyLinearVelocity = Vector3.zero
end

local NpcPositions = {}

local function cacheNpcs()
    local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
    if not npcs then
        return
    end
    for _, npc in ipairs(npcs:GetChildren()) do
        local ok, pivot = pcall(npc.GetPivot, npc)
        if ok then
            NpcPositions[npc.Name] = pivot.Position
        end
    end
end

local function npcOptions()
    cacheNpcs()
    local out = {}
    for name in pairs(NpcPositions) do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

local function zoneOptions()
    local out = { "Town" }
    local mapData = loadData("MapData")
    local list = {}
    if type(mapData) == "table" then
        for id, zone in pairs(mapData) do
            if type(zone) == "table" then
                table.insert(list, { id = id, order = tonumber(zone.Order) or 99, name = zone.DisplayName or id })
            end
        end
    end
    table.sort(list, function(a, b)
        return a.order < b.order
    end)
    for _, z in ipairs(list) do
        table.insert(out, ("%s [%s]"):format(z.name, z.id))
    end
    return out
end

local function townPosition()
    local map = workspace:FindFirstChild("Map")
    local warps = map and map:FindFirstChild("Warps")
    local warp = warps and warps:FindFirstChild("Warp_Town")
    return warp and warp:GetPivot().Position + Vector3.new(0, 5, 0) or nil
end

local function teleportTo(position)
    local _, root = getRoot()
    if not (root and position) then
        return false
    end
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(position, 5)
    end)
    root.CFrame = CFrame.new(position)
    root.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function teleportZone(choice)
    if type(choice) ~= "string" then
        return false
    end
    if choice == "Town" then
        return teleportTo(townPosition())
    end
    local id = choice:match("%[(.-)%]$")
    return id ~= nil and teleportTo(zoneCenter(id))
end

local function teleportNpc(name)
    cacheNpcs()
    local pos = NpcPositions[name]
    if not pos then
        return false
    end
    return teleportTo(pos + Vector3.new(0, 3, 4))
end

local LevelZones = {}
local RepeatQuests = {}

local function buildLeveling()
    local mapData = loadData("MapData")
    if type(mapData) == "table" then
        for id, zone in pairs(mapData) do
            if type(zone) == "table" then
                local ids = {}
                for _, spawn in pairs(type(zone.Spawns) == "table" and zone.Spawns or {}) do
                    if type(spawn) == "table" and type(spawn.Id) == "string" then
                        table.insert(ids, spawn.Id)
                    end
                end
                table.insert(LevelZones, {
                    id = id,
                    order = tonumber(zone.Order) or 99,
                    minLevel = tonumber(tostring(zone.LevelText or ""):match("%d+")) or 1,
                    bossRoom = zone.BossRoom == true,
                    unlocks = zone.Unlocks,
                    boss = zone.Boss,
                    ids = ids,
                })
            end
        end
        table.sort(LevelZones, function(a, b)
            return a.order < b.order
        end)
    end
    local questData = loadData("QuestData")
    local quests = type(questData) == "table" and type(questData.Quests) == "table" and questData.Quests or {}
    for id, q in pairs(quests) do
        if type(q) == "table" and q.Repeat == true and q.Type == "kill" then
            table.insert(RepeatQuests, { id = id, level = tonumber(q.ReqLevel) or 1, target = q.Target, count = tonumber(q.Count) or 1 })
        end
    end
    table.sort(RepeatQuests, function(a, b)
        return a.level < b.level
    end)
end

buildLeveling()

local function zoneOfMob(monsterId)
    for _, z in ipairs(LevelZones) do
        if not z.bossRoom and table.find(z.ids, monsterId) then
            return z
        end
    end
    return nil
end

local function zoneBlocked(z)
    return (Game.blockedZones[z.id] or 0) > os.clock()
end

local function inZone(root, z)
    local center = zoneCenter(z.id)
    if not center then
        return false
    end
    return math.abs(root.Position.Z - center.Z) < 110 and math.abs(root.Position.X - center.X) < 200
end

local function activeQuest()
    local data = readJson("QuestsJson")
    local active = type(data) == "table" and type(data.Active) == "table" and data.Active or {}
    for id, progress in pairs(active) do
        for _, q in ipairs(RepeatQuests) do
            if q.id == id then
                return q, tonumber(progress) or 0
            end
        end
        return { id = id, other = true }, tonumber(progress) or 0
    end
    return nil, 0
end

local function bestQuest(level)
    local best = nil
    for _, q in ipairs(RepeatQuests) do
        local z = q.target and zoneOfMob(q.target)
        if q.level <= level and z and not zoneBlocked(z) then
            best = q
        end
    end
    return best
end

local function stepQuests(level)
    local quest, progress = activeQuest()
    if quest and not quest.other then
        if progress >= quest.count then
            fire("QuestAction", "claim", quest.id)
            Game.questWait = os.clock() + 2
            return
        end
        local z = zoneOfMob(quest.target)
        local best = bestQuest(level)
        if not z or zoneBlocked(z) or (best and best.level > quest.level) then
            fire("QuestAction", "abandon", quest.id)
            Game.questWait = os.clock() + 2
        end
        return
    end
    if quest then
        return
    end
    local best = bestQuest(level)
    if best then
        fire("QuestAction", "accept", best.id)
        Game.questWait = os.clock() + 2
    end
end

local function bossRoomFor(fieldId)
    for _, z in ipairs(LevelZones) do
        if z.bossRoom and z.unlocks == fieldId then
            return z
        end
    end
    return nil
end

local function planLeveling(level)
    local field = nil
    for _, z in ipairs(LevelZones) do
        if not z.bossRoom and z.minLevel <= level then
            if zoneBlocked(z) then
                local room = bossRoomFor(z.id)
                if Flags.LevelBosses and room and room.minLevel <= level and not zoneBlocked(room) then
                    return { zone = room, mobIds = { [room.boss] = true }, prefer = room.boss, boss = true }
                end
                break
            end
            field = z
        end
    end
    local quest, progress = activeQuest()
    if Flags.LevelQuests and quest and not quest.other and progress < quest.count then
        local qz = zoneOfMob(quest.target)
        if qz and not zoneBlocked(qz) then
            field = qz
        end
    end
    if not field then
        return nil
    end
    local ids = {}
    for _, id in ipairs(field.ids) do
        if not tostring(id):match("^boss_") then
            ids[id] = true
        end
    end
    local prefer = quest and not quest.other and quest.target or nil
    return { zone = field, mobIds = ids, prefer = prefer }
end

local function stepLeveling()
    local _, root = getRoot()
    if not root then
        return
    end
    local level = tonumber(LocalPlayer:GetAttribute("Level")) or 1
    if Flags.LevelQuests and os.clock() > Game.questWait then
        stepQuests(level)
    end
    local plan = planLeveling(level)
    Game.levelPlan = plan
    if not plan then
        Game.levelStatus = "No reachable zone"
        return
    end
    local quest, progress = activeQuest()
    local questText = quest and not quest.other and ("%s %d/%d"):format(quest.id, progress, quest.count) or "none"
    Game.levelStatus = ("Lv %d | %s%s | Quest %s"):format(level, plan.zone.id, plan.boss and " (boss)" or "", questText)
    if Game.busy then
        return
    end
    local pending = Game.levelTravel
    if pending and os.clock() - pending.at > 4 then
        Game.levelTravel = nil
        if pending.zone == plan.zone.id and not inZone(root, plan.zone) then
            Game.blockedZones[plan.zone.id] = os.clock() + 300
            Game.levelPlan = nil
            return
        end
    end
    if not Game.levelTravel and not inZone(root, plan.zone) then
        local center = zoneCenter(plan.zone.id)
        if center then
            Game.target = nil
            pcall(function()
                LocalPlayer:RequestStreamAroundAsync(center, 5)
            end)
            root.CFrame = CFrame.new(center)
            root.AssemblyLinearVelocity = Vector3.zero
            Game.levelTravel = { zone = plan.zone.id, at = os.clock() }
        end
    end
end

local function stepFarm()
    if Game.busy then
        return
    end
    local _, root = getRoot()
    if not root then
        return
    end
    local target = findTarget(root)
    if target ~= Game.target then
        Game.target = target
        Game.lastTargetFire = 0
    end
    if not target then
        if not Flags.Leveling then
            travelToWanted(root)
        end
        return
    end
    Game.travelIndex = 0
    setCurrentTarget(target)
    if os.clock() - Game.lastTargetFire > 1 then
        Game.lastTargetFire = os.clock()
        fire("SetTarget", target, false, true)
    end
end

local function learnedSkills()
    local out = {}
    local skills = readJson("SkillsJson")
    if type(skills) == "table" then
        for id, level in pairs(skills) do
            if type(id) == "string" and (tonumber(level) or 0) > 0 then
                table.insert(out, id)
            end
        end
    end
    table.sort(out)
    return out
end

local function selectedList(set)
    local out = {}
    for key, on in pairs(set) do
        if on then
            table.insert(out, key)
        end
    end
    table.sort(out)
    return out
end

local function stepSkills()
    local target = Game.target
    if not mobAlive(target) then
        return
    end
    local list = selectedList(Flags.Skills)
    if #list == 0 then
        return
    end
    Game.skillIndex = Game.skillIndex % #list + 1
    fire("UseSkill", list[Game.skillIndex], target)
end

local function potionOptions()
    local out = {}
    if type(ItemData) ~= "table" then
        return out
    end
    local src = type(ItemData.Items) == "table" and ItemData.Items or ItemData
    for id, def in pairs(src) do
        if type(def) == "table" and def.Kind == "usable" and (def.HealMin or def.SpPercent or def.Duration) then
            table.insert(out, id)
        end
    end
    table.sort(out)
    return out
end

local function stepPotions()
    local items = readJson("ItemsJson") or {}
    local hpPct, spPct = math.floor(Flags.HpPercent / 5) * 5, math.floor(Flags.SpPercent / 5) * 5
    for id in pairs(Flags.Potions) do
        local def = itemDef(id)
        local count = tonumber(items[id]) or 0
        if def and count > 0 then
            if def.HealMin then
                if LocalPlayer:GetAttribute("PotionHpNow") ~= id then
                    fire("SetPotionSlot", "hp", id)
                end
                if tonumber(LocalPlayer:GetAttribute("PotionHpPercent")) ~= hpPct then
                    fire("SetPotionAuto", "hp", hpPct)
                end
            elseif def.SpPercent then
                if LocalPlayer:GetAttribute("PotionSpNow") ~= id then
                    fire("SetPotionSlot", "sp", id)
                end
                if tonumber(LocalPlayer:GetAttribute("PotionSpPercent")) ~= spPct then
                    fire("SetPotionAuto", "sp", spPct)
                end
            elseif def.Duration then
                local last = Game.buffUsed[id]
                if not last or os.clock() - last > (tonumber(def.Duration) or 600) then
                    Game.buffUsed[id] = os.clock()
                    fire("UseItem", id)
                end
            end
        end
    end
end

local function stepRewards()
    local daily = readJson("DailyJson")
    if type(daily) == "table" and daily.CanClaim == true then
        fire("DailyClaim")
    end
    local rewards = readJson("RewardsJson")
    if type(rewards) ~= "table" then
        return
    end
    local online = rewards.Online
    if type(online) == "table" and (tonumber(LocalPlayer:GetAttribute("RewardsReady")) or 0) > 0 then
        local got = {}
        for _, v in ipairs(type(online.Got) == "table" and online.Got or {}) do
            got[tonumber(v) or v] = true
        end
        for i = 1, 12 do
            if not got[i] then
                fire("RewardAction", "online", i)
                task.wait(0.2)
            end
        end
    end
    local c8 = rewards.C8
    if type(c8) == "table" and c8.Can == true then
        fire("RewardAction", "c8", nil)
    end
    local month = rewards.Month
    if type(month) == "table" then
        local claimed = false
        for _, day in ipairs(type(month.Days) == "table" and month.Days or {}) do
            if tonumber(day) == tonumber(month.Today) then
                claimed = true
            end
        end
        if not claimed then
            fire("RewardAction", "month", nil)
        end
    end
end

local function stepGear()
    if LocalPlayer:GetAttribute("AutoEquip") ~= true then
        Game.gearSetByUs = true
        fire("SetAutoEquip", true)
    end
end

local function stepCards()
    fire("CardAction", "auto")
end

local function gearName(gid, gear)
    if GearUtil and type(GearUtil.Resolve) == "function" then
        local ok, def = pcall(GearUtil.Resolve, gid, gear)
        if ok and type(def) == "table" then
            return def.Name, def.Kind, def
        end
    end
    local entry = gear[gid]
    local def = type(entry) == "table" and itemDef(entry.Id)
    if def then
        return def.Name, def.Kind
    end
    return nil, nil
end

local function ownedWeapons()
    local out = {}
    local gear = readJson("GearJson") or {}
    local refine = readJson("RefineJson") or {}
    for gid in pairs(gear) do
        local name, kind = gearName(gid, gear)
        if kind == "weapon" then
            local _, _, def = gearName(gid, gear)
            table.insert(out, { gid = gid, name = name or gid, level = tonumber(refine[gid]) or 0, def = def })
        end
    end
    table.sort(out, function(a, b)
        return a.gid < b.gid
    end)
    return out
end

local function weaponLabel(w)
    return ("%s +%d [%s]"):format(w.name, w.level, w.gid)
end

local function weaponOptions()
    local out = {}
    for _, w in ipairs(ownedWeapons()) do
        table.insert(out, weaponLabel(w))
    end
    return out
end

local function refineMax()
    return tonumber(RefineConfig.Max) or 10
end

local function refineChance(level)
    local chances = RefineConfig.Chance
    return type(chances) == "table" and tonumber(chances[level + 1]) or 0
end

local function refineCost(w)
    if w.def and GearUtil and type(GearUtil.RefineCost) == "function" then
        local ok, cost = pcall(GearUtil.RefineCost, w.def, w.level + 1)
        if ok and tonumber(cost) then
            return tonumber(cost)
        end
    end
    return math.huge
end

local function refineAllowed(w)
    if w.level >= math.min(Flags.RefineTarget, refineMax()) then
        return false
    end
    if Flags.RefineSafeOnly and refineChance(w.level) < 100 then
        return false
    end
    local gold = tonumber(LocalPlayer:GetAttribute("Silver")) or 0
    return gold - refineCost(w) >= Flags.RefineGoldReserve
end

local function blacksmithPosition()
    local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
    local npc = npcs and npcs:FindFirstChild("blacksmith")
    return npc and npc:GetPivot().Position or nil
end

local RefineStatusLabel = nil

local function setRefineStatus(text)
    if RefineStatusLabel and Game.refineStatus ~= text then
        Game.refineStatus = text
        pcall(RefineStatusLabel.SetText, RefineStatusLabel, "Status: " .. text)
    end
end

local function stepRefine()
    local items = readJson("ItemsJson") or {}
    local stones = tonumber(items.refine_stone) or 0
    if next(Flags.RefineWeapons) == nil then
        setRefineStatus("No weapon selected")
        return
    end
    if stones <= 0 then
        setRefineStatus("No Refine Stones")
        return
    end
    local pick, blocked = nil, nil
    for _, w in ipairs(ownedWeapons()) do
        if Flags.RefineWeapons[w.gid] then
            if refineAllowed(w) then
                pick = w
                break
            end
            blocked = w
        end
    end
    if not pick then
        if blocked and blocked.level < Flags.RefineTarget then
            setRefineStatus(("Waiting: %s +%d (gold or chance limit)"):format(blocked.name, blocked.level))
        else
            setRefineStatus("Done: selected weapons reached target")
        end
        return
    end
    setRefineStatus(("Refining %s +%d -> +%d (%d%%, %d gold, %d stones)"):format(pick.name, pick.level, pick.level + 1, refineChance(pick.level), refineCost(pick), stones))
    local _, root = getRoot()
    local npcPos = blacksmithPosition()
    if not (root and npcPos) then
        return
    end
    Game.busy = true
    local back = root.CFrame
    if (root.Position - npcPos).Magnitude > 8 then
        standNear(root, npcPos, 4)
        task.wait(0.4)
    end
    if not unloaded and Flags.AutoRefine then
        local chance = refineChance(pick.level)
        local protect = Flags.RefineProtect and chance < 100 and pick.level + 1 >= (tonumber(RefineConfig.DowngradeFrom) or 5) and pick.level > 0 and (tonumber(items.protection_stone) or 0) > 0
        local lucky = Flags.RefineLucky and chance < 100 and (tonumber(items.lucky_stone) or 0) > 0
        fire("RefineWeapon", pick.gid, protect == true, lucky == true, true)
        task.wait(math.max(Flags.RefineDelay, 0.5))
    end
    if not Flags.AutoFarm then
        root.CFrame = back
    end
    Game.busy = false
end

local SellStatusLabel = nil

local function setSellStatus(text)
    if SellStatusLabel and Game.sellStatus ~= text then
        Game.sellStatus = text
        pcall(SellStatusLabel.SetText, SellStatusLabel, "Status: " .. text)
    end
end

local function sellKindOptions()
    local seen, out = {}, {}
    if type(ItemData) == "table" then
        local src = type(ItemData.Items) == "table" and ItemData.Items or ItemData
        for _, def in pairs(src) do
            if type(def) == "table" and type(def.Kind) == "string" and (tonumber(def.Sell) or 0) > 0 and not seen[def.Kind] then
                seen[def.Kind] = true
                table.insert(out, def.Kind)
            end
        end
    end
    table.sort(out)
    table.insert(out, "Gear")
    return out
end

local function sellItemOptions()
    local out = {}
    if type(ItemData) == "table" then
        local src = type(ItemData.Items) == "table" and ItemData.Items or ItemData
        for id, def in pairs(src) do
            if type(def) == "table" and def.Name and (tonumber(def.Sell) or 0) > 0 then
                table.insert(out, ("%s [%s]"):format(def.Name, id))
            end
        end
    end
    table.sort(out)
    return out
end

local function sellList()
    local items = readJson("ItemsJson") or {}
    local locks = readJson("LocksJson") or {}
    local refine = readJson("RefineJson") or {}
    local junkKeep = type(GameConfig) == "table" and type(GameConfig.JunkKeep) == "table" and GameConfig.JunkKeep or {}
    local equipped = {}
    local weapon = LocalPlayer:GetAttribute("WeaponId")
    if type(weapon) == "string" and weapon ~= "" then
        equipped[weapon] = 1
    end
    for _, v in pairs(readJson("EquipJson") or {}) do
        if type(v) == "string" and v ~= "" then
            equipped[v] = (equipped[v] or 0) + 1
        end
    end
    local list = {}
    for id, count in pairs(items) do
        local def = itemDef(id)
        if def and def.Name and type(count) == "number" and not locks[id] and (tonumber(def.Sell) or 0) > 0
            and Flags.SellKinds[def.Kind] and not Flags.SellKeep[id] and not junkKeep[id] then
            local amount = count - (equipped[id] or 0) - Flags.SellKeepAmount
            if amount > 0 then
                table.insert(list, { id, amount })
            end
        end
    end
    if Flags.SellKinds.Gear then
        local gear = readJson("GearJson") or {}
        for gid in pairs(gear) do
            local _, _, def = gearName(gid, gear)
            if def and not equipped[gid] and not locks[gid] and (tonumber(def.Sell) or 0) > 0
                and not (Flags.SellKeepRefined and (tonumber(refine[gid]) or 0) > 0) then
                table.insert(list, { gid, 1 })
            end
        end
    end
    return list
end

local function merchantPosition()
    local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
    if not npcs then
        return nil
    end
    for _, npc in ipairs(npcs:GetChildren()) do
        if npc:GetAttribute("NpcId") == "merchant" or npc.Name == "merchant" then
            return npc:GetPivot().Position
        end
    end
    return nil
end

local function sellDue()
    if Flags.SellTrigger == "Interval" then
        return os.clock() - (Game.lastSell or 0) >= Flags.SellInterval
    end
    local used = tonumber(LocalPlayer:GetAttribute("BagSlotsUsed")) or 0
    local max = tonumber(LocalPlayer:GetAttribute("BagSlotsMax")) or 0
    return max > 0 and used / max * 100 >= Flags.SellBagPercent
end

local function stepSell()
    local list = sellList()
    if #list == 0 and not Flags.SellJunk then
        setSellStatus("Nothing to sell")
        return
    end
    if not sellDue() then
        setSellStatus(("Waiting | Bag %s/%s"):format(tostring(LocalPlayer:GetAttribute("BagSlotsUsed") or "?"), tostring(LocalPlayer:GetAttribute("BagSlotsMax") or "?")))
        return
    end
    if Game.busy then
        return
    end
    local _, root = getRoot()
    local npcPos = merchantPosition()
    if not (root and npcPos) then
        setSellStatus("Merchant not found")
        return
    end
    Game.busy = true
    local back = root.CFrame
    if (root.Position - npcPos).Magnitude > 8 then
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(npcPos, 5)
        end)
        standNear(root, npcPos, 4)
        task.wait(0.4)
    end
    if not unloaded and Flags.AutoSell then
        local before = tonumber(LocalPlayer:GetAttribute("Silver")) or 0
        if #list > 0 then
            fire("ShopSellMany", list)
            task.wait(0.6)
        end
        if Flags.SellJunk and not unloaded and Flags.AutoSell then
            fire("ShopSellJunk")
            task.wait(0.6)
        end
        Game.lastSell = os.clock()
        local gained = (tonumber(LocalPlayer:GetAttribute("Silver")) or 0) - before
        setSellStatus(("Sold %d entries, +%d gold"):format(#list, gained))
    end
    if not Flags.AutoFarm then
        root.CFrame = back
    end
    Game.busy = false
end

local STAT_NAMES = { "STR", "AGI", "VIT", "INT", "DEX", "LUK" }

local function buildOptions()
    local out = {}
    local job = LocalPlayer:GetAttribute("Job")
    local jobs = type(BuildData) == "table" and BuildData.Jobs
    if type(jobs) == "table" and type(jobs[job]) == "table" then
        for id in pairs(jobs[job]) do
            table.insert(out, "Build: " .. tostring(id))
        end
        table.sort(out)
    end
    for _, stat in ipairs(STAT_NAMES) do
        table.insert(out, "Stat: " .. stat)
    end
    return out
end

local function stepStats()
    local choice = Flags.StatChoice
    if type(choice) ~= "string" then
        return
    end
    local build = choice:match("^Build: (.+)$")
    if build then
        if LocalPlayer:GetAttribute("AutoBuild") ~= build then
            fire("ApplyBuild", build, true)
        end
        return
    end
    local stat = choice:match("^Stat: (.+)$")
    if not stat then
        return
    end
    if (LocalPlayer:GetAttribute("AutoBuild") or "manual") ~= "manual" then
        fire("SetAutoBuild", "manual")
        return
    end
    if (tonumber(LocalPlayer:GetAttribute("StatPoints")) or 0) > 0 then
        fire("AllocateStat", stat)
    end
end

local function dropReady(part, now)
    local freeAt = tonumber(part:GetAttribute("FreeAt")) or 0
    local owner = tonumber(part:GetAttribute("OwnerUserId")) or 0
    return owner == 0 or owner == LocalPlayer.UserId or freeAt <= now
end

local function stepDrops()
    local _, root = getRoot()
    if not root then
        return
    end
    local now = workspace:GetServerTimeNow()
    for _, part in ipairs(CollectionService:GetTagged("Drop")) do
        if unloaded or not Flags.AutoDrops then
            break
        end
        if part:IsA("BasePart") and part.Parent and dropReady(part, now) then
            Game.busy = true
            root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2.5, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.15)
            fire("PickupDrop")
            task.wait(0.3)
        end
    end
    Game.busy = false
end

local function boxPosition(box)
    if box:IsA("BasePart") then
        return box.Position
    end
    if box:IsA("Model") then
        return box:GetPivot().Position
    end
    return nil
end

local function stepBoxes()
    local _, root = getRoot()
    if not root then
        return
    end
    for _, box in ipairs(CollectionService:GetTagged("LootBox")) do
        if unloaded or not Flags.AutoBoxes then
            break
        end
        local pos = box.Parent and dropReady(box, workspace:GetServerTimeNow()) and boxPosition(box)
        if pos then
            Game.busy = true
            standNear(root, pos, 3)
            task.wait(0.2)
            fire("OpenLootBox", box)
            local prompt = box:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and type(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            end
            task.wait(0.6)
        end
    end
    Game.busy = false
end

local function applyWalkSpeed()
    local humanoid = select(1, getRoot())
    if not humanoid then
        return
    end
    if Flags.WalkSpeedEnabled then
        if walkSpeedRestore[humanoid] == nil then
            walkSpeedRestore[humanoid] = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = Flags.WalkSpeed
    elseif walkSpeedRestore[humanoid] ~= nil then
        humanoid.WalkSpeed = walkSpeedRestore[humanoid]
        walkSpeedRestore[humanoid] = nil
    end
end

local function setWalkSpeedEnabled(value)
    Flags.WalkSpeedEnabled = value == true
    applyWalkSpeed()
end

local function setWalkSpeed(value)
    Flags.WalkSpeed = tonumber(value) or Flags.WalkSpeed
    if Flags.WalkSpeedEnabled then
        applyWalkSpeed()
    end
end

local function setAlwaysSprint(value)
    Flags.AlwaysSprint = value == true
    if sprintConn then
        sprintConn:Disconnect()
        sprintConn = nil
    end
    if not Flags.AlwaysSprint then
        if sprintRestore ~= nil then
            LocalPlayer:SetAttribute("LumiSprintLock", sprintRestore)
            sprintRestore = nil
        end
        return
    end
    if sprintRestore == nil then
        sprintRestore = LocalPlayer:GetAttribute("LumiSprintLock") == true
    end
    LocalPlayer:SetAttribute("LumiSprintLock", true)
    sprintConn = track(LocalPlayer:GetAttributeChangedSignal("LumiSprintLock"):Connect(function()
        if Flags.AlwaysSprint and not unloaded and LocalPlayer:GetAttribute("LumiSprintLock") ~= true then
            LocalPlayer:SetAttribute("LumiSprintLock", true)
        end
    end))
end

local function setInfJump(value)
    Flags.InfJump = value == true
    if infJumpConn then
        infJumpConn:Disconnect()
        infJumpConn = nil
    end
    if not Flags.InfJump then
        return
    end
    infJumpConn = track(UserInputService.JumpRequest:Connect(function()
        if unloaded or not Flags.InfJump then
            return
        end
        local humanoid = select(1, getRoot())
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))
end

local function setNoClip(value)
    Flags.NoClip = value == true
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    if not Flags.NoClip then
        for part, canCollide in pairs(noclipRestore) do
            if part.Parent then
                part.CanCollide = canCollide
            end
        end
        table.clear(noclipRestore)
        return
    end
    noclipConn = track(RunService.Stepped:Connect(function()
        if unloaded or not Flags.NoClip then
            return
        end
        local character = LocalPlayer.Character
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if noclipRestore[part] == nil then
                    noclipRestore[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end))
end

local function snapshotPrompt(prompt)
    if promptRestore[prompt] == nil then
        promptRestore[prompt] = {
            HoldDuration = prompt.HoldDuration,
            MaxActivationDistance = prompt.MaxActivationDistance,
            RequiresLineOfSight = prompt.RequiresLineOfSight,
        }
    end
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 50
    prompt.RequiresLineOfSight = false
end

local function setInstantProximityPrompt(value)
    Flags.InstantProximityPrompt = value == true
    if promptConn then
        promptConn:Disconnect()
        promptConn = nil
    end
    if not Flags.InstantProximityPrompt then
        for prompt, prev in pairs(promptRestore) do
            if prompt.Parent then
                prompt.HoldDuration = prev.HoldDuration
                prompt.MaxActivationDistance = prev.MaxActivationDistance
                prompt.RequiresLineOfSight = prev.RequiresLineOfSight
            end
        end
        table.clear(promptRestore)
        return
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            snapshotPrompt(inst)
        end
    end
    promptConn = track(workspace.DescendantAdded:Connect(function(inst)
        if unloaded or not Flags.InstantProximityPrompt then
            return
        end
        if inst:IsA("ProximityPrompt") then
            snapshotPrompt(inst)
        end
    end))
end

local function stopFly()
    if flyState and flyState.conn then
        flyState.conn:Disconnect()
    end
    local humanoid = flyState and flyState.humanoid
    if humanoid and humanoid.Parent and flyState.platformStand ~= nil then
        humanoid.PlatformStand = flyState.platformStand
    end
    flyState = nil
end

local function setFly(value)
    Flags.Fly = value == true
    stopFly()
    if not Flags.Fly then
        return
    end
    local humanoid, root = getRoot()
    if not (humanoid and root) then
        return
    end
    flyState = {
        humanoid = humanoid,
        root = root,
        platformStand = humanoid.PlatformStand,
    }
    humanoid.PlatformStand = true
    flyState.conn = track(RunService.RenderStepped:Connect(function()
        if unloaded or not Flags.Fly then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        local hum, hrp = getRoot()
        if not (hum and hrp) then
            return
        end
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            move += cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            move -= cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            move -= cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            move += cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            move += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            move -= Vector3.yAxis
        end
        if move.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = move.Unit * Flags.FlySpeed
        else
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        hum.PlatformStand = true
    end))
end

local function setFlySpeed(value)
    Flags.FlySpeed = tonumber(value) or Flags.FlySpeed
end

local function setAutoReconnect(value)
    Flags.AutoReconnect = value == true
    reconnectToken += 1
    if reconnectConn then
        reconnectConn:Disconnect()
        reconnectConn = nil
    end
    if reconnectFailedConn then
        reconnectFailedConn:Disconnect()
        reconnectFailedConn = nil
    end
    if not Flags.AutoReconnect then
        return
    end
    local attempt = 0
    local function tryReconnect(token)
        if unloaded or not Flags.AutoReconnect or reconnectToken ~= token then
            return
        end
        attempt += 1
        if attempt == 1 then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        elseif attempt == 2 then
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        else
            warn("[HuntingTogether] auto reconnect: attempts exhausted")
        end
    end
    reconnectConn = track(GuiService.ErrorMessageChanged:Connect(function(message)
        if unloaded or not Flags.AutoReconnect or attempt > 0 or message == "" then
            return
        end
        local token = reconnectToken
        task.delay(1.5, tryReconnect, token)
    end))
    reconnectFailedConn = track(TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LocalPlayer or unloaded or not Flags.AutoReconnect or attempt == 0 then
            return
        end
        local token = reconnectToken
        task.delay(3, tryReconnect, token)
    end))
end

local function setDisable3D(value)
    Flags.Disable3DRendering = value == true
    if Flags.Disable3DRendering then
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
        if not renderBacking then
            local gui = Instance.new("ScreenGui")
            gui.Name = "OuroborosRenderBacking"
            gui.IgnoreGuiInset = true
            gui.DisplayOrder = -100
            gui.ResetOnSpawn = false
            local frame = Instance.new("Frame")
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.Size = UDim2.fromScale(1, 1)
            frame.BorderSizePixel = 0
            frame.Parent = gui
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
            renderBacking = gui
        end
    else
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
        if renderBacking then
            renderBacking:Destroy()
            renderBacking = nil
        end
    end
end

local function captureFps(inst)
    if fpsRestore[inst] ~= nil then
        return
    end
    local snap = {}
    if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
        snap.Enabled = inst.Enabled
        inst.Enabled = false
    elseif inst:IsA("Explosion") then
        snap.Visible = inst.Visible
        inst.Visible = false
    end
    fpsRestore[inst] = snap
end


local function setFpsBoost(value)
    Flags.FpsBoost = value == true
    if fpsConn then
        fpsConn:Disconnect()
        fpsConn = nil
    end
    if not Flags.FpsBoost then
        for inst, snap in pairs(fpsRestore) do
            if typeof(inst) == "Instance" and inst.Parent then
                for key, prev in pairs(snap) do
                    pcall(function()
                        inst[key] = prev
                    end)
                end
            end
        end
        local light = fpsRestore.Lighting
        if light then
            Lighting.GlobalShadows = light.GlobalShadows
            Lighting.FogEnd = light.FogEnd
        end
        table.clear(fpsRestore)
        return
    end
    if fpsRestore.Lighting == nil then
        fpsRestore.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        captureFps(inst)
    end
    fpsConn = track(workspace.DescendantAdded:Connect(function(inst)
        if unloaded or not Flags.FpsBoost then
            return
        end
        captureFps(inst)
    end))
end

local AntiAfk = {
    Enabled = false,
    Disabled = {},
    Fallback = nil,
    Worker = nil,
}

function AntiAfk.disableIdled()
    if type(getconnections) == "function" then
        local ok, list = pcall(getconnections, LocalPlayer.Idled)
        if ok and type(list) == "table" then
            for _, conn in ipairs(list) do
                if type(conn) == "table" or typeof(conn) == "userdata" then
                    local disabled = pcall(function()
                        conn:Disable()
                    end)
                    if disabled and not table.find(AntiAfk.Disabled, conn) then
                        table.insert(AntiAfk.Disabled, conn)
                    end
                end
            end
            return
        end
    end
    if not AntiAfk.Fallback then
        AntiAfk.Fallback = track(LocalPlayer.Idled:Connect(function()
            if unloaded or not AntiAfk.Enabled then
                return
            end
            local sent = pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
                vim:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
            end)
            if not sent then
                pcall(function()
                    local cam = workspace.CurrentCamera
                    VirtualUser:Button2Down(Vector2.zero, cam.CFrame)
                    task.wait(0.1)
                    VirtualUser:Button2Up(Vector2.zero, cam.CFrame)
                end)
            end
        end))
    end
end

function AntiAfk.restoreIdled()
    for _, conn in ipairs(AntiAfk.Disabled) do
        local ok, err = pcall(function()
            conn:Enable()
        end)
        if not ok then
            warn("[HuntingTogether] anti afk restore: " .. tostring(err))
        end
    end
    table.clear(AntiAfk.Disabled)
    if AntiAfk.Fallback then
        AntiAfk.Fallback:Disconnect()
        AntiAfk.Fallback = nil
    end
end

local function setAntiAfk(value)
    AntiAfk.Enabled = value == true
    if AntiAfk.Enabled then
        AntiAfk.disableIdled()
        if not AntiAfk.Worker then
            AntiAfk.Worker = task.spawn(function()
                while AntiAfk.Enabled and not unloaded do
                    task.wait(30)
                    if not AntiAfk.Enabled or unloaded then
                        break
                    end
                    AntiAfk.disableIdled()
                end
                AntiAfk.Worker = nil
            end)
        end
    else
        AntiAfk.restoreIdled()
    end
end

local function bindCharacter(character)
    task.defer(function()
        if unloaded then
            return
        end
        applyWalkSpeed()
        if Flags.Fly then
            setFly(true)
        end
    end)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    if humanoid then
        track(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Flags.WalkSpeedEnabled and not unloaded then
                if humanoid.WalkSpeed ~= Flags.WalkSpeed then
                    humanoid.WalkSpeed = Flags.WalkSpeed
                end
            end
        end))
    end
end

local WORKER_STEPS = {
    AutoFarm = { 0.15, stepFarm },
    AutoSkills = { 0.5, stepSkills },
    AutoPotions = { 2, stepPotions },
    AutoRewards = { 30, stepRewards },
    AutoGear = { 10, stepGear },
    AutoCards = { 30, stepCards },
    AutoStats = { 1, stepStats },
    AutoDrops = { 0.5, stepDrops },
    AutoBoxes = { 0.5, stepBoxes },
    AutoRefine = { 0.5, stepRefine },
    AutoSell = { 1, stepSell },
    Leveling = { 1, stepLeveling },
}

local function setFeature(key, value)
    Flags[key] = value == true
    local spec = WORKER_STEPS[key]
    if spec then
        setWorker(key, Flags[key], spec[1], spec[2])
    end
    if key == "Leveling" then
        Game.levelPlan = nil
        Game.levelTravel = nil
        Game.target = nil
        table.clear(Game.blockedZones)
        if not Flags.Leveling then
            Game.levelStatus = "Idle"
        end
    end
    if key == "AutoRefine" and not Flags.AutoRefine then
        setRefineStatus("Idle")
    end
    if key == "AutoSell" and not Flags.AutoSell then
        setSellStatus("Idle")
    end
    if key == "AutoFarm" then
        if Game.followConn then
            Game.followConn:Disconnect()
            Game.followConn = nil
        end
        if Flags.AutoFarm then
            Game.followConn = track(RunService.Heartbeat:Connect(followStep))
        else
            Game.target = nil
            pcall(setCurrentTarget, nil)
        end
    end
    if key == "AutoGear" and not Flags.AutoGear and Game.gearSetByUs then
        Game.gearSetByUs = false
        pcall(fire, "SetAutoEquip", false)
    end
end

local function stop()
    if unloaded then
        return
    end
    local ok, err = pcall(function()
        for key in pairs(WORKER_STEPS) do
            setFeature(key, false)
        end
        Game.busy = false
        setWalkSpeedEnabled(false)
        setInfJump(false)
        setAlwaysSprint(false)
        setNoClip(false)
        setInstantProximityPrompt(false)
        setFly(false)
        setAutoReconnect(false)
        setDisable3D(false)
        setFpsBoost(false)
        setAntiAfk(false)
    end)
    if not ok then
        warn("[HuntingTogether] cleanup: " .. tostring(err))
    end
    unloaded = true
    for _, conn in ipairs(connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(connections)
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
if LocalPlayer.Character then
    bindCharacter(LocalPlayer.Character)
end


--==================================================================--
-- UI : Ouroboros UI
--==================================================================--
-- Status labels in the logic layer only need a truthy object with SetText.
-- The visible text is rendered by CreateStatusList reading Game.*Status.
RefineStatusLabel = { SetText = function() end }
SellStatusLabel = { SetText = function() end }

local function buildUI()
    -- load library ---------------------------------------------------
    local ok, result = pcall(function()
        local chunk, compileErr = loadstring(game:HttpGet(UI_URL .. "?cb=" .. tostring(os.time())))
        if type(chunk) ~= "function" then
            error("library failed to compile: " .. tostring(compileErr), 0)
        end
        local lib = chunk()
        if type(lib) ~= "table" then
            error("library file did not return a table", 0)
        end
        return lib
    end)
    if not ok then
        error("failed to load UI library: " .. tostring(result), 0)
    end
    Library = result
    Library:SetDefaultTheme(UI_THEME)

    local Window = Library:CreateWindow({
	Name             = "128b!t OFFICIAL",
	LoadingSubtitle  = "Hunting Together | v.1.0",
	ToggleUIKeybind  = "RightControl",
    Icon = "rbxassetid://97177675697505",
	ConfigurationSaving = {
		Enabled    = true,
		FolderName = "128Bit_Config",
		FileName   = "default",
	},
	ToggleButton = { Platform = "Mobile",Icon = "rbxassetid://97177675697505" },
	Home = {
		Title   = "Welcome to " .. SCRIPT_NAME .. "!",
		Tier    = SCRIPT_VERSION,
		Discord = "https://discord.gg/E6ft5s7Ddu",
		Website = "https://128bit.online",
		Stats   = { "Players", "Session", "FPS", "Ping" },
	},
})

    -- helpers --------------------------------------------------------
    local Ctl = {} -- controls by flag, for visual sync

    -- รองรับทั้ง array {"A","B"} และ dict {A=true}
    local function toSet(value)
        local out = {}
        if type(value) == "string" then
            out[value] = true
        elseif type(value) == "table" then
            for key, on in pairs(value) do
                if type(key) == "number" and type(on) == "string" then
                    out[on] = true
                elseif on == true then
                    out[key] = true
                end
            end
        end
        return out
    end

    -- dropdown เลือกได้อันเดียว อาจส่งมาเป็น string หรือ {string}
    local function single(value)
        if type(value) == "table" then
            return value[1]
        end
        return value
    end

    -- ลองเรียกเมธอดรีเฟรชของ dropdown ตามชื่อที่พบบ่อย
    local function refreshDropdown(ctrl, list)
        if type(ctrl) ~= "table" and typeof(ctrl) ~= "userdata" then
            return false
        end
        for _, method in ipairs({ "Refresh", "SetOptions", "SetValues", "UpdateOptions" }) do
            local fn = ctrl[method]
            if type(fn) == "function" and pcall(fn, ctrl, list) then
                return true
            end
        end
        return false
    end

    local function setToggleVisual(ctrl, value)
        if type(ctrl) ~= "table" then
            return
        end
        for _, method in ipairs({ "Set", "SetValue" }) do
            local fn = ctrl[method]
            if type(fn) == "function" and pcall(fn, ctrl, value) then
                return
            end
        end
    end

    local function notify(text, kind)
        Library:Notify({ Title = GAME_NAME, Content = text, Type = kind or "Info", Duration = 3 })
    end

    local function refreshButton(box, name, desc, flag, getList)
        box:CreateButton({
            Name = name,
            Description = desc,
            Callback = function()
                if refreshDropdown(Ctl[flag], getList()) then
                    notify("รีเฟรชรายการแล้ว", "Success")
                else
                    notify("UI นี้ไม่รองรับการรีเฟรช dropdown ให้ execute ใหม่แทน")
                end
            end,
        })
    end

    local function featureToggle(box, key, name, desc)
        Ctl[key] = box:CreateToggle({
            Name = name,
            Description = desc,
            CurrentValue = false,
            Flag = key,
            Callback = function(value)
                setFeature(key, value)
            end,
        })
    end

    local function simpleToggle(box, key, name, desc, default, fn)
        Ctl[key] = box:CreateToggle({
            Name = name,
            Description = desc,
            CurrentValue = default,
            Flag = key,
            Callback = fn,
        })
    end

    local function slider(box, key, name, desc, min, max, step, default, fn)
        Ctl[key] = box:CreateSlider({
            Name = name,
            Description = desc,
            Range = { min, max },
            Increment = step,
            CurrentValue = default,
            Flag = key,
            Callback = fn,
        })
    end

    local function statusList(box, name, getText)
        box:CreateStatusList({
            Name = name,
            MaxRows = 1,
            UpdateRate = 1,
            Update = function()
                return { { Text = "Status", Value = tostring(getText() or "Idle") } }
            end,
        })
    end

    -- tabs -----------------------------------------------------------
    local FarmTab = Window:CreateTab({ Name = "Farm", Icon = "swords" })
    local RefineTab = Window:CreateTab({ Name = "Refine", Icon = "hammer" })
    local SellTab = Window:CreateTab({ Name = "Sell", Icon = "coins" })
    local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "user" })
    local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })

    ------------------------------------------------------------------
    -- FARM
    ------------------------------------------------------------------
    local Farm = FarmTab:AddLeftGroupbox({ Name = "Autofarm", Icon = "swords" })
    featureToggle(Farm, "AutoFarm", "Autofarm", "ฟาร์มม็อบอัตโนมัติ วาร์ปไปยืนใกล้ม็อบแล้วโจมตีต่อเนื่อง")
    Ctl.FarmMobs = Farm:CreateDropdown({
        Name = "Mob Selector",
        Description = "เลือกม็อบที่ต้องการฟาร์ม (ไม่เลือกเลย = ฟาร์มม็อบทุกตัว)",
        Options = mobNames(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "FarmMobs",
        Callback = function(value)
            local set = {}
            for label in pairs(toSet(value)) do
                set[labelToName(label)] = true
            end
            Flags.FarmMobs = set
            local order = {}
            for _, name in ipairs(Flags.FarmOrder) do
                if set[name] then
                    table.insert(order, name)
                end
            end
            local added = {}
            for name in pairs(set) do
                if not table.find(order, name) then
                    table.insert(added, name)
                end
            end
            table.sort(added, function(a, b)
                local oa = MobInfo[a] and MobInfo[a].order or 999
                local ob = MobInfo[b] and MobInfo[b].order or 999
                if oa ~= ob then
                    return oa < ob
                end
                return a < b
            end)
            for _, name in ipairs(added) do
                table.insert(order, name)
            end
            Flags.FarmOrder = order
            Game.travelIndex = 0
            Game.target = nil
        end,
    })
    refreshButton(Farm, "Refresh Mobs", "รีเฟรชรายชื่อม็อบใหม่", "FarmMobs", mobNames)
    Farm:CreateDropdown({
        Name = "Priority",
        Description = "เกณฑ์เลือกเป้าหมายก่อน: ตามลำดับที่เลือก / ใกล้สุด / เลเวลสูงสุด / เลเวลต่ำสุด / HP น้อยสุด",
        Options = { "Selection Order", "Nearest", "Highest Level", "Lowest Level", "Lowest HP" },
        CurrentOption = "Selection Order",
        AllowNone = false,
        Flag = "FarmPriority",
        Callback = function(value)
            Flags.FarmPriority = single(value) or "Selection Order"
        end,
    })
    Farm:CreateDropdown({
        Name = "Position",
        Description = "ตำแหน่งที่ยืนเทียบกับม็อบ: หน้า / หลัง / บน / ล่าง / วนรอบ",
        Options = { "Front", "Behind", "Above", "Below", "Orbit" },
        CurrentOption = "Front",
        AllowNone = false,
        Flag = "FarmPosition",
        Callback = function(value)
            Flags.FarmPosition = single(value) or "Front"
        end,
    })
    slider(Farm, "FarmDistance", "Distance", "ระยะห่างระหว่างตัวละครกับม็อบ", 2, 30, 1, 8, function(value)
        Flags.FarmDistance = tonumber(value) or Flags.FarmDistance
    end)

    local Leveling = FarmTab:AddLeftGroupbox({ Name = "Level 1 - 99", Icon = "trending-up" })
    Ctl.Leveling = Leveling:CreateToggle({
        Name = "Level 1 - 99",
        Description = "เลเวลอัตโนมัติ 1-99 (ทำเควสซ้ำ + สู้บอสประตู) เปิดแล้วจะทับค่า Mob Selector และเปิด Autofarm ให้เอง",
        CurrentValue = false,
        Flag = "Leveling",
        Callback = function(value)
            setFeature("Leveling", value)
            if value and not Flags.AutoFarm then
                setFeature("AutoFarm", true)
                setToggleVisual(Ctl.AutoFarm, true)
            end
        end,
    })
    statusList(Leveling, "Level Status", function()
        return Game.levelStatus
    end)
    simpleToggle(Leveling, "LevelQuests", "Use Repeatable Quests", "ใช้เควสซ้ำช่วยเพิ่มเลเวล", true, function(value)
        Flags.LevelQuests = value == true
    end)
    simpleToggle(Leveling, "LevelBosses", "Fight Gate Bosses", "สู้บอสประตู (Gate Boss) อัตโนมัติระหว่างเลเวล", true, function(value)
        Flags.LevelBosses = value == true
    end)

    local Skills = FarmTab:AddLeftGroupbox({ Name = "Skills", Icon = "zap" })
    featureToggle(Skills, "AutoSkills", "Auto Skills", "ใช้สกิลที่เลือกอัตโนมัติ")
    Ctl.Skills = Skills:CreateDropdown({
        Name = "Skills",
        Description = "เลือกสกิลที่ต้องการให้ใช้อัตโนมัติ",
        Options = learnedSkills(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "Skills",
        Callback = function(value)
            Flags.Skills = toSet(value)
        end,
    })
    refreshButton(Skills, "Refresh Skills", "รีเฟรชรายชื่อสกิลที่เรียนแล้ว", "Skills", learnedSkills)

    local Potions = FarmTab:AddRightGroupbox({ Name = "Potions", Icon = "flask-conical" })
    featureToggle(Potions, "AutoPotions", "Auto Potions", "ดื่มยาอัตโนมัติเมื่อ HP/SP ต่ำกว่าค่าที่ตั้ง")
    Ctl.Potions = Potions:CreateDropdown({
        Name = "Potions",
        Description = "เลือกยาที่อนุญาตให้ใช้อัตโนมัติ",
        Options = potionOptions(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "Potions",
        Callback = function(value)
            Flags.Potions = toSet(value)
        end,
    })
    slider(Potions, "HpPercent", "HP Potion Below %", "ดื่มยา HP เมื่อเลือดต่ำกว่า % นี้", 5, 90, 1, 50, function(value)
        Flags.HpPercent = tonumber(value) or Flags.HpPercent
    end)
    slider(Potions, "SpPercent", "SP Potion Below %", "ดื่มยา SP เมื่อมานาต่ำกว่า % นี้", 5, 90, 1, 30, function(value)
        Flags.SpPercent = tonumber(value) or Flags.SpPercent
    end)

    local Stats = FarmTab:AddRightGroupbox({ Name = "Stats", Icon = "trending-up" })
    featureToggle(Stats, "AutoStats", "Auto Stats", "แจกแต้มสเตตัสอัตโนมัติตามบิลด์ที่เลือก")
    Stats:CreateDropdown({
        Name = "Build / Stat",
        Description = "เลือกบิลด์หรือสเตตัสที่จะลงแต้มให้",
        Options = buildOptions(),
        CurrentOption = {},
        AllowNone = true,
        Flag = "StatChoice",
        Callback = function(value)
            Flags.StatChoice = single(value)
        end,
    })

    local Progress = FarmTab:AddRightGroupbox({ Name = "Progression", Icon = "gift" })
    featureToggle(Progress, "AutoRewards", "Auto Claim Online, 8-Day, Monthly", "รับรางวัลออนไลน์ / 8 วัน / รายเดือนอัตโนมัติ")
    featureToggle(Progress, "AutoGear", "Auto Gear", "สวมใส่อุปกรณ์ที่ดีที่สุดอัตโนมัติ")
    featureToggle(Progress, "AutoCards", "Auto Cards", "จัดการการ์ดอัตโนมัติ")

    local Collect = FarmTab:AddLeftGroupbox({ Name = "Collect", Icon = "package" })
    featureToggle(Collect, "AutoDrops", "Auto Collect Dropped", "เก็บไอเทมที่ม็อบดรอปอัตโนมัติ")
    featureToggle(Collect, "AutoBoxes", "Auto Collect Hard Worker Box", "เก็บกล่อง Hard Worker อัตโนมัติ")

    ------------------------------------------------------------------
    -- REFINE
    ------------------------------------------------------------------
    local Refine = RefineTab:AddLeftGroupbox({ Name = "Auto Refine", Icon = "hammer" })
    featureToggle(Refine, "AutoRefine", "Auto Refine", "ตีบวกอาวุธอัตโนมัติจนถึงเลเวลที่ตั้งไว้")
    statusList(Refine, "Refine Status", function()
        return Game.refineStatus
    end)
    Ctl.RefineWeapons = Refine:CreateDropdown({
        Name = "Weapons",
        Description = "เลือกอาวุธที่ต้องการตีบวก",
        Options = weaponOptions(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "RefineWeapons",
        Callback = function(value)
            local set = {}
            for label in pairs(toSet(value)) do
                local gid = tostring(label):match("%[(.-)%]$")
                if gid then
                    set[gid] = true
                end
            end
            Flags.RefineWeapons = set
        end,
    })
    refreshButton(Refine, "Refresh Weapons", "รีเฟรชรายชื่ออาวุธในกระเป๋า", "RefineWeapons", weaponOptions)

    local RefineBox = RefineTab:AddRightGroupbox({ Name = "Configuration", Icon = "sliders-horizontal" })
    slider(RefineBox, "RefineTarget", "Stop At Level", "หยุดตีบวกเมื่อถึงเลเวลนี้", 1, refineMax(), 1, 4, function(value)
        Flags.RefineTarget = tonumber(value) or Flags.RefineTarget
    end)
    simpleToggle(RefineBox, "RefineSafeOnly", "Only 100% Chance", "ตีบวกเฉพาะตอนที่โอกาสสำเร็จ 100% (เลเวลที่ล้มเหลวแล้วไม่ลดระดับ)", true, function(value)
        Flags.RefineSafeOnly = value == true
    end)
    simpleToggle(RefineBox, "RefineProtect", "Use Protect Stone", "ใช้ Protect Stone กันอาวุธลดเลเวลเมื่อตีบวกพลาด", false, function(value)
        Flags.RefineProtect = value == true
    end)
    simpleToggle(RefineBox, "RefineLucky", "Use Lucky Stone", "ใช้ Lucky Stone เพิ่มโอกาสตีบวกสำเร็จ", false, function(value)
        Flags.RefineLucky = value == true
    end)
    -- Ouroboros ไม่มีช่องพิมพ์ตัวเลข จึงใช้สไลเดอร์แทน (ก้าวละ 1,000)
    slider(RefineBox, "RefineGoldReserve", "Keep Gold Above", "เก็บทองขั้นต่ำไว้ ไม่ใช้ตีบวกถ้าทองจะเหลือน้อยกว่าค่านี้", 0, 1000000, 1000, 0, function(value)
        Flags.RefineGoldReserve = tonumber(value) or 0
    end)
    slider(RefineBox, "RefineDelay", "Delay (s)", "หน่วงเวลาระหว่างการตีบวกแต่ละครั้ง (วินาที)", 0.5, 5, 0.1, 1, function(value)
        Flags.RefineDelay = tonumber(value) or Flags.RefineDelay
    end)

    ------------------------------------------------------------------
    -- SELL
    ------------------------------------------------------------------
    local Sell = SellTab:AddLeftGroupbox({ Name = "Auto Sell", Icon = "coins" })
    featureToggle(Sell, "AutoSell", "Auto Sell", "ขายไอเทมอัตโนมัติ (ไอเทมที่ล็อกไว้และสวมใส่อยู่จะไม่ถูกขาย)")
    statusList(Sell, "Sell Status", function()
        return Game.sellStatus
    end)
    Sell:CreateDropdown({
        Name = "Sell Categories",
        Description = "เลือกหมวดไอเทมที่จะขาย",
        Options = sellKindOptions(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "SellKinds",
        Callback = function(value)
            Flags.SellKinds = toSet(value)
        end,
    })
    Ctl.SellKeep = Sell:CreateDropdown({
        Name = "Never Sell",
        Description = "ไอเทมที่ห้ามขายเด็ดขาด",
        Options = sellItemOptions(),
        MultipleOptions = true,
        CurrentOption = {},
        Flag = "SellKeep",
        Callback = function(value)
            local set = {}
            for label in pairs(toSet(value)) do
                local id = tostring(label):match("%[(.-)%]$")
                if id then
                    set[id] = true
                end
            end
            Flags.SellKeep = set
        end,
    })
    refreshButton(Sell, "Refresh Items", "รีเฟรชรายการไอเทมที่ห้ามขาย", "SellKeep", sellItemOptions)
    simpleToggle(Sell, "SellJunk", "Also Sell Junk", "ขายของขยะ (Junk) ด้วย", true, function(value)
        Flags.SellJunk = value == true
    end)

    local SellBox = SellTab:AddRightGroupbox({ Name = "Configuration", Icon = "sliders-horizontal" })
    SellBox:CreateDropdown({
        Name = "Sell When",
        Description = "เงื่อนไขการขาย: เมื่อกระเป๋าเต็มตาม % หรือขายตามช่วงเวลา",
        Options = { "Bag Full %", "Interval" },
        CurrentOption = "Bag Full %",
        AllowNone = false,
        Flag = "SellTrigger",
        Callback = function(value)
            Flags.SellTrigger = single(value) or "Bag Full %"
        end,
    })
    slider(SellBox, "SellBagPercent", "Bag Full %", "ขายเมื่อกระเป๋าเต็มถึง % นี้", 10, 100, 1, 90, function(value)
        Flags.SellBagPercent = tonumber(value) or Flags.SellBagPercent
    end)
    slider(SellBox, "SellInterval", "Interval (s)", "ขายทุก ๆ กี่วินาที (ใช้เมื่อเลือก Interval)", 10, 900, 1, 120, function(value)
        Flags.SellInterval = tonumber(value) or Flags.SellInterval
    end)
    slider(SellBox, "SellKeepAmount", "Keep Per Item", "เก็บไอเทมแต่ละชนิดไว้กี่ชิ้น ไม่ขายส่วนนี้", 0, 100, 1, 0, function(value)
        Flags.SellKeepAmount = tonumber(value) or 0
    end)
    simpleToggle(SellBox, "SellKeepRefined", "Keep Refined Gear", "ไม่ขายอุปกรณ์ที่ตีบวกแล้ว", true, function(value)
        Flags.SellKeepRefined = value == true
    end)

    ------------------------------------------------------------------
    -- PLAYER
    ------------------------------------------------------------------
    local Movement = PlayerTab:AddLeftGroupbox({ Name = "Movement", Icon = "move" })
    simpleToggle(Movement, "WalkSpeedEnabled", "WalkSpeed", "เปิดใช้ความเร็วการเดินที่กำหนดเอง", false, setWalkSpeedEnabled)
    slider(Movement, "WalkSpeed", "Speed", "ความเร็วการเดิน", 16, 250, 1, 32, setWalkSpeed)
    simpleToggle(Movement, "AlwaysSprint", "Always Sprint", "วิ่งเร็ว (Sprint) ตลอดเวลาโดยไม่ต้องกดค้าง", false, setAlwaysSprint)
    simpleToggle(Movement, "InfJump", "Infinite Jump", "กระโดดกลางอากาศได้ไม่จำกัด", false, setInfJump)
    simpleToggle(Movement, "NoClip", "Noclip", "เดินทะลุกำแพงและวัตถุ", false, setNoClip)
    simpleToggle(Movement, "InstantProximityPrompt", "Instant ProximityPrompt", "กดโต้ตอบ (ProximityPrompt) ได้ทันทีโดยไม่ต้องกดค้าง", false, setInstantProximityPrompt)

    local FlyBox = PlayerTab:AddRightGroupbox({ Name = "Fly", Icon = "plane" })
    simpleToggle(FlyBox, "Fly", "Fly", "บินได้อย่างอิสระ", false, setFly)
    slider(FlyBox, "FlySpeed", "Fly Speed", "ความเร็วในการบิน", 10, 400, 1, 60, setFlySpeed)

    local Teleports = PlayerTab:AddRightGroupbox({ Name = "Teleports", Icon = "map-pin" })
    local selectedZone, selectedNpc = nil, nil
    Teleports:CreateDropdown({
        Name = "Zone",
        Description = "เลือกโซนที่ต้องการวาร์ปไป",
        Options = zoneOptions(),
        CurrentOption = {},
        AllowNone = true,
        Flag = "ZoneTeleport",
        Callback = function(value)
            selectedZone = single(value)
        end,
    })
    Teleports:CreateButton({
        Name = "Teleport To Zone",
        Description = "วาร์ปไปยังโซนที่เลือก",
        Callback = function()
            if not teleportZone(selectedZone) then
                notify("ไม่พบตำแหน่งของโซน")
            end
        end,
    })
    Ctl.NpcTeleport = Teleports:CreateDropdown({
        Name = "NPC",
        Description = "เลือก NPC ที่ต้องการวาร์ปไปหา",
        Options = npcOptions(),
        CurrentOption = {},
        AllowNone = true,
        Flag = "NpcTeleport",
        Callback = function(value)
            selectedNpc = single(value)
        end,
    })
    Teleports:CreateButton({
        Name = "Teleport To NPC",
        Description = "วาร์ปไปหา NPC ที่เลือก",
        Callback = function()
            if not teleportNpc(selectedNpc) then
                notify("ไม่พบตำแหน่งของ NPC")
            end
        end,
    })
    refreshButton(Teleports, "Refresh NPCs", "รีเฟรชรายชื่อ NPC ใหม่", "NpcTeleport", npcOptions)

    local Client = PlayerTab:AddLeftGroupbox({ Name = "Client", Icon = "monitor" })
    simpleToggle(Client, "AutoReconnect", "Auto Reconnect on Kick", "เชื่อมต่อกลับเข้าเกมอัตโนมัติเมื่อถูกเตะหรือหลุด", false, setAutoReconnect)
    simpleToggle(Client, "Disable3DRendering", "Disable 3D Rendering", "ปิดการเรนเดอร์ 3D เพื่อลดการใช้ GPU/CPU (จอจะดำ)", false, setDisable3D)
    simpleToggle(Client, "FpsBoost", "FPS Boost", "ลดเอฟเฟกต์และกราฟิกเพื่อเพิ่ม FPS", false, setFpsBoost)

    ------------------------------------------------------------------
    -- SETTINGS
    ------------------------------------------------------------------
    local Menu = SettingsTab:AddLeftGroupbox({ Name = "Menu", Icon = "monitor" })
    Menu:CreateKeybind({
        Name = "Toggle UI",
        Description = "ปุ่มลัดเปิด/ปิดหน้าต่างเมนู",
        CurrentKeybind = UI_TOGGLE_KEY,
        Flag = "ToggleUIKey",
        Callback = function() end,
        OnChanged = function(key)
            Window:SetKeybind(key)
        end,
    })
    Menu:CreateDropdown({
        Name = "Toggle button",
        Description = "แสดงปุ่มเปิด/ปิดเมนูบนหน้าจอ: เฉพาะมือถือ หรือทั้งมือถือและ PC",
        Options = { "Mobile only", "Mobile & PC" },
        CurrentOption = "Mobile only",
        AllowNone = false,
        Flag = "ToggleButtonPlatform",
        Callback = function(option)
            local choice = single(option)
            Window:SetToggleButtonPlatform(choice == "Mobile & PC" and "Both" or "Mobile")
        end,
    })
    simpleToggle(Menu, "AntiAfk", "Anti AFK", "กันโดนเตะเมื่ออยู่เฉย ๆ (AFK)", true, setAntiAfk)
    Menu:CreateButton({
        Name = "Unload UI",
        Description = "หยุดทุกฟีเจอร์และปิดเมนู",
        Icon = "power",
        Callback = function()
            Library:Confirm({
                Title = "Unload?",
                ConfirmText = "Unload",
                Callback = function()
                    stop()
                    Window:Destroy()
                end,
            })
        end,
    })

    SettingsTab:CreateConfigManager({ Name = "Configs", Side = "Left" })
    SettingsTab:CreateThemeManager({ Name = "Themes", Side = "Right" })

    setAntiAfk(true) -- ค่าเริ่มต้นของ Anti AFK; ถ้ามี config เซฟไว้ LoadAutoload จะทับให้

    -- ต้องเรียกหลังสร้างทุก control เสร็จแล้วเท่านั้น
    Window:LoadAutoload()

    notify("Loaded successfully.", "Success")
end

buildUI()
