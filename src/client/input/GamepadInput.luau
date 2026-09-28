--!strict
-- NIGHTSHIFT gamepad input adapter (STUB — real mapping deferred).
-- Same adapter interface as KeyboardInput/TouchInput. Future work maps
-- thumbsticks/triggers through deadzones and the shared sanitizer; analog
-- values must still clamp to the VehicleInput contract, which is enforced at
-- the emission point here, never in vehicle physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleInput = require(ReplicatedStorage.Shared.vehicle.VehicleInput)

local GamepadInput = {}

local intent: VehicleInput.VehicleInput = VehicleInput.neutral()

function GamepadInput.start(): ()
	-- No listeners yet; real gamepad mapping is deferred past Phase 1.
end

function GamepadInput.stop(): ()
	GamepadInput.reset()
end

function GamepadInput.reset(): ()
	intent = VehicleInput.neutral()
end

-- Debug/extension entry point (same contract as TouchInput.setIntent).
function GamepadInput.setIntent(partial: any): ()
	intent = VehicleInput.sanitize(partial)
end

function GamepadInput.getInput(): VehicleInput.VehicleInput
	return intent
end

return GamepadInput
