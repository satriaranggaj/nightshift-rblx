--!strict
-- DEV-ONLY Phase 2 test rig (NOT production content; replaced by the real
-- district in Phase 13). Builds a flat tarmac, one blockout test vehicle, and
-- assigns network ownership to the joining player so the client's
-- VehicleController simulates responsively with physics replication.
--
-- Forward convention: the vehicle's nose points along -Z (Roblox vehicle
-- convention); forward speed is measured on -Chassis.CFrame.LookVector.
-- Single test vehicle: the most recent joiner owns it (documented limit;
-- multi-vehicle ownership is a Phase 11 concern).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)

local SPAWN_CFRAME = CFrame.new(0, 4, 0)
local RECOVERY_Y = -50

local function weldTo(main: BasePart, part: BasePart): ()
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = main
	weld.Part1 = part
	weld.Parent = main
end

local function buildWheel(chassis: BasePart, offset: Vector3): ()
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
	wheel.Parent = chassis.Parent
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
	chassis.Color = Color3.fromRGB(200, 60, 40)
	chassis.Parent = model

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
	cabin.Parent = model
	weldTo(chassis, cabin)

	buildWheel(chassis, Vector3.new(-2.1, -0.9, -2.4))
	buildWheel(chassis, Vector3.new(2.1, -0.9, -2.4))
	buildWheel(chassis, Vector3.new(-2.1, -0.9, 2.4))
	buildWheel(chassis, Vector3.new(2.1, -0.9, 2.4))

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

local function handOwnership(player: Player): ()
	local chassis = VehicleContract.resolveRoot(vehicle)
	if chassis == nil then
		warn("[NIGHTSHIFT Rig] Ownership skipped: root part missing.")
		return
	end
	local ok, err = pcall(function()
		chassis:SetNetworkOwner(player)
	end)
	if not ok then
		warn("[NIGHTSHIFT Rig] SetNetworkOwner failed: " .. tostring(err))
		return
	end
	-- DEV-ONLY Phase 2D: confirm effective ownership (never assume the pcall).
	local owner = chassis:GetNetworkOwner()
	local ownerName = if owner ~= nil then owner.Name else "<server/none>"
	print(
		string.format(
			"[NIGHTSHIFT Rig] Ownership: player=%s assemblyOwner=%s anchored=%s mass=%.2f",
			player.Name,
			ownerName,
			tostring(chassis.Anchored),
			chassis.AssemblyMass
		)
	)
end

for _, player in Players:GetPlayers() do
	handOwnership(player)
end
Players.PlayerAdded:Connect(handOwnership)

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
