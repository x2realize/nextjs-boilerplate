-- Load Ouroboros UI library
local Library
local ok, result = pcall(function()
	local url = "https://raw.githubusercontent.com/x2realize/Library/refs/heads/main/fetched.lua?cb=" .. tostring(os.time())
	local chunk, compileErr = loadstring(game:HttpGet(url))
	if type(chunk) ~= "function" then
		error("library failed to compile: " .. tostring(compileErr), 0)
	end
	local lib = chunk()
	if type(lib) ~= "table" then
		error("library did not return a table", 0)
	end
	return lib
end)
if not ok then error("failed to load UI library: " .. tostring(result), 0) end
Library = result

-- Services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Aim state.
local State = {
	aim = false,
	showFov = false,
	fovRadius = 250,
}
local target = { position = nil }
local Hooks = {}

-- FOV circle.
local FovGui, FovCircle

local function updateFovSize()
	if FovCircle then
		FovCircle.Size = UDim2.fromOffset(State.fovRadius * 2, State.fovRadius * 2)
		local v = Camera.ViewportSize
		FovCircle.Position = UDim2.fromOffset(v.X / 2 - State.fovRadius, v.Y / 2 - State.fovRadius)
	end
end

local function createFov()
	if FovGui then return end
	FovGui = Instance.new("ScreenGui")
	FovGui.Name = "FOVGui"
	FovGui.ResetOnSpawn = false
	FovGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

	FovCircle = Instance.new("Frame")
	FovCircle.Name = "FOVCircle"
	FovCircle.BackgroundTransparency = 0.9
	FovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	FovCircle.BorderSizePixel = 0
	FovCircle.Parent = FovGui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = FovCircle

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = FovCircle

	updateFovSize()
end

local function destroyFov()
	if FovGui then
		FovGui:Destroy()
		FovGui, FovCircle = nil, nil
	end
end

-- หาเป้าหมายที่ใกล้กลางจอสุดภายใน FOV.
local function getClosestTarget()
	local closestDist = math.huge
	local closestPos = nil
	local viewportSize = Camera.ViewportSize

	if viewportSize.X == 0 or viewportSize.Y == 0 then return nil end

	local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)

	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
			local model = part.Parent
			if model and model ~= LocalPlayer.Character then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
					if onScreen then
						local screenVec = Vector2.new(screenPos.X, screenPos.Y)
						local dist = (screenVec - center).Magnitude
						if dist <= State.fovRadius and dist < closestDist then
							closestDist = dist
							closestPos = part.Position
						end
					end
				end
			end
		end
	end
	return closestPos
end

RunService.Heartbeat:Connect(function()
	if State.aim then
		target.position = getClosestTarget()
	else
		target.position = nil
	end
end)

-- Hook Raycast สำหรับ aim.
pcall(function()
	if hookmetamethod and getnamecallmethod then
		Hooks.Raycast = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local args = { ... }
			local method = getnamecallmethod():lower()

			if State.aim and target.position and method == "raycast" and self == workspace then
				args[2] = (target.position - Camera.CFrame.Position).Unit * 200
				return Hooks.Raycast(self, table.unpack(args))
			end
			return Hooks.Raycast(self, ...)
		end))
	end
end)

-- ESP state.
local DrawingLib = (getgenv and getgenv().Drawing) or Drawing
local HAS_DRAWING = DrawingLib ~= nil and type(DrawingLib.new) == "function"
local Esp = {
	highlight = false,
	highlightColor = Color3.fromRGB(255, 255, 255),
}
local humanoids = {}
local tracked = {}
local errored = false

local function refreshHumanoids()
	local list = {}
	for _, h in ipairs(workspace:GetDescendants()) do
		if h:IsA("Humanoid") then
			local m = h.Parent
			if m and m:IsA("Model") and m ~= LocalPlayer.Character and m:FindFirstChild("HumanoidRootPart") then
				list[m] = h
			end
		end
	end
	humanoids = list
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if Esp.highlight then
			refreshHumanoids()
		end
	end
end)

local function clearEntry(model)
	local e = tracked[model]
	if not e then return end
	if e.hl then e.hl:Destroy() end
	tracked[model] = nil
end

local function updateEsp(model, hum)
	local e = tracked[model]
	if not e then
		e = {}
		tracked[model] = e
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	local alive = root and model.Parent and hum.Health > 0

	if Esp.highlight and alive then
		if not e.hl or not e.hl.Parent then
			e.hl = Instance.new("Highlight")
			e.hl.Name = "ESPHighlight"
			e.hl.FillTransparency = 0.5
			e.hl.OutlineTransparency = 0
			e.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			e.hl.Parent = model
		end
		e.hl.FillColor = Esp.highlightColor
		e.hl.OutlineColor = Esp.highlightColor
	elseif e.hl then
		e.hl:Destroy()
		e.hl = nil
	end
end

RunService.RenderStepped:Connect(function()
	for model, hum in pairs(humanoids) do
		if model.Parent then
			local ok3, err = pcall(updateEsp, model, hum)
			if not ok3 and not errored then
				errored = true
				warn("ESP error: " .. tostring(err))
			end
		else
			clearEntry(model)
			humanoids[model] = nil
		end
	end
	for model in pairs(tracked) do
		if not humanoids[model] then
			clearEntry(model)
		end
	end
end)

-- Movement state.
local Movement = {
	speed = false,
	speedValue = 50,
	highJump = false,
	jumpValue = 100,
	infiniteJump = false,
	noclip = false,
}

RunService.Heartbeat:Connect(function()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if Movement.speed then hum.WalkSpeed = Movement.speedValue end
	if Movement.highJump then hum.JumpPower = Movement.jumpValue end
end)

local infiniteJumpConn
LocalPlayer.CharacterAdded:Connect(function(char)
	if infiniteJumpConn then infiniteJumpConn:Disconnect() end
	local hum = char:WaitForChild("Humanoid")
	infiniteJumpConn = hum.StateChanged:Connect(function(_, new)
		if Movement.infiniteJump and new == Enum.HumanoidStateType.Jumping then
			task.wait(0.15)
			hum:ChangeState(Enum.HumanoidStateType.Landed)
		end
	end)
end)

RunService.Stepped:Connect(function()
	if not Movement.noclip then return end
	local char = LocalPlayer.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end)

-- UI.
local SCRIPT_NAME = "128B!t"
local SCRIPT_VERSION = "v1.0"

Library:SetDefaultTheme("Mono")

local Window = Library:CreateWindow({
	Name            = "128B!t | OFFICIAL",
	LoadingSubtitle = "ONE TAP | v 1.0",
	ToggleUIKeybind = "RightControl",
	Icon            = "rbxassetid://97177675697505",
	ConfigurationSaving = {
		Enabled    = true,
		FolderName = "128BitHub",
		FileName   = "default",
	},
	ToggleButton = { Platform = "Mobile", Icon = "rbxassetid://97177675697505" },
	Home = {
		Title   = "Welcome to " .. SCRIPT_NAME .. "!",
		Tier    = SCRIPT_VERSION,
		Discord = "https://discord.gg/E6ft5s7Ddu",
		Website = "https://128bit.online",
		Stats   = { "Players", "Session", "FPS", "Ping" },
	},
})

-- Tab: Combat.
local CombatTab = Window:Tab({ Name = "Combat", Icon = "crosshair" })

CombatTab:Toggle({
	Name        = "Silent Aim",
	Description = "กระสุนตรงหาเป้า",
	Default     = false,
	Callback    = function(value)
		State.aim = value
	end,
})

CombatTab:Toggle({
	Name        = "Show FOV",
	Description = "เปิด/ปิดวง FOV",
	Default     = false,
	Callback    = function(value)
		State.showFov = value
		if value then createFov() else destroyFov() end
	end,
})

CombatTab:Slider({
	Name        = "FOV Size",
	Description = "ปรับวง FOV",
	Min         = 50,
	Max         = 600,
	Step        = 5,
	Default     = State.fovRadius,
	Suffix      = "px",
	Callback    = function(value)
		State.fovRadius = value
		updateFovSize()
	end,
})

-- Tab: ESP.
local EspTab = Window:Tab({ Name = "Esp", Icon = "eye" })

EspTab:Section("Highlight")
EspTab:Toggle({
	Name        = "ESP Highlight",
	Description = "มอง ผู้เล่น&บอท",
	Default     = false,
	Callback    = function(value)
		Esp.highlight = value
		if value then refreshHumanoids() end
	end,
})
EspTab:ColorPicker({
	Name        = "Highlight Color",
	Description = "เปลี่ยนสีไฮไลท์",
	Default     = Esp.highlightColor,
	Callback    = function(color)
		Esp.highlightColor = color
	end,
})

-- Tab: Movement.
local MoveTab = Window:Tab({ Name = "Movement", Icon = "zap" })

MoveTab:Section("Speed")
MoveTab:Toggle({
	Name        = "Speed Hack",
	Description = "วิ่งเร็ว",
	Default     = false,
	Callback    = function(value)
		Movement.speed = value
		if not value then
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end
	end,
})
MoveTab:Slider({
	Name        = "Walk Speed",
	Description = "ปรับความเร็ว",
	Min         = 16,
	Max         = 500,
	Step        = 1,
	Default     = 50,
	Suffix      = " stud/s",
	Callback    = function(value)
		Movement.speedValue = value
	end,
})

MoveTab:Section("Jump")
MoveTab:Toggle({
	Name        = "High Jump",
	Description = "โดดสูง",
	Default     = false,
	Callback    = function(value)
		Movement.highJump = value
		if not value then
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.JumpPower = 50 end
		end
	end,
})
MoveTab:Slider({
	Name        = "Jump Power",
	Description = "ปรับความสูง",
	Min         = 50,
	Max         = 1000,
	Step        = 10,
	Default     = 100,
	Suffix      = " pw",
	Callback    = function(value)
		Movement.jumpValue = value
	end,
})
MoveTab:Toggle({
	Name        = "Infinite Jump",
	Description = "กระโดดไม่จำกัด",
	Default     = false,
	Callback    = function(value)
		Movement.infiniteJump = value
		if value then
			local char = LocalPlayer.Character
			if char and not infiniteJumpConn then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					infiniteJumpConn = hum.StateChanged:Connect(function(_, new)
						if Movement.infiniteJump and new == Enum.HumanoidStateType.Jumping then
							task.wait(0.15)
							hum:ChangeState(Enum.HumanoidStateType.Landed)
						end
					end)
				end
			end
		end
	end,
})

MoveTab:Section("Noclip")
MoveTab:Toggle({
	Name        = "Noclip",
	Description = "ทะลุกำแพง",
	Default     = false,
	Callback    = function(value)
		Movement.noclip = value
	end,
})
