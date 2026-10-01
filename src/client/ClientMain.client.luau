--!strict
-- NIGHTSHIFT client entry point.
-- Phase 2 wires input + the arcade VehicleController onto the dev rig vehicle.
-- No camera, gameplay, garage, or economy systems yet.
-- Client never grants currency, ownership, rewards, or progression (see AGENTS.md).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local inputFolder = script.Parent.input
local controllersFolder = script.Parent.controllers

local InputController = require(inputFolder.InputController)
local KeyboardInput = require(inputFolder.KeyboardInput)
local TouchInput = require(inputFolder.TouchInput)
local GamepadInput = require(inputFolder.GamepadInput)
local InputDebug = require(inputFolder.InputDebug)
local VehicleController = require(controllersFolder.VehicleController)
local ChassisConfig = require(ReplicatedStorage.Shared.config.ChassisConfig)
local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)

-- TEMPORARY Phase 1+2: normalized-input readout until a debug UI exists.
local DEBUG_INPUT = true

-- TEMPORARY Phase 2D: bounded physics snapshot (~1Hz, only under input).
-- Remove once the stationary-vehicle cause is measured.
local DEBUG_PHYSICS = true

local ClientMain = {}

-- Event-driven vehicle readiness (no sleeps, no timeouts): returns once the
-- Model exists locally AND the replication attribute is true AND the named
-- root part exists AND structural validation passes — regardless of whether
-- the attribute or the root arrives first. Spurious wakeups just re-check.
function ClientMain.waitForVehicleReady(vehicle: Instance): ()
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

function ClientMain.start(): ()
	local input = InputController.new()
	-- Priority order: keyboard, gamepad, touch (first non-neutral wins).
	input:register(KeyboardInput)
	input:register(GamepadInput)
	input:register(TouchInput)
	input:startAll()

	if DEBUG_INPUT then
		InputDebug.start(input)
	end

	-- DEV-ONLY Phase 2: attach to the rig vehicle (server-built test blockout).
	-- A freshly replicated Model shell is never mistaken for a ready vehicle.
	local rig = Workspace:WaitForChild("NIGHTSHIFT_Rig")
	local vehicle = rig:WaitForChild("TestBlockout")
	ClientMain.waitForVehicleReady(vehicle)
	if vehicle:IsA("Model") then
		local driver = VehicleController.new(input, ChassisConfig.TEST_BLOCKOUT)
		driver:setDiagnosticsEnabled(DEBUG_PHYSICS)
		local ok, message = driver:attach(vehicle)
		if ok then
			warn("[NIGHTSHIFT] VehicleController attached (Phase 2).")
		else
			warn("[NIGHTSHIFT] VehicleController attach failed: " .. message)
		end
	else
		warn("[NIGHTSHIFT] Rig vehicle missing; input-only mode.")
	end
end

ClientMain.start()

return ClientMain
