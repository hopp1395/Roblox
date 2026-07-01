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
local scoreLabel = nil
local speedLabel = nil

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

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Position = UDim2.fromOffset(20, 56)
	scoreLabel.Size = UDim2.fromOffset(280, 28)
	scoreLabel.Font = Enum.Font.GothamSemibold
	scoreLabel.Text = "Treffer: 0"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 236, 143)
	scoreLabel.TextSize = 22
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = screenGui

	speedLabel = Instance.new("TextLabel")
	speedLabel.BackgroundTransparency = 1
	speedLabel.Position = UDim2.fromOffset(20, 86)
	speedLabel.Size = UDim2.fromOffset(280, 24)
	speedLabel.Font = Enum.Font.Gotham
	speedLabel.Text = "Tempo: 0"
	speedLabel.TextColor3 = Color3.fromRGB(223, 240, 255)
	speedLabel.TextSize = 18
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = screenGui

	local instructions = Instance.new("TextLabel")
	instructions.BackgroundTransparency = 0.2
	instructions.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	instructions.Position = UDim2.new(1, -280, 0, 18)
	instructions.Size = UDim2.fromOffset(250, 90)
	instructions.Font = Enum.Font.Gotham
	instructions.Text = "W / Pfeil hoch: Beschleunigen\nS / Pfeil runter: Bremsen\nA/D oder Pfeile: Lenken"
	instructions.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructions.TextSize = 16
	instructions.TextWrapped = true
	instructions.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = instructions

	hud = screenGui
end

local function getScore()
	local leaderstats = player:FindFirstChild("leaderstats")
	local hits = leaderstats and leaderstats:FindFirstChild("Hits")
	return hits and hits.Value or 0
end

local function updateHud()
	if not scoreLabel or not speedLabel then
		return
	end

	scoreLabel.Text = string.format("Treffer: %d", getScore())

	if currentCarBody and currentCarBody.Parent then
		local speed = currentCarBody:GetAttribute("Speed") or 0
		speedLabel.Text = string.format("Tempo: %d", speed)
	else
		speedLabel.Text = "Tempo: 0"
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
