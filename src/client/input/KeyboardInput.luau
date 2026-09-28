--!strict
-- NIGHTSHIFT keyboard input adapter (PC).
-- Translates physical keys into the normalized VehicleInput contract.
-- All KeyCode knowledge lives here; nothing keyboard-specific leaks into the
-- shared contract or future vehicle physics.
--
-- Mapping: W = throttle, S = brake, A = steer left, D = steer right,
-- Space = drift, LeftShift = nitro.
-- Simultaneous A+D resolves to neutral steer (VehicleInput.combineSteer).
-- W+S are reported independently; arbitration belongs to vehicle simulation.
-- Keys consumed by UI (gameProcessedEvent) are ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VehicleInput = require(ReplicatedStorage.Shared.vehicle.VehicleInput)

local THROTTLE_KEYS = { [Enum.KeyCode.W] = true }
local BRAKE_KEYS = { [Enum.KeyCode.S] = true }
local LEFT_KEYS = { [Enum.KeyCode.A] = true }
local RIGHT_KEYS = { [Enum.KeyCode.D] = true }
local DRIFT_KEYS = { [Enum.KeyCode.Space] = true }
local NITRO_KEYS = { [Enum.KeyCode.LeftShift] = true }

local KeyboardInput = {}

local pressed: { [Enum.KeyCode]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function anyPressed(set: { [Enum.KeyCode]: boolean }): boolean
	for key in set do
		if pressed[key] then
			return true
		end
	end
	return false
end

function KeyboardInput.start(): ()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				pressed[input.KeyCode] = true
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				pressed[input.KeyCode] = nil
			end
		end)
	)
end

function KeyboardInput.stop(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(pressed)
	started = false
end

function KeyboardInput.reset(): ()
	table.clear(pressed)
end

function KeyboardInput.getInput(): VehicleInput.VehicleInput
	return VehicleInput.sanitize({
		throttle = if anyPressed(THROTTLE_KEYS) then 1 else 0,
		brake = if anyPressed(BRAKE_KEYS) then 1 else 0,
		steer = VehicleInput.combineSteer(anyPressed(LEFT_KEYS), anyPressed(RIGHT_KEYS)),
		drift = anyPressed(DRIFT_KEYS),
		nitro = anyPressed(NITRO_KEYS),
	})
end

return KeyboardInput
