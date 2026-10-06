--!strict
-- NIGHTSHIFT client entry point.
-- Phase 2I wires input + the driver session (walk → E-enter → drive → E-exit).
-- No camera, gameplay, garage, or economy systems yet.
-- Client never grants currency, ownership, rewards, or progression (see AGENTS.md).

local inputFolder = script.Parent.input
local controllersFolder = script.Parent.controllers

local InputController = require(inputFolder.InputController)
local KeyboardInput = require(inputFolder.KeyboardInput)
local TouchInput = require(inputFolder.TouchInput)
local GamepadInput = require(inputFolder.GamepadInput)
local InputDebug = require(inputFolder.InputDebug)
local VehicleSession = require(controllersFolder.VehicleSession)
local ChassisConfig = require(game:GetService("ReplicatedStorage").Shared.config.ChassisConfig)

-- TEMPORARY Phase 1+2: normalized-input readout until a debug UI exists.
local DEBUG_INPUT = true

-- TEMPORARY Phase 2D: bounded physics snapshot (~1Hz, only under input).
-- Remove once the stationary-vehicle cause is measured.
local DEBUG_PHYSICS = true

-- TEMPORARY Phase 2E: DEV constraint-isolation default. FIRST RETEST MUST USE
-- "FORCE_ONLY" (VectorForce alone). "WITH_YAW" adds AngularVelocity; "FULL" is
-- the intended Phase-2 stack. The NIGHTSHIFT_PhysicsMode model attribute, when
-- set in Studio, overrides this live without re-syncing.
local PHYSICS_ISOLATION = "FULL" -- "FORCE_ONLY" | "WITH_YAW" | "FULL"

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

	-- Phase 2I: no auto-attach. The session attaches VehicleController only
	-- while the server records us as the driver (walk → E-enter → drive).
	local session = VehicleSession.new(input, ChassisConfig.TEST_BLOCKOUT, PHYSICS_ISOLATION, DEBUG_PHYSICS)
	session:start()
end

ClientMain.start()

return ClientMain
