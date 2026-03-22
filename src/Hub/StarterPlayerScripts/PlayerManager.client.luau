local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

-- UI
local bananasCount = player.UIData.Bananas

local playerGUI = player:WaitForChild("PlayerGui")
local platformSound = playerGUI:WaitForChild("Sounds").PlatformSound
local bananaText = playerGUI.MainUI.BananaNbrText
local loadingText = playerGUI.MainUI.LoadingText

local platformTouched = ReplicatedStorage.Shared:WaitForChild("PlatformTouched")

platformTouched.OnClientEvent:Connect(function()
	-- print("Platform Touched Event")
	platformSound:Play()
	loadingText.Visible = true
end)

bananasCount.Changed:Connect(function()
	bananaText.Text = bananasCount.Value
end)

-- Update Bananas
bananaText.Text = bananasCount.Value
