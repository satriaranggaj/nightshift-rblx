--!strict
-- NIGHTSHIFT visual-shell adapter (shared).
-- Adapts a Studio-authored visual model (e.g. Visual/R34) into a look-only
-- shell around the physics Chassis: discovers BaseParts recursively,
-- configures visual-only flags, and welds each part to the chassis WITHOUT
-- moving parts (WeldConstraint preserves world placement; relative layout
-- stays exactly as authored). No services required; the creation function
-- defaults to Instance.new and is injectable for deterministic tests.
--
-- Safety rules:
-- * Only plain body parts are welded. Seating/spawn classes (Seat,
--   VehicleSeat, SpawnLocation) are NEVER welded and are reported as skipped,
--   so a stray A-Chassis seat can neither compete nor silently vanish.
-- * Non-BasePart objects (Meshes, SurfaceAppearance, Decals, Attachments,
--   lights, effects, Scripts) are left completely untouched.
-- * Idempotent: a part already carrying our named weld to this chassis is
--   skipped, so repeated runs never stack duplicate welds.

export type VisualScan = {
	parts: { BasePart },
	skipped: { Instance },
}

export type Factory = (className: string) -> any

local VehicleVisualAdapter = {}

VehicleVisualAdapter.WELD_NAME = "NIGHTSHIFT_VisualWeld"

-- Recursive runtime discovery. Works on whatever the Studio hierarchy holds;
-- no mesh names are hardcoded and Rojo source is never required. Seating and
-- spawn classes are reported as skipped (never welded); every other
-- non-BasePart object is ignored entirely.
function VehicleVisualAdapter.collect(visualRoot: Instance): VisualScan
	local parts: { BasePart } = {}
	local skipped: { Instance } = {}
	local descendants: { Instance } = {}
	if visualRoot ~= nil then
		local ok, found = pcall(function()
			return (visualRoot :: any):GetDescendants()
		end)
		if ok and typeof(found) == "table" then
			descendants = found
		end
	end
	for _, obj in descendants do
		local isA = (obj :: any).IsA
		if typeof(isA) == "function" and isA(obj, "BasePart") then
			if isA(obj, "Seat") or isA(obj, "VehicleSeat") or isA(obj, "SpawnLocation") then
				table.insert(skipped, obj :: Instance)
			else
				table.insert(parts, obj :: BasePart)
			end
		end
	end
	return { parts = parts, skipped = skipped }
end

export type AttachStats = {
	welded: number,
	alreadyWelded: number,
	failed: number,
}

function VehicleVisualAdapter.attach(chassis: BasePart, parts: { BasePart }, factory: Factory?): AttachStats
	local create: Factory = if factory ~= nil then factory :: Factory else Instance.new
	local stats: AttachStats = { welded = 0, alreadyWelded = 0, failed = 0 }
	for _, part in parts do
		if part == chassis then
			continue
		end
		local existing = part:FindFirstChild(VehicleVisualAdapter.WELD_NAME)
		if existing ~= nil and existing:IsA("WeldConstraint") then
			local wc = existing :: WeldConstraint
			if wc.Part0 == chassis or wc.Part1 == chassis then
				stats.alreadyWelded += 1
				continue
			end
		end
		local ok, _ = pcall(function()
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			local weld = create("WeldConstraint") :: WeldConstraint
			weld.Name = VehicleVisualAdapter.WELD_NAME
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = chassis
		end)
		if ok then
			stats.welded += 1
		else
			stats.failed += 1
		end
	end
	return stats
end

return VehicleVisualAdapter
