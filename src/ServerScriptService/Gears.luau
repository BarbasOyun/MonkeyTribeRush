local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")
local KillsData = DataStoreService:GetOrderedDataStore("Wins")
local BananasData = DataStoreService:GetDataStore("Bananas")

local ServerEvents = require(ServerScriptService.Server.ServerEvents)

local gears = {}

local weaponHitFolder = workspace.WeaponHit
local mapLimits = { X = Vector2.new(-300, 300), Z = Vector2.new(-200, 200) }

-- Prefabs
local smallXpOrb = ReplicatedStorage.Prefabs.SmallXpOrb
local banana = ReplicatedStorage.Prefabs.Banana
local enemy = ReplicatedStorage.Prefabs.Robot

function gears.ExecuteFor(duration, lambda)
	local execute = RunService.Heartbeat:Connect(function()
		lambda()
	end)

	task.delay(duration, function()
		execute:Disconnect()
	end)
end

function gears.drawSphere(position, radius, color)
	local adorn = Instance.new("SphereHandleAdornment")
	adorn.Radius = radius
	adorn.Color3 = color or Color3.new(0.5, 0, 0)
	adorn.Transparency = 0.5
	adorn.Adornee = workspace.Terrain -- Must be attached to something
	adorn.CFrame = CFrame.new(position)
	adorn.AlwaysOnTop = true
	adorn.Parent = workspace.Terrain

	game.Debris:AddItem(adorn, 0.01)
end

function gears.DrawEdge(startPos, endPos, color)
	local adorn = Instance.new("LineHandleAdornment")
	adorn.Length = (endPos - startPos).Magnitude
	adorn.Color3 = color or Color3.new(0, 1, 0)
	adorn.Thickness = 20
	adorn.Adornee = workspace.Terrain
	-- Position it at origin and point it toward the direction
	adorn.CFrame = CFrame.lookAt(startPos, endPos)
	adorn.AlwaysOnTop = true
	adorn.Parent = workspace.Terrain

	game.Debris:AddItem(adorn, 0.01)
end

function gears.drawRay(origin, direction, color)
	gears.DrawEdge(origin, origin + direction, color)
end

function gears.CirclePoints(radius, division) -- TODO : Add Progress
	local points = {}
	local pointDistance = (math.pi * 2) / division

	for i = 0, (division - 1), 1 do
		table.insert(points, gears.CirclePos(radius, pointDistance * i))
	end

	return points
end

function gears.DrawCircle(basePos, circlePoints)
	local function DrawEdge(point1, point2)
		local startPos = basePos + Vector3.new(point1.X, 0, point1.Y)
		local endPos = basePos + Vector3.new(point2.X, 0, point2.Y)
		gears.DrawEdge(startPos, endPos)
	end

	-- Draw Edges
	for index = 1, #circlePoints - 1, 1 do
		DrawEdge(circlePoints[index], circlePoints[index + 1])
	end

	-- Draw Last Edges : Last Point -> First
	DrawEdge(circlePoints[#circlePoints], circlePoints[1])
end

function gears.FloatRandom(minNbr, maxNbr)
	return math.random(minNbr, maxNbr - 1) + math.random(1, 10) / 10
end

function gears.PointsDistance(pointA, pointB)
	return (pointA - pointB).Magnitude
end

function gears.NormalizeOrZero(vector2)
	if vector2 == Vector2.zero then
		return Vector2.zero
	end

	return vector2.Unit
end

function gears.ParabolaPos(startPos, endPos, height, progress)
	local lerpPos = startPos + (endPos - startPos) * progress
	local y = startPos.Y + (height * 4 * progress * (1 - progress))
	return Vector3.new(lerpPos.X, y, lerpPos.Z)
end

function gears.CirclePos(radius, progress)
	-- progress = (progress + 0.01) % (math.pi * 2)
	local x = math.cos(progress) * radius
	local y = math.sin(progress) * radius
	return Vector2.new(x, y) -- Add to a position
end

function gears.SpherePos(latitude, longitude, radius)
	-- progress = (progress + 0.01) % (math.pi * 2)
	local x = math.sin(latitude) * math.cos(longitude) * radius
	local y = math.sin(latitude) * math.sin(longitude) * radius
	local z = math.cos(latitude) * radius
	return Vector3.new(x, y, z) -- Add to a position
end

function gears.LootMovement(item, startPos)
	item.Position = startPos
	item.Parent = workspace

	local targetPos = startPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	local finalTargetPos = targetPos
	local result = workspace:Raycast(targetPos, Vector3.new(0, -10, 0))

	if result then
		finalTargetPos = result.Position
	end

	local steps = 60
	local height = math.random(2, 5)

	for i = 1, steps do
		local progress = i / steps
		item.CFrame = CFrame.new(gears.ParabolaPos(startPos, finalTargetPos, height, progress))
		RunService.Heartbeat:Wait()
	end

	item.Parent = workspace.XP_Orbs -- Enable Pickup
end

function gears.SpawnXP(spawnPosition)
	-- print("Spawn XP Orb")
	local newOrb = smallXpOrb:Clone()

	gears.LootMovement(newOrb, spawnPosition)
end

function gears.SpawnBanana(spawnPosition)
	-- print("Spawn Banana")
	local newBanana = banana:Clone()

	gears.LootMovement(newBanana, spawnPosition)
end

function gears.SpawnEnemyCircle(basePosition)
	local radius = math.random(60, 120)
	local progress = math.random(0, math.pi * 2)
	local circlePos = gears.CirclePos(radius, progress)
	gears.SpawnEnemy(basePosition + Vector3.new(circlePos.X, 0, circlePos.Y))
end

function gears.SpawnEnemy(spawnPosition)
	local newEnemy = enemy:Clone()
	newEnemy.Parent = weaponHitFolder
	local xPos = math.clamp(spawnPosition.X, mapLimits.X.X, mapLimits.X.Y)
	local zPos = math.clamp(spawnPosition.Z, mapLimits.Z.X, mapLimits.Z.Y)
	newEnemy.PrimaryPart.CFrame = CFrame.new(Vector3.new(xPos, spawnPosition.Y, zPos))
	ServerEvents.EnemySpawned:Fire(newEnemy)
end

function gears.SaveData()
	-- Save Data : Kills, Destruction, Bananas -> use pcall
	-- Cap Data to max

	for _, player in ipairs(Players:GetPlayers()) do
		print("Save Data for : " .. player.Name)
		print(player.leaderstats)
		-- BananasData:IncrementAsync(player.UserId, 1)
	end
end

function gears.sumTable(t)
	local total = 0
	for i = 1, #t do
		total += t[i]
	end
	return total
end

function gears.IncreaseToMultiplier(increaseValue)
	return 1 + increaseValue / 100
end

return gears
