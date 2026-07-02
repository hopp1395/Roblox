local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local existingRemotes = ReplicatedStorage:FindFirstChild("RoadRampageRemotes")
if existingRemotes then
	existingRemotes:Destroy()
end

local existingWorld = workspace:FindFirstChild("RoadRampageWorld")
if existingWorld then
	existingWorld:Destroy()
end

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "RoadRampageRemotes"
remotesFolder.Parent = ReplicatedStorage

local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name = "InputChanged"
inputRemote.Parent = remotesFolder

local worldFolder = Instance.new("Folder")
worldFolder.Name = "RoadRampageWorld"
worldFolder.Parent = workspace

local lanesFolder = Instance.new("Folder")
lanesFolder.Name = "Lanes"
lanesFolder.Parent = worldFolder

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = worldFolder

local stagingPad = Instance.new("Part")
stagingPad.Name = "CharacterPad"
stagingPad.Anchored = true
stagingPad.CanCollide = true
stagingPad.Transparency = 1
stagingPad.Size = Vector3.new(128, 1, 128)
stagingPad.Position = Vector3.new(0, -40, 0)
stagingPad.Parent = worldFolder

local cityFloor = Instance.new("Part")
cityFloor.Name = "CityFloor"
cityFloor.Anchored = true
cityFloor.CanCollide = false
cityFloor.Material = Enum.Material.Slate
cityFloor.Color = Color3.fromRGB(27, 30, 40)
cityFloor.Size = Vector3.new(4096, 1, 8192)
cityFloor.Position = Vector3.new(0, GameConfig.WORLD_FLOOR_Y - 1, 2048)
cityFloor.Parent = worldFolder

local cityGlow = Instance.new("Part")
cityGlow.Name = "CityGlow"
cityGlow.Anchored = true
cityGlow.CanCollide = false
cityGlow.Material = Enum.Material.Neon
cityGlow.Color = Color3.fromRGB(74, 197, 255)
cityGlow.Transparency = 0.82
cityGlow.Size = Vector3.new(2300, 1, 7600)
cityGlow.Position = Vector3.new(0, GameConfig.WORLD_FLOOR_Y - 0.7, 2048)
cityGlow.Parent = worldFolder

local skylineColors = {
	Color3.fromRGB(62, 80, 122),
	Color3.fromRGB(92, 53, 131),
	Color3.fromRGB(44, 126, 154),
}

local obstacleTemplates = {
	{
		name = "CargoCrate",
		size = Vector3.new(12, 7, 5),
		color = Color3.fromRGB(78, 86, 104),
		material = Enum.Material.Metal,
		label = "CARGO",
	},
	{
		name = "QuarantineBarrier",
		size = Vector3.new(14, 9, 3),
		color = Color3.fromRGB(223, 117, 64),
		material = Enum.Material.Metal,
		label = "BLOCK",
	},
	{
		name = "PowerNode",
		size = Vector3.new(10, 8, 4),
		color = Color3.fromRGB(109, 66, 190),
		material = Enum.Material.SmoothPlastic,
		label = "GRID",
	},
}

local bonusTemplates = {
	{
		name = "EnergyCell",
		points = 3,
		color = Color3.fromRGB(70, 208, 255),
		size = Vector3.new(3, 5, 3),
		material = Enum.Material.Metal,
		label = "+3 Akku",
	},
	{
		name = "RepairKit",
		points = 5,
		color = Color3.fromRGB(255, 187, 74),
		size = Vector3.new(4, 2, 1),
		material = Enum.Material.Metal,
		label = "+5 Toolkit",
	},
}

local districtThemes = {
	{
		maxProgress = 0.24,
		name = "NEON QUARTER",
		signTexts = { "GRID A", "CORE RUN", "NEON LOOP", "KEEP MOVING" },
		primaryColor = Color3.fromRGB(92, 233, 255),
		secondaryColor = Color3.fromRGB(255, 111, 78),
		facadeColor = Color3.fromRGB(46, 58, 86),
		glowColor = Color3.fromRGB(115, 240, 255),
	},
	{
		maxProgress = 0.5,
		name = "TRANSIT RING",
		signTexts = { "STATION 7", "POWER LANE", "SKY LOOP", "SAFE ROUTE" },
		primaryColor = Color3.fromRGB(123, 255, 151),
		secondaryColor = Color3.fromRGB(76, 154, 255),
		facadeColor = Color3.fromRGB(34, 64, 65),
		glowColor = Color3.fromRGB(150, 255, 193),
	},
	{
		maxProgress = 0.76,
		name = "INDUSTRIAL BELT",
		signTexts = { "COOLANT", "TURBINE", "REPAIR BAY", "MAINTAIN" },
		primaryColor = Color3.fromRGB(255, 184, 87),
		secondaryColor = Color3.fromRGB(255, 108, 108),
		facadeColor = Color3.fromRGB(71, 58, 52),
		glowColor = Color3.fromRGB(255, 215, 132),
	},
	{
		maxProgress = 1,
		name = "EVAC CORRIDOR",
		signTexts = { "EVAC", "LAST MILE", "CITY GATE", "DO NOT STOP" },
		primaryColor = Color3.fromRGB(255, 96, 126),
		secondaryColor = Color3.fromRGB(255, 231, 117),
		facadeColor = Color3.fromRGB(58, 36, 52),
		glowColor = Color3.fromRGB(255, 151, 184),
	},
}

local lanes = {}
local playerStates = {}
local nextLaneIndex = 0
local nextObstacleId = 0
local nextBonusId = 0

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function getDistrictTheme(zPosition)
	local progress = math.clamp(zPosition / GameConfig.FINISH_LINE_Z, 0, 1)

	for _, theme in ipairs(districtThemes) do
		if progress <= theme.maxProgress then
			return theme
		end
	end

	return districtThemes[#districtThemes]
end

local function createPart(properties)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(properties) do
		part[key] = value
	end

	return part
end

local function replaceLightingInstance(name, className, properties)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name

	for key, value in pairs(properties) do
		instance[key] = value
	end

	instance.Parent = Lighting
	return instance
end

local function replaceTerrainInstance(name, className, properties)
	local terrain = workspace.Terrain
	local existing = terrain:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name

	for key, value in pairs(properties) do
		instance[key] = value
	end

	instance.Parent = terrain
	return instance
end

local function configurePresentation()
	Lighting.Brightness = 2.8
	Lighting.ClockTime = 17.35
	Lighting.Ambient = Color3.fromRGB(92, 101, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(124, 138, 160)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.45

	replaceLightingInstance("RoadRampageAtmosphere", "Atmosphere", {
		Color = Color3.fromRGB(206, 224, 255),
		Decay = Color3.fromRGB(255, 171, 123),
		Density = 0.32,
		Glare = 0.18,
		Haze = 1.4,
		Offset = 0.15,
	})

	replaceLightingInstance("RoadRampageBloom", "BloomEffect", {
		Intensity = 0.28,
		Size = 30,
		Threshold = 1.1,
	})

	replaceLightingInstance("RoadRampageColor", "ColorCorrectionEffect", {
		Brightness = 0.04,
		Contrast = 0.08,
		Saturation = 0.2,
		TintColor = Color3.fromRGB(255, 244, 228),
	})

	replaceLightingInstance("RoadRampageSunRays", "SunRaysEffect", {
		Intensity = 0.07,
		Spread = 0.74,
	})

	replaceTerrainInstance("RoadRampageClouds", "Clouds", {
		Color = Color3.fromRGB(255, 245, 240),
		Cover = 0.28,
		Density = 0.55,
	})
end

local function addSurfaceLabel(part, face, text, accentColor)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = face
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 34
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = accentColor
	label.TextScaled = true
	label.Parent = surfaceGui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(14, 14, 18)
	stroke.Thickness = 2
	stroke.Parent = label
end

local function createRoadsideLamp(parent, name, basePosition, direction, accentColor)
	createPart({
		Name = name .. "_Pole",
		Size = Vector3.new(1.2, 16, 1.2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(72, 76, 86),
		CanCollide = false,
		Position = basePosition + Vector3.new(0, 8, 0),
		Parent = parent,
	})

	createPart({
		Name = name .. "_Arm",
		Size = Vector3.new(4.5, 0.7, 0.7),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(92, 96, 108),
		CanCollide = false,
		Position = basePosition + Vector3.new(direction * 1.8, 15.1, 0),
		Parent = parent,
	})

	local lamp = createPart({
		Name = name .. "_Lamp",
		Size = Vector3.new(1.8, 1, 1.8),
		Material = Enum.Material.Neon,
		Color = accentColor,
		CanCollide = false,
		Position = basePosition + Vector3.new(direction * 3.5, 14.2, 0),
		Parent = parent,
	})

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1.2
	pointLight.Color = accentColor
	pointLight.Range = 18
	pointLight.Parent = lamp
end

local function createRoadsideSign(parent, name, basePosition, direction, text, accentColor)
	createPart({
		Name = name .. "_Pole",
		Size = Vector3.new(1.2, 12, 1.2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(78, 78, 82),
		CanCollide = false,
		Position = basePosition + Vector3.new(0, 6, 0),
		Parent = parent,
	})

	local sign = createPart({
		Name = name .. "_Board",
		Size = Vector3.new(11, 5.6, 0.8),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(20, 22, 28),
		CanCollide = false,
		CFrame = CFrame.lookAt(
			basePosition + Vector3.new(0, 12, 0),
			basePosition + Vector3.new(-direction * 18, 12, 0)
		),
		Parent = parent,
	})

	addSurfaceLabel(sign, Enum.NormalId.Front, text, accentColor)
	addSurfaceLabel(sign, Enum.NormalId.Back, text, accentColor)

	createPart({
		Name = name .. "_Accent",
		Size = Vector3.new(11.8, 0.45, 1.2),
		Material = Enum.Material.Neon,
		Color = accentColor,
		CanCollide = false,
		CFrame = sign.CFrame * CFrame.new(0, 3.1, 0),
		Parent = parent,
	})
end

local function createFacadeBlock(parent, name, centerPosition, size, theme, isContainer)
	local base = createPart({
		Name = name,
		Size = size,
		Material = isContainer and Enum.Material.Metal or Enum.Material.SmoothPlastic,
		Color = theme.facadeColor,
		CanCollide = false,
		Position = centerPosition,
		Parent = parent,
	})

	createPart({
		Name = name .. "_GlowBand",
		Size = Vector3.new(size.X - 4, 1, size.Z - 6),
		Material = Enum.Material.Neon,
		Color = theme.glowColor,
		CanCollide = false,
		Position = centerPosition + Vector3.new(0, size.Y * 0.5 - 3, 0),
		Parent = parent,
	})

	createPart({
		Name = name .. "_Roof",
		Size = Vector3.new(size.X + 2, 0.8, size.Z + 2),
		Material = Enum.Material.Metal,
		Color = theme.secondaryColor,
		CanCollide = false,
		Position = centerPosition + Vector3.new(0, size.Y * 0.5 + 0.6, 0),
		Parent = parent,
	})

	return base
end

local function createArrowMarker(parent, name, basePosition, direction, theme)
	createPart({
		Name = name .. "_Pole",
		Size = Vector3.new(1, 10, 1),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(78, 78, 88),
		CanCollide = false,
		Position = basePosition + Vector3.new(0, 5, 0),
		Parent = parent,
	})

	local arrow = createPart({
		Name = name .. "_Arrow",
		Size = Vector3.new(9, 3, 0.8),
		Material = Enum.Material.Neon,
		Color = theme.primaryColor,
		CanCollide = false,
		CFrame = CFrame.lookAt(
			basePosition + Vector3.new(0, 10.5, 0),
			basePosition + Vector3.new(-direction * 18, 10.5, 0)
		),
		Parent = parent,
	})

	addSurfaceLabel(arrow, Enum.NormalId.Front, direction < 0 and "<<" or ">>", theme.secondaryColor)
	addSurfaceLabel(arrow, Enum.NormalId.Back, direction < 0 and "<<" or ">>", theme.secondaryColor)
end

local function createSkyline()
	local skylineFolder = Instance.new("Folder")
	skylineFolder.Name = "Skyline"
	skylineFolder.Parent = worldFolder

	createPart({
		Name = "HorizonWall",
		Size = Vector3.new(2800, 180, 40),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(17, 20, 28),
		CanCollide = false,
		Position = Vector3.new(0, 90, 3980),
		Parent = skylineFolder,
	})

	for sideIndex, direction in ipairs({ -1, 1 }) do
		for buildingIndex = 0, 8 do
			local height = 42 + (buildingIndex % 4) * 14
			local width = 40 + (buildingIndex % 3) * 10
			local z = 340 + buildingIndex * 360
			local x = direction * (260 + sideIndex * 120 + (buildingIndex % 2) * 45)
			local building = createPart({
				Name = string.format("Tower_%d_%d", direction, buildingIndex),
				Size = Vector3.new(width, height, 60),
				Material = Enum.Material.SmoothPlastic,
				Color = skylineColors[(buildingIndex % #skylineColors) + 1],
				CanCollide = false,
				Position = Vector3.new(x, GameConfig.WORLD_FLOOR_Y + height * 0.5, z),
				Parent = skylineFolder,
			})

			createPart({
				Name = string.format("TowerGlow_%d_%d", direction, buildingIndex),
				Size = Vector3.new(width - 8, 1, 48),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(120, 225, 255),
				CanCollide = false,
				Position = building.Position + Vector3.new(0, height * 0.5 - 4, 0),
				Parent = skylineFolder,
			})

			for windowIndex = 0, 2 do
				createPart({
					Name = string.format("TowerWindows_%d_%d_%d", direction, buildingIndex, windowIndex),
					Size = Vector3.new(width - 12, 1.2, 8),
					Material = Enum.Material.Neon,
					Color = buildingIndex % 2 == 0 and Color3.fromRGB(255, 198, 118) or Color3.fromRGB(108, 232, 255),
					CanCollide = false,
					Position = building.Position + Vector3.new(0, -height * 0.2 + windowIndex * (height * 0.22), 0),
					Parent = skylineFolder,
				})
			end

			createPart({
				Name = string.format("TowerBeacon_%d_%d", direction, buildingIndex),
				Size = Vector3.new(4, 4, 4),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 82, 109),
				CanCollide = false,
				Position = building.Position + Vector3.new(0, height * 0.5 + 2.5, 0),
				Parent = skylineFolder,
			})
		end
	end
end

configurePresentation()
createSkyline()

local function hideCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	if rootPart then
		rootPart.CFrame = stagingPad.CFrame + Vector3.new(0, 5, 0)
	end
end

local function buildRoadSegment(lane, segmentIndex)
	local segmentLength = GameConfig.ROAD_SEGMENT_LENGTH
	local centerZ = segmentIndex * segmentLength + segmentLength * 0.5
	local theme = getDistrictTheme(math.max(centerZ, 0))
	local segmentFolder = Instance.new("Folder")
	segmentFolder.Name = string.format("Segment_%d", segmentIndex)
	segmentFolder.Parent = lane.folder

	local road = createPart({
		Name = string.format("Road_%d", segmentIndex),
		Size = Vector3.new(GameConfig.ROAD_WIDTH, 1, segmentLength),
		Material = Enum.Material.Asphalt,
		Color = Color3.fromRGB(38, 38, 44),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y, centerZ),
		Parent = segmentFolder,
	})

	local shoulderWidth = 4
	local shoulderOffset = GameConfig.ROAD_WIDTH * 0.5 + shoulderWidth * 0.5
	local shoulderColor = theme.secondaryColor

	for _, direction in ipairs({ -1, 1 }) do
		createPart({
			Name = string.format("Sidewalk_%d_%d", segmentIndex, direction),
			Size = Vector3.new(8, 1.02, segmentLength),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(64, 66, 74),
			Position = Vector3.new(
				lane.xOffset + direction * (GameConfig.ROAD_WIDTH * 0.5 + 10),
				GameConfig.WORLD_FLOOR_Y + 0.01,
				centerZ
			),
			Parent = segmentFolder,
		})

		createPart({
			Name = string.format("Shoulder_%d_%d", segmentIndex, direction),
			Size = Vector3.new(shoulderWidth, 1.05, segmentLength),
			Material = Enum.Material.Neon,
			Color = shoulderColor,
			Position = Vector3.new(lane.xOffset + direction * shoulderOffset, GameConfig.WORLD_FLOOR_Y + 0.03, centerZ),
			Parent = segmentFolder,
		})

		createPart({
			Name = string.format("Rumble_%d_%d", segmentIndex, direction),
			Size = Vector3.new(2.4, 1.04, segmentLength),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(206, 54, 54),
			Position = Vector3.new(
				lane.xOffset + direction * (GameConfig.ROAD_WIDTH * 0.5 - 1.2),
				GameConfig.WORLD_FLOOR_Y + 0.025,
				centerZ
			),
			Parent = segmentFolder,
		})

		createPart({
			Name = string.format("Rail_%d_%d", segmentIndex, direction),
			Size = Vector3.new(1.4, 2.2, segmentLength),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(186, 193, 205),
			CanCollide = false,
			Position = Vector3.new(
				lane.xOffset + direction * (GameConfig.ROAD_WIDTH * 0.5 + 7.4),
				GameConfig.WORLD_FLOOR_Y + 1.2,
				centerZ
			),
			Parent = segmentFolder,
		})
	end

	createPart({
		Name = string.format("DistrictGlow_%d", segmentIndex),
		Size = Vector3.new(GameConfig.ROAD_WIDTH - 10, 0.16, segmentLength - 10),
		Material = Enum.Material.Neon,
		Color = theme.primaryColor,
		Transparency = 0.92,
		CanCollide = false,
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.09, centerZ),
		Parent = segmentFolder,
	})

	local dashLength = 18
	local dashGap = 18
	local dashCount = math.floor(segmentLength / (dashLength + dashGap))
	local startZ = centerZ - segmentLength * 0.5 + 22

	for dashIndex = 0, dashCount do
		createPart({
			Name = string.format("Dash_%d_%d", segmentIndex, dashIndex),
			Size = Vector3.new(1, 1.08, dashLength),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 255, 255),
			Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.05, startZ + dashIndex * (dashLength + dashGap)),
			Parent = segmentFolder,
		})
	end

	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = string.format("Scenery_%d", segmentIndex)
	sceneryFolder.Parent = segmentFolder

	local scenicOffset = GameConfig.ROAD_WIDTH * 0.5 + 13
	local scenicStartZ = centerZ - segmentLength * 0.5 + 52

	for decoIndex = 0, 1 do
		local decoZ = scenicStartZ + decoIndex * 96
		local accentColor = decoIndex % 2 == 0 and theme.primaryColor or theme.secondaryColor
		local signDirection = decoIndex % 2 == 0 and -1 or 1
		local facadeDirection = -signDirection
		local facadeHeight = 20 + ((segmentIndex + decoIndex) % 3) * 8
		local facadeDepth = 28 + ((segmentIndex + decoIndex) % 2) * 12

		createRoadsideLamp(
			sceneryFolder,
			string.format("LampL_%d_%d", segmentIndex, decoIndex),
			Vector3.new(lane.xOffset - scenicOffset, GameConfig.WORLD_FLOOR_Y, decoZ),
			1,
			accentColor
		)

		createRoadsideLamp(
			sceneryFolder,
			string.format("LampR_%d_%d", segmentIndex, decoIndex),
			Vector3.new(lane.xOffset + scenicOffset, GameConfig.WORLD_FLOOR_Y, decoZ + 28),
			-1,
			accentColor
		)

		createRoadsideSign(
			sceneryFolder,
			string.format("Sign_%d_%d", segmentIndex, decoIndex),
			Vector3.new(lane.xOffset + signDirection * (scenicOffset + 8), GameConfig.WORLD_FLOOR_Y, decoZ + 44),
			signDirection,
			theme.signTexts[((segmentIndex + decoIndex) % #theme.signTexts) + 1],
			accentColor
		)

		createFacadeBlock(
			sceneryFolder,
			string.format("Facade_%d_%d", segmentIndex, decoIndex),
			Vector3.new(
				lane.xOffset + facadeDirection * (GameConfig.ROAD_WIDTH * 0.5 + 33),
				GameConfig.WORLD_FLOOR_Y + facadeHeight * 0.5,
				decoZ + 14
			),
			Vector3.new(18 + decoIndex * 6, facadeHeight, facadeDepth),
			theme,
			theme.name == "INDUSTRIAL BELT"
		)

		if theme.name == "EVAC CORRIDOR" then
			createArrowMarker(
				sceneryFolder,
				string.format("Arrow_%d_%d", segmentIndex, decoIndex),
				Vector3.new(lane.xOffset + signDirection * (GameConfig.ROAD_WIDTH * 0.5 + 19), GameConfig.WORLD_FLOOR_Y, decoZ + 12),
				signDirection,
				theme
			)
		end
	end

	createRoadsideSign(
		sceneryFolder,
		string.format("DistrictMarker_%d", segmentIndex),
		Vector3.new(lane.xOffset - (GameConfig.ROAD_WIDTH * 0.5 + 24), GameConfig.WORLD_FLOOR_Y, centerZ + 8),
		-1,
		theme.name,
		theme.primaryColor
	)

	road.Parent = segmentFolder
end

local function createCheckpointLine(lane, name, lineZ, color, text)
	local checkpointFolder = Instance.new("Folder")
	checkpointFolder.Name = name
	checkpointFolder.Parent = lane.folder

	local isFinishLine = name == "FinishLine"

	local line = createPart({
		Name = name .. "_Line",
		Size = Vector3.new(GameConfig.ROAD_WIDTH, 1.15, 6),
		Material = isFinishLine and Enum.Material.SmoothPlastic or Enum.Material.Neon,
		Color = color,
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.08, lineZ),
		Parent = checkpointFolder,
	})

	local postOffset = GameConfig.ROAD_WIDTH * 0.5 + 2
	for _, direction in ipairs({ -1, 1 }) do
		createPart({
			Name = string.format("%s_Post_%d", name, direction),
			Size = Vector3.new(2, isFinishLine and 24 or 14, 2),
			Material = isFinishLine and Enum.Material.Neon or Enum.Material.Metal,
			Color = isFinishLine and color or Color3.fromRGB(230, 230, 230),
			Position = Vector3.new(lane.xOffset + direction * postOffset, GameConfig.WORLD_FLOOR_Y + (isFinishLine and 12 or 7), lineZ),
			Parent = checkpointFolder,
		})
	end

	local banner = createPart({
		Name = name .. "_Banner",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 8, isFinishLine and 6 or 3, 1),
		Material = isFinishLine and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(25, 25, 25),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + (isFinishLine and 22 or 13), lineZ),
		Parent = checkpointFolder,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 24
	surfaceGui.Parent = banner

	local backSurfaceGui = Instance.new("SurfaceGui")
	backSurfaceGui.Face = Enum.NormalId.Back
	backSurfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	backSurfaceGui.PixelsPerStud = 24
	backSurfaceGui.Parent = banner

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = surfaceGui

	local backLabel = label:Clone()
	backLabel.Parent = backSurfaceGui

	if isFinishLine then
		local stripeCount = 12
		local stripeWidth = GameConfig.ROAD_WIDTH / stripeCount

		for stripeIndex = 0, stripeCount - 1 do
			createPart({
				Name = string.format("%s_Stripe_%d", name, stripeIndex),
				Size = Vector3.new(stripeWidth, 1.2, 6),
				Material = Enum.Material.SmoothPlastic,
				Color = stripeIndex % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(35, 35, 35),
				Position = Vector3.new(
					lane.xOffset - GameConfig.ROAD_WIDTH * 0.5 + stripeWidth * 0.5 + stripeIndex * stripeWidth,
					GameConfig.WORLD_FLOOR_Y + 0.12,
					lineZ
				),
				Parent = checkpointFolder,
			})
		end

		createPart({
			Name = "FinishMarker",
			Size = Vector3.new(GameConfig.ROAD_WIDTH + 18, 1, 18),
			Material = Enum.Material.Neon,
			Color = color,
			Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 0.18, lineZ),
			Parent = checkpointFolder,
		})
	end

	line.Parent = checkpointFolder
end

local function createRoadEndBarrier(lane)
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "RoadEnd"
	barrierFolder.Parent = lane.folder

	createPart({
		Name = "Barrier",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 18, 16, 6),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(102, 20, 36),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 8, GameConfig.TRACK_END_Z + 3),
		Parent = barrierFolder,
	})

	createPart({
		Name = "BarrierTop",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 22, 1.4, 7),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 226, 107),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 16.4, GameConfig.TRACK_END_Z + 3),
		Parent = barrierFolder,
	})

	local sealSign = createPart({
		Name = "SealSign",
		Size = Vector3.new(26, 6, 1),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(18, 18, 24),
		CanCollide = false,
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 8, GameConfig.TRACK_END_Z - 0.8),
		Parent = barrierFolder,
	})

	addSurfaceLabel(sealSign, Enum.NormalId.Front, "CITY SEALED", Color3.fromRGB(255, 118, 146))
	addSurfaceLabel(sealSign, Enum.NormalId.Back, "CITY SEALED", Color3.fromRGB(255, 118, 146))
end

local function createStartHub(lane)
	local startFolder = Instance.new("Folder")
	startFolder.Name = "StartHub"
	startFolder.Parent = lane.folder

	createPart({
		Name = "StartPad",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 18, 0.8, 34),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(34, 38, 52),
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y - 0.08, 6),
		Parent = startFolder,
	})

	for _, direction in ipairs({ -1, 1 }) do
		createPart({
			Name = string.format("HubTower_%d", direction),
			Size = Vector3.new(8, 22, 8),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(52, 58, 74),
			CanCollide = false,
			Position = Vector3.new(lane.xOffset + direction * (GameConfig.ROAD_WIDTH * 0.5 + 10), GameConfig.WORLD_FLOOR_Y + 11, 10),
			Parent = startFolder,
		})
	end

	local commandBanner = createPart({
		Name = "CommandBanner",
		Size = Vector3.new(GameConfig.ROAD_WIDTH + 12, 4, 1),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(84, 214, 255),
		CanCollide = false,
		Position = Vector3.new(lane.xOffset, GameConfig.WORLD_FLOOR_Y + 18, 10),
		Parent = startFolder,
	})

	addSurfaceLabel(commandBanner, Enum.NormalId.Front, "BLACKOUT RESPONSE HUB", Color3.fromRGB(255, 239, 173))
	addSurfaceLabel(commandBanner, Enum.NormalId.Back, "BLACKOUT RESPONSE HUB", Color3.fromRGB(255, 239, 173))
end

local function ensureRoadAhead(lane, carZ)
	local maxSegment = math.ceil(GameConfig.TRACK_END_Z / GameConfig.ROAD_SEGMENT_LENGTH) - 1
	local targetSegment = math.floor((carZ + GameConfig.ROAD_LOOKAHEAD) / GameConfig.ROAD_SEGMENT_LENGTH)
	targetSegment = math.min(targetSegment, maxSegment)

	while lane.lastSegmentIndex < targetSegment do
		lane.lastSegmentIndex += 1
		buildRoadSegment(lane, lane.lastSegmentIndex)
	end
end

local function createObstaclePart(lane, obstacleZ)
	nextObstacleId += 1

	local template = obstacleTemplates[math.random(1, #obstacleTemplates)]
	local usableHalfWidth = GameConfig.ROAD_WIDTH * 0.5 - GameConfig.OBSTACLE_SIDE_MARGIN
	local localX = math.random(-usableHalfWidth * 10, usableHalfWidth * 10) / 10
	local part = Instance.new("Part")
	part.Name = string.format("%s_%d", template.name, nextObstacleId)
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = template.size
	part.Color = template.color
	part.Material = template.material
	part.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5,
		obstacleZ
	)

	part.Parent = lane.obstaclesFolder

	local stripe = createPart({
		Name = string.format("%s_Stripe", part.Name),
		Size = Vector3.new(template.size.X + 0.2, 0.8, template.size.Z + 0.2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 224, 112),
		CanCollide = false,
		CFrame = part.CFrame * CFrame.new(0, template.size.Y * 0.5 - 0.7, 0),
		Parent = lane.obstaclesFolder,
	})

	addSurfaceLabel(part, Enum.NormalId.Front, template.label, Color3.fromRGB(245, 248, 255))
	addSurfaceLabel(part, Enum.NormalId.Back, template.label, Color3.fromRGB(245, 248, 255))

	local obstacle = {
		id = nextObstacleId,
		lane = lane,
		localX = localX,
		worldX = lane.xOffset + localX,
		z = obstacleZ,
		part = part,
		extraParts = { stripe },
		halfWidth = template.size.X * 0.5,
		halfLength = template.size.Z * 0.5,
	}

	lane.obstacles[nextObstacleId] = obstacle
end

local function addPoint(state, amount)
	state.score += amount
	state.hits.Value = state.score
	state.body:SetAttribute("Score", state.score)
end

local function createBonusItem(lane, bonusZ)
	nextBonusId += 1

	local template = bonusTemplates[math.random(1, #bonusTemplates)]
	local usableHalfWidth = GameConfig.ROAD_WIDTH * 0.5 - GameConfig.OBSTACLE_SIDE_MARGIN - 2
	local localX = math.random(-usableHalfWidth * 10, usableHalfWidth * 10) / 10

	local model = Instance.new("Model")
	model.Name = string.format("%s_%d", template.name, nextBonusId)
	model:SetAttribute("IsBonus", true)
	model:SetAttribute("BonusId", nextBonusId)
	model.Parent = lane.bonusFolder

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Size = template.size
	body.Color = template.color
	body.Material = template.material
	body.Parent = model

	if template.name == "EnergyCell" then
		local cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Anchored = true
		cap.CanCollide = false
		cap.Size = Vector3.new(1, 1.5, 1)
		cap.Color = Color3.fromRGB(40, 40, 40)
		cap.Material = Enum.Material.Metal
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth
		cap.Parent = model
		cap.CFrame = CFrame.new(
			lane.xOffset + localX,
			GameConfig.WORLD_FLOOR_Y + template.size.Y + 0.75,
			bonusZ
		)
	elseif template.name == "RepairKit" then
		local head1 = Instance.new("Part")
		head1.Name = "Head1"
		head1.Anchored = true
		head1.CanCollide = false
		head1.Size = Vector3.new(2.5, 2.5, 1)
		head1.Color = template.color
		head1.Material = Enum.Material.Metal
		head1.TopSurface = Enum.SurfaceType.Smooth
		head1.BottomSurface = Enum.SurfaceType.Smooth
		head1.Parent = model
		head1.CFrame = CFrame.new(
			lane.xOffset + localX + 2.8,
			GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
			bonusZ
		)

		local head2 = head1:Clone()
		head2.Name = "Head2"
		head2.CFrame = CFrame.new(
			lane.xOffset + localX - 2.8,
			GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
			bonusZ
		)
		head2.Parent = model
	end

	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = Vector3.new(template.size.X + 3, 0.3, template.size.X + 3)
	glow.Shape = Enum.PartType.Cylinder
	glow.Color = template.color
	glow.Material = Enum.Material.Neon
	glow.TopSurface = Enum.SurfaceType.Smooth
	glow.BottomSurface = Enum.SurfaceType.Smooth
	glow.Parent = model
	glow.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + 0.2,
		bonusZ
	) * CFrame.Angles(0, 0, math.rad(90))

	body.CFrame = CFrame.new(
		lane.xOffset + localX,
		GameConfig.WORLD_FLOOR_Y + template.size.Y * 0.5 + 1,
		bonusZ
	)

	model.PrimaryPart = body

	local bonus = {
		id = nextBonusId,
		lane = lane,
		worldX = lane.xOffset + localX,
		z = bonusZ,
		model = model,
		body = body,
		halfWidth = (template.size.X + 3) * 0.5,
		halfLength = (template.size.Z + 3) * 0.5,
		points = template.points,
		label = template.label,
	}

	lane.bonusItems[nextBonusId] = bonus
end

local function destroyBonus(lane, bonusId)
	local bonus = lane.bonusItems[bonusId]
	if not bonus then return end
	if bonus.model then bonus.model:Destroy() end
	lane.bonusItems[bonusId] = nil
end

local function ensureObstaclesAhead(lane, carZ)
	local obstacleLimit = math.min(carZ + GameConfig.OBSTACLE_LOOKAHEAD, GameConfig.FINISH_LINE_Z - GameConfig.FINISH_OBSTACLE_BUFFER)

	while lane.nextObstacleZ < obstacleLimit do
		local spacing = math.random(GameConfig.OBSTACLE_SPACING_MIN, GameConfig.OBSTACLE_SPACING_MAX)
		lane.nextObstacleZ += spacing
		createObstaclePart(lane, lane.nextObstacleZ)
	end
end

local function ensureBonusAhead(lane, carZ)
	local bonusLimit = math.min(carZ + GameConfig.OBSTACLE_LOOKAHEAD, GameConfig.FINISH_LINE_Z - GameConfig.FINISH_OBSTACLE_BUFFER)

	while lane.nextBonusZ < bonusLimit do
		local spacing = math.random(GameConfig.BONUS_SPACING_MIN, GameConfig.BONUS_SPACING_MAX)
		lane.nextBonusZ += spacing
		createBonusItem(lane, lane.nextBonusZ)
	end
end

local function ensureLane(laneIndex)
	if lanes[laneIndex] then
		return lanes[laneIndex]
	end

	local xOffset = (laneIndex - 1) * GameConfig.LANE_SPACING
	local laneFolder = Instance.new("Folder")
	laneFolder.Name = string.format("Lane_%d", laneIndex)
	laneFolder.Parent = lanesFolder

	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = laneFolder

	local bonusFolder = Instance.new("Folder")
	bonusFolder.Name = "Bonus"
	bonusFolder.Parent = laneFolder

	local lane = {
		index = laneIndex,
		xOffset = xOffset,
		folder = laneFolder,
		obstaclesFolder = obstaclesFolder,
		bonusFolder = bonusFolder,
		obstacles = {},
		bonusItems = {},
		nextObstacleZ = GameConfig.OBSTACLE_START_Z,
		nextBonusZ = GameConfig.BONUS_START_Z,
		lastSegmentIndex = -1,
	}

	lanes[laneIndex] = lane

	createStartHub(lane)
	createCheckpointLine(lane, "StartLine", GameConfig.START_LINE_Z, Color3.fromRGB(77, 255, 125), GameConfig.START_BANNER_TEXT)
	createCheckpointLine(lane, "FinishLine", GameConfig.FINISH_LINE_Z, Color3.fromRGB(255, 92, 92), GameConfig.FINISH_BANNER_TEXT)
	createRoadEndBarrier(lane)
	buildRoadSegment(lane, -1)
	lane.lastSegmentIndex = -1
	ensureRoadAhead(lane, 0)
	ensureObstaclesAhead(lane, 0)
	ensureBonusAhead(lane, 0)

	return lane
end

local function createCar(player, lane)
	local model = Instance.new("Model")
	model.Name = string.format("%s_Runner", player.Name)
	model:SetAttribute("OwnerUserId", player.UserId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Size = Vector3.new(8, 2, 12)
	body.Color = Color3.fromRGB(75, 214, 255)
	body.Material = Enum.Material.SmoothPlastic
	body:SetAttribute("OwnerUserId", player.UserId)
	body.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Anchored = true
	cabin.CanCollide = false
	cabin.TopSurface = Enum.SurfaceType.Smooth
	cabin.BottomSurface = Enum.SurfaceType.Smooth
	cabin.Size = Vector3.new(6, 2.5, 5)
	cabin.Color = Color3.fromRGB(192, 225, 255)
	cabin.Material = Enum.Material.Glass
	cabin.Parent = model

	local bumper = Instance.new("Part")
	bumper.Name = "Bumper"
	bumper.Anchored = true
	bumper.CanCollide = false
	bumper.TopSurface = Enum.SurfaceType.Smooth
	bumper.BottomSurface = Enum.SurfaceType.Smooth
	bumper.Size = Vector3.new(8.4, 1, 1)
	bumper.Color = Color3.fromRGB(240, 240, 240)
	bumper.Material = Enum.Material.Metal
	bumper.Parent = model

	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.TopSurface = Enum.SurfaceType.Smooth
	stripe.BottomSurface = Enum.SurfaceType.Smooth
	stripe.Size = Vector3.new(2.2, 0.3, 10)
	stripe.Color = Color3.fromRGB(255, 165, 86)
	stripe.Material = Enum.Material.Neon
	stripe.Parent = model

	local spoiler = Instance.new("Part")
	spoiler.Name = "Spoiler"
	spoiler.Anchored = true
	spoiler.CanCollide = false
	spoiler.TopSurface = Enum.SurfaceType.Smooth
	spoiler.BottomSurface = Enum.SurfaceType.Smooth
	spoiler.Size = Vector3.new(7.2, 0.45, 1.2)
	spoiler.Color = Color3.fromRGB(32, 32, 38)
	spoiler.Material = Enum.Material.Metal
	spoiler.Parent = model

	local headlightLeft = Instance.new("Part")
	headlightLeft.Name = "HeadlightLeft"
	headlightLeft.Anchored = true
	headlightLeft.CanCollide = false
	headlightLeft.Size = Vector3.new(1.2, 0.5, 0.4)
	headlightLeft.Color = Color3.fromRGB(255, 245, 188)
	headlightLeft.Material = Enum.Material.Neon
	headlightLeft.Parent = model

	local headlightRight = headlightLeft:Clone()
	headlightRight.Name = "HeadlightRight"
	headlightRight.Parent = model

	local taillightLeft = Instance.new("Part")
	taillightLeft.Name = "TaillightLeft"
	taillightLeft.Anchored = true
	taillightLeft.CanCollide = false
	taillightLeft.Size = Vector3.new(1, 0.4, 0.4)
	taillightLeft.Color = Color3.fromRGB(255, 70, 70)
	taillightLeft.Material = Enum.Material.Neon
	taillightLeft.Parent = model

	local taillightRight = taillightLeft:Clone()
	taillightRight.Name = "TaillightRight"
	taillightRight.Parent = model

	for _, lightPart in ipairs({ headlightLeft, headlightRight }) do
		local pointLight = Instance.new("PointLight")
		pointLight.Brightness = 1.3
		pointLight.Range = 16
		pointLight.Color = Color3.fromRGB(255, 244, 184)
		pointLight.Parent = lightPart
	end

	local wheelOffsets = {
		Vector3.new(-3.6, -1.1, -4.1),
		Vector3.new(3.6, -1.1, -4.1),
		Vector3.new(-3.6, -1.1, 4.1),
		Vector3.new(3.6, -1.1, 4.1),
	}

	for index, offset in ipairs(wheelOffsets) do
		local wheel = Instance.new("Part")
		wheel.Name = string.format("Wheel_%d", index)
		wheel.Anchored = true
		wheel.CanCollide = false
		wheel.TopSurface = Enum.SurfaceType.Smooth
		wheel.BottomSurface = Enum.SurfaceType.Smooth
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(2, 2.8, 2.8)
		wheel.Color = Color3.fromRGB(22, 22, 22)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.Parent = model
		wheel:SetAttribute("OffsetX", offset.X)
		wheel:SetAttribute("OffsetY", offset.Y)
		wheel:SetAttribute("OffsetZ", offset.Z)
	end

	model.PrimaryPart = body
	model.Parent = carsFolder

	local function positionCar(localX, z, steerAngle)
		local baseCFrame = CFrame.new(
			lane.xOffset + localX,
			GameConfig.WORLD_FLOOR_Y + GameConfig.CAR_HEIGHT,
			z
		) * CFrame.Angles(0, math.pi + math.rad(steerAngle), 0)

		body.CFrame = baseCFrame
		cabin.CFrame = baseCFrame * CFrame.new(0, 2.1, 0.5)
		bumper.CFrame = baseCFrame * CFrame.new(0, -0.4, -6.2)
		stripe.CFrame = baseCFrame * CFrame.new(0, 1.16, 0)
		spoiler.CFrame = baseCFrame * CFrame.new(0, 1.65, 5.25)
		headlightLeft.CFrame = baseCFrame * CFrame.new(-2.25, 0.35, -6.05)
		headlightRight.CFrame = baseCFrame * CFrame.new(2.25, 0.35, -6.05)
		taillightLeft.CFrame = baseCFrame * CFrame.new(-2.35, 0.32, 6.05)
		taillightRight.CFrame = baseCFrame * CFrame.new(2.35, 0.32, 6.05)

		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Part") and child.Name:match("^Wheel_") then
				local offset = Vector3.new(
					child:GetAttribute("OffsetX"),
					child:GetAttribute("OffsetY"),
					child:GetAttribute("OffsetZ")
				)
				child.CFrame = baseCFrame
					* CFrame.new(offset)
					* CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end

	positionCar(0, 0, 0)
	body:SetAttribute("Speed", GameConfig.START_SPEED)
	body:SetAttribute("Score", 0)
	body:SetAttribute("GameTitle", GameConfig.GAME_NAME)
	body:SetAttribute("GameState", "Running")
	body:SetAttribute("Progress", 0)
	body:SetAttribute("StatusText", GameConfig.STATUS_DEFAULT)

	return model, positionCar
end

local function createLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local hits = Instance.new("IntValue")
	hits.Name = "Points"
	hits.Value = 0
	hits.Parent = leaderstats

	return hits
end

local function registerPlayer(player)
	nextLaneIndex += 1
	local lane = ensureLane(nextLaneIndex)
	local hits = createLeaderstats(player)
	local carModel, positionCar = createCar(player, lane)

	playerStates[player] = {
		player = player,
		lane = lane,
		car = carModel,
		body = carModel.PrimaryPart,
		positionCar = positionCar,
		localX = 0,
		z = 0,
		speed = GameConfig.START_SPEED,
		score = 0,
		hits = hits,
		finished = false,
		input = {
			throttle = 0,
			steer = 0,
		},
	}
end

local function cleanupPlayer(player)
	local state = playerStates[player]
	if not state then
		return
	end

	if state.car then
		state.car:Destroy()
	end

	playerStates[player] = nil
end

local function destroyObstacle(lane, obstacleId)
	local obstacle = lane.obstacles[obstacleId]
	if not obstacle then
		return
	end

	if obstacle.part then
		obstacle.part:Destroy()
	end

	if obstacle.extraParts then
		for _, extraPart in ipairs(obstacle.extraParts) do
			if extraPart then
				extraPart:Destroy()
			end
		end
	end

	lane.obstacles[obstacleId] = nil
end

local function crashPlayer(state, obstacle)
	state.crashed = true
	state.speed = 0
	state.input.throttle = 0
	state.input.steer = 0

	local crashStopZ = math.max(0, obstacle.z - (GameConfig.CAR_HALF_LENGTH + obstacle.halfLength * 0.5))
	state.z = math.min(state.z, crashStopZ)
	state.positionCar(state.localX, state.z, 0)
	state.body.Color = Color3.fromRGB(90, 25, 20)
	state.body.Material = Enum.Material.Metal
	state.body:SetAttribute("Speed", 0)
	state.body:SetAttribute("GameState", "Crashed")
	state.body:SetAttribute("Progress", math.clamp(state.z / GameConfig.FINISH_LINE_Z, 0, 1))
	state.body:SetAttribute("StatusText", GameConfig.STATUS_CRASHED)

	if obstacle.part then
		local explosion = Instance.new("Explosion")
		explosion.Position = obstacle.part.Position
		explosion.BlastPressure = 0
		explosion.BlastRadius = 8
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = workspace
	end
end

local function updatePlayerState(state, dt)
	if state.crashed then
		state.speed = 0
		state.body:SetAttribute("Speed", 0)
		state.positionCar(state.localX, state.z, 0)
		return
	end

	if state.finished then
		state.speed = 0
		state.body:SetAttribute("Speed", 0)
		state.body:SetAttribute("GameState", "Finished")
		state.body:SetAttribute("Progress", 1)
		state.body:SetAttribute("StatusText", GameConfig.STATUS_FINISHED)
		state.positionCar(state.localX, state.z, 0)
		return
	end

	local throttle = state.input.throttle
	local steer = state.input.steer

	if throttle > 0 then
		state.speed = math.min(GameConfig.MAX_SPEED, state.speed + GameConfig.ACCELERATION * throttle * dt)
	elseif throttle < 0 then
		state.speed = math.max(GameConfig.MIN_SPEED, state.speed - GameConfig.BRAKE_STRENGTH * math.abs(throttle) * dt)
	else
		state.speed = math.max(GameConfig.MIN_SPEED, state.speed - GameConfig.DRAG * dt)
	end

	state.localX = clamp(
		state.localX - steer * GameConfig.STEER_SPEED * dt,
		-(GameConfig.ROAD_WIDTH * 0.5 - GameConfig.CAR_HALF_WIDTH),
		GameConfig.ROAD_WIDTH * 0.5 - GameConfig.CAR_HALF_WIDTH
	)

	local nextZ = state.z + state.speed * dt
	if nextZ >= GameConfig.FINISH_LINE_Z then
		nextZ = GameConfig.FINISH_LINE_Z
		state.finished = true
		state.speed = 0
	end

	state.z = nextZ

	local steerAngle = steer * GameConfig.MAX_STEER_ANGLE
	state.positionCar(state.localX, state.z, steerAngle)
	state.body:SetAttribute("Speed", math.floor(state.speed + 0.5))
	state.body:SetAttribute("Score", state.score)
	state.body:SetAttribute("Progress", math.clamp(state.z / GameConfig.FINISH_LINE_Z, 0, 1))

	ensureRoadAhead(state.lane, state.z)
	ensureObstaclesAhead(state.lane, state.z)
	ensureBonusAhead(state.lane, state.z)

	for obstacleId, obstacle in pairs(state.lane.obstacles) do
		if obstacle.z < state.z - GameConfig.OBSTACLE_CULL_DISTANCE then
			addPoint(state, 1)
			destroyObstacle(state.lane, obstacleId)
		else
			local dx = math.abs((state.lane.xOffset + state.localX) - obstacle.worldX)
			local dz = math.abs(state.z - obstacle.z)
			local hitWidth = GameConfig.CAR_HALF_WIDTH + obstacle.halfWidth * 0.75
			local hitLength = GameConfig.CAR_HALF_LENGTH + obstacle.halfLength * 0.75

			if dx <= hitWidth and dz <= hitLength then
				crashPlayer(state, obstacle)
				return
			end
		end
	end

	for bonusId, bonus in pairs(state.lane.bonusItems) do
		if bonus.z < state.z - GameConfig.OBSTACLE_CULL_DISTANCE then
			destroyBonus(state.lane, bonusId)
		else
			local dx = math.abs((state.lane.xOffset + state.localX) - bonus.worldX)
			local dz = math.abs(state.z - bonus.z)

			if dx <= bonus.halfWidth and dz <= bonus.halfLength then
				addPoint(state, bonus.points)
				state.body:SetAttribute("StatusText", string.format("%s gesammelt!", bonus.label))
				task.delay(1.5, function()
					if not state.crashed and not state.finished then
						state.body:SetAttribute("StatusText", GameConfig.STATUS_DEFAULT)
					end
				end)
				destroyBonus(state.lane, bonusId)
			end
		end
	end
end

inputRemote.OnServerEvent:Connect(function(player, payload)
	local state = playerStates[player]
	if not state or type(payload) ~= "table" then
		return
	end

	local throttle = tonumber(payload.throttle) or 0
	local steer = tonumber(payload.steer) or 0

	state.input.throttle = clamp(throttle, -1, 1)
	state.input.steer = clamp(steer, -1, 1)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(hideCharacter)
	if player.Character then
		hideCharacter(player.Character)
	end

	registerPlayer(player)
end)

Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		if player.Character then
			hideCharacter(player.Character)
		end

		player.CharacterAdded:Connect(hideCharacter)
		registerPlayer(player)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, state in pairs(playerStates) do
		updatePlayerState(state, dt)
	end
end)
