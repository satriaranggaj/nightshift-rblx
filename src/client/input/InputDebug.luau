--!strict
-- TEMPORARY Phase 1 diagnostic: prints normalized VehicleInput on change.
-- Remove (or gate behind a proper debug UI) in Phase 2; it must not ship as a
-- gameplay feature. Exists only to validate adapters without a vehicle.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleInput = require(ReplicatedStorage.Shared.vehicle.VehicleInput)

local InputDebug = {}

local connection: RBXScriptConnection? = nil
local last: VehicleInput.VehicleInput? = nil

local function format(state: VehicleInput.VehicleInput): string
	return string.format(
		"[NIGHTSHIFT Input] throttle=%.2f brake=%.2f steer=%.2f drift=%s nitro=%s",
		state.throttle,
		state.brake,
		state.steer,
		tostring(state.drift),
		tostring(state.nitro)
	)
end

-- `getInput` is any object exposing `getInput()` (the InputController).
function InputDebug.start(source: { getInput: (any) -> VehicleInput.VehicleInput }): ()
	if connection ~= nil then
		return
	end
	last = nil
	connection = RunService.Heartbeat:Connect(function()
		local state = VehicleInput.sanitize(source:getInput())
		if last == nil or not VehicleInput.equals(last, state) then
			last = state
			print(format(state))
		end
	end)
end

function InputDebug.stop(): ()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	last = nil
end

return InputDebug
