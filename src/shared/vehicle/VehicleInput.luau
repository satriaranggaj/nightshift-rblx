--!strict
-- NIGHTSHIFT normalized vehicle-input domain (shared, pure).
-- Single sanitization path for every platform adapter (keyboard, touch, gamepad)
-- and for future server-side re-validation. No Roblox service dependencies, so
-- this module is unit-testable without physics or device input.
--
-- Normalization rules (deterministic, documented):
-- * throttle/brake clamp to 0..1, steer clamps to -1..1.
-- * NaN, non-number, or missing numerics fall back to the neutral default (0),
--   because NaN would otherwise contaminate downstream math (NaN comparisons
--   are always false, so clamping alone cannot contain it).
-- * Infinite values clamp to the bound (documented; adapters should not emit them).
-- * drift/nitro are strict: only literal `true` passes. Anything else is false,
--   so a malformed payload can never latch an action on.
-- * Simultaneous left+right resolves to neutral steer (see combineSteer).
-- * W+S (throttle+brake) are reported independently; arbitration is the future
--   vehicle simulation's job, not the input layer's.

local Types = require(script.Parent.Parent.Types)

export type VehicleInput = Types.VehicleInput

local VehicleInput = {}

function VehicleInput.neutral(): VehicleInput
	return {
		throttle = 0,
		brake = 0,
		steer = 0,
		drift = false,
		nitro = false,
	}
end

local function sanitizeAxis(value: any, min: number, max: number): number
	if typeof(value) ~= "number" then
		return 0
	end
	local n: number = value
	if n ~= n then
		-- NaN: fall back to neutral rather than propagating.
		return 0
	end
	return math.clamp(n, min, max)
end

function VehicleInput.sanitize(raw: any): VehicleInput
	if typeof(raw) ~= "table" then
		return VehicleInput.neutral()
	end
	local input: any = raw
	return {
		throttle = sanitizeAxis(input.throttle, 0, 1),
		brake = sanitizeAxis(input.brake, 0, 1),
		steer = sanitizeAxis(input.steer, -1, 1),
		drift = input.drift == true,
		nitro = input.nitro == true,
	}
end

-- Deterministic digital-steer resolution: both sides held (A+D) is neutral.
function VehicleInput.combineSteer(leftHeld: boolean, rightHeld: boolean): number
	if leftHeld == rightHeld then
		return 0
	elseif leftHeld then
		return -1
	else
		return 1
	end
end

function VehicleInput.isNeutral(state: VehicleInput): boolean
	return state.throttle == 0
		and state.brake == 0
		and state.steer == 0
		and state.drift == false
		and state.nitro == false
end

function VehicleInput.equals(a: VehicleInput, b: VehicleInput): boolean
	return a.throttle == b.throttle
		and a.brake == b.brake
		and a.steer == b.steer
		and a.drift == b.drift
		and a.nitro == b.nitro
end

return VehicleInput
