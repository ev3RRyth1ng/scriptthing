-- kill previous instance
if _G.__FlightController and _G.__FlightController.stop then
	pcall(_G.__FlightController.stop)
	_G.__FlightController = nil
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local player           = Players.LocalPlayer

-- flight path
local COORDS = {
	Vector3.new(-56, 60, 1131),
	Vector3.new(-56, 60,  1797),
	Vector3.new(-56, 60,  2611),
	Vector3.new(-56, 60,  3310),
	Vector3.new(-56, 60,  4183),
	Vector3.new(-56, 30,  4880),
	Vector3.new(-56, 60,  5737),
	Vector3.new(-56, 60,  7206),
	Vector3.new(-56, 60,  8061),
	Vector3.new(-56, 60,  8616),
	Vector3.new(-56, -358, 9493),
}

local MIN_SPEED, MAX_SPEED = 100, 500
local speed       = 350
local active      = false
local stopped     = false
local connections = {}
local currentBF, currentHumanoid = nil, nil

local function track(conn)
	table.insert(connections, conn)
	return conn
end

-- ================= auto rejoin =================
local rejoinInProgress = false

-- detect the queue function across different executors
local queueFunc =
    (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or (krnl and krnl.queue_on_teleport)
    or (secure_call and queue_on_teleport)
    or queue_on_teleport
    or queueteleport
    or (getgenv and getgenv().queue_on_teleport)

local SCRIPT_URL = "https://raw.githubusercontent.com/ev3RRything/scriptthing/refs/heads/main/script.lua"

local LOADER = ([[
	task.wait(3)
	local ok, err = pcall(function()
		loadstring(game:HttpGet("]] .. SCRIPT_URL .. [["))()
	end)
	if not ok then warn("[af] reload failed:", err) end
]])

-- queue on script load as well, just in case
if queueFunc then
	pcall(queueFunc, LOADER)
end

-- also queue every time a teleport starts — most reliable moment
pcall(function()
	player.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Started and queueFunc then
			pcall(queueFunc, LOADER)
		end
	end)
end)

local function attemptRejoin()
	if rejoinInProgress then return end
	rejoinInProgress = true
	print("[af] rejoin triggered")

	local placeId = game.PlaceId
	local jobId   = game.JobId

	pcall(function()
		if jobId and jobId ~= "" then
			TeleportService:TeleportToPlaceInstance(placeId, jobId)
		else
			TeleportService:Teleport(placeId)
		end
	end)
end

task.spawn(function()
	local CoreGui = game:GetService("CoreGui")
	local ok, promptGui = pcall(function()
		return CoreGui:WaitForChild("RobloxPromptGui", 20)
	end)
	if not ok or not promptGui then return end
	local ok2, overlay = pcall(function()
		return promptGui:WaitForChild("promptOverlay", 20)
	end)
	if not ok2 or not overlay then return end

	local function check(obj)
		if obj:IsA("TextLabel") then
			local txt = obj.Text
			if txt:find("Disconnected")
			or txt:find("Lost connection")
			or txt:find("kicked")
			or txt:find("shutdown")
			or txt:find("connection") then
				attemptRejoin()
			end
		end
	end

	for _, d in ipairs(overlay:GetDescendants()) do
		check(d)
		if d:IsA("TextLabel") then
			d:GetPropertyChangedSignal("Text"):Connect(function() check(d) end)
		end
	end

	overlay.DescendantAdded:Connect(function(d)
		check(d)
		if d:IsA("TextLabel") then
			d:GetPropertyChangedSignal("Text"):Connect(function() check(d) end)
		end
	end)
end)

track(Players.PlayerRemoving:Connect(function(p)
	if p == player then attemptRejoin() end
end))

-- ================= anti-afk =================
local antiAfkEnabled = false

local function pressKey(kc)
	if keypress and keyrelease then
		pcall(function()
			keypress(kc)
			task.wait(0.05)
			keyrelease(kc)
		end)
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:TypeKey(kc, true)
		task.wait(0.05)
		VirtualUser:TypeKey(kc, false)
	end)
end

local function clickMouse(btn)
	if btn == 1 and mouse1click then
		pcall(mouse1click)
		return
	end
	if btn == 2 and mouse2click then
		pcall(mouse2click)
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		if btn == 1 then
			VirtualUser:ClickButton1(Vector2.new(0, 0))
		else
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end
	end)
end

local function antiAfkTick()
	local choice = math.random(1, 6)
	if choice == 1 then pressKey(Enum.KeyCode.W)
	elseif choice == 2 then pressKey(Enum.KeyCode.A)
	elseif choice == 3 then pressKey(Enum.KeyCode.S)
	elseif choice == 4 then pressKey(Enum.KeyCode.D)
	elseif choice == 5 then clickMouse(1)
	else clickMouse(2)
	end
end

local function runAntiAfkLoop()
	while antiAfkEnabled and not stopped do
		antiAfkTick()
		task.wait(10)
	end
end

local function setAntiAfk(state)
	antiAfkEnabled = state
	if state then
		task.spawn(runAntiAfkLoop)
	end
end

-- ================= flight =================
local function flyLoop()
	while active and not stopped do

		local character
		while active and not stopped do
			character = player.Character
			if character and character.Parent then
				local hum = character:FindFirstChildOfClass("Humanoid")
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 then break end
			end
			task.wait(0.1)
		end
		if not active or stopped then break end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp      = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then
			task.wait(0.1)
			continue
		end

		currentHumanoid = humanoid
		humanoid.PlatformStand = true

		local bf = Instance.new("BodyForce")
		bf.Name   = "__GravityCancel"
		bf.Force  = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass, 0)
		bf.Parent = hrp
		currentBF = bf

		pcall(function() character:PivotTo(CFrame.new(COORDS[1])) end)
		hrp.AssemblyLinearVelocity = Vector3.zero

		local function isDead()
			if player.Character ~= character then return true end
			if not character.Parent then return true end
			if not hrp.Parent then return true end
			local h = character:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then return true end
			return false
		end

		for i = 2, #COORDS do
			if not active or stopped or isDead() then break end
			local target = COORDS[i]
			while active and not stopped and not isDead() do
				local diff = target - hrp.Position
				if diff.Magnitude < 3 then break end
				hrp.AssemblyLinearVelocity = diff.Unit * speed
				RunService.Heartbeat:Wait()
			end
		end

		if active and not stopped and not isDead() then
			local finalPos = COORDS[#COORDS]
			while active and not stopped and not isDead() do
				hrp.AssemblyLinearVelocity = (finalPos - hrp.Position) * 10
				RunService.Heartbeat:Wait()
			end
		end

		if bf and bf.Parent then bf:Destroy() end
		if currentBF == bf then currentBF = nil end
		if humanoid and humanoid.Parent then
			pcall(function() humanoid.PlatformStand = false end)
		end
		if hrp and hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end

		task.wait(0.3)
	end
end

-- ================= gui =================
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name           = "af"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = pg

local W, H = 220, 168

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, W, 0, H)
panel.Position         = UDim2.new(0, 20, 0.75, -H / 2)
panel.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
panel.BorderSizePixel  = 0
panel.Parent           = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)

-- header
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position               = UDim2.new(0, 12, 0, 8)
title.Size                   = UDim2.new(1, -80, 0, 14)
title.Font                   = Enum.Font.SourceSans
title.Text                   = "autofly"
title.TextColor3             = Color3.fromRGB(160, 160, 165)
title.TextSize               = 13
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = panel

local speedValue = Instance.new("TextLabel")
speedValue.BackgroundTransparency = 1
speedValue.Position               = UDim2.new(1, -60, 0, 8)
speedValue.Size                   = UDim2.new(0, 48, 0, 14)
speedValue.Font                   = Enum.Font.SourceSans
speedValue.Text                   = tostring(speed)
speedValue.TextColor3             = Color3.fromRGB(200, 200, 205)
speedValue.TextSize               = 13
speedValue.TextXAlignment         = Enum.TextXAlignment.Right
speedValue.Parent                 = panel

-- separator under header
local sep = Instance.new("Frame")
sep.Position         = UDim2.new(0, 12, 0, 26)
sep.Size             = UDim2.new(1, -24, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(50, 50, 54)
sep.BorderSizePixel  = 0
sep.Parent           = panel

-- start/stop button
local toggle = Instance.new("TextButton")
toggle.Position         = UDim2.new(0, 12, 0, 34)
toggle.Size             = UDim2.new(1, -24, 0, 34)
toggle.BackgroundColor3 = Color3.fromRGB(48, 48, 52)
toggle.Text             = "start"
toggle.TextColor3       = Color3.fromRGB(210, 210, 215)
toggle.Font             = Enum.Font.SourceSansBold
toggle.TextSize         = 14
toggle.BorderSizePixel  = 0
toggle.AutoButtonColor  = true
toggle.Parent           = panel

Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)

-- speed label
local speedLabel = Instance.new("TextLabel")
speedLabel.BackgroundTransparency = 1
speedLabel.Position               = UDim2.new(0, 12, 0, 76)
speedLabel.Size                   = UDim2.new(1, -24, 0, 12)
speedLabel.Font                   = Enum.Font.SourceSans
speedLabel.Text                   = "speed"
speedLabel.TextColor3             = Color3.fromRGB(130, 130, 135)
speedLabel.TextSize               = 12
speedLabel.TextXAlignment         = Enum.TextXAlignment.Left
speedLabel.Parent                 = panel

-- slider
local slider = Instance.new("Frame")
slider.Name                   = "Slider"
slider.BackgroundTransparency = 1
slider.Position               = UDim2.new(0, 12, 0, 96)
slider.Size                   = UDim2.new(1, -24, 0, 16)
slider.Parent                 = panel

local trackBar = Instance.new("Frame")
trackBar.Name             = "Track"
trackBar.AnchorPoint      = Vector2.new(0, 0.5)
trackBar.Position         = UDim2.new(0, 0, 0.5, 0)
trackBar.Size             = UDim2.new(1, 0, 0, 4)
trackBar.BackgroundColor3 = Color3.fromRGB(52, 52, 56)
trackBar.BorderSizePixel  = 0
trackBar.Parent           = slider

Instance.new("UICorner", trackBar).CornerRadius = UDim.new(1, 0)

local sliderInitScale = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)

local fill = Instance.new("Frame")
fill.Name             = "Fill"
fill.Size             = UDim2.new(sliderInitScale, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(190, 190, 195)
fill.BorderSizePixel  = 0
fill.Parent           = trackBar

Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local knob = Instance.new("Frame")
knob.Name             = "Knob"
knob.AnchorPoint      = Vector2.new(0.5, 0.5)
knob.Size             = UDim2.new(0, 11, 0, 11)
knob.Position         = UDim2.new(sliderInitScale, 0, 0.5, 0)
knob.BackgroundColor3 = Color3.fromRGB(230, 230, 235)
knob.BorderSizePixel  = 0
knob.Parent           = trackBar

Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

-- anti-afk checkbox
local afkBtn = Instance.new("TextButton")
afkBtn.Name                 = "AfkBtn"
afkBtn.Position             = UDim2.new(0, 12, 0, 124)
afkBtn.Size                 = UDim2.new(1, -24, 0, 28)
afkBtn.BackgroundTransparency = 1
afkBtn.Text                 = ""
afkBtn.TextColor3           = Color3.fromRGB(200, 200, 205)
afkBtn.AutoButtonColor      = false
afkBtn.BorderSizePixel      = 0
afkBtn.Parent               = panel

local afkBox = Instance.new("Frame")
afkBox.Name             = "Box"
afkBox.Position         = UDim2.new(0, 0, 0.5, -7)
afkBox.Size             = UDim2.new(0, 14, 0, 14)
afkBox.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
afkBox.BorderSizePixel  = 0
afkBox.Parent           = afkBtn

Instance.new("UICorner", afkBox).CornerRadius = UDim.new(0, 3)

local afkBoxStroke = Instance.new("UIStroke")
afkBoxStroke.Color        = Color3.fromRGB(80, 80, 85)
afkBoxStroke.Thickness    = 1
afkBoxStroke.Parent       = afkBox

local afkCheck = Instance.new("Frame")
afkCheck.Name             = "Check"
afkCheck.Position         = UDim2.new(0, 3, 0, 3)
afkCheck.Size             = UDim2.new(0, 8, 0, 8)
afkCheck.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
afkCheck.BorderSizePixel  = 0
afkCheck.Visible          = false
afkCheck.Parent           = afkBox

Instance.new("UICorner", afkCheck).CornerRadius = UDim.new(0, 2)

local afkLabel = Instance.new("TextLabel")
afkLabel.BackgroundTransparency = 1
afkLabel.Position               = UDim2.new(0, 22, 0, 0)
afkLabel.Size                   = UDim2.new(1, -22, 1, 0)
afkLabel.Font                   = Enum.Font.SourceSans
afkLabel.Text                   = "anti-afk"
afkLabel.TextColor3             = Color3.fromRGB(180, 180, 185)
afkLabel.TextSize               = 13
afkLabel.TextXAlignment         = Enum.TextXAlignment.Left
afkLabel.Parent                 = afkBtn

-- ================= fade in =================
local fadeProps = {}
for _, obj in ipairs(gui:GetDescendants()) do
	local props = {}
	if obj:IsA("GuiObject") then
		props.BackgroundTransparency = obj.BackgroundTransparency
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		props.TextTransparency       = obj.TextTransparency
		props.TextStrokeTransparency = obj.TextStrokeTransparency
	end
	if obj:IsA("UIStroke") then
		props.Transparency = obj.Transparency
	end
	if next(props) then
		fadeProps[obj] = props
	end
end

local function fadeTo(alpha, duration)
	for obj, props in pairs(fadeProps) do
		if obj.Parent then
			local t = {}
			for k, orig in pairs(props) do
				t[k] = orig + (1 - orig) * alpha
			end
			TweenService:Create(obj,
				TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				t):Play()
		end
	end
end

for obj, props in pairs(fadeProps) do
	for k, _ in pairs(props) do
		obj[k] = 1
	end
end

task.spawn(function()
	task.wait(0.05)
	fadeTo(0, 0.3)
end)

-- ================= panel drag =================
local dragging          = false
local dragTarget        = nil
local dragStartMouse    = nil
local dragStartFramePos = nil

local function isInteractive(obj)
	while obj and obj ~= panel do
		if obj:IsA("GuiButton") then return true end
		if obj.Name == "Slider" then return true end
		obj = obj.Parent
	end
	return false
end

track(panel.InputBegan:Connect(function(input)
	if stopped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		if not isInteractive(input.Target) then
			dragging          = true
			dragStartMouse    = Vector2.new(input.Position.X, input.Position.Y)
			local abs         = panel.AbsolutePosition
			dragStartFramePos = Vector2.new(abs.X, abs.Y)
		end
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if stopped then return end
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = Vector2.new(input.Position.X - dragStartMouse.X,
								  input.Position.Y - dragStartMouse.Y)
		dragTarget  = dragStartFramePos + delta
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

-- ================= slider =================
local sliderTargetScale  = sliderInitScale
local sliderCurrentScale = sliderInitScale
local sliderDragging     = false

local function handleSliderInput(input)
	local absTrack = trackBar.AbsolutePosition
	local size     = trackBar.AbsoluteSize
	if size.X <= 0 then return end
	local rel = (input.Position.X - absTrack.X) / size.X
	sliderTargetScale = math.clamp(rel, 0, 1)
end

track(slider.InputBegan:Connect(function(input)
	if stopped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = true
		handleSliderInput(input)
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if stopped then return end
	if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		handleSliderInput(input)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = false
	end
end))

track(RunService.RenderStepped:Connect(function(dt)
	if stopped then return end

	if dragTarget then
		local cx, cy = panel.Position.X.Offset, panel.Position.Y.Offset
		local vps    = workspace.CurrentCamera.ViewportSize
		local tx     = math.clamp(dragTarget.X, 0, vps.X - W)
		local ty     = math.clamp(dragTarget.Y, 0, vps.Y - H)
		local a      = math.min(dt * 20, 1)
		panel.Position = UDim2.new(0, cx + (tx - cx) * a, 0, cy + (ty - cy) * a)
	end

	local a = math.min(dt * 22, 1)
	sliderCurrentScale = sliderCurrentScale + (sliderTargetScale - sliderCurrentScale) * a
	if math.abs(sliderTargetScale - sliderCurrentScale) < 0.0003 then
		sliderCurrentScale = sliderTargetScale
	end
	knob.Position = UDim2.new(sliderCurrentScale, 0, 0.5, 0)
	fill.Size     = UDim2.new(sliderCurrentScale, 0, 1, 0)

	local newSpeed = math.floor(MIN_SPEED + sliderCurrentScale * (MAX_SPEED - MIN_SPEED) + 0.5)
	if newSpeed ~= speed then
		speed = newSpeed
		speedValue.Text = tostring(speed)
	end
end))

-- ================= start/stop =================
local function setToggleState(isActive)
	active = isActive
	local bg = isActive and Color3.fromRGB(40, 95, 55) or Color3.fromRGB(48, 48, 52)
	TweenService:Create(toggle,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = bg }):Play()
	toggle.Text = isActive and "stop" or "start"
	if isActive then
		task.spawn(flyLoop)
	end
end

track(toggle.MouseButton1Click:Connect(function()
	if stopped then return end
	setToggleState(not active)
end))

-- ================= anti-afk toggle =================
local function setAfkState(state)
	afkCheck.Visible = state
	afkLabel.TextColor3 = state
		and Color3.fromRGB(210, 210, 215)
		or  Color3.fromRGB(180, 180, 185)
	setAntiAfk(state)
end

track(afkBtn.MouseButton1Click:Connect(function()
	if stopped then return end
	setAfkState(not antiAfkEnabled)
end))

-- ================= shutdown =================
local function stop()
	if stopped then return end
	stopped        = true
	active         = false
	antiAfkEnabled = false

	fadeTo(1, 0.25)

	task.delay(0.3, function()
		for _, c in ipairs(connections) do
			if c and c.Connected then
				pcall(function() c:Disconnect() end)
			end
		end
		connections = {}

		if currentHumanoid and currentHumanoid.Parent then
			pcall(function() currentHumanoid.PlatformStand = false end)
		end
		if currentBF and currentBF.Parent then
			pcall(function() currentBF:Destroy() end)
		end
		if player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
			end
		end

		if gui and gui.Parent then
			pcall(function() gui:Destroy() end)
		end
	end)
end

_G.__FlightController = { stop = stop }

-- auto start
task.spawn(function()
	task.wait(0.25)
	if stopped then return end
	setToggleState(true)
end)
