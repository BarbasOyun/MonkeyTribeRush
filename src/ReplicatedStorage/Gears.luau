local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Gizmo = require(ReplicatedStorage.Shared.gizmo)

local gears = {}
local smallXpOrb = ReplicatedStorage.Prefabs:WaitForChild("SmallXpOrb")

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

function gears.SpawnXP(spawnPosition)
	-- print("Spawn XP Orb")
	local newOrb = smallXpOrb:Clone()

	newOrb.Position = spawnPosition
	newOrb.Parent = workspace.XP_Orbs
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
