--!strict
-- NIGHTSHIFT arcade chassis simulation (shared, pure).
-- Deterministic step function: (input, measured speeds, previous steer, config, dt)
-- -> per-step motion targets. No instances, no services; fully unit-testable.
-- The client VehicleController measures real velocities, calls step(), and
-- converts targets into constraint forces. Server-side re-simulation (Phase 11)
-- can reuse this exact function for plausibility checks.
--
-- Forward policy (first match wins; throttle and brake stay independent in the
-- input layer, arbitration happens HERE and is documented):
-- 1. throttle held and not meaningfully reversing -> drive toward throttle target.
-- 2. brake held at/near stop (fwd <= reverseThreshold) -> reverse toward brake target.
-- 3. any longitudinal intent otherwise (braking while fast, throttling while
--    reversing) -> oppose motion toward 0 at brakeDecel, never auto-flip.
-- 4. no longitudinal intent -> coast toward 0 (never an instant stop).
-- Lateral target is always 0 at lateralGrip rate (Phase 6 will modulate this).
-- Yaw is smoothed steer * steerYawRate, scaled down near standstill so the car
-- cannot spin in place. drift/nitro are read (contract-stable) but have NO
-- effect until Phase 6/7; the manual matrix must observe exactly that.

local Types = require(script.Parent.Parent.Types)
local ChassisConfigModule = require(script.Parent.Parent.config.ChassisConfig)

export type VehicleInput = Types.VehicleInput
export type ChassisConfig = ChassisConfigModule.ChassisConfig

export type ChassisStep = {
	targetForwardSpeed: number,
	forwardRate: number,
	lateralRate: number,
	steerOut: number,
	yawRate: number,
}

local ArcadeChassis = {}

local VehicleInputModule = require(script.Parent.VehicleInput)

function ArcadeChassis.validateConfig(config: any): (boolean, string)
	if typeof(config) ~= "table" then
		return false, "config must be a table"
	end
	local positive = {
		"maxForwardSpeed",
		"maxReverseSpeed",
		"forwardAccel",
		"reverseAccel",
		"brakeDecel",
		"coastDecel",
		"steerYawRate",
		"steerSmooth",
		"lateralGrip",
		"uprightResponsiveness",
		"yawTorqueFactor",
		"maxForceAccel",
	}
	for _, key in positive do
		local value = (config :: any)[key]
		if typeof(value) ~= "number" or value ~= value or value <= 0 then
			return false, key .. " must be a positive finite number"
		end
	end
	local nonNegative = { "reverseThreshold", "uprightMaxTorque" }
	for _, key in nonNegative do
		local value = (config :: any)[key]
		if typeof(value) ~= "number" or value ~= value or value < 0 then
			return false, key .. " must be a non-negative finite number"
		end
	end
	return true, "ok"
end

-- Pure velocity-approach helper used by the controller to convert step targets
-- into per-step velocity deltas. Same dt-clamp convention as step(); non-finite
-- or non-positive rates command zero delta (never NaN, never a jump).
function ArcadeChassis.approachVelocity(current: number, target: number, rate: number, dt: number): number
	local c = if current == current then current else 0
	local t = if target == target then target else c
	if rate ~= rate or rate <= 0 then
		return 0
	end
	local stepDt = if dt ~= dt or dt <= 0 then 1 / 60 else math.min(dt, 1 / 20)
	return math.clamp(t - c, -rate * stepDt, rate * stepDt)
end

function ArcadeChassis.step(
	rawInput: any,
	forwardSpeed: number,
	prevSteer: number,
	config: ChassisConfig,
	dt: number
): ChassisStep
	local input: VehicleInput = VehicleInputModule.sanitize(rawInput)
	local fwd = if forwardSpeed == forwardSpeed then forwardSpeed else 0
	local prev = if prevSteer == prevSteer then math.clamp(prevSteer, -1, 1) else 0
	local stepDt = if dt ~= dt or dt <= 0 then 1 / 60 else math.min(dt, 1 / 20)

	local target: number
	local rate: number
	if input.throttle > 0 and fwd >= -0.5 then
		target = input.throttle * config.maxForwardSpeed
		rate = config.forwardAccel
	elseif input.brake > 0 and fwd <= config.reverseThreshold then
		target = -input.brake * config.maxReverseSpeed
		rate = config.reverseAccel
	elseif input.brake > 0 or input.throttle > 0 then
		-- Covers braking while fast AND throttling while reversing: oppose
		-- motion toward a stop at brakeDecel, never auto-flip direction.
		target = 0
		rate = config.brakeDecel
	else
		target = 0
		rate = config.coastDecel
	end

	local steerOut = prev + math.clamp(input.steer - prev, -config.steerSmooth * stepDt, config.steerSmooth * stepDt)
	steerOut = math.clamp(steerOut, -1, 1)
	local speedFactor = math.clamp(math.abs(fwd) / 4, 0, 1)
	local yawRate = steerOut * config.steerYawRate * speedFactor

	return {
		targetForwardSpeed = target,
		forwardRate = rate,
		lateralRate = config.lateralGrip,
		steerOut = steerOut,
		yawRate = yawRate,
	}
end

return ArcadeChassis
