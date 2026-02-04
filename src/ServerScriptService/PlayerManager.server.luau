-- Services
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- local Gears = require(ReplicatedStorage.Shared.Gears)

-- Variables
local frameCount = 0
local targetFrame = 5

-- XpGrabRange Parameters
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.XP_Orbs }
params.MaxParts = 50

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game!")

	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	PlayersStats.CreatePlayer(player, leaderstats)
end)

local function GetXp(xpOrb)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	end
	xpOrb.Parent = nil
end

local function GrabXp(charater, xpOrb)
	-- print("xpOrb Found")
	xpOrb.CanCollide = false
	xpOrb.Parent = game.Workspace

	-- On Collision
	local connection

	local function TouchEvent(otherPart)
		if Players:GetPlayerFromCharacter(otherPart:FindFirstAncestorWhichIsA("Model")) then
			-- print("XP Orb Touched Player")
			if connection then
				connection:Disconnect()
			end
			GetXp(xpOrb)
		end
	end

	connection = xpOrb.Touched:Connect(TouchEvent)

	-- Lerp
	local startPos = xpOrb.CFrame

	local steps = 60
	local overSteps = steps * 0.9
	-- local duration = 1 -- seconds
	-- local waitTime = duration / steps

	for i = 1, steps do
		local alpha = i / overSteps -- This moves from 0 to 1
		xpOrb.CFrame = startPos:Lerp(charater:GetPivot(), alpha)
		-- task.wait(waitTime)
		RunService.Heartbeat:Wait()
	end

	-- Finish XP Movement
	-- RunService.Heartbeat:Connect(function()
	-- 	xpOrb.CFrame = startPos:Lerp(charater:GetPivot(), alpha)
	-- end)
end

local function XpGrabRange()
	if frameCount < targetFrame then
		frameCount += 1
		return
	end

	frameCount = 0

	for _, player in pairs(game.Players:GetChildren()) do
		-- print(player.Name)
		local character = player.Character or player.CharacterAdded:Wait()
		local position = character.HumanoidRootPart.CFrame.Position
		local range = PlayersStats[player].xpGrabRange

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position, range, params)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXp(character, xpOrb)
		end
	end
end

RunService.Heartbeat:Connect(XpGrabRange)
