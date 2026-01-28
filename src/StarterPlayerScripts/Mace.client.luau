local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer.Name

-- Mace Client -> Input +  Animation
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = character:WaitForChild("Humanoid")

local attackEvent = Events.ToolAttack
local equipEvent = Events.ToolEquip

local animationTrack
local animator = Humanoid:WaitForChild("Animator")

local function loadAnimation()
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://522635514" -- R6 slash animation
	animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action
end

loadAnimation()

equipEvent.OnClientEvent:Connect(function(isEquipped)
	print("Mace Equipped: " .. tostring(isEquipped) .. " for player: " .. Username)
end)

--Attack Triggered
attackEvent.OnClientEvent:Connect(function()
	--print("Animation for player: " .. Username)
	animationTrack:Play()
end)

--Try to Attack
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then -- or input.KeyCode == Enum.KeyCode.E then
		attackEvent:FireServer(LocalPlayer)
	end
end)
