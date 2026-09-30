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
-- per-car script copies ever exist.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArcadeChassis = require(ReplicatedStorage.Shared.vehicle.ArcadeChassis)
local VehicleContract = require(ReplicatedStorage.Shared.vehicle.VehicleContract)

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
		_force: VectorForce?,
		_yaw: AngularVelocity?,
		_upright: AlignOrientation?,
		_steer: number,
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
		_force = nil,
		_yaw = nil,
		_upright = nil,
		_steer = 0,
	}, VehicleController)
end

function VehicleController.isAttached(self: VehicleController): boolean
	return self._model ~= nil
end

function VehicleController.attach(self: VehicleController, model: Model): (boolean, string)
	if self._model ~= nil then
		return false, "already attached"
	end
	local ready, reason = VehicleContract.isReady(model)
	if not ready then
		return false, reason
	end
	local primary = model:FindFirstChild(VehicleContract.ROOT_PART_NAME)
	if primary == nil or not primary:IsA("BasePart") then
		return false, "contract re-check: root vanished"
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "NIGHTSHIFT_Drive"
	attachment.Parent = primary

	local force = Instance.new("VectorForce")
	force.Name = "NIGHTSHIFT_DriveForce"
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Attachment0 = attachment
	force.Force = Vector3.zero
	force.Parent = primary

	local yaw = Instance.new("AngularVelocity")
	yaw.Name = "NIGHTSHIFT_Yaw"
	yaw.RelativeTo = Enum.ActuatorRelativeTo.World
	yaw.Attachment0 = attachment
	yaw.AngularVelocity = Vector3.zero
	yaw.MaxTorque = math.max(1, primary.AssemblyMass * self._config.yawTorqueFactor)
	yaw.Parent = primary

	local upright = Instance.new("AlignOrientation")
	upright.Name = "NIGHTSHIFT_Upright"
	upright.RelativeTo = Enum.ActuatorRelativeTo.World
	upright.Attachment0 = attachment
	upright.Stiffness = self._config.uprightStiffness
	upright.Damping = self._config.uprightDamping
	upright.MaxTorque = self._config.uprightMaxTorque
	upright.Parent = primary

	self._model = model
	self._chassis = primary
	self._force = force
	self._yaw = yaw
	self._upright = upright
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
	if self._force ~= nil then
		self._force:Destroy()
		self._force = nil
	end
	if self._yaw ~= nil then
		self._yaw:Destroy()
		self._yaw = nil
	end
	if self._upright ~= nil then
		self._upright:Destroy()
		self._upright = nil
	end
	local chassis = self._chassis
	if chassis ~= nil then
		local drive = chassis:FindFirstChild("NIGHTSHIFT_Drive")
		if drive ~= nil then
			drive:Destroy()
		end
	end
	self._model = nil
	self._chassis = nil
	self._steer = 0
	self._input:reset()
end

function VehicleController._step(self: VehicleController, dt: number): ()
	local chassis = self._chassis
	local force = self._force
	local yaw = self._yaw
	local upright = self._upright
	if chassis == nil or force == nil or yaw == nil or upright == nil then
		return
	end
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

	local step = ArcadeChassis.step(self._input:getInput(), fwdSpeed, self._steer, self._config, dt)
	self._steer = step.steerOut

	local dvForward = math.clamp(step.targetForwardSpeed - fwdSpeed, -step.forwardRate * dt, step.forwardRate * dt)
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
end

return VehicleController
