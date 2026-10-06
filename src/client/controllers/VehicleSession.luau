--!strict
-- NIGHTSHIFT driver session (client).
-- Owns the local ON_FOOT / IN_VEHICLE state for one player. The SERVER decides
-- occupancy (driver attribute); this session only reacts: attach
-- VehicleController while WE are the recorded driver, detach otherwise.
-- Entry intent comes from the engine ProximityPrompt; exit intent (E) fires
-- the RequestExitVehicle remote. Never writes occupancy state.
--
-- Activation boundary: keyboard input feeds the car ONLY while attached.
-- On foot, WASD drives the character normally and never touches the vehicle.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controllersFolder = script.Parent

local VehicleController = require(controllersFolder.VehicleController)
local ChassisConfig = require(ReplicatedStorage.Shared.config.ChassisConfig)
local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)

local NET_FOLDER_NAME = "NIGHTSHIFT_Net"
local EXIT_REMOTE_NAME = "RequestExitVehicle"

export type SessionState = "ON_FOOT" | "IN_VEHICLE"

local VehicleSession = {}
VehicleSession.__index = VehicleSession

export type VehicleSession = typeof(setmetatable(
	{} :: {
		_input: any,
		_config: ChassisConfig.ChassisConfig,
		_isolation: any,
		_diagnostics: boolean,
		_controller: VehicleController.VehicleController,
		_state: SessionState,
		_vehicle: Model?,
		_exitRemote: RemoteEvent?,
		_myId: number,
	},
	VehicleSession
))

function VehicleSession.new(input: any, config: ChassisConfig.ChassisConfig, isolation: any, diagnostics: boolean)
	local controller = VehicleController.new(input, config)
	controller:setDiagnosticsEnabled(diagnostics)
	controller:setIsolationMode(isolation)
	return setmetatable({
		_input = input,
		_config = config,
		_isolation = isolation,
		_diagnostics = diagnostics,
		_controller = controller,
		_state = "ON_FOOT",
		_vehicle = nil,
		_exitRemote = nil,
		_myId = 0,
	}, VehicleSession)
end

-- Event-driven vehicle readiness (no sleeps, no timeouts). Returns once the
-- Model exists locally AND the replication attribute is true AND the named
-- root part exists AND structural validation passes, in either arrival order.
local function waitForVehicleReady(vehicle: Instance): ()
	local signal = Instance.new("BindableEvent")
	local attrConn: RBXScriptConnection? = nil
	local childConn: RBXScriptConnection? = nil

	local function poke(): ()
		signal:Fire()
	end
	attrConn = vehicle:GetAttributeChangedSignal(VehicleContract.READY_ATTRIBUTE):Connect(poke)
	childConn = vehicle.ChildAdded:Connect(poke)

	while true do
		if vehicle:GetAttribute(VehicleContract.READY_ATTRIBUTE) == true then
			if vehicle:FindFirstChild(VehicleContract.ROOT_PART_NAME) ~= nil then
				local complete, _ = VehicleContract.isComplete(vehicle)
				if complete then
					break
				end
			end
		end
		signal.Event:Wait()
	end

	if attrConn ~= nil then
		attrConn:Disconnect()
	end
	if childConn ~= nil then
		childConn:Disconnect()
	end
	signal:Destroy()
end

function VehicleSession._syncDriver(self: VehicleSession): ()
	local vehicle = self._vehicle
	if vehicle == nil then
		return
	end
	local driver = vehicle:GetAttribute(VehicleContract.DRIVER_ATTRIBUTE)
	local isMe = driver == self._myId and self._myId ~= 0
	if isMe and self._state == "ON_FOOT" then
		local ok, message = self._controller:attach(vehicle)
		if ok then
			self._state = "IN_VEHICLE"
			warn("[NIGHTSHIFT] Driving — press E to exit.")
		else
			warn("[NIGHTSHIFT] VehicleController attach failed: " .. message)
			-- Self-heal a stuck seat: free the server state we cannot use.
			if self._exitRemote ~= nil then
				self._exitRemote:FireServer()
			end
		end
	elseif not isMe and self._state == "IN_VEHICLE" then
		self._controller:detach()
		self._state = "ON_FOOT"
		warn("[NIGHTSHIFT] On foot.")
	end
end

function VehicleSession.start(self: VehicleSession): ()
	local player = Players.LocalPlayer
	if player == nil then
		warn("[NIGHTSHIFT] No LocalPlayer; session disabled.")
		return
	end
	self._myId = player.UserId

	local netFolder = ReplicatedStorage:WaitForChild(NET_FOLDER_NAME, 10)
	if netFolder ~= nil and netFolder:IsA("Folder") then
		local remote = netFolder:WaitForChild(EXIT_REMOTE_NAME, 10)
		if remote ~= nil and remote:IsA("RemoteEvent") then
			self._exitRemote = remote
		end
	end
	if self._exitRemote == nil then
		warn("[NIGHTSHIFT] Exit remote missing; E-to-exit disabled.")
	end

	-- DEV-ONLY Phase 2I: single rig vehicle (server-built test blockout).
	local rig = Workspace:WaitForChild("NIGHTSHIFT_Rig")
	local vehicle = rig:WaitForChild("TestBlockout")
	waitForVehicleReady(vehicle)
	if not vehicle:IsA("Model") then
		warn("[NIGHTSHIFT] Rig vehicle missing; input-only mode.")
		return
	end
	self._vehicle = vehicle
	vehicle:GetAttributeChangedSignal(VehicleContract.DRIVER_ATTRIBUTE):Connect(function()
		self:_syncDriver()
	end)
	self:_syncDriver()

	-- E-to-exit: connected ONCE (never per-enter). Active only IN_VEHICLE;
	-- ignored while chat/text consumes the keystroke.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if self._state ~= "IN_VEHICLE" then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.E then
			return
		end
		if self._exitRemote ~= nil then
			self._exitRemote:FireServer()
		end
	end)

	warn("[NIGHTSHIFT] Session ready (ON_FOOT).")
end

return VehicleSession
