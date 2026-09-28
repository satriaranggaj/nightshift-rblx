--!strict
-- NIGHTSHIFT shared foundational types.
-- Bootstrap only: normalized contracts, no gameplay logic, no business rules.
-- Full ownership/persistence schema is intentionally deferred (see docs/ROADMAP.md).
-- Do not silently change these contracts; treat changes as breaking (see AGENTS.md).

export type VehicleInput = {
	-- Normalized 0..1. Auto-throttle policies live in platform input layers, not here.
	throttle: number,
	-- Normalized 0..1.
	brake: number,
	-- Normalized -1..1 (negative = left, positive = right).
	steer: number,
	drift: boolean,
	nitro: boolean,
}

export type VehicleUUID = string
export type ModelId = string

-- Minimal identity stub. Deferred: mileage, parts, stats, vinyl, etc.
export type OwnedVehicleIdentity = {
	vehicleUuid: VehicleUUID,
	ownerUserId: number,
	modelId: ModelId,
}

-- Explicit race lifecycle (contract only; no implementation yet).
export type RaceState = "CREATED" | "WAITING" | "READY" | "COUNTDOWN" | "RUNNING" | "FINISHED" | "CANCELLED"

return nil
