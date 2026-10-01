--!nonstrict
-- NIGHTSHIFT ArcadeChassis spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- Lint coverage for those globals comes from the testez std layer (testez.yml).
-- Roblox physics is NOT validated here; Studio covers motion (see test matrix
-- in the Phase 2 report). These specs pin the deterministic step policy.

local Shared = game:GetService("ReplicatedStorage").Shared
local ArcadeChassis = require(Shared.vehicle.ArcadeChassis)
local ChassisConfig = require(Shared.config.ChassisConfig)

local CONFIG = ChassisConfig.TEST_BLOCKOUT
local DT = 1 / 60

return function()
	describe("validateConfig", function()
		it("accepts the bundled test config", function()
			local ok, _ = ArcadeChassis.validateConfig(CONFIG)
			expect(ok).to.equal(true)
		end)

		it("rejects non-positive, NaN, and non-table configs", function()
			local bad = table.clone(CONFIG)
			bad.maxForwardSpeed = -1
			local ok, _ = ArcadeChassis.validateConfig(bad)
			expect(ok).to.equal(false)
			bad.maxForwardSpeed = 0 / 0
			ok, _ = ArcadeChassis.validateConfig(bad)
			expect(ok).to.equal(false)
			ok, _ = ArcadeChassis.validateConfig(nil)
			expect(ok).to.equal(false)
		end)
	end)

	describe("forward policy", function()
		it("drives toward throttle-scaled max speed", function()
			local step = ArcadeChassis.step({ throttle = 1 }, 0, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(CONFIG.maxForwardSpeed)
			expect(step.forwardRate).to.equal(CONFIG.forwardAccel)
		end)

		it("never targets above max even when overspeed", function()
			local step = ArcadeChassis.step({ throttle = 1 }, 200, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(CONFIG.maxForwardSpeed)
		end)

		it("brakes toward zero while moving fast", function()
			local step = ArcadeChassis.step({ brake = 1 }, 30, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(0)
			expect(step.forwardRate).to.equal(CONFIG.brakeDecel)
		end)

		it("transitions to reverse when braking near stop", function()
			local step = ArcadeChassis.step({ brake = 1 }, 1, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(-CONFIG.maxReverseSpeed)
			expect(step.forwardRate).to.equal(CONFIG.reverseAccel)
		end)

		it("kills reverse (no auto-flip) when throttling while reversing", function()
			local step = ArcadeChassis.step({ throttle = 1 }, -10, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(0)
			expect(step.forwardRate).to.equal(CONFIG.brakeDecel)
		end)

		it("coasts mildly with no intent (never an instant stop)", function()
			local step = ArcadeChassis.step({}, 30, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(0)
			expect(step.forwardRate).to.equal(CONFIG.coastDecel)
		end)

		it("prioritizes throttle over brake when rolling forward", function()
			local step = ArcadeChassis.step({ throttle = 1, brake = 1 }, 10, 0, CONFIG, DT)
			expect(step.targetForwardSpeed).to.equal(CONFIG.maxForwardSpeed)
		end)
	end)

	describe("steering", function()
		it("smooths steer progressively and clamps", function()
			local first = ArcadeChassis.step({ steer = 1 }, 20, 0, CONFIG, DT)
			expect(first.steerOut).to.equal(CONFIG.steerSmooth * DT)
			local second = ArcadeChassis.step({ steer = 1 }, 20, first.steerOut, CONFIG, DT)
			expect(second.steerOut).to.equal(first.steerOut + CONFIG.steerSmooth * DT)
			local clamped = ArcadeChassis.step({ steer = 5 }, 20, 1, CONFIG, DT)
			expect(clamped.steerOut).to.equal(1)
		end)

		it("produces no yaw at standstill and full yaw at speed", function()
			local still = ArcadeChassis.step({ steer = 1 }, 0, 1, CONFIG, DT)
			expect(still.yawRate).to.equal(0)
			local fast = ArcadeChassis.step({ steer = 1 }, 20, 1, CONFIG, DT)
			expect(fast.yawRate).to.equal(CONFIG.steerYawRate)
			local left = ArcadeChassis.step({ steer = -1 }, 20, -1, CONFIG, DT)
			expect(left.yawRate).to.equal(-CONFIG.steerYawRate)
		end)
	end)

	describe("robustness", function()
		it("sanitizes NaN input instead of propagating it", function()
			local nan = 0 / 0
			local step = ArcadeChassis.step({ throttle = nan, steer = nan }, nan, nan, CONFIG, nan)
			expect(step.targetForwardSpeed).to.equal(0)
			expect(step.steerOut).to.equal(0)
			expect(step.yawRate).to.equal(0)
		end)

		it("ignores drift/nitro until their phases (contract-stable no-op)", function()
			local plain = ArcadeChassis.step({ throttle = 1 }, 10, 0, CONFIG, DT)
			local flagged = ArcadeChassis.step({ throttle = 1, drift = true, nitro = true }, 10, 0, CONFIG, DT)
			expect(flagged.targetForwardSpeed).to.equal(plain.targetForwardSpeed)
			expect(flagged.forwardRate).to.equal(plain.forwardRate)
			expect(flagged.yawRate).to.equal(plain.yawRate)
		end)

		it("clamps pathological dt for stability", function()
			local step = ArcadeChassis.step({ steer = 1 }, 20, 0, CONFIG, 10)
			expect(step.steerOut).to.equal(CONFIG.steerSmooth * (1 / 20))
		end)
	end)

	describe("approachVelocity", function()
		it("advances toward the target at most rate*dt", function()
			expect(ArcadeChassis.approachVelocity(0, 60, 30, DT)).to.equal(30 * DT)
			expect(ArcadeChassis.approachVelocity(59.5, 60, 30, DT)).to.equal(0.5)
		end)

		it("handles the reverse direction symmetrically", function()
			expect(ArcadeChassis.approachVelocity(0, -20, 20, DT)).to.equal(-20 * DT)
		end)

		it("returns zero for bad rates and guards NaN", function()
			expect(ArcadeChassis.approachVelocity(10, 60, 0, DT)).to.equal(0)
			expect(ArcadeChassis.approachVelocity(10, 60, -5, DT)).to.equal(0)
			expect(ArcadeChassis.approachVelocity(0 / 0, 60, 30, DT)).to.equal(30 * DT)
			expect(ArcadeChassis.approachVelocity(10, 0 / 0, 30, DT)).to.equal(0)
		end)

		it("clamps pathological dt like step()", function()
			expect(ArcadeChassis.approachVelocity(0, 60, 30, 10)).to.equal(30 * (1 / 20))
			expect(ArcadeChassis.approachVelocity(0, 60, 30, 0)).to.equal(30 * (1 / 60))
		end)
	end)

	describe("projectForward", function()
		it("preserves LookVector sign (nose -Z stays -Z)", function()
			local nose = ArcadeChassis.projectForward(Vector3.new(0, 0, -1))
			expect(nose.X).to.equal(0)
			expect(nose.Y).to.equal(0)
			expect(nose.Z).to.equal(-1)
			local tail = ArcadeChassis.projectForward(Vector3.new(0, 0, 1))
			expect(tail.Z).to.equal(1)
		end)

		it("projects onto XZ and normalizes", function()
			local p = ArcadeChassis.projectForward(Vector3.new(3, 99, -4))
			expect(p.X).to.equal(0.6)
			expect(p.Y).to.equal(0)
			expect(p.Z).to.equal(-0.8)
		end)

		it("falls back to world -Z for degenerate looks", function()
			local p = ArcadeChassis.projectForward(Vector3.new(0, 5, 0))
			expect(p.X).to.equal(0)
			expect(p.Y).to.equal(0)
			expect(p.Z).to.equal(-1)
		end)
	end)
end
