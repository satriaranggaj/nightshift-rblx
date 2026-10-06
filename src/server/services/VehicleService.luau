--!strict
-- NIGHTSHIFT vehicle occupancy service (server, authoritative).
-- Owns the driver lifecycle: entry/exit validation, seat assignment, network
-- ownership, driver-state replication, death/disconnect cleanup.
--
-- Contract: clients send INTENT only — ProximityPrompt triggers (server-bound)
-- and the RequestExitVehicle RemoteEvent. The server decides every outcome and
-- replicates it via the NIGHTSHIFT_DriverUserId attribute (0 = unoccupied).
-- Never trust client-supplied instances, prices, or "I am the driver" claims.
--
-- Minimal bounded scope (Phase 2I): one interaction pair per vehicle, no
-- passengers, no ownership/persistence/economy. Required by the rig (or any
-- future builder) via registerVehicle; no auto-discovery chains.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)
local DriverState = require(ReplicatedStorage.Shared.vehicle.DriverState)

local NET_FOLDER_NAME = "NIGHTSHIFT_Net"
local EXIT_REMOTE_NAME = "RequestExitVehicle"
local ENTER_DISTANCE = 12
local REQUEST_COOLDOWN = 0.75
local EXIT_LIFT = 2.5

export type VehicleRecord = {
	model: Model,
	seat: Seat,
	entryPart: BasePart,
	exitPoint: Instance,
	prompt: ProximityPrompt,
	driver: number,
	driverPlayer: Player?,
	diedConn: RBXScriptConnection?,
}

local VehicleService = {}

-- Single test vehicle in Phase 2I (multi-vehicle registry is Phase 11 scope);
-- the record is captured by the prompt/remote closures below.
local playerVehicle: { [Player]: VehicleRecord } = {}
local lastRequest: { [Player]: number } = {}

-- Networking seam (Phase 2I): exactly one client→server intent remote.
-- Entry intent arrives via the server-bound ProximityPrompt instead.
local netFolder: Folder
do
	local found = ReplicatedStorage:FindFirstChild(NET_FOLDER_NAME)
	if found ~= nil and found:IsA("Folder") then
		netFolder = found
	else
		netFolder = Instance.new("Folder")
		netFolder.Name = NET_FOLDER_NAME
		netFolder.Parent = ReplicatedStorage
	end
end
local exitRemote: RemoteEvent
do
	local found = netFolder:FindFirstChild(EXIT_REMOTE_NAME)
	if found ~= nil and found:IsA("RemoteEvent") then
		exitRemote = found
	else
		exitRemote = Instance.new("RemoteEvent")
		exitRemote.Name = EXIT_REMOTE_NAME
		exitRemote.Parent = netFolder
	end
end

local function exitPositionOf(exitPoint: Instance): Vector3
	if exitPoint:IsA("Attachment") then
		return exitPoint.WorldPosition
	end
	if exitPoint:IsA("BasePart") then
		return exitPoint.Position
	end
	return Vector3.zero
end

local function checkRateLimit(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

local function release(record: VehicleRecord, withTeleport: boolean, reason: string): ()
	if record.diedConn ~= nil then
		record.diedConn:Disconnect()
		record.diedConn = nil
	end
	local player = record.driverPlayer
	if player ~= nil then
		playerVehicle[player] = nil
		local character = player.Character
		local humanoid: Humanoid? = nil
		local root: BasePart? = nil
		if character ~= nil then
			local found = character:FindFirstChildOfClass("Humanoid")
			if found ~= nil then
				humanoid = found :: Humanoid
			end
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp ~= nil and hrp:IsA("BasePart") then
				root = hrp
			end
		end
		if humanoid ~= nil and humanoid.SeatPart == record.seat then
			humanoid.Sit = false
			humanoid.Jump = true
		end
		if withTeleport and root ~= nil then
			root.CFrame = CFrame.new(exitPositionOf(record.exitPoint) + Vector3.new(0, EXIT_LIFT, 0))
		end
	end
	record.driver = 0
	record.driverPlayer = nil
	record.model:SetAttribute(VehicleContract.DRIVER_ATTRIBUTE, 0)
	record.prompt.Enabled = true
	local chassis = VehicleContract.resolveRoot(record.model)
	if chassis ~= nil then
		local ok, err = pcall(function()
			chassis:SetNetworkOwner(nil)
		end)
		if not ok then
			warn("[NIGHTSHIFT Vehicle] ownership release failed: " .. tostring(err))
		end
	end
	print("[NIGHTSHIFT Vehicle] Released (" .. reason .. ").")
end

local function enter(record: VehicleRecord, player: Player, humanoid: Humanoid): ()
	record.driver = player.UserId
	record.driverPlayer = player
	record.model:SetAttribute(VehicleContract.DRIVER_ATTRIBUTE, player.UserId)
	record.prompt.Enabled = false
	playerVehicle[player] = record
	record.seat:Sit(humanoid)
	local chassis = VehicleContract.resolveRoot(record.model)
	if chassis ~= nil then
		local ok, err = pcall(function()
			chassis:SetNetworkOwner(player)
		end)
		if not ok then
			warn("[NIGHTSHIFT Vehicle] SetNetworkOwner failed: " .. tostring(err))
		else
			local owner = chassis:GetNetworkOwner()
			print(
				"[NIGHTSHIFT Vehicle] Driver "
					.. player.Name
					.. " seated; assemblyOwner="
					.. (if owner ~= nil then owner.Name else "<server/none>")
			)
		end
	end
	record.diedConn = humanoid.Died:Connect(function()
		release(record, false, "driver died")
	end)
end

-- All 11 entry validations. Returns (allowed, reason).
local function validateEnter(record: VehicleRecord, player: Player): (boolean, string, Humanoid?)
	if typeof(player) ~= "Instance" or not (player :: any):IsA("Player") or player.Parent ~= Players then
		return false, "unknown player", nil
	end
	local character = player.Character
	if character == nil then
		return false, "no character", nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid == nil then
		return false, "no humanoid", nil
	end
	if humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
		return false, "humanoid unavailable", nil
	end
	if record.model.Parent == nil then
		return false, "vehicle gone", nil
	end
	if record.model:GetAttribute(VehicleContract.READY_ATTRIBUTE) ~= true then
		return false, "vehicle not ready", nil
	end
	local complete, _ = VehicleContract.isComplete(record.model)
	if not complete then
		return false, "vehicle incomplete", nil
	end
	if record.seat.Parent == nil then
		return false, "seat gone", nil
	end
	local allowed, transition = DriverState.tryEnter(record.driver, player.UserId)
	if not allowed then
		return false, tostring(transition), nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp == nil or not (hrp :: any):IsA("BasePart") then
		return false, "no root part", nil
	end
	if ((hrp :: BasePart).Position - record.entryPart.Position).Magnitude > ENTER_DISTANCE then
		return false, "too far", nil
	end
	if playerVehicle[player] ~= nil then
		return false, "already driving", nil
	end
	if not checkRateLimit(player) then
		return false, "too fast", nil
	end
	return true, "ok", humanoid
end

function VehicleService.registerVehicle(model: Model): (boolean, string)
	local complete, reason = VehicleContract.isComplete(model)
	if not complete then
		return false, reason
	end
	local seat = VehicleContract.findSeat(model)
	if seat == nil then
		return false, "missing DriverSeat"
	end
	local entryPart = model:FindFirstChild(VehicleContract.DRIVER_ENTRY_NAME)
	if entryPart == nil or not entryPart:IsA("BasePart") then
		return false, "missing DriverEntry"
	end
	local exitPoint = model:FindFirstChild(VehicleContract.DRIVER_EXIT_NAME)
	if exitPoint == nil then
		return false, "missing DriverExitPoint"
	end
	local prompt = entryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		return false, "missing entry prompt"
	end
	local record: VehicleRecord = {
		model = model,
		seat = seat :: Seat,
		entryPart = entryPart,
		exitPoint = exitPoint,
		prompt = prompt,
		driver = 0,
		driverPlayer = nil,
		diedConn = nil,
	}
	model:SetAttribute(VehicleContract.DRIVER_ATTRIBUTE, 0)
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player: Player)
		local humanoid: Humanoid? = nil
		local allowed, why, found = validateEnter(record, player)
		humanoid = found
		if not allowed or humanoid == nil then
			warn("[NIGHTSHIFT Vehicle] Enter rejected (" .. tostring(player) .. "): " .. why)
			return
		end
		enter(record, player, humanoid)
	end)
	return true, "ok"
end

exitRemote.OnServerEvent:Connect(function(player: Player)
	local record = playerVehicle[player]
	if record == nil then
		return
	end
	if not checkRateLimit(player) then
		return
	end
	local allowed, why = DriverState.tryExit(record.driver, player.UserId)
	if not allowed then
		warn("[NIGHTSHIFT Vehicle] Exit rejected (" .. tostring(player) .. "): " .. tostring(why))
		return
	end
	release(record, true, "driver exit")
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local record = playerVehicle[player]
	if record ~= nil then
		release(record, false, "player left")
	end
	lastRequest[player] = nil
end)

return VehicleService
