local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage.Shared
local player = game.Players.LocalPlayer

-- UI
local uiData = player:WaitForChild("UIData")
local bananasCount = uiData.Bananas

local playerGUI = player:WaitForChild("PlayerGui")
local platformSound = playerGUI:WaitForChild("Sounds").PlatformSound
local bananaText = playerGUI.MainUI.BananaNbrText
local loadingText = playerGUI.MainUI.LoadingText

-- Upgrade Tree
local maxIncrements = 10

local upgradeBoard = playerGUI.UpgradeBoardGUI
local loadingFrame = upgradeBoard.Loading

local upgradeTree = {
	upgradeBoard.AttackDamage,
	upgradeBoard.AttackSpeed,
	upgradeBoard.AOE,
	upgradeBoard.CritChance,
	upgradeBoard.CritMulti,
	upgradeBoard.MaxLife,
	upgradeBoard.LifeRegen,
	upgradeBoard.DR,
	upgradeBoard.Mobility,
	upgradeBoard.PickupRadius,
	upgradeBoard.IncrXP,
	upgradeBoard.Luck,
}

-- Events
local platformTouched = ReplicatedStorage.Shared:WaitForChild("PlatformTouched")

local function AskUpgradeTree(index)
	Events.UpgradeTree:FireServer(index)
end

local function UpdateUpgradeDisplay(index, lvl, statValue, cost, displayText)
	upgradeTree[index].Title.Text = displayText .. lvl .. " / " .. maxIncrements
	upgradeTree[index].StatText.Text = statValue
	upgradeTree[index].CostText.Text = "Cost : " .. cost .. " Bananas"
end

local function InitUi()
	-- upgradeTree[1].MouseButton1Click:Connect(function()
	-- 	print("Asking for Attack Damage")
	-- 	Events.UpgradeTree:FireServer(1)
	-- end)

	for i, upgradeButton in ipairs(upgradeTree) do
		upgradeButton.MouseButton1Click:Connect(function()
			-- print("Asking for Upgrade : " .. i)
			loadingFrame.Visible = true
			Events.UpgradeTree:FireServer(i)
		end)
	end
end

local function OnCharacterAdded(character)
	-- Re Get UI
end

-- Player Events

player.CharacterAdded:Connect(OnCharacterAdded)

platformTouched.OnClientEvent:Connect(function()
	-- print("Platform Touched Event")
	platformSound:Play()
	loadingText.Visible = true
end)

bananasCount.Changed:Connect(function()
	bananaText.Text = bananasCount.Value
end)

-- Upgrade Tree Events
Events.GetFullStageData.OnClientEvent:Connect(function(maximumIncrements, playerData)
	maxIncrements = maximumIncrements

	bananaText.Text = playerData[1].Value

	local upgradeTreeData = playerData[2]

	for index, upgradeData in ipairs(upgradeTreeData) do
		UpdateUpgradeDisplay(index, upgradeData.lvl, upgradeData.statValue, upgradeData.cost, upgradeData.displayText)
	end
end)

Events.UpgradeTree.OnClientEvent:Connect(function(success, index, upgradeData)
	loadingFrame.Visible = false

	if success then
		UpdateUpgradeDisplay(index, upgradeData.lvl, upgradeData.statValue, upgradeData.cost, upgradeData.displayText)
	end
end)

-- Do
InitUi()
