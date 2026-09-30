--!strict
-- NIGHTSHIFT vehicle structural contract (shared, pure).
-- Single source of truth for what makes a vehicle Model attach-ready, used by
-- the server builder, the client controller, and the wiring between them.
-- No services, no instances created here; fully unit-testable with mocks.
--
-- Why an explicit root part instead of Model.PrimaryPart: PrimaryPart does not
-- reliably replicate to clients for server-constructed models, so attachment
-- must never depend on it. The root part has a stable name; readiness is
-- signalled explicitly via an attribute set AFTER construction + parenting.
-- A vehicle is ready only when the complete structural contract exists.

local VehicleContract = {}

-- Stable identity of the single rigid root BasePart (assembly welded to it).
VehicleContract.ROOT_PART_NAME = "Chassis"

-- Set to true by the builder as its LAST step (post-parent). Clients wait on
-- this (event-driven, never a sleep) before resolving the root part.
VehicleContract.READY_ATTRIBUTE = "NIGHTSHIFT_Ready"

-- Deterministic readiness check. Accepts real Instances or mock tables
-- exposing FindFirstChild(string); rejects everything else with a reason.
function VehicleContract.isReady(model: any): (boolean, string)
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

return VehicleContract
