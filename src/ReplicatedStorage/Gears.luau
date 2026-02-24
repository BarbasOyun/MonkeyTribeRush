local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Gizmo = require(ReplicatedStorage.Shared.gizmo)

local gears = {}
local smallXpOrb = ReplicatedStorage.Prefabs.SmallXpOrb
local banana = ReplicatedStorage.Prefabs.Banana

function gears.DisplayHitBox(cFrame, range, transparency)
	local drawSphere = RunService.Heartbeat:Connect(function()
		--print("Draw Sphere Gizmo")
		Gizmo.setColor("Bright red")
		Gizmo.setTransparency(transparency)
		Gizmo.drawSphere(cFrame, range)
		Gizmo.reset()
	end)

	task.delay(0.5, function()
		drawSphere:Disconnect()
	end)
end

function gears.DrawRay(startPos, endPos)
	Gizmo.drawRay(startPos, endPos)

	local drawRay = RunService.Heartbeat:Connect(function()
		Gizmo.setColor("Bright red")
		Gizmo.setTransparency(0.5)
		Gizmo.drawRay(startPos, endPos)
		Gizmo.reset()
	end)

	task.delay(0.5, function()
		drawRay:Disconnect()
	end)
end

function gears.ParabolaPos(startPos, endPos, height, progress)
	local lerpPos = startPos + (endPos - startPos) * progress
	local y = startPos.Y + (height * 4 * progress * (1 - progress))
	return CFrame.new(Vector3.new(lerpPos.X, y, lerpPos.Z))
end

function gears.CirclePos(startPos, radius, progress)
	-- progress = (progress + 0.01) % (math.pi * 2)
	local x = startPos + math.cos(progress) * radius
	local y = startPos + math.sin(progress) * radius
	return x, y
end

function gears.SpherePos(startPos, latitude, longitude, radius)
	local x = startPos.x + math.sin(latitude) * math.cos(longitude) * radius
	local y = startPos.y + math.sin(latitude) * math.sin(longitude) * radius
	local z = startPos.z + math.cos(latitude) * radius
	return Vector3.new(x, y, z)
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
		local progress = i / steps -- This moves from 0 to 1
		item.CFrame = gears.ParabolaPos(startPos, finalTargetPos, height, progress)
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
	print("Spawn Banana")
	local newBanana = banana:Clone()

	gears.LootMovement(newBanana, spawnPosition)
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
