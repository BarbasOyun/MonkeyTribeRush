-- Services
local DataStoreService = game:GetService("DataStoreService"):GetOrderedDataStore("Wins")
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
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

	local uiInfos = Instance.new("Folder")
	uiInfos.Parent = player
	uiInfos.Name = "UIInfos"

	PlayersStats.CreatePlayer(player, leaderstats, uiInfos)

	-- TODO : At the end of the Game
	local kills = leaderstats:WaitForChild("Kills")
	-- kills.Changed:Connect(function()
	-- 	DataStoreService:SetAsync(player.UserId, kills.Value)
	-- end)
end)

local function GetXp(xpOrb)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
	end
	xpOrb:Destroy()
end

local function GrabXp(charater, xpOrb)
	-- print("xpOrb Found")
	if not xpOrb.Parent then
		return
	end

	if xpOrb.Parent ~= workspace.XP_Orbs then
		return
	end

	xpOrb.Parent = game.Workspace
	xpOrb.CanCollide = false

	-- Lerp XP
	local startPos = xpOrb.CFrame

	local steps = 60

	for i = 1, steps do
		local alpha = i / steps -- This moves from 0 to 1
		xpOrb.CFrame = startPos:Lerp(charater:GetPivot(), alpha)
		RunService.Heartbeat:Wait()
	end

	GetXp(xpOrb)
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
		local range = PlayersStats[player].pickupRange
			* Gears.IncreaseToMultiplier(PlayersStats[player].increasedPickupRange)

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position, range, params)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXp(character, xpOrb)
		end
	end
end

RunService.Heartbeat:Connect(XpGrabRange)
