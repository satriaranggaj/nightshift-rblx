--!strict
-- NIGHTSHIFT drive-constraint assembly (shared).
-- Builds the controller's runtime constraints onto a root part TRANSACTIONALLY:
-- everything is created in local scope, and any mid-build failure destroys all
-- partial objects before returning an error, so attach() can never leak orphan
-- constraints. No services required; the creation function defaults to
-- Instance.new and is injectable for deterministic failure tests.
--
-- Rotational separation of powers (yaw-decoupled upright, Phase 2G):
-- AngularVelocity owns YAW; AlignOrientation owns UPRIGHT (pitch/roll) only.
-- The upright uses single-attachment PRIMARY-AXIS alignment
-- (AlignType.PrimaryAxisParallel): torque occurs ONLY for primary-axis
-- misalignment, so rotation about world up stays free for AngularVelocity.
-- Geometry: the drive attachment is rolled 90° about Z so its local X axis
-- rides chassis up; PrimaryAxis (goal X) = world up. Verified against the
-- AlignOrientation/Attachment API: old Parallel/Perpendicular enum values and
-- PrimaryAxisOnly are deprecated (do not use); AlignOrientation has NO
-- RelativeTo, Stiffness, or Damping (assigning those errors at runtime);
-- Attachment.Axis derives from its CFrame (rotating the attachment aims it).
-- VectorForce/AngularVelocity expose RelativeTo and use World space.

export type ConstraintParams = {
	mass: number,
	uprightResponsiveness: number,
	uprightMaxTorque: number,
	yawTorqueFactor: number,
}

export type ConstraintSet = {
	attachment: Attachment,
	force: VectorForce,
	yaw: AngularVelocity,
	upright: AlignOrientation,
}

-- Creation function. Returns `any` so callers keep precise casts; production
-- passes nothing (Instance.new), tests inject failures. `::` casts below are
-- compile-time only and specialize the factory's untyped results.
export type Factory = (className: string) -> any

local ConstraintSet = {}

function ConstraintSet.build(root: BasePart, params: ConstraintParams, factory: Factory?): (ConstraintSet?, string)
	local create: Factory = if factory ~= nil then factory :: Factory else Instance.new
	local created: { Instance } = {}

	local function track(obj: Instance): Instance
		table.insert(created, obj)
		return obj
	end

	local function destroyAll(): ()
		for _, obj in created do
			obj:Destroy()
		end
		table.clear(created)
	end

	local ok, result = pcall(function(): ConstraintSet
		local attachment = track(create("Attachment")) :: Attachment
		attachment.Name = "NIGHTSHIFT_Drive"
		-- Roll local X onto chassis up (see header): the primary-axis goal
		-- below then corrects pitch/roll while leaving yaw free. Orientation
		-- is irrelevant to VectorForce/AngularVelocity (world-space vectors).
		attachment.CFrame = CFrame.Angles(0, 0, math.pi / 2)
		attachment.Parent = root

		local force = track(create("VectorForce")) :: VectorForce
		force.Name = "NIGHTSHIFT_DriveForce"
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Attachment0 = attachment
		-- Applied at the assembly center of mass: the drive force must never
		-- gain a lever arm (and unwanted torque) from the attachment position,
		-- regardless of future mass distribution.
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.zero
		force.Parent = root

		local yaw = track(create("AngularVelocity")) :: AngularVelocity
		yaw.Name = "NIGHTSHIFT_Yaw"
		yaw.RelativeTo = Enum.ActuatorRelativeTo.World
		yaw.Attachment0 = attachment
		yaw.AngularVelocity = Vector3.zero
		yaw.MaxTorque = math.max(1, params.mass * params.yawTorqueFactor)
		yaw.Parent = root

		-- Yaw-decoupled upright: AlignType.PrimaryAxisParallel enforces ONLY the
		-- primary-axis relationship (attachment Axis ∥ PrimaryAxis = world up),
		-- so yaw about that axis stays free for AngularVelocity. No RelativeTo,
		-- Stiffness, or Damping: none of those exist on this class.
		local upright = track(create("AlignOrientation")) :: AlignOrientation
		upright.Name = "NIGHTSHIFT_Upright"
		upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
		upright.AlignType = Enum.AlignType.PrimaryAxisParallel
		upright.PrimaryAxis = Vector3.new(0, 1, 0)
		upright.Attachment0 = attachment
		upright.Responsiveness = params.uprightResponsiveness
		upright.MaxTorque = params.uprightMaxTorque
		upright.Parent = root

		return {
			attachment = attachment,
			force = force,
			yaw = yaw,
			upright = upright,
		}
	end)

	if not ok then
		destroyAll()
		return nil, "constraint build failed: " .. tostring(result)
	end
	return result, "ok"
end

function ConstraintSet.destroy(set: ConstraintSet?): ()
	if set == nil then
		return
	end
	set.upright:Destroy()
	set.yaw:Destroy()
	set.force:Destroy()
	set.attachment:Destroy()
end

export type IsolationMode = "FORCE_ONLY" | "WITH_YAW" | "FULL"

-- DEV-ONLY Phase 2E isolation contract (pure, spec-pinned):
-- FORCE_ONLY = VectorForce alone (no yaw, no upright),
-- WITH_YAW   = VectorForce + AngularVelocity (no upright),
-- FULL       = all three (intended Phase-2 configuration).
-- Anything unrecognized normalizes to FULL, so a typo can never silently
-- disable stabilization.
function ConstraintSet.resolveMode(raw: any): IsolationMode
	if raw == "FORCE_ONLY" then
		return "FORCE_ONLY"
	elseif raw == "WITH_YAW" then
		return "WITH_YAW"
	else
		return "FULL"
	end
end

return ConstraintSet
