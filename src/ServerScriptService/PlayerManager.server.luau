-- Services
local DataStoreService = game:GetService("DataStoreService"):GetOrderedDataStore("Wins")
local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local RunService = game:GetService("RunService")

-- Variables
local frameCount = 0
local targetFrame = 5

-- XpGrabRange Parameters
local xpPickupParam = OverlapParams.new()
xpPickupParam.FilterType = Enum.RaycastFilterType.Include
xpPickupParam.FilterDescendantsInstances = { workspace.XP_Orbs }
xpPickupParam.MaxParts = 50
local getXpSound = workspace.GetXp

local function EquipDefaultWeapon(player)
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	local defaultTool = backpack:FindFirstChild("WoodenClub")
	if defaultTool then
		humanoid:EquipTool(defaultTool)
	end
end

local function GetXp(xpOrb)
	if xpOrb.Name == "SmallXpOrb" then
		-- print("Add Small XP Orb")
		PlayersStats.AddXp(10)
		getXpSound:Play()
	elseif xpOrb.Name == "Banana" then
		print("Banana Collected")
	end

	xpOrb:Destroy()
end

local function GrabXp(character, xpOrb)
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
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		xpOrb.CFrame = startPos:Lerp(character:GetPivot(), progress)
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
		local range = PlayersStats[player.UserId].finalPickupRange

		-- Gears.DisplayHitBox(position, range, 0.1)
		local xpOrbs = workspace:GetPartBoundsInRadius(position, range, xpPickupParam)
		for _, xpOrb in ipairs(xpOrbs) do
			GrabXp(character, xpOrb)
		end
	end
end

RunService.Heartbeat:Connect(XpGrabRange)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game!")

	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = player
	leaderstats.Name = "leaderstats"

	local uiInfos = Instance.new("Folder")
	uiInfos.Parent = player
	uiInfos.Name = "UIInfos"

	PlayersStats.CreatePlayer(player, leaderstats, uiInfos)

	EquipDefaultWeapon(player)

	-- TODO : At the end of the Game
	local kills = leaderstats:WaitForChild("Kills")
	-- kills.Changed:Connect(function()
	-- 	DataStoreService:SetAsync(player.UserId, kills.Value)
	-- end)
end)

local para = workspace.Para
local circle = workspace.Circle
local sphere = workspace.Sphere

RunService.Heartbeat:Connect(function()
	local progress1 = 0
	local progress2 = 0
	local lat = 0
	local long = 0

	para.CFrame = Gears.ParabolaPos(Vector3.new(0, 0, -50), Vector3.new(10, 0, -50), 5, progress1)

	local circlePos = Gears.CirclePos(Vector3.new(15, 5, -50), 5, progress2)
	print(circlePos.x)
	circle.CFrame = CFrame.new(Vector3.new(15, circlePos.x, circlePos.y))

	sphere.CFrame = CFrame.new(Gears.SpherePos(Vector3.new(30, 5, -50), lat, long, 5))

	local maxRad = math.pi * 2
	progress1 = (progress1 + 0.01) % 1
	progress2 = (progress2 + 0.01) % maxRad
	lat = (lat + 0.01) % maxRad
	long = (long + 0.05) % maxRad
end)
