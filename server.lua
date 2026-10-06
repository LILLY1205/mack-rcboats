local ActiveBoats = {}

RegisterNetEvent("mack-rcboats:deployBoat")
AddEventHandler("mack-rcboats:deployBoat", function(boatNetId)
	ActiveBoats[source] = { boatNetId = boatNetId, health = Config.StartingHealth }

	for playerId, data in pairs(ActiveBoats) do
		if playerId ~= source then
			TriggerClientEvent("mack-rcboats:opponentBoat", playerId, boatNetId)
			TriggerClientEvent("mack-rcboats:opponentBoat", source, data.boatNetId)
		end
	end

	local count = 0
	for _ in pairs(ActiveBoats) do
		count = count + 1
	end
	if count >= 2 then
		for playerId in pairs(ActiveBoats) do
			TriggerClientEvent("mack-rcboats:gameStarted", playerId)
		end
	end
end)

RegisterNetEvent("mack-rcboats:stowBoat")
AddEventHandler("mack-rcboats:stowBoat", function()
	if ActiveBoats[source] then
		ActiveBoats[source] = nil
		TriggerClientEvent("mack-rcboats:opponentLeft", -1)
	end
end)

RegisterNetEvent("mack-rcboats:torpedoHitBoat")
AddEventHandler("mack-rcboats:torpedoHitBoat", function(hitBoatNetId, hitCoords)
	for playerId, data in pairs(ActiveBoats) do
		if data.boatNetId == hitBoatNetId then
			data.health = data.health - Config.TorpedoDamage

			TriggerClientEvent("mack-rcboats:explosionAt", -1, hitCoords)
			TriggerClientEvent("mack-rcboats:boatDamaged", -1, hitBoatNetId, data.health)

			if data.health <= 0 then
				TriggerClientEvent("mack-rcboats:boatDestroyed", -1, hitBoatNetId)
				ActiveBoats[playerId] = nil
			end
			break
		end
	end
end)

RegisterNetEvent("mack-rcboats:torpedoFired")
AddEventHandler("mack-rcboats:torpedoFired", function(torpedoCoords, torpedoNetId)
	TriggerClientEvent("mack-rcboats:torpedoFired", -1, torpedoCoords, torpedoNetId)
end)

RegisterNetEvent("mack-rcboats:torpedoReloaded")
AddEventHandler("mack-rcboats:torpedoReloaded", function(boatCoords)
	TriggerClientEvent("mack-rcboats:torpedoReloaded", -1, boatCoords)
end)

AddEventHandler("playerDropped", function(reason)
	if ActiveBoats[source] then
		ActiveBoats[source] = nil
		TriggerClientEvent("mack-rcboats:opponentLeft", -1)
	end
end)
