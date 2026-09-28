--!strict
-- NIGHTSHIFT chassis configuration (data only).
-- Pure value tables: no behavior, no services, no imports. All tuning lives
-- here so simulation (ArcadeChassis) and the controller never hardcode feel.
-- Validation logic lives in ArcadeChassis.validateConfig, not here.
--
-- Units: speeds studs/s, accel rates studs/s^2, yaw rad/s, stiffness/damping
-- in AlignOrientation units, forces derived from assembly mass at runtime.

export type ChassisConfig = {
	maxForwardSpeed: number,
	maxReverseSpeed: number,
	forwardAccel: number,
	reverseAccel: number,
	brakeDecel: number,
	coastDecel: number,
	-- Full-lock yaw rate at standstill reference; scaled by speed in simulation.
	steerYawRate: number,
	-- Minimal Phase-2 steer smoothing (1/s lerp rate). Phase 5 owns curves.
	steerSmooth: number,
	-- Lateral velocity kill rate (1/s). The future drift hook (Phase 6).
	lateralGrip: number,
	-- |forward speed| at/below which held brake engages reverse.
	reverseThreshold: number,
	-- Prototype upright assist (isolated; see ArcadeChassis).
	uprightStiffness: number,
	uprightDamping: number,
	uprightMaxTorque: number,
	-- Yaw authority scale (x assembly mass) for the AngularVelocity constraint.
	yawTorqueFactor: number,
	-- Numeric safety cap: total applied force accel never exceeds this (studs/s^2).
	maxForceAccel: number,
}

-- Conservative starter values for the blockout rig. All numbers are HUMAN
-- TUNING CANDIDATES: feel must be validated in Studio (mobile + PC) and
-- adjusted here, never by forking logic into the controller.
local ChassisConfig = {
	TEST_BLOCKOUT = {
		maxForwardSpeed = 60,
		maxReverseSpeed = 20,
		forwardAccel = 30,
		reverseAccel = 20,
		brakeDecel = 60,
		coastDecel = 8,
		steerYawRate = 1.6,
		steerSmooth = 6,
		lateralGrip = 10,
		reverseThreshold = 2,
		uprightStiffness = 1500,
		uprightDamping = 300,
		uprightMaxTorque = 50000,
		yawTorqueFactor = 40,
		maxForceAccel = 150,
	} :: ChassisConfig,
}

return ChassisConfig
