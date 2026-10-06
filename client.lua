local RCBoat
local Driver
local Camera
local OpponentBoatNetId
local MyBoatHealth = Config.StartingHealth
local OpponentBoatHealth = Config.StartingHealth
local IsInGame = false
local TorpedoPrompts
local SelfDestructPrompts
local RCBoatPromptGroups

local function Notify(desc, duration)
	exports.bln_notify:send({
		title = "RC Boat Battle",
		description = desc,
		placement = Config.NotifyPlacement,
		duration = duration or 4000
	})
end

function PrepareSoundset(soundsetName, p1)
	return Citizen.InvokeNative(0xD9130842D7226045, soundsetName, p1)
end

function PlaySoundFromPosition(audioName, x, y, z, audioRef, isNetwork, p6, p7, p8)
	return Citizen.InvokeNative(0xCCE219C922737BFA, audioName, x, y, z, audioRef, isNetwork, p6, p7, p8)
end

function RemoveSoundset(soundsetName)
	return Citizen.InvokeNative(0x531A78D6BF27014B, soundsetName)
end

function IsUsingKeyboard(padIndex)
	return Citizen.InvokeNative(0xA571D46727E2B718, padIndex)
end

function BlipAddForEntity(blipHash, entity)
	return Citizen.InvokeNative(0x23F74C2FDA6E7C61, blipHash, entity)
end

function LoadModel(model)
	if not IsModelInCdimage(model) then
		return false
	end
	RequestModel(model)
	while not HasModelLoaded(model) do
		Citizen.Wait(0)
	end
	return true
end

function CreateRCBoat()
	LoadModel(Config.RCBoatModel)
	local playerPed = PlayerPedId()
	local playerPos = GetEntityCoords(playerPed)
	local playerYaw = GetEntityHeading(playerPed)
	local r = math.rad(-playerYaw)
	local spawnPos = playerPos + vector3(5 * math.sin(r), 5 * math.cos(r), 0)
	local rcboat = CreateVehicle(Config.RCBoatModel, spawnPos, playerYaw, true, false, false, false)
	SetModelAsNoLongerNeeded(Config.RCBoatModel)
	SetEntityHealth(rcboat, Config.StartingHealth)
	if Config.RCBoatBlip then
		BlipAddForEntity(Config.RCBoatBlip, rcboat)
	end
	return rcboat
end

function CreateDriver()
	LoadModel(Config.DriverModel)
	local driver = CreatePedInsideVehicle(RCBoat, Config.DriverModel, -1, false, false, false)
	SetModelAsNoLongerNeeded(Config.DriverModel)
	SetEntityVisible(driver, false)
	SetEntityInvincible(driver, true)
	FreezeEntityPosition(driver, true)
	SetBlockingOfNonTemporaryEvents(driver, true)
	SetPedFleeAttributes(driver, 0, false)
	SetPedCanBeTargetted(driver, false)
	SetPedCanBeKnockedOffVehicle(driver, false)
	return driver
end

function DeployRCBoat()
	RCBoat = CreateRCBoat()
	Driver = CreateDriver()
	MyBoatHealth = Config.StartingHealth
	OpponentBoatHealth = Config.StartingHealth
	local netId = NetworkGetNetworkIdFromEntity(RCBoat)
	TriggerServerEvent("mack-rcboats:deployBoat", netId)
	Notify("RC Boat deployed! Waiting for opponent...", 3000)
end

function PlaySound(set, name, coords)
	Citizen.CreateThread(function()
		while not PrepareSoundset(set, 0) do
			Citizen.Wait(0)
		end
		PlaySoundFromPosition(name, coords, set, false, 0, true, 0)
		Citizen.Wait(2000)
		RemoveSoundset(set)
	end)
end

function StowRCBoat()
	if RCBoat then
		DeleteVehicle(RCBoat)
		RCBoat = nil
	end
	if Driver then
		DeletePed(Driver)
		Driver = nil
	end
	if Camera then
		ToggleCamera()
	end
	if IsInGame then
		TriggerServerEvent("mack-rcboats:stowBoat")
		IsInGame = false
	end
	OpponentBoatNetId = nil
	Notify("RC Boat stowed", 2000)
end

function ToggleCamera()
	if Camera then
		RenderScriptCams(false, true, 500, true, true)
		DestroyCam(Camera)
		Camera = nil
	else
		Camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
		AttachCamToEntity(Camera, RCBoat, 0.0, -1.0, 0.4, true)
		RenderScriptCams(true, true, 500, true, true)
	end
end

function Accelerate(prompt)
	TaskVehicleTempAction(Driver, RCBoat, 9, 1)
end

function Deaccelerate(prompt)
	TaskVehicleTempAction(Driver, RCBoat, 6, 2500)
end

function Reverse(prompt)
	TaskVehicleTempAction(Driver, RCBoat, 28, 1)
end

function TurnLeft(prompt)
	if prompt.acceleratePrompt:isControlPressed() then
		TaskVehicleTempAction(Driver, RCBoat, 7, 1)
	elseif prompt.reversePrompt:isControlPressed() then
		TaskVehicleTempAction(Driver, RCBoat, 13, 1)
	else
		TaskVehicleTempAction(Driver, RCBoat, 4, 1)
	end
end

function TurnRight(prompt)
	if prompt.acceleratePrompt:isControlPressed() then
		TaskVehicleTempAction(Driver, RCBoat, 8, 1)
	elseif prompt.reversePrompt:isControlPressed() then
		TaskVehicleTempAction(Driver, RCBoat, 14, 1)
	else
		TaskVehicleTempAction(Driver, RCBoat, 5, 1)
	end
end

local AltPrompts = {}

function AltPrompts:new(prompts)
	self.__index = self
	local self = setmetatable({}, self)
	self.prompts = prompts or {}
	return self
end

function AltPrompts:addPrompt(prompt)
	table.insert(self.prompts, prompt)
end

function AltPrompts:setEnabled(toggle)
	for _, prompt in ipairs(self.prompts) do
		prompt:setEnabled(toggle)
	end
end

function AltPrompts:setText(text)
	for _, prompt in ipairs(self.prompts) do
		prompt:setText(text)
	end
end

TorpedoPrompts = AltPrompts:new()

function FireTorpedo(prompt)
	if not RCBoat then return end
	TorpedoPrompts:setEnabled(false)
	local rcboatCoords = GetEntityCoords(RCBoat)
	local heading = GetEntityHeading(RCBoat)
	LoadModel(Config.TorpedoModel)
	local r = math.rad(-heading)
	local startCoords = rcboatCoords + vector3(2 * math.sin(r), 2 * math.cos(r), 0)
	local torpedo = CreateObjectNoOffset(Config.TorpedoModel, startCoords, true, false, true, false)
	SetModelAsNoLongerNeeded(Config.TorpedoModel)
	SetEntityHeading(torpedo, heading)
	local velocity = vector3(Config.TorpedoSpeed * math.sin(r), Config.TorpedoSpeed * math.cos(r), 0.0)
	SetEntityVelocity(torpedo, velocity)
	NetworkRegisterEntityAsNetworked(torpedo)
	if NetworkGetEntityIsNetworked(torpedo) then
		TriggerServerEvent("mack-rcboats:torpedoFired", rcboatCoords, ObjToNet(torpedo))
	end
	Citizen.CreateThread(function()
		local text = prompt:getText()
		while torpedo do
			local torpedoCoords = GetEntityCoords(torpedo)
			local distance = #(torpedoCoords - startCoords)
			local range = math.floor(Config.TorpedoRange - distance)
			local hitSomething = false
			if OpponentBoatNetId and NetworkDoesNetworkIdExist(OpponentBoatNetId) then
				local opponentBoat = NetToObj(OpponentBoatNetId)
				if DoesEntityExist(opponentBoat) then
					local opponentCoords = GetEntityCoords(opponentBoat)
					local distToOpponent = #(torpedoCoords - opponentCoords)
					if distToOpponent < Config.HitDetectionRange then
						hitSomething = true
						TriggerServerEvent("mack-rcboats:torpedoHitBoat", OpponentBoatNetId, torpedoCoords)
					end
				end
			end
			if HasEntityCollidedWithAnything(torpedo) or range <= 0 or hitSomething then
				if not hitSomething then
					AddExplosion(torpedoCoords - vector3(0, 0, 0.5), 23, Config.ExplosionDamageScale, true, false, 1.0)
				end
				DeleteObject(torpedo)
				torpedo = nil
			else
				SetEntityVelocity(torpedo, velocity)
				TorpedoPrompts:setText(text .. " (" .. range .. "m)")
			end
			Citizen.Wait(0)
		end
		for secs = Config.TorpedoCooldown, 1, -1 do
			TorpedoPrompts:setText(text .. " (" .. secs .. "s)")
			Citizen.Wait(1000)
		end
		TriggerServerEvent("mack-rcboats:torpedoReloaded", GetEntityCoords(RCBoat))
		TorpedoPrompts:setText(text)
		TorpedoPrompts:setEnabled(true)
	end)
end

function ExplodeRCBoat()
	AddExplosion(GetEntityCoords(RCBoat) - vector3(0, 0, 0.5), 23, Config.SelfDestructDamage, true, false, 1.0)
	SetEntityHealth(RCBoat, 0)
end

SelfDestructPrompts = AltPrompts:new()

function SelfDestruct(prompt)
	SelfDestructPrompts:setEnabled(false)
	Citizen.CreateThread(function()
		local text = prompt:getText()
		for secs = Config.SelfDestructTime, 1, -1 do
			SelfDestructPrompts:setText("~COLOR_RED~" .. text .. " in " .. secs .. "s")
			Citizen.Wait(1000)
		end
		ExplodeRCBoat()
		SelfDestructPrompts:setText(text)
		SelfDestructPrompts:setEnabled(true)
	end)
end

local function SetupPrompts()
	RCBoatPromptGroups = AltPrompts:new()
	local RCBoatPrompts = UipromptGroup:new("RC Boat")
	local AcceleratePrompt = Uiprompt:new(`INPUT_FRONTEND_UP`, "Accelerate", RCBoatPrompts)
	AcceleratePrompt:setOnControlPressed(Accelerate)
	AcceleratePrompt:setOnControlJustReleased(Deaccelerate)
	local ReversePrompt = Uiprompt:new(`INPUT_FRONTEND_DOWN`, "Reverse", RCBoatPrompts)
	ReversePrompt:setOnControlPressed(Reverse)
	ReversePrompt:setOnControlJustReleased(Deaccelerate)
	local TurnLeftPrompt = Uiprompt:new(`INPUT_FRONTEND_LEFT`, "Turn Left", RCBoatPrompts)
	TurnLeftPrompt:setOnControlPressed(TurnLeft)
	TurnLeftPrompt.acceleratePrompt = AcceleratePrompt
	TurnLeftPrompt.reversePrompt = ReversePrompt
	local TurnRightPrompt = Uiprompt:new(`INPUT_FRONTEND_RIGHT`, "Turn Right", RCBoatPrompts)
	TurnRightPrompt:setOnControlPressed(TurnRight)
	TurnRightPrompt.acceleratePrompt = AcceleratePrompt
	TurnRightPrompt.reversePrompt = ReversePrompt
	local ToggleCameraPrompt = Uiprompt:new(`INPUT_FRONTEND_ACCEPT`, "Toggle Camera", RCBoatPrompts)
	ToggleCameraPrompt:setHoldMode(true)
	ToggleCameraPrompt:setOnHoldModeJustCompleted(ToggleCamera)
	local TorpedoPrompt = Uiprompt:new(`INPUT_GAME_MENU_EXTRA_OPTION`, "Fire Torpedo", RCBoatPrompts)
	TorpedoPrompt:setOnControlJustReleased(FireTorpedo)
	TorpedoPrompts:addPrompt(TorpedoPrompt)
	local SelfDestructPrompt = Uiprompt:new(`INPUT_FRONTEND_CANCEL`, "Self-destruct", RCBoatPrompts)
	SelfDestructPrompt:setHoldMode(true)
	SelfDestructPrompt:setOnHoldModeJustCompleted(SelfDestruct)
	SelfDestructPrompts:addPrompt(SelfDestructPrompt)
	RCBoatPromptGroups:addPrompt(RCBoatPrompts)
	local AltRCBoatPrompts = UipromptGroup:new("RC Boat")
	local AltAcceleratePrompt = Uiprompt:new(`INPUT_FRONTEND_UP`, "Accelerate", AltRCBoatPrompts)
	AltAcceleratePrompt:setOnControlPressed(Accelerate)
	AltAcceleratePrompt:setOnControlJustReleased(Deaccelerate)
	local AltReversePrompt = Uiprompt:new(`INPUT_FRONTEND_DOWN`, "Reverse", AltRCBoatPrompts)
	AltReversePrompt:setOnControlPressed(Reverse)
	AltReversePrompt:setOnControlJustReleased(Deaccelerate)
	local AltTurnLeftPrompt = Uiprompt:new(`INPUT_FRONTEND_LB`, "Turn Left", AltRCBoatPrompts)
	AltTurnLeftPrompt:setOnControlPressed(TurnLeft)
	AltTurnLeftPrompt.acceleratePrompt = AltAcceleratePrompt
	AltTurnLeftPrompt.reversePrompt = AltReversePrompt
	local AltTurnRightPrompt = Uiprompt:new(`INPUT_FRONTEND_RB`, "Turn Right", AltRCBoatPrompts)
	AltTurnRightPrompt:setOnControlPressed(TurnRight)
	AltTurnRightPrompt.acceleratePrompt = AltAcceleratePrompt
	AltTurnRightPrompt.reversePrompt = AltReversePrompt
	local AltToggleCameraPrompt = Uiprompt:new(`INPUT_FRONTEND_ACCEPT`, "Toggle Camera", AltRCBoatPrompts)
	AltToggleCameraPrompt:setHoldMode(true)
	AltToggleCameraPrompt:setOnHoldModeJustCompleted(ToggleCamera)
	local AltTorpedoPrompt = Uiprompt:new(`INPUT_GAME_MENU_EXTRA_OPTION`, "Fire Torpedo", AltRCBoatPrompts)
	AltTorpedoPrompt:setOnControlJustReleased(FireTorpedo)
	TorpedoPrompts:addPrompt(AltTorpedoPrompt)
	local AltSelfDestructPrompt = Uiprompt:new(`INPUT_FRONTEND_CANCEL`, "Self-destruct", AltRCBoatPrompts)
	AltSelfDestructPrompt:setHoldMode(true)
	AltSelfDestructPrompt:setOnHoldModeJustCompleted(SelfDestruct)
	SelfDestructPrompts:addPrompt(AltSelfDestructPrompt)
	RCBoatPromptGroups:addPrompt(AltRCBoatPrompts)
end

-- ox_lib menu
local function OpenRCMenu()
	local options = {}
	if RCBoat then
		options[#options + 1] = { label = "Stow RC Boat", icon = "times-circle", args = { action = "stow" } }
	else
		options[#options + 1] = { label = "Deploy RC Boat", icon = "ship", args = { action = "deploy" } }
	end
	options[#options + 1] = { label = "Close", icon = "arrow-left" }
	lib.registerMenu({
		id = "mack_rcboats_menu",
		title = "RC Boat Battle",
		position = "top-right",
		options = options
	}, function(selected, scrollIndex, args)
		if args and args.action == "deploy" then
			DeployRCBoat()
		elseif args and args.action == "stow" then
			StowRCBoat()
		end
	end)
	lib.showMenu("mack_rcboats_menu")
end

RegisterCommand("rcboat", function()
	if not RCBoat then
		OpenRCMenu()
	else
		OpenRCMenu()
	end
end, false)

AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() == resourceName and RCBoat then
		StowRCBoat()
	end
end)

-- Network events
AddEventHandler("mack-rcboats:opponentBoat", function(boatNetId)
	OpponentBoatNetId = boatNetId
	if NetworkDoesNetworkIdExist(boatNetId) then
		local boat = NetToObj(boatNetId)
		if DoesEntityExist(boat) then
			BlipAddForEntity(Config.RCBoatBlip, boat)
		end
	end
end)

AddEventHandler("mack-rcboats:gameStarted", function()
	IsInGame = true
	Notify("Battle started! Sink the enemy boat!", 5000)
end)

AddEventHandler("mack-rcboats:opponentLeft", function()
	OpponentBoatNetId = nil
	OpponentBoatHealth = Config.StartingHealth
	if IsInGame then
		Notify("Opponent left the battle", 3000)
		IsInGame = false
	end
end)

AddEventHandler("mack-rcboats:torpedoFired", function(torpedoCoords, torpedoNetId)
	PlaySound("RCKPT1_Sounds", "TORPEDO_FIRE", torpedoCoords)
	if NetworkDoesNetworkIdExist(torpedoNetId) then
		UseParticleFxAsset("scr_crackpot")
		StartParticleFxLoopedOnEntity("scr_crackpot_torpedo_spray", NetToObj(torpedoNetId), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, false, false, false)
	end
end)

AddEventHandler("mack-rcboats:torpedoReloaded", function(boatCoords)
	PlaySound("RCKPT1_Sounds", "BOAT_RELOAD", boatCoords)
end)

AddEventHandler("mack-rcboats:explosionAt", function(hitCoords)
	AddExplosion(hitCoords - vector3(0, 0, 0.5), 23, Config.ExplosionDamageScale, true, false, 1.0)
end)

AddEventHandler("mack-rcboats:boatDamaged", function(boatNetId, health)
	if boatNetId == NetworkGetNetworkIdFromEntity(RCBoat) then
		MyBoatHealth = health
		SetEntityHealth(RCBoat, health)
		Notify("~red~Direct hit!~e~ Your boat: " .. math.floor(health) .. " HP remaining", 2500)
	elseif boatNetId == OpponentBoatNetId then
		OpponentBoatHealth = health
		Notify("~green~Hit!~e~ Enemy: " .. math.floor(health) .. " HP remaining", 2500)
	end
end)

AddEventHandler("mack-rcboats:boatDestroyed", function(boatNetId)
	if boatNetId == NetworkGetNetworkIdFromEntity(RCBoat) then
		Notify("~red~Your boat was destroyed! You lose!", 6000)
		StowRCBoat()
	elseif boatNetId == OpponentBoatNetId then
		Notify("~green~Enemy boat destroyed! You win!", 6000)
		OpponentBoatNetId = nil
		OpponentBoatHealth = Config.StartingHealth
		IsInGame = false
	end
end)

Citizen.CreateThread(function()
	TriggerEvent("chat:addSuggestion", "/rcboat", "Open the RC Boat Battle menu to deploy or stow your boat")
end)

SetupPrompts()

Citizen.CreateThread(function()
	while true do
		if RCBoat then
			if IsUsingKeyboard(0) then
				RCBoatPromptGroups.prompts[1]:handleEvents()
			else
				RCBoatPromptGroups.prompts[2]:handleEvents()
			end
			if Camera then
				if IsControlJustPressed(0, `INPUT_LOOK_BEHIND`) then
					AttachCamToEntity(Camera, RCBoat, 0.0, 1.0, 0.4, true)
				end
				if IsControlJustReleased(0, `INPUT_LOOK_BEHIND`) then
					AttachCamToEntity(Camera, RCBoat, 0.0, -1.0, 0.4, true)
				end
				if IsControlPressed(0, `INPUT_LOOK_BEHIND`) then
					SetCamRot(Camera, GetEntityRotation(RCBoat) + vector3(0, 0, 180))
				else
					SetCamRot(Camera, GetEntityRotation(RCBoat))
				end
			end
		end
		Citizen.Wait(0)
	end
end)

Citizen.CreateThread(function()
	local cautionShown = false
	while true do
		if RCBoat then
			local playerPed = PlayerPedId()
			local playerCoords = GetEntityCoords(playerPed)
			local rcBoatCoords = GetEntityCoords(RCBoat)
			local distance = #(playerCoords - rcBoatCoords)
			local rcBoatHealth = GetEntityHealth(RCBoat)
			if not DoesEntityExist(Driver) then
				Driver = CreateDriver()
			elseif GetPedInVehicleSeat(RCBoat, -1) ~= Driver then
				DeletePed(Driver)
				Driver = CreateDriver()
			end
			if rcBoatHealth == 0 then
				StowRCBoat()
			elseif IsPedDeadOrDying(playerPed) or distance > Config.ControlRange then
				ExplodeRCBoat()
			end
			local colour
			if distance > Config.ControlRange - Config.WarningRange then
				colour = "~COLOR_RED~"
			elseif distance > Config.ControlRange - Config.CautionRange then
				colour = "~COLOR_YELLOW~"
				if not cautionShown then
					Notify("Stay within range or the RC boat will self-destruct!", 5000)
					cautionShown = true
				end
			else
				colour = "~COLOR_WHITE~"
				cautionShown = false
			end
			local opponentInfo = ""
			if OpponentBoatNetId and NetworkDoesNetworkIdExist(OpponentBoatNetId) then
				local opponentBoat = NetToObj(OpponentBoatNetId)
				if DoesEntityExist(opponentBoat) then
					local oppCoords = GetEntityCoords(opponentBoat)
					local oppDist = #(rcBoatCoords - oppCoords)
					opponentInfo = " | Enemy: " .. math.floor(OpponentBoatHealth) .. "HP (" .. math.floor(oppDist) .. "m)"
				end
			end
			RCBoatPromptGroups:setText("RC Boat - " .. math.floor(MyBoatHealth) .. "HP (" .. colour .. math.floor(distance) .. "m~COLOR_WHITE~)" .. opponentInfo)
		end
		Citizen.Wait(500)
	end
end)
