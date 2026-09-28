--!strict
-- NIGHTSHIFT shared constants (bootstrap).
-- Configuration only: value tables, no runtime behavior, no business logic.
-- Stat calculation and economy rules live server-side later; never duplicate them here.

local Constants = {
	-- Canonical bounds for the normalized VehicleInput contract (see Types.luau).
	InputBounds = {
		ThrottleMin = 0,
		ThrottleMax = 1,
		BrakeMin = 0,
		BrakeMax = 1,
		SteerMin = -1,
		SteerMax = 1,
	},
}

return Constants
