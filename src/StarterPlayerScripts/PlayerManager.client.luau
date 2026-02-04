local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Events = ReplicatedStorage.Shared

local player = game.Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local level = leaderstats:WaitForChild("Level")

local playerGui = player:WaitForChild("PlayerGui")

local screenGui = playerGui:WaitForChild("ScreenGui")
local levelText = screenGui:WaitForChild("LevelText")
local levelUpButton = screenGui:WaitForChild("Lvl+Button")

local cardGui = playerGui:WaitForChild("CardGui")
local card_01 = cardGui:WaitForChild("Card_01")
local card_02 = cardGui:WaitForChild("Card_02")
local card_03 = cardGui:WaitForChild("Card_03")

local levelUpEvent = Events.LevelUp

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
	if gameProcessed then
		return
	end

	local keyName = UserInputService:GetStringForKeyCode(input.KeyCode)

	if keyName:lower() == "a" then
		cardGui.Enabled = true
	end
end)

level.Changed:Connect(function()
	levelText.Text = "Level : " .. level.Value
end)

local function PrintAugmentChoice(augment)
	print("1] : Type = " .. augment[1] .. " Rarity = " .. augment[2] .. " Value : " .. augment[2])
end

levelUpEvent.OnClientEvent:Connect(function(augmentsChoice)
	levelUpButton.Visible = true
	print("Augment Choices :")
	PrintAugmentChoice(augmentsChoice[1])
	PrintAugmentChoice(augmentsChoice[2])
	PrintAugmentChoice(augmentsChoice[3])
end)

levelUpButton.MouseButton1Click:Connect(function()
	cardGui.Enabled = true
end)

local function ChooseCard(choiceNbr)
	cardGui.Enabled = false
	levelUpButton.Visible = false
	levelUpEvent:FireServer(choiceNbr)
end

card_01.MouseButton1Click:Connect(function()
	ChooseCard(1)
end)

card_02.MouseButton1Click:Connect(function()
	ChooseCard(2)
end)

card_03.MouseButton1Click:Connect(function()
	ChooseCard(3)
end)
