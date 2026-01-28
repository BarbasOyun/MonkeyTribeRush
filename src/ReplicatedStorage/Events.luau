local function createRemoteEvent(name)
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = script.Parent
	return remoteEvent
end

--print("Events module loaded")

return {
	TryAttack = createRemoteEvent("TryAttack"),
	ToolAttack = createRemoteEvent("ToolAttack"),
	ToolEquip = createRemoteEvent("ToolEquip"),
}
