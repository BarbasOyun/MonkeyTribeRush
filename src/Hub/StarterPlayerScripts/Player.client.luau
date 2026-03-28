local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage.Shared
local player = game.Players.LocalPlayer

local platformTouched = ReplicatedStorage.Shared.PlatformTouched -- :WaitForChild("PlatformTouched")

-- UI
local uiData = player:WaitForChild("UIData")
local bananasUi = uiData.BananasUi

local playerGUI = player:WaitForChild("PlayerGui")
local platformSound = playerGUI:WaitForChild("Sounds").PlatformSound
local bananaText = playerGUI.MainUI.BananaNbrText
local loadingText = playerGUI.MainUI.LoadingText

-- Donations
local hundredDonationId = 3563342388
local thousandDonationId = 3563893138

local donationBoard = playerGUI:WaitForChild("DonationGUI")
local hundredDonationButton = donationBoard.Donate100
local thousandDonationButton = donationBoard.Donate1000

-- Upgrade Tree
local upgradeTreeData = nil
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

local function UpdateUpgradeDisplay(index, lvl, statValue, cost, displayText)
	upgradeTree[index].Title.Text = displayText .. lvl .. " / " .. maxIncrements
	upgradeTree[index].StatText.Text = statValue
	upgradeTree[index].CostText.Text = "Cost : " .. cost .. " Bananas"
end

local function UpdateAllUpgradeDisplay()
	for index, upgradeData in ipairs(upgradeTreeData) do
		UpdateUpgradeDisplay(index, upgradeData.lvl, upgradeData.statValue, upgradeData.cost, upgradeData.displayText)
	end
end

local function InitUi()
	-- Upgrade Tree
	bananasUi.Changed:Connect(function()
		bananaText.Text = bananasUi.Value
	end)

	for i, upgradeButton in ipairs(upgradeTree) do
		upgradeButton.MouseButton1Click:Connect(function()
			-- print("Asking for Upgrade : " .. i)
			loadingFrame.Visible = true
			Events.UpgradeTree:FireServer(i)
		end)
	end

	-- Donation Events
	hundredDonationButton.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, hundredDonationId)
	end)

	thousandDonationButton.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, thousandDonationId)
	end)
end

-- Respawn
local function OnCharacterAdded(character)
	-- Re-Fetch UI
	uiData = player.UIData -- :WaitForChild("UIData")
	bananasUi = uiData.Bananas

	playerGUI = player:WaitForChild("PlayerGui")
	platformSound = playerGUI:WaitForChild("Sounds").PlatformSound
	bananaText = playerGUI.MainUI.BananaNbrText
	loadingText = playerGUI.MainUI.LoadingText

	bananaText.Text = bananasUi.Value

	-- Donations
	donationBoard = playerGUI:WaitForChild("DonationGUI")
	hundredDonationButton = donationBoard.Donate100
	thousandDonationButton = donationBoard.Donate1000

	-- Upgrade Tree
	upgradeBoard = playerGUI.UpgradeBoardGUI
	loadingFrame = upgradeBoard.Loading

	upgradeTree = {
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

	InitUi()
	UpdateAllUpgradeDisplay()
end

-- Player Events

player.CharacterAdded:Connect(OnCharacterAdded)

platformTouched.OnClientEvent:Connect(function()
	-- print("Platform Touched Event")
	platformSound:Play()
	loadingText.Visible = true
end)

-- Stage Events

Events.GetFullStageData.OnClientEvent:Connect(function(maximumIncrements, playerData)
	maxIncrements = maximumIncrements

	bananaText.Text = playerData[1]
	upgradeTreeData = playerData[2]

	UpdateAllUpgradeDisplay()
end)

-- Upgrade Tree Events

Events.UpgradeTree.OnClientEvent:Connect(function(success, index, upgradeData)
	loadingFrame.Visible = false

	if success then
		upgradeTreeData[index].lvl = upgradeData.lvl
		upgradeTreeData[index].statValue = upgradeData.statValue
		upgradeTreeData[index].cost = upgradeData.cost
		UpdateUpgradeDisplay(index, upgradeData.lvl, upgradeData.statValue, upgradeData.cost, upgradeData.displayText)
	end
end)

-- Do
InitUi()
