--!strict
-- NIGHTSHIFT client entry point.
-- Phase 1 wires the input stack only (keyboard + stub adapters behind the
-- InputController). No vehicle, camera, or gameplay systems yet.
-- Client never grants currency, ownership, rewards, or progression (see AGENTS.md).

local inputFolder = script.Parent.input

local InputController = require(inputFolder.InputController)
local KeyboardInput = require(inputFolder.KeyboardInput)
local TouchInput = require(inputFolder.TouchInput)
local GamepadInput = require(inputFolder.GamepadInput)
local InputDebug = require(inputFolder.InputDebug)

-- TEMPORARY Phase 1: normalized-input readout until a debug UI exists.
local DEBUG_INPUT = true

local ClientMain = {}

function ClientMain.start(): ()
	local controller = InputController.new()
	-- Priority order: keyboard, gamepad, touch (first non-neutral wins).
	controller:register(KeyboardInput)
	controller:register(GamepadInput)
	controller:register(TouchInput)
	controller:startAll()

	if DEBUG_INPUT then
		InputDebug.start(controller)
	end

	warn("[NIGHTSHIFT] Client input stack ready (Phase 1).")
end

ClientMain.start()

return ClientMain
