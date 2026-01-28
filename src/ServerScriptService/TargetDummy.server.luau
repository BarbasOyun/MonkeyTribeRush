--Target Dummy by LegoMasterMaker
--Updated by RedRocStudio

local CollectionService = game:GetService("CollectionService")

local function setupDummy(dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local clone = dummy:Clone()

	if not humanoid then
		warn("TargetDummy missing Humanoid:", dummy.Name)
		return
	end

	-- Respawn
	humanoid.Died:Connect(function()
		print(dummy.Name .. " Died")
		task.wait(1)
		clone.Parent = workspace
		dummy:Destroy()
	end)

	--[[ humanoid.HealthChanged:Connect(function(health)
		print(dummy.Name .. " health: " .. health)
	end) ]]

	local anchor = script:GetAttribute("Anchor")

	if anchor and dummy:FindFirstChild("HumanoidRootPart") then
		dummy.HumanoidRootPart.Anchored = true
	end
end

for _, dummy in pairs(CollectionService:GetTagged("TargetDummy")) do
	setupDummy(dummy)
end

-- New dummies
CollectionService:GetInstanceAddedSignal("TargetDummy"):Connect(setupDummy)
