--!strict
-- NIGHTSHIFT server entry point (bootstrap).
-- No systems registered yet. Phase 1+ will add services under src/server/systems|services.
-- Server is authoritative for economy, ownership, rewards, and race outcomes (see AGENTS.md).

local ServerMain = {}

function ServerMain.start(): ()
	warn("[NIGHTSHIFT] Server bootstrap: no systems registered (Phase 0).")
end

ServerMain.start()

return ServerMain
