local Players = game:GetService("Players")
local PlayersStats = require(script.Parent.PlayersStats)

Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " has joined the game!")
	PlayersStats.CreatePlayer(player)
end)
