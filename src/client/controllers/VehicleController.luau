--!strict
-- NIGHTSHIFT vehicle controller (client).
-- Owns the local driving lifecycle: attach to a vehicle model, consume
-- normalized VehicleInput each Heartbeat, convert ArcadeChassis step targets
-- into constraint forces, detach/reset cleanly.
--
-- Boundaries: consumes INTENT via the injected input source (never reads keys,
-- buttons, or sticks). Produces MOTION via ArcadeChassis math (never invents
-- physics). No economy, persistence, or race logic.
--
-- Model contract (minimal, explicit): a Model containing a single rigid root
-- BasePart named `Chassis` (whole assembly welded to it; see VehicleContract).
-- The builder signals structural completeness via the NIGHTSHIFT_Ready
-- attribute; attach() still re-validates and fails safely for malformed
-- models. PrimaryPart is deliberately NOT used: it does not reliably
-- replicate to clients for server-constructed models.
-- Optional `Wheels` folder is visual-only in Phase 2 (welded blockout;
-- spinning wheels need hinge constraints, deferred).
-- The controller creates and owns its DriveAttachment/VectorForce/
-- AngularVelocity/AlignOrientation on attach and destroys them on detach, so no
-- per-car script copies ever exist. Assembly is transactional (see
-- ConstraintSet): partial builds are rolled back, never committed.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArcadeChassis = require(ReplicatedStorage.Shared.vehicle.ArcadeChassis)
local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)
local ConstraintSet = require(ReplicatedStorage.Shared.vehicle.ConstraintSet)

export type InputSource = {
	getInput: (any) -> ArcadeChassis.VehicleInput,
	reset: (any) -> (),
}

local VehicleController = {}
VehicleController.__index = VehicleController

export type VehicleController = typeof(setmetatable(
	{} :: {
		_input: InputSource,
		_config: ArcadeChassis.ChassisConfig,
		_model: Model?,
		_chassis: BasePart?,
		_connection: RBXScriptConnection?,
		_set: ConstraintSet.ConstraintSet?,
		_steer: number,
		-- TEMPORARY Phase 2D: bounded physics diagnosis (see _maybeDiagnose).
		_diagEnabled: boolean,
		_diagLast: number,
	},
	VehicleController
))

function VehicleController.new(input: InputSource, config: ArcadeChassis.ChassisConfig): VehicleController
	local ok, message = ArcadeChassis.validateConfig(config)
	assert(ok, "VehicleController.new: invalid config: " .. message)
	return setmetatable({
		_input = input,
		_config = config,
		_model = nil,
		_chassis = nil,
		_connection = nil,
		_set = nil,
		_steer = 0,
		_diagEnabled = false,
		_diagLast = 0,
	}, VehicleController)
end

-- TEMPORARY Phase 2D: enables the throttled physics snapshot. Must not ship
-- as a gameplay feature; remove alongside the 2D diagnostic rig output.
function VehicleController.setDiagnosticsEnabled(self: VehicleController, enabled: boolean): ()
	self._diagEnabled = enabled
end

function VehicleController.isAttached(self: VehicleController): boolean
	return self._model ~= nil
end

function VehicleController.attach(self: VehicleController, model: Model): (boolean, string)
	if self._model ~= nil then
		return false, "already attached"
	end
	local complete, reason = VehicleContract.isComplete(model)
	if not complete then
		return false, reason
	end
	local primary = VehicleContract.resolveRoot(model)
	if primary == nil then
		return false, "contract re-check: root vanished"
	end

	-- Transactional assembly: build fully in local scope; commit to self only
	-- on success. build() destroys its own partials on failure, so a failed
	-- attach leaves no orphan constraints and self stays pristine.
	local set, buildError = ConstraintSet.build(primary, {
		mass = math.max(0.001, primary.AssemblyMass),
		uprightResponsiveness = self._config.uprightResponsiveness,
		uprightMaxTorque = self._config.uprightMaxTorque,
		yawTorqueFactor = self._config.yawTorqueFactor,
	})
	if set == nil then
		return false, buildError
	end

	self._model = model
	self._chassis = primary
	self._set = set
	self._steer = 0
	self._connection = RunService.Heartbeat:Connect(function(dt: number)
		self:_step(dt)
	end)
	return true, "ok"
end

function VehicleController.detach(self: VehicleController): ()
	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end
	ConstraintSet.destroy(self._set)
	self._set = nil
	self._model = nil
	self._chassis = nil
	self._steer = 0
	self._input:reset()
end

function VehicleController._step(self: VehicleController, dt: number): ()
	local chassis = self._chassis
	local set = self._set
	if chassis == nil or set == nil then
		return
	end
	local force = set.force
	local yaw = set.yaw
	local upright = set.upright
	local mass = math.max(0.001, chassis.AssemblyMass)

	local velocity = chassis.AssemblyLinearVelocity
	local flatForward = Vector3.new(-chassis.CFrame.LookVector.X, 0, -chassis.CFrame.LookVector.Z)
	if flatForward.Magnitude < 0.001 then
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end
	local flatVel = Vector3.new(velocity.X, 0, velocity.Z)
	local fwdSpeed = flatVel:Dot(flatForward)

	local input = self._input:getInput()
	local step = ArcadeChassis.step(input, fwdSpeed, self._steer, self._config, dt)
	self._steer = step.steerOut

	local dvForward = ArcadeChassis.approachVelocity(fwdSpeed, step.targetForwardSpeed, step.forwardRate, dt)
	local accelF = dvForward / math.max(dt, 1e-4)
	local lateral = flatVel - flatForward * fwdSpeed
	local dvLateral = lateral * -1
	local maxDv = step.lateralRate * dt
	if dvLateral.Magnitude > maxDv then
		dvLateral = dvLateral.Unit * maxDv
	end
	local accelL = dvLateral / math.max(dt, 1e-4)

	local total = flatForward * accelF + accelL
	if total.Magnitude > self._config.maxForceAccel then
		total = total.Unit * self._config.maxForceAccel
	end
	force.Force = total * mass

	yaw.MaxTorque = math.max(1, mass * self._config.yawTorqueFactor)
	yaw.AngularVelocity = Vector3.new(0, step.yawRate, 0)

	local _, yRot, _ = chassis.CFrame:ToEulerAnglesYXZ()
	upright.CFrame = CFrame.new(chassis.Position) * CFrame.Angles(0, yRot, 0)

	self:_applyIsolation(yaw, upright)
	self:_maybeDiagnose(input, step, fwdSpeed, mass, accelF, accelL, total, force, chassis, velocity)
end

-- DEV-ONLY Phase 2D isolation (command-bar driven, default off/full):
-- set the vehicle model's NIGHTSHIFT_Isolate attribute to "forceOnly" or
-- "noUpright" to test VectorForce alone or without the upright assist.
-- Production behavior is always the full stack; this changes nothing unless
-- the attribute is explicitly set in Studio.
function VehicleController._applyIsolation(self: VehicleController, yaw: AngularVelocity, upright: AlignOrientation): ()
	local model = self._model
	local mode: any = nil
	if model ~= nil then
		mode = model:GetAttribute("NIGHTSHIFT_Isolate")
	end
	if mode == "forceOnly" then
		yaw.Enabled = false
		upright.Enabled = false
	elseif mode == "noUpright" then
		yaw.Enabled = true
		upright.Enabled = false
	else
		yaw.Enabled = true
		upright.Enabled = true
	end
end

-- TEMPORARY Phase 2D diagnosis: at most one compact snapshot per second, and
-- only while input is meaningfully non-neutral. Never per-frame.
function VehicleController._maybeDiagnose(
	self: VehicleController,
	input: ArcadeChassis.VehicleInput,
	step: ArcadeChassis.ChassisStep,
	fwdSpeed: number,
	mass: number,
	accelF: number,
	accelL: Vector3,
	total: Vector3,
	force: VectorForce,
	chassis: BasePart,
	velocity: Vector3
): ()
	if not self._diagEnabled then
		return
	end
	if math.abs(input.throttle) < 0.01 and math.abs(input.brake) < 0.01 and math.abs(input.steer) < 0.01 then
		return
	end
	local now = os.clock()
	if now - self._diagLast < 1 then
		return
	end
	self._diagLast = now
	local set = self._set
	local attachOk = set ~= nil and set.attachment.Parent == chassis
	print(
		string.format(
			"[NIGHTSHIFT Physics] in=(%.2f,%.2f,%.2f) fwd=%.2f tgt=%.2f rate=%.2f sOut=%.2f yaw=%.2f",
			input.throttle,
			input.brake,
			input.steer,
			fwdSpeed,
			step.targetForwardSpeed,
			step.forwardRate,
			step.steerOut,
			step.yawRate
		)
	)
	print(
		string.format(
			"[NIGHTSHIFT Physics] mass=%.2f aF=%.2f aL=%.2f aTot=%.2f force=(%.1f,%.1f,%.1f) en=%s rel=%s com=%s",
			mass,
			accelF,
			accelL.Magnitude,
			total.Magnitude,
			force.Force.X,
			force.Force.Y,
			force.Force.Z,
			tostring(force.Enabled),
			tostring(force.RelativeTo),
			tostring(force.ApplyAtCenterOfMass)
		)
	)
	print(
		string.format(
			"[NIGHTSHIFT Physics] vel=(%.2f,%.2f,%.2f) avel=(%.2f,%.2f,%.2f) anchored=%s asm=%.2f attach=%s",
			velocity.X,
			velocity.Y,
			velocity.Z,
			chassis.AssemblyAngularVelocity.X,
			chassis.AssemblyAngularVelocity.Y,
			chassis.AssemblyAngularVelocity.Z,
			tostring(chassis.Anchored),
			chassis.AssemblyMass,
			tostring(attachOk)
		)
	)
end

return VehicleController
