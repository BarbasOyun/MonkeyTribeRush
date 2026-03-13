local ServerScriptService = game:GetService("ServerScriptService")
-- local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Gears = require(ServerScriptService.Server.Gears)
local Events = ReplicatedStorage.Shared
local ServerEvents = ServerScriptService.Server

local mapGenerator = {}

local weaponHitFolder = workspace.WeaponHit

-- Buildings Data
-- TODO : Move to file
local militaryBase = { prefab = ReplicatedStorage.Prefabs.MilitaryBase, nbrOfParts = 1110, radius = 55 }
local militaryCamp = { prefab = ReplicatedStorage.Prefabs.MilitaryCamp, nbrOfParts = 912, radius = 60 }
local militaryCanvas = { prefab = ReplicatedStorage.Prefabs.MilitaryCanvas, nbrOfParts = 336, radius = 40 }
local smallCamp = { prefab = ReplicatedStorage.Prefabs.SmallCamp, nbrOfParts = 1000, radius = 35 } -- Real Nbr = 1806
local sniperTower = { prefab = ReplicatedStorage.Prefabs.SniperTower, nbrOfParts = 139, radius = 20 }
local woodCrates = { prefab = ReplicatedStorage.Prefabs.WoodCrates, nbrOfParts = 76, radius = 15 }

local reactor = { prefab = ReplicatedStorage.Prefabs.Reactor, nbrOfParts = 700, radius = 55 } -- Real Nbr = 1230
local galileoLaboratorty = { prefab = ReplicatedStorage.Prefabs.GalileoLaboratorty, nbrOfParts = 38, radius = 20 }
local alchemyLab = { prefab = ReplicatedStorage.Prefabs.AlchemyLab, nbrOfParts = 175, radius = 30 }
local labRoom = { prefab = ReplicatedStorage.Prefabs.LabRoom, nbrOfParts = 129, radius = 45 }
local labBattery = { prefab = ReplicatedStorage.Prefabs.LabBattery, nbrOfParts = 25, radius = 15 }

local militaryMap = { militaryBase, militaryCamp, militaryCanvas, smallCamp, sniperTower, woodCrates }
local researchLabMap = { reactor, galileoLaboratorty, alchemyLab, labRoom, labBattery }

local maps = { militaryMap, researchLabMap }
local mapsMusics = {
	ReplicatedStorage.Prefabs.MilitaryMapMusic,
	ReplicatedStorage.Prefabs.ResearchMapMusic,
}

-- Stage
local MINIMUM_RADIUS = 40
-- local CIRCLE_DIVISION = 20
local ADDITIONAL_BUILDINGS = 2
local BUILDING_LIMIT = 10
local isWaitingForNextStage = false

local currentMusic = nil

local totalParts = 0
local partsCount = 0

local stageBuildingNbr = 3
-- local maxStage = 5 -- TODO : Roll
local currentStage = 0

local eventsEnum = { SWARM = "SWARM" } -- TODO Add More Events
local maxEvents = 0
local currentEvent = 0
local stageEvents = {}

function mapGenerator.FindOverlappingNodes(nodesPos, nodesBuilding, startPos, radius)
	local overlappingNodes = {}

	for i = 1, #nodesPos - 1, 1 do
		local distance = Gears.PointsDistance(startPos, nodesPos[i])
		local minDistance = radius + nodesBuilding[i].radius

		if distance < minDistance then
			-- table.insert(overlappingNodes, distance)
			local node = {
				distance = distance,
				radius = radius,
				position = nodesPos[i],
			}

			overlappingNodes[#overlappingNodes + 1] = node
		end
	end

	return overlappingNodes
end

function mapGenerator.AdjustNodePos(startPos, overlappingNodes, radius)
	local adjustDirection = Vector2.new(0, 0)
	local adjustDistance = 0

	for i in overlappingNodes do
		local node = overlappingNodes[i]
		local distance = node.distance
		local min_distance = node.radius + radius

		if distance < min_distance then
			adjustDirection += startPos - node.position
			adjustDistance += min_distance - distance
		end
	end

	local adjustedPos = startPos + Gears.NormalizeOrZero(adjustDirection) * adjustDistance

	local minimumDistance = radius + MINIMUM_RADIUS
	local distanceCenter = Gears.PointsDistance(Vector2.zero, adjustedPos) -- Vector2.zero = Center of the Map

	if distanceCenter < minimumDistance then
		adjustDirection = adjustedPos - Vector2.zero
		adjustDistance = minimumDistance - distanceCenter
		adjustedPos = adjustedPos + Gears.NormalizeOrZero(adjustDirection) * adjustDistance
	end

	return startPos + Gears.NormalizeOrZero(adjustDirection) * adjustDistance
end

function mapGenerator.CreateNode(nodesPos, nodesBuilding, nodePos, building)
	local adjustedPos = nodePos

	local overlappingNodes = mapGenerator.FindOverlappingNodes(nodesPos, nodesBuilding, adjustedPos, building.radius)
	local count = 0

	while count < 3 and #overlappingNodes > 0 do
		adjustedPos = mapGenerator.AdjustNodePos(adjustedPos, overlappingNodes, building.radius)
		overlappingNodes = mapGenerator.FindOverlappingNodes(nodesPos, nodesBuilding, adjustedPos, building.radius)
		count += 1
	end

	return adjustedPos
end

function mapGenerator.GenerateMapData(stageRadiusSize, buildingTable, buildingNbr)
	local buildingsPos = {}
	local nodesBuilding = {}
	local buildingIndex = math.random(1, 5)

	-- Generate Buildings
	for _ = 1, buildingNbr, 1 do
		-- Choose Building
		local building = buildingTable[buildingIndex]
		buildingIndex = Gears.LoopValue(buildingIndex + 1, #buildingTable, 1)
		totalParts += building.nbrOfParts

		-- Building Position
		local rngRadius = Gears.FloatRandom(MINIMUM_RADIUS, stageRadiusSize)
		local rngProgress = Gears.FloatRandom(0, math.pi * 2)
		local buildingPos = Gears.CirclePos(rngRadius, rngProgress)

		local adjustedPos = mapGenerator.CreateNode(buildingsPos, nodesBuilding, buildingPos, building)
		table.insert(buildingsPos, adjustedPos)
		table.insert(nodesBuilding, building)
	end

	totalParts *= 0.5 -- Require 50% of the stage to be completed

	return buildingsPos, nodesBuilding
end

function mapGenerator.GenerateMap(stageRadiusSize, mapId, buildingNbr)
	mapGenerator.ClearMap()

	local buildingTable = maps[mapId]
	local nodesPos, nodesBuilding = mapGenerator.GenerateMapData(stageRadiusSize, buildingTable, buildingNbr)

	currentMusic = mapsMusics[mapId]:clone()
	currentMusic.Playing = true
	currentMusic.Parent = workspace

	-- DEBUG
	-- RunService.Heartbeat:Connect(function()
	-- 	Gears.DrawCircle(Vector3.new(0, 3, 0), Gears.CirclePoints(stageRadiusSize, CIRCLE_DIVISION))
	-- 	Gears.DrawCircle(Vector3.new(0, 3, 0), Gears.CirclePoints(MINIMUM_RADIUS, CIRCLE_DIVISION)) -- Min Radius
	-- end)

	-- Instantiate Buildings
	for i in nodesPos do
		local building = nodesBuilding[i].prefab:clone()
		building:PivotTo(CFrame.new(nodesPos[i].X, building:GetPivot().Position.Y, nodesPos[i].Y))
		building.Parent = weaponHitFolder

		-- DEBUG
		-- RunService.Heartbeat:Connect(function()
		-- 	Gears.DrawCircle(building:GetPivot().Position, Gears.CirclePoints(nodesBuilding[i].radius, CIRCLE_DIVISION))
		-- end)
	end
end

function mapGenerator.FinishStage()
	print("Stage Finished")
	currentStage += 1

	task.spawn(function()
		Gears.SaveData()
	end)

	-- if currentStage > maxStage then
	-- 	print("Level Finished -> Going back to Hub")
	-- 	-- Go Back to Hub
	-- 	return
	-- end

	-- Countdown
	print("10 sec until New Stage")
	isWaitingForNextStage = true
	Events.CurrentStageChanged:FireAllClients(currentStage)
	ServerEvents.StageChanged:Fire()
	local countDown = 10
	for _ = 0, 10, 1 do
		task.wait(1)
		countDown -= 1
		Events.NextStageTimerTick:FireAllClients(countDown)
	end

	stageBuildingNbr = math.clamp(stageBuildingNbr + ADDITIONAL_BUILDINGS, 0, BUILDING_LIMIT)
	totalParts = 0
	partsCount = 0
	mapGenerator.StartStage()
end

function mapGenerator.IncrementBuilding()
	if isWaitingForNextStage then
		return
	end

	partsCount += 1
	local stageProgress = partsCount / totalParts
	Events.StageProgress:FireAllClients(stageProgress)
	-- print("Current Stage Progress : " .. stageProgress)

	-- Check Stage Events
	if currentEvent / maxEvents >= stageProgress then
		print("Trigger : " .. currentEvent)
		currentEvent += 1
		print(stageEvents[currentEvent])
	end

	-- Stage Finished
	if stageProgress >= 1 then
		mapGenerator.FinishStage()
	end
end

function mapGenerator.ClearMap() -- Clear Building + Enenmies
	for _, object in ipairs(weaponHitFolder:GetDescendants()) do
		object:Destroy()
	end

	if currentMusic then
		currentMusic:Destroy()
	end
end

function mapGenerator.StartStage()
	isWaitingForNextStage = false
	Events.StageProgress:FireAllClients(0)

	-- Reset Players Positions
	for _, player in ipairs(Players:GetPlayers()) do
		player.Character:MoveTo(Vector3.zero)
	end

	local mapId = math.random(1, #maps)
	mapGenerator.GenerateMap(200, mapId, stageBuildingNbr)

	-- Stage Events
	maxEvents = math.random(2, 5)

	for i = 0, maxEvents do
		table.insert(stageEvents, eventsEnum.SWARM)
		-- print("Stage Event " .. i .. " : " .. eventsEnum.SWARM)
	end
end

return mapGenerator
