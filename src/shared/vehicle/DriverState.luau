--!strict
-- NIGHTSHIFT driver-occupancy transitions (shared, pure).
-- Single authority for "who may enter / who may exit" logic. The server
-- VehicleService owns the live registry and calls these; specs pin them.
-- Driver is a UserId; 0 means unoccupied. No instances, no services.

local DriverState = {}

export type DriverId = number

function DriverState.isOccupied(driver: DriverId): boolean
	return driver ~= 0
end

-- Returns (allowed, newDriver | reason).
function DriverState.tryEnter(current: DriverId, requester: DriverId): (boolean, any)
	if requester == 0 then
		return false, "invalid requester"
	end
	if current ~= 0 then
		if current == requester then
			return false, "already driving"
		end
		return false, "occupied"
	end
	return true, requester
end

function DriverState.tryExit(current: DriverId, requester: DriverId): (boolean, any)
	if current == 0 then
		return false, "unoccupied"
	end
	if current ~= requester then
		return false, "not the driver"
	end
	return true, 0
end

return DriverState
