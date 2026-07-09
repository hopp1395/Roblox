local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local remotes = ReplicatedStorage:WaitForChild("RoadRampageRemotes")
local inputRemote = remotes:WaitForChild("InputChanged")

local worldFolder = workspace:WaitForChild("RoadRampageWorld")
local carsFolder = worldFolder:WaitForChild("Cars")

local currentCarBody = nil
local hud = nil
local statusLabel = nil
local pointsLabel = nil
local speedLabel = nil
local timerLabel = nil

local keyState = {
	forward = false,
	backward = false,
	left = false,
	right = false,
}

local lastPayload = {
	throttle = 99,
	steer = 99,
}

local function buildHud()
	if hud then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoadRampageHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 16)
	title.Size = UDim2.fromOffset(460, 34)
	title.Font = Enum.Font.GothamBold
	title.Text = "Road Rampage"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = screenGui

		statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Position = UDim2.fromOffset(20, 56)
		statusLabel.Size = UDim2.fromOffset(420, 28)
		statusLabel.Font = Enum.Font.GothamSemibold
		statusLabel.Text = "Status: Weiche dem Gegenverkehr aus"
		statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
		statusLabel.TextSize = 22
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = screenGui

		pointsLabel = Instance.new("TextLabel")
		pointsLabel.BackgroundTransparency = 1
		pointsLabel.Position = UDim2.fromOffset(20, 86)
		pointsLabel.Size = UDim2.fromOffset(280, 24)
		pointsLabel.Font = Enum.Font.Gotham
		pointsLabel.Text = "Punkte: 0"
		pointsLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
		pointsLabel.TextSize = 18
		pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
		pointsLabel.Parent = screenGui

		speedLabel = Instance.new("TextLabel")
		speedLabel.BackgroundTransparency = 1
		speedLabel.Position = UDim2.fromOffset(20, 110)
		speedLabel.Size = UDim2.fromOffset(280, 24)
		speedLabel.Font = Enum.Font.Gotham
		speedLabel.Text = "Tempo: 0"
	speedLabel.TextColor3 = Color3.fromRGB(223, 240, 255)
	speedLabel.TextSize = 18
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = screenGui

	timerLabel = Instance.new("TextLabel")
	timerLabel.BackgroundTransparency = 1
	timerLabel.Position = UDim2.fromOffset(20, 134)
	timerLabel.Size = UDim2.fromOffset(280, 28)
	timerLabel.Font = Enum.Font.GothamSemibold
	timerLabel.Text = "Zeit: 00:00:00"
	timerLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	timerLabel.TextSize = 20
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.Parent = screenGui

	local instructions = Instance.new("TextLabel")
	instructions.BackgroundTransparency = 0.2
	instructions.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	instructions.Position = UDim2.new(1, -280, 0, 18)
	instructions.Size = UDim2.fromOffset(250, 90)
	instructions.Font = Enum.Font.Gotham
	instructions.Text = "Weiche dem Gegenverkehr aus.\nKollision = Crash.\nW/S und A/D oder Pfeile: Fahren"
	instructions.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructions.TextSize = 16
	instructions.TextWrapped = true
	instructions.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = instructions

	hud = screenGui
end

local function formatTime(seconds)
	local mm = math.floor(seconds / 60)
	local ss = math.floor(seconds % 60)
	local mi = math.floor((seconds % 1) * 100)
	return string.format("%02d:%02d:%02d", mm, ss, mi)
end

local function updateHud()
	if not statusLabel or not pointsLabel or not speedLabel or not timerLabel then
		return
	end

	if currentCarBody and currentCarBody.Parent then
		local score = currentCarBody:GetAttribute("Score") or 0
		local speed = currentCarBody:GetAttribute("Speed") or 0
		local state = currentCarBody:GetAttribute("GameState") or "Running"
		local statusText = currentCarBody:GetAttribute("StatusText") or "Weiche dem Gegenverkehr aus"
		local elapsed = currentCarBody:GetAttribute("ElapsedTime") or 0
		pointsLabel.Text = string.format("Punkte: %d", score)
		speedLabel.Text = string.format("Tempo: %d", speed)
		timerLabel.Text = string.format("Zeit: %s", formatTime(elapsed))

		if state == "Crashed" then
			statusLabel.Text = statusText
			statusLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
			timerLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
		elseif state == "Finished" then
			statusLabel.Text = statusText
			statusLabel.TextColor3 = Color3.fromRGB(122, 255, 145)
			timerLabel.TextColor3 = Color3.fromRGB(122, 255, 145)
		else
			statusLabel.Text = statusText
			statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
			timerLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
		end
	else
		statusLabel.Text = "Status: Warte auf das Auto"
		statusLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
		pointsLabel.Text = "Punkte: 0"
		speedLabel.Text = "Tempo: 0"
		timerLabel.Text = "Zeit: 00:00:00"
		timerLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	end
end

local function setCurrentCarBody(body)
	currentCarBody = body

	if currentCarBody then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function refreshCurrentCar()
	for _, candidate in ipairs(carsFolder:GetChildren()) do
		if candidate:IsA("Model") then
			local modelOwnerUserId = candidate:GetAttribute("OwnerUserId")
			local body = candidate.PrimaryPart or candidate:FindFirstChild("Body")
			local bodyOwnerUserId = body and body:GetAttribute("OwnerUserId")

			if (modelOwnerUserId == player.UserId or bodyOwnerUserId == player.UserId) and body and body:IsA("BasePart") then
				setCurrentCarBody(body)
				return
			end
		end
	end

	setCurrentCarBody(nil)
end

local function sendInput()
	local payload = {
		throttle = (keyState.forward and 1 or 0) + (keyState.backward and -1 or 0),
		steer = (keyState.right and 1 or 0) + (keyState.left and -1 or 0),
	}

	if payload.throttle == lastPayload.throttle and payload.steer == lastPayload.steer then
		return
	end

	lastPayload = payload
	inputRemote:FireServer(payload)
end

local function updateKeyState(input, isPressed)
	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
		keyState.forward = isPressed
	elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
		keyState.backward = isPressed
	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		keyState.left = isPressed
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		keyState.right = isPressed
	else
		return
	end

	sendInput()
end

buildHud()
refreshCurrentCar()

carsFolder.ChildAdded:Connect(function()
	task.defer(refreshCurrentCar)
end)

carsFolder.ChildRemoved:Connect(function()
	task.defer(refreshCurrentCar)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	updateKeyState(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
	updateKeyState(input, false)
end)

RunService.RenderStepped:Connect(function()
	if not currentCarBody or not currentCarBody.Parent then
		refreshCurrentCar()
	end

	if currentCarBody and currentCarBody.Parent then
		local carCFrame = currentCarBody.CFrame
		local cameraOffset = carCFrame:ToWorldSpace(CFrame.new(0, 10, 24)).Position
		local focusPoint = carCFrame.Position + carCFrame.LookVector * 20 + Vector3.new(0, 3, 0)
		camera.CFrame = CFrame.lookAt(cameraOffset, focusPoint)
	end

	updateHud()
end)
