local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Gizmo = require(ReplicatedStorage.Shared.gizmo)

local gears = {}

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

return gears
