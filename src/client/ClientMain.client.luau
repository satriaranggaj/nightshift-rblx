--!strict
-- NIGHTSHIFT client entry point (bootstrap).
-- No controllers registered yet. Phase 1+ adds input/vehicle/camera controllers here.
-- Client never grants currency, ownership, rewards, or progression (see AGENTS.md).

local ClientMain = {}

function ClientMain.start(): ()
	warn("[NIGHTSHIFT] Client bootstrap: no controllers registered (Phase 0).")
end

ClientMain.start()

return ClientMain
