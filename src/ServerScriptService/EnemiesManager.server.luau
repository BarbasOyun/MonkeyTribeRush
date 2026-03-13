local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
-- local RunService = game:GetService("RunService")

local Gears = require(ServerScriptService.Server.Gears)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)
local PlayersStats = require(ServerScriptService.Server.PlayersStats)

local MAX_ENEMIES = 200
local enemies = {}
local moveToTasks = {}

local scaleSpeed = 1 -- How much stats does the Robots Get over time

local function CreatePlayerPath(enemyPos, playerPos)
	local path = PathfindingService:CreatePath()

	local success, errorMessage = pcall(function()
		path:ComputeAsync(enemyPos, playerPos)
	end)

	if success then
		return path
	else
		warn(errorMessage)
		return nil
	end
end

local function getNearestPlayer(enemyPosition)
	local closestPlayer = nil
	local shortestDistance = math.huge -- Start with infinity

	for _, player in ipairs(Players:GetPlayers()) do
		if PlayersStats[player.UserId].pickingAugment then
			return nil
		end

		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local enemyPlayerVector = (character.HumanoidRootPart.Position - enemyPosition)
			local distance = enemyPlayerVector:Dot(enemyPlayerVector)

			if distance < shortestDistance then
				shortestDistance = distance
				closestPlayer = character
			end
		end
	end

	return closestPlayer
end

-- Pathfinding
local function RunAtPlayer()
	for _, enemy in ipairs(enemies) do
		if not enemy then
			return
		end

		local humanoid = enemy.Humanoid -- enemiesHumanoids[enemy]

		if not humanoid then
			return
		end

		local target = getNearestPlayer(enemy.HumanoidRootPart.Position)

		if target then
			local path = CreatePlayerPath(enemy.PrimaryPart.Position, target.PrimaryPart.Position)

			local t = task.spawn(function()
				for _, wayPoint in pairs(path:GetWaypoints()) do
					humanoid:MoveTo(wayPoint.Position)
					humanoid.MoveToFinished:Wait()
				end
			end)
			table.insert(moveToTasks, t)
		end
	end

	task.wait(1)

	for _, t in ipairs(moveToTasks) do
		task.cancel(t)
	end

	table.clear(moveToTasks)

	RunAtPlayer()
end

local function MoveToPlayer()
	for _, enemy in ipairs(enemies) do
		pcall(function()
			if not enemy then
				return
			end

			local humanoid = enemy.Humanoid

			if not humanoid then
				return
			end

			local target = getNearestPlayer(enemy.HumanoidRootPart.Position)

			if target then
				humanoid:MoveTo(target.PrimaryPart.Position)
			else
				humanoid:MoveTo(enemy.HumanoidRootPart.Position) -- Stop if no target found
			end
		end)
	end

	task.wait(1)
	MoveToPlayer()
end

local function SetupEnemy(enemy)
	table.insert(enemies, enemy)

	enemy.Humanoid.Died:Connect(function()
		Gears.SpawnXP(enemy.PrimaryPart.Position)
		-- task.wait(2)
		enemy:Destroy()
	end)
end

local function StreamSpawn() -- Spawn Enemies constantly
	if #enemies >= MAX_ENEMIES then
		return
	end

	local spawnDelta = math.random(5, 10)
	task.wait(spawnDelta)

	for _, player in ipairs(Players:GetPlayers()) do
		local enemyNbr = math.random(1, 2)

		for _ = 1, enemyNbr, 1 do
			Gears.SpawnEnemyCircle(player.Character.PrimaryPart.Position)
		end

		StreamSpawn()
	end
end

local function swarmSpawn() -- Spawn Big wave of Enemies
end

ServerEvents.EnemySpawned.Event:Connect(function(enemy)
	-- print("Enemy Spawned : " .. enemy.Name)
	-- table.insert(enemies, enemy)
	SetupEnemy(enemy)
end)

--RunAtPlayer()
task.spawn(function()
	StreamSpawn()
end)
MoveToPlayer()
