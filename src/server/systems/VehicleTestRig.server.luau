--!strict
-- DEV-ONLY Phase 2 test rig (NOT production content; replaced by the real
-- district in Phase 13). Builds a flat tarmac and one blockout test vehicle.
-- Network ownership now follows the SERVER-VALIDATED driver lifecycle
-- (VehicleService): unoccupied vehicles stay server-owned; the driver owns the
-- assembly only while seated. See VehicleService for validation rules.
--
-- Forward convention: the vehicle's nose points along -Z (Roblox vehicle
-- convention); forward speed is measured on -Chassis.CFrame.LookVector.
-- Single test vehicle (documented limit; multi-vehicle is a Phase 11 concern).
--
-- R34 VISUAL: a Studio-authored shell at Workspace.NIGHTSHIFT_TestVehicle /
-- Visual / R34 (NOT in this repo; Rojo never syncs Workspace) is cloned and
-- adapted at build when present; otherwise the blockout below is used.
-- R34_VISUAL_SOURCE backup and A-Chassis objects are never resolved.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)
local VehicleService = require(script.Parent.Parent.services.VehicleService)
local VehicleVisualAdapter = require(ReplicatedStorage.Shared.vehicle.VehicleVisualAdapter)

local SPAWN_CFRAME = CFrame.new(0, 4, 0)
local RECOVERY_Y = -50

local function weldTo(main: BasePart, part: BasePart): ()
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = main
	weld.Part1 = part
	weld.Parent = main
end

local function buildWheel(chassis: BasePart, visual: Instance, offset: Vector3): ()
	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(1.2, 1.6, 1.6)
	-- Cylinder axis is X by default: axle across the car, rolls around X.
	wheel.CFrame = chassis.CFrame * CFrame.new(offset)
	wheel.CanCollide = false
	wheel.Massless = true
	wheel.Anchored = false
	wheel.Material = Enum.Material.SmoothPlastic
	wheel.Color = Color3.fromRGB(20, 20, 20)
	wheel.Parent = visual
	weldTo(chassis, wheel)
end

local function buildVehicle(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "TestBlockout"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 1.2, 7)
	chassis.CFrame = SPAWN_CFRAME
	chassis.CanCollide = true
	chassis.Anchored = false
	chassis.Material = Enum.Material.SmoothPlastic
	-- DEV-ONLY Phase 2F contact policy: the blockout chassis IS the contact
	-- patch (wheels are visual, CanCollide=false), so default material friction
	-- locks it: breakaway ≈ μ·196 ≫ forwardAccel 30. Explicit low-friction
	-- contact instead of raising drive force (which stays untouched).
	-- density 0.7 preserves the measured assembly mass (~23.5);
	-- frictionWeight 100 dominates the pairwise average against the tarmac so
	-- combined μ ≈ 0.05 → breakaway ≈ 10 < 30. DEV/test-rig values, not tuning.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 1)
	chassis.Color = Color3.fromRGB(200, 60, 40)
	chassis.Parent = model

	-- Visual container (Phase 2I): all look-only geometry lives here, welded
	-- to Chassis, massless, never a contact patch. R34 INTEGRATION: replace
	-- the Blockout folder below with a Model named R34 (Body/Interior/Glass/
	-- Lights/Wheels as massless, CanCollide=false welded parts) after deleting
	-- any Script/LocalScript/ModuleScript/Remote objects inside the import.
	-- No controller changes required; Chassis stays the physics root.
	local visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = model

	local blockout = Instance.new("Folder")
	blockout.Name = "Blockout"
	blockout.Parent = visual

	-- Phase 2I R34 adoption: prefer a Studio-authored Visual/R34 shell when
	-- present. ONLY that path is resolved; R34_VISUAL_SOURCE (backup), DriveSeat,
	-- A-Chassis objects, and scripts are never touched or depended upon.
	local studioR34: Model? = nil
	do
		local source = Workspace:FindFirstChild("NIGHTSHIFT_TestVehicle")
		local sourceVisual = if source ~= nil then source:FindFirstChild("Visual") else nil
		local candidate = if sourceVisual ~= nil then sourceVisual:FindFirstChild("R34") else nil
		if candidate ~= nil and candidate:IsA("Model") then
			local bodyParts = 0
			for _, descendant in candidate:GetDescendants() do
				if descendant:IsA("BasePart") then
					bodyParts += 1
				end
			end
			if bodyParts > 0 then
				studioR34 = candidate
			else
				warn("[NIGHTSHIFT Rig] Studio R34 has no BaseParts; using blockout.")
			end
		end
	end

	-- Blockout visuals exist ONLY when no Studio R34 shell was adopted, so the
	-- two never overlap. Chassis + interaction structure always build.
	if studioR34 == nil then
		-- Cabin block: orientation readability only (rear-biased so nose is obvious).
		local cabin = Instance.new("Part")
		cabin.Name = "Cabin"
		cabin.Size = Vector3.new(2.6, 1, 3)
		cabin.CFrame = chassis.CFrame * CFrame.new(0, 1.1, 1.2)
		cabin.CanCollide = false
		cabin.Massless = true
		cabin.Anchored = false
		cabin.Material = Enum.Material.SmoothPlastic
		cabin.Color = Color3.fromRGB(30, 30, 40)
		cabin.Parent = blockout
		weldTo(chassis, cabin)

		buildWheel(chassis, blockout, Vector3.new(-2.1, -0.9, -2.4))
		buildWheel(chassis, blockout, Vector3.new(2.1, -0.9, -2.4))
		buildWheel(chassis, blockout, Vector3.new(-2.1, -0.9, 2.4))
		buildWheel(chassis, blockout, Vector3.new(2.1, -0.9, 2.4))
	end

	-- DriverSeat: plain Seat for Humanoid occupancy ONLY (position + driver
	-- identity). Never VehicleSeat physics; NIGHTSHIFT owns driving.
	local seat = Instance.new("Seat")
	seat.Name = VehicleContract.DRIVER_SEAT_NAME
	seat.Size = Vector3.new(2, 0.8, 2)
	seat.CFrame = chassis.CFrame * CFrame.new(0, 2, 1.2)
	seat.CanCollide = false
	seat.Massless = true
	seat.Anchored = false
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = Color3.fromRGB(15, 15, 20)
	seat.Parent = model
	weldTo(chassis, seat)

	-- DriverEntry: invisible interaction volume on the driver's side (-X).
	-- Hosts the server-validated [E] Drive ProximityPrompt.
	local entry = Instance.new("Part")
	entry.Name = VehicleContract.DRIVER_ENTRY_NAME
	entry.Size = Vector3.new(2.5, 3, 2.5)
	entry.CFrame = chassis.CFrame * CFrame.new(-3.4, 0.6, 0.8)
	entry.Transparency = 1
	entry.CanCollide = false
	entry.CanQuery = false
	entry.Massless = true
	entry.Anchored = false
	entry.Parent = model
	weldTo(chassis, entry)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Test Blockout"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = entry

	-- DriverExitPoint: welded marker; world transform follows the car so exit
	-- lands beside the CURRENT vehicle location, never inside the chassis.
	local exitPoint = Instance.new("Attachment")
	exitPoint.Name = VehicleContract.DRIVER_EXIT_NAME
	exitPoint.CFrame = CFrame.new(-3.6, 0.8, 0.8)
	exitPoint.Parent = chassis

	-- Adopt the Studio R34 shell when present: CLONED (source never moved or
	-- modified), rigidly centered on the chassis (internal offsets and authored
	-- orientation preserved; developer aligns facing in Studio if backward),
	-- then adapted to visual-only + welded. Chassis goes invisible but stays
	-- the sole physical contact body.
	if studioR34 ~= nil then
		local shell = studioR34:Clone() :: Model
		shell.Name = "R34"
		shell.Parent = visual
		shell:PivotTo(chassis.CFrame)
		local scan = VehicleVisualAdapter.collect(shell)
		local massBefore = chassis.AssemblyMass
		local stats = VehicleVisualAdapter.attachVisuals(chassis, scan.parts)
		chassis.Transparency = 1
		print(
			string.format(
				"[NIGHTSHIFT Rig] R34 adopted: parts=%d skipped=%d welded=%d dup=%d failed=%d mass=%.2f->%.2f",
				#scan.parts,
				#scan.skipped,
				stats.welded,
				stats.alreadyWelded,
				stats.failed,
				massBefore,
				chassis.AssemblyMass
			)
		)
	else
		print("[NIGHTSHIFT Rig] No Studio R34 shell; blockout visuals active.")
	end

	model.PrimaryPart = chassis
	model.Parent = parent
	-- Readiness invariant (LAST step): clients attach only after this attribute
	-- replicates, which guarantees the complete structure arrived first.
	-- PrimaryPart is set for Studio tooling only and never read at runtime;
	-- root resolution always goes through VehicleContract (see above).
	model:SetAttribute(VehicleContract.READY_ATTRIBUTE, true)
	return model
end

local rig = Instance.new("Folder")
rig.Name = "NIGHTSHIFT_Rig"
rig.Parent = Workspace

local tarmac = Instance.new("Part")
tarmac.Name = "Tarmac"
tarmac.Size = Vector3.new(256, 2, 256)
tarmac.Position = Vector3.new(0, -1.05, 0)
tarmac.Anchored = true
tarmac.CanCollide = true
tarmac.Material = Enum.Material.Asphalt
tarmac.Color = Color3.fromRGB(50, 50, 55)
tarmac.Parent = rig

local vehicle = buildVehicle(rig)

-- DEV-ONLY Phase 2D/2E assembly audit: runs once at build. Reports every
-- BasePart's structural flags so a welded descendant with surprising assembly
-- behavior is visible without per-frame spam.
for _, descendant in vehicle:GetDescendants() do
	if descendant:IsA("BasePart") then
		local root = descendant.AssemblyRootPart
		print(
			string.format(
				"[NIGHTSHIFT Rig] Part: name=%s anchored=%s massless=%s root=%s",
				descendant.Name,
				tostring(descendant.Anchored),
				tostring(descendant.Massless),
				if root ~= nil then root.Name else "<none>"
			)
		)
	end
end

-- Ownership now follows the server-validated driver lifecycle (VehicleService):
-- unoccupied vehicles stay server-owned; the seated driver owns the assembly.
-- The rig hands the built vehicle to the service explicitly (no discovery).
local registered, regMessage = VehicleService.registerVehicle(vehicle)
if not registered then
	warn("[NIGHTSHIFT Rig] Vehicle registration failed: " .. regMessage)
end

-- Safe reset: recover escaped vehicles instead of leaving them under the world.
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
	local chassis = VehicleContract.resolveRoot(vehicle)
	if chassis == nil then
		return
	end
	if chassis.Position.Y < RECOVERY_Y then
		chassis.CFrame = SPAWN_CFRAME
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
		warn("[NIGHTSHIFT Rig] Test vehicle recovered to spawn.")
	end
end)

warn("[NIGHTSHIFT Rig] Dev rig ready (DEV-ONLY, Phase 2).")
