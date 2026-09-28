--!strict
-- NIGHTSHIFT input multiplexer (client).
-- Aggregates registered platform adapters into one VehicleInput. Deterministic
-- rule: first non-neutral adapter in registration order wins; otherwise
-- neutral. Registration order is set once by the caller (ClientMain), so
-- adapter priority is explicit and reviewable in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleInput = require(ReplicatedStorage.Shared.vehicle.VehicleInput)

export type InputAdapter = {
	start: () -> (),
	stop: () -> (),
	reset: () -> (),
	getInput: () -> VehicleInput.VehicleInput,
}

local InputController = {}
InputController.__index = InputController

export type InputController = typeof(setmetatable(
	{} :: {
		_adapters: { InputAdapter },
	},
	InputController
))

function InputController.new(): InputController
	return setmetatable({ _adapters = {} }, InputController)
end

function InputController.register(self: InputController, adapter: InputAdapter): ()
	table.insert(self._adapters, adapter)
end

function InputController.startAll(self: InputController): ()
	for _, adapter in self._adapters do
		adapter.start()
	end
end

function InputController.stopAll(self: InputController): ()
	for _, adapter in self._adapters do
		adapter.stop()
	end
end

function InputController.reset(self: InputController): ()
	for _, adapter in self._adapters do
		adapter.reset()
	end
end

function InputController.getInput(self: InputController): VehicleInput.VehicleInput
	for _, adapter in self._adapters do
		local state = VehicleInput.sanitize(adapter.getInput())
		if not VehicleInput.isNeutral(state) then
			return state
		end
	end
	return VehicleInput.neutral()
end

return InputController
