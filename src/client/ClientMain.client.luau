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

local ClientMain = {}

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
	-- Readiness invariant (event-driven, never a sleep): the rig sets
	-- NIGHTSHIFT_Ready only after the structural contract is complete, so a
	-- freshly replicated Model shell can never be mistaken for a ready vehicle.
	local rig = Workspace:WaitForChild("NIGHTSHIFT_Rig")
	local vehicle = rig:WaitForChild("TestBlockout")
	if vehicle:GetAttribute(VehicleContract.READY_ATTRIBUTE) ~= true then
		vehicle:GetAttributeChangedSignal(VehicleContract.READY_ATTRIBUTE):Wait()
	end
	vehicle:WaitForChild(VehicleContract.ROOT_PART_NAME)
	if vehicle:IsA("Model") then
		local driver = VehicleController.new(input, ChassisConfig.TEST_BLOCKOUT)
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
