-- Services
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Variables
local frameCount = 0
local targetFrame = 5

-- GetXP Parameters
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.XP_Orbs }
params.MaxParts = 50

local function GrabXP(xpOrb)
	print("xpOrb Found")
	xpOrb.Parent = game.Workspace
end

local function GetXP()
	if frameCount < targetFrame then
		frameCount += 1
		return
	end

	frameCount = 0

	for _, player in pairs(game.Players:GetChildren()) do
		-- print(player.Name)
		local position = player.Character.HumanoidRootPart.CFrame
		local range = PlayersStats[player].xpGrabRange

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position.Position, range, params)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXP(xpOrb)
		end
	end
end

task.delay(1, function()
	RunService.Heartbeat:Connect(GetXP)
end)
