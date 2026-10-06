--!strict
-- NIGHTSHIFT vehicle structural contract (shared, pure).
-- Single source of truth for what makes a vehicle Model attach-ready, used by
-- the server builder, the client controller, and the wiring between them.
-- No services, no instances created here; fully unit-testable with mocks.
--
-- Why an explicit root part instead of Model.PrimaryPart: PrimaryPart does not
-- reliably replicate to clients for server-constructed models, so attachment
-- must never depend on it. The root part has a stable name; replication
-- readiness is signalled explicitly via an attribute set AFTER construction +
-- parenting. A vehicle is attachable only when BOTH hold:
--   structural completeness (isComplete: the named root BasePart exists), AND
--   replication readiness (READY_ATTRIBUTE == true: the full structure arrived).
-- The attribute is the replication signal; isComplete is the structure check.
-- Client wiring waits for both, in either arrival order.

local VehicleContract = {}

-- Stable identity of the single rigid root BasePart (assembly welded to it).
VehicleContract.ROOT_PART_NAME = "Chassis"

-- Set to true by the builder as its LAST step (post-parent). Clients wait on
-- this (event-driven, never a sleep) before resolving the root part.
VehicleContract.READY_ATTRIBUTE = "NIGHTSHIFT_Ready"

-- Server-written driver occupancy (UserId; 0 = unoccupied). Clients read only.
VehicleContract.DRIVER_ATTRIBUTE = "NIGHTSHIFT_DriverUserId"

-- Predictable interaction structure (Phase 2I). The seat positions the
-- Humanoid and identifies the driver; it never implements driving physics.
VehicleContract.DRIVER_SEAT_NAME = "DriverSeat"
VehicleContract.DRIVER_ENTRY_NAME = "DriverEntry"
VehicleContract.DRIVER_EXIT_NAME = "DriverExitPoint"

-- Deterministic structural-completeness check (NOT the replication signal).
-- Accepts real Instances or mock tables exposing FindFirstChild(string);
-- rejects everything else with a reason.
function VehicleContract.isComplete(model: any): (boolean, string)
	if typeof(model) ~= "table" and typeof(model) ~= "Instance" then
		return false, "model must be a Model"
	end
	local find = (model :: any).FindFirstChild
	if typeof(find) ~= "function" then
		return false, "model cannot resolve children"
	end
	local root: any = find(model, VehicleContract.ROOT_PART_NAME)
	if root == nil then
		return false, "model is missing its '" .. VehicleContract.ROOT_PART_NAME .. "' root part"
	end
	local isA = (root :: any).IsA
	if typeof(isA) ~= "function" or isA(root, "BasePart") ~= true then
		return false, "root part '" .. VehicleContract.ROOT_PART_NAME .. "' must be a BasePart"
	end
	return true, "ok"
end

-- Single root-resolution path: the named stable root, or nil. Never PrimaryPart.
function VehicleContract.resolveRoot(model: any): BasePart?
	local complete, _ = VehicleContract.isComplete(model)
	if not complete then
		return nil
	end
	return (model :: any):FindFirstChild(VehicleContract.ROOT_PART_NAME) :: BasePart
end

-- Interaction-structure lookup: the driver Seat, or nil. Accepts real
-- Instances or mock tables; never errors on malformed input.
function VehicleContract.findSeat(model: any): any
	if typeof(model) ~= "table" and typeof(model) ~= "Instance" then
		return nil
	end
	local find = (model :: any).FindFirstChild
	if typeof(find) ~= "function" then
		return nil
	end
	local seat: any = find(model, VehicleContract.DRIVER_SEAT_NAME)
	if seat == nil then
		return nil
	end
	local isA = (seat :: any).IsA
	if typeof(isA) ~= "function" then
		return nil
	end
	if isA(seat, "Seat") or isA(seat, "VehicleSeat") then
		return seat
	end
	return nil
end

return VehicleContract
