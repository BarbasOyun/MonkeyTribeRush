local ServerScriptService = game:GetService("ServerScriptService")
-- local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Gears = require(ServerScriptService.Server.Gears)
local Events = ReplicatedStorage.Shared
local ServerEvents = ServerScriptService.Server

local mapGenerator = {}

local weaponHitFolder = workspace.WeaponHit
local orbsFolder = workspace.XP_Orbs

-- Buildings Data
-- TODO : Move to file
local militaryBase = { prefab = ReplicatedStorage.Prefabs.MilitaryBase, nbrOfParts = 800, radius = 55 } -- Real Nbr = 1110
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

-- Weapons Prefabs
local weapons = { ReplicatedStorage.Prefabs.IronAxe, ReplicatedStorage.Prefabs.IronMace }

-- Stage
local MINIMUM_RADIUS = 40
local SPAWN_POS = Vector2.new(0, 170)
-- local CIRCLE_DIVISION = 20
local ADDITIONAL_BUILDINGS = 2
local BUILDING_LIMIT = 10
local isWaitingForNextStage = false

local currentMapId = math.random(1, #maps)

local currentStage = 0
local stageBuildingNbr = 3
local currentMusic = nil

local totalParts = 0
local partsCount = 0

-- Stage Events
local eventsEnum = { SWARM = "SWARM" } -- TODO Add More Events
local maxEvents = 0
local currentEvent = 1
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
	local adjustDirection = Vector2.zero
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

	-- Minimum Distance Spawn
	local minimumDistance = radius + MINIMUM_RADIUS
	local distanceCenter = Gears.PointsDistance(SPAWN_POS, adjustedPos)

	if distanceCenter < minimumDistance then
		adjustDirection = adjustedPos - SPAWN_POS
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
	local buildingTable = maps[mapId]
	local nodesPos, nodesBuilding = mapGenerator.GenerateMapData(stageRadiusSize, buildingTable, buildingNbr)

	currentMusic = mapsMusics[mapId]:clone()
	currentMusic.Playing = true
	currentMusic.Parent = workspace

	-- DEBUG
	-- RunService.Heartbeat:Connect(function()
	-- 	Gears.DrawCircle(Vector3.new(0, 3, 0), Gears.CirclePoints(stageRadiusSize, CIRCLE_DIVISION))
	-- 	Gears.DrawCircle(Vector3.new(SPAWN_POS.X, 3, SPAWN_POS.Y), Gears.CirclePoints(MINIMUM_RADIUS, CIRCLE_DIVISION)) -- Min Radius
	-- end)

	local weaponCount = 0

	-- Instantiate Buildings
	for i in nodesPos do
		local building = nodesBuilding[i].prefab:clone()
		building:PivotTo(CFrame.new(nodesPos[i].X, building:GetPivot().Position.Y, nodesPos[i].Y))
		building.Parent = weaponHitFolder

		-- Generate Weapons
		weaponCount += 1
		if weaponCount >= 3 then
			local weaponRoll = math.random(1, #weapons)
			local weapon = weapons[weaponRoll]:clone()
			weapon.Parent = workspace
			weapon.Handle.CFrame = CFrame.new(building:GetPivot().Position) -- Set Parent -> Set Position = Work with Weld
			weaponCount = 0
		end

		-- DEBUG
		-- RunService.Heartbeat:Connect(function()
		-- 	Gears.DrawCircle(building:GetPivot().Position, Gears.CirclePoints(nodesBuilding[i].radius, CIRCLE_DIVISION))
		-- end)
	end
end

function mapGenerator.GenerateEvents()
	maxEvents = math.random(3, 4)
	-- print("Generating " .. maxEvents .. " Events")

	for i = 1, maxEvents do
		-- print("Stage Event " .. i .. " : " .. eventsEnum.SWARM)
		table.insert(stageEvents, eventsEnum.SWARM)
	end

	mapGenerator.stageEventsNbr = #stageEvents
end

function mapGenerator.FinishStage()
	print("Stage Finished")
	currentStage += 1

	isWaitingForNextStage = true
	Events.CurrentStageChanged:FireAllClients(currentStage)

	-- Countdown
	print("10 sec until New Stage")
	local countDown = 10
	for _ = 0, 10, 1 do
		task.wait(1)
		countDown -= 1
		Events.NextStageTimerTick:FireAllClients(countDown)
	end

	ServerEvents.StageChanged:Fire()

	-- Stage Increments
	stageBuildingNbr = math.clamp(stageBuildingNbr + ADDITIONAL_BUILDINGS, 0, BUILDING_LIMIT)

	-- Restart
	mapGenerator.ResetStage()
	mapGenerator.StartStage()
end

function mapGenerator.SetStageProgress(stageProgress)
	Events.StageProgress:FireAllClients(stageProgress)
	mapGenerator.stageProgress = stageProgress
	-- print("Current Stage Progress : " .. stageProgress)
end

function mapGenerator.StageProgress()
	if isWaitingForNextStage then
		return
	end

	partsCount += 1
	local stageProgress = partsCount / totalParts
	mapGenerator.SetStageProgress(stageProgress)
	-- print("Current Stage Progress : " .. stageProgress)

	-- Check Stage Events
	local nextEventProgress = currentEvent / (maxEvents + 1)
	if nextEventProgress < 1 and stageProgress >= nextEventProgress then
		-- print("Trigger Event " .. currentEvent .. " / " .. maxEvents .. " -> " .. stageEvents[currentEvent])

		if stageEvents[currentEvent] == eventsEnum.SWARM then
			ServerEvents.SwarmEvent:Fire()
		end

		currentEvent += 1
	end

	-- Stage Finished
	if stageProgress >= 1 then
		mapGenerator.FinishStage()
	end
end

function mapGenerator.ResetStage()
	isWaitingForNextStage = false
	mapGenerator.SetStageProgress(0)
	table.clear(stageEvents)
	totalParts = 0
	partsCount = 0

	-- Clear Building + Enemies
	for _, object in ipairs(weaponHitFolder:GetDescendants()) do
		if object:IsA("Folder") then -- TODO : Create Building Folder
			continue
		end

		object:Destroy()
	end

	-- Clear Orbs
	for _, orb in ipairs(orbsFolder:GetDescendants()) do
		orb:Destroy()
	end

	if currentMusic then
		currentMusic:Destroy()
	end

	-- Reset Players Positions
	for _, player in ipairs(Players:GetPlayers()) do
		player.Character:MoveTo(Vector3.new(SPAWN_POS.X, 1, SPAWN_POS.Y))
	end
end

function mapGenerator.StartStage()
	mapGenerator.GenerateMap(200, currentMapId, stageBuildingNbr)
	currentMapId = Gears.LoopValue(currentMapId + 1, #maps, 1)

	mapGenerator.GenerateEvents()
end

return mapGenerator
