--!strict
-- NIGHTSHIFT touch input adapter (STUB — Phase 3 owns the real UI).
-- Exposes the same adapter interface as KeyboardInput so the controller and
-- future vehicle code never branch on platform. Touch UI is explicitly out of
-- Phase 1 scope; this stub holds a programmatic intent (driven from the
-- command bar or future UI) and always emits sanitized VehicleInput.
--
-- Phase 3 seam: real touch controls (buttons/tilt, smoothing, speed-sensitive
-- steer, auto-throttle hook) will replace the intent source, not the interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleInput = require(ReplicatedStorage.Shared.vehicle.VehicleInput)

local TouchInput = {}

local intent: VehicleInput.VehicleInput = VehicleInput.neutral()

function TouchInput.start(): ()
	-- No listeners yet; Phase 3 connects touch UI here.
end

function TouchInput.stop(): ()
	TouchInput.reset()
end

function TouchInput.reset(): ()
	intent = VehicleInput.neutral()
end

-- Debug/extension entry point: inject a (possibly partial) intent; output is
-- always sanitized. Example from the command bar:
--   TouchInput.setIntent({ throttle = 1, steer = -0.5 })
function TouchInput.setIntent(partial: any): ()
	intent = VehicleInput.sanitize(partial)
end

function TouchInput.getInput(): VehicleInput.VehicleInput
	return intent
end

return TouchInput
