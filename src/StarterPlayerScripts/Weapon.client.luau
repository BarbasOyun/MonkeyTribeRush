-- Weapon Client -> Input +  Animation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared
local Players = game:GetService("Players")

-- Variables
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local animationTracks = {}

-- Remote Events
local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip
local attackHitEvent = Events.AttackHit

local function loadAnimation(animationId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId
	local animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action

	animationTrack:GetMarkerReachedSignal("AttackHit"):Connect(function()
		--print("Hit Event Triggered by player: " .. LocalPlayer.Name)
		attackHitEvent:FireServer(localPlayer)
	end)

	return animationTrack
end

local function loadAllAnimations()
	local horizontalSlash = loadAnimation("rbxassetid://88145589618998") -- Combo 1
	local verticalSlash = loadAnimation("rbxassetid://119339188916178") -- Combo 2

	table.insert(animationTracks, horizontalSlash)
	table.insert(animationTracks, verticalSlash)
end

loadAllAnimations()

equipEvent.OnClientEvent:Connect(function(isEquipped)
	--print("Weapon Equipped: " .. tostring(isEquipped) .. " for player: " .. LocalPlayer.Name)
end)

--Attack Triggered
attackEvent.OnClientEvent:Connect(function(animationId, animationSpeed)
	--print(LocalPlayer.Name .. " Combo: " .. AnimationId .. " Animation Speed: " .. AnimationSpeed)
	animationTracks[animationId]:Play()
	animationTracks[animationId]:AdjustSpeed(animationSpeed)
end)

--Try to Attack
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attackEvent:FireServer(localPlayer)
	end
end)
