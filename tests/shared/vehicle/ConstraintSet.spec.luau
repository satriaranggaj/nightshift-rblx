--!nonstrict
-- NIGHTSHIFT ConstraintSet spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- A mock creation factory stands in for Instance.new, so transactional
-- rollback and the AlignOrientation API contract are verified deterministically.
-- Regression targets (Phase 2B/2C):
--   * AlignOrientation must use ONLY its real API (Responsiveness/MaxTorque).
--     RelativeTo, Stiffness, Damping do not exist on it (runtime attach errors).
--   * A mid-build failure must destroy every partial object (no orphans).

local ConstraintSet = require(game:GetService("ReplicatedStorage").Shared.vehicle.ConstraintSet)

local PARAMS = {
	mass = 100,
	uprightResponsiveness = 200,
	uprightMaxTorque = 50000,
	yawTorqueFactor = 40,
}

local function mockRoot(): any
	return {}
end

-- Mock factory: records every created object and every property set.
-- `failAt` (1-based creation index) makes that creation throw.
local function makeFactory(failAt: any): any
	local created: any = {}
	local count = 0
	local factory = function(className: string): any
		count += 1
		if failAt ~= nil and count == failAt then
			error("boom:" .. className)
		end
		local obj: any = { ClassName = className, Destroyed = false, _sets = {} }
		obj.Destroy = function(self: any)
			self.Destroyed = true
		end
		table.insert(created, obj)
		return setmetatable(obj, {
			__newindex = function(t: any, k: string, v: any)
				t._sets[k] = v
				rawset(t, k, v)
			end,
		})
	end
	return factory, created
end

return function()
	describe("build", function()
		it("assembles four parented constraints with valid API usage", function()
			local factory, created = makeFactory(nil)
			local set, err = ConstraintSet.build(mockRoot(), PARAMS, factory)
			expect(err).to.equal("ok")
			expect(set ~= nil).to.equal(true)
			expect(#created).to.equal(4)
			expect(created[1].ClassName).to.equal("Attachment")
			expect(created[2].ClassName).to.equal("VectorForce")
			expect(created[3].ClassName).to.equal("AngularVelocity")
			expect(created[4].ClassName).to.equal("AlignOrientation")
			for _, obj in created do
				expect(obj.Destroyed).to.equal(false)
			end
		end)

		it("assigns only valid AlignOrientation properties", function()
			local factory, created = makeFactory(nil)
			local set, _ = ConstraintSet.build(mockRoot(), PARAMS, factory)
			expect(set ~= nil).to.equal(true)
			local uprightSets = created[4]._sets
			expect(uprightSets.RelativeTo).to.equal(nil)
			expect(uprightSets.Stiffness).to.equal(nil)
			expect(uprightSets.Damping).to.equal(nil)
			expect(uprightSets.Attachment0 ~= nil).to.equal(true)
			expect(uprightSets.Responsiveness).to.equal(PARAMS.uprightResponsiveness)
			expect(uprightSets.MaxTorque).to.equal(PARAMS.uprightMaxTorque)
			-- Sibling constraints DO use world-space actuation.
			expect(created[2]._sets.RelativeTo).to.equal("World")
			expect(created[3]._sets.RelativeTo).to.equal("World")
			-- Drive force applies at the assembly center (no lever-arm torque).
			expect(created[2]._sets.ApplyAtCenterOfMass).to.equal(true)
		end)

		it("scales yaw torque from mass", function()
			local factory, created = makeFactory(nil)
			local set, _ = ConstraintSet.build(mockRoot(), PARAMS, factory)
			expect(set ~= nil).to.equal(true)
			expect(created[3]._sets.MaxTorque).to.equal(PARAMS.mass * PARAMS.yawTorqueFactor)
		end)

		it("destroys all partials when a mid-build creation fails", function()
			local factory, created = makeFactory(3)
			local set, err = ConstraintSet.build(mockRoot(), PARAMS, factory)
			expect(set).to.equal(nil)
			expect(string.find(err, "constraint build failed") ~= nil).to.equal(true)
			expect(#created).to.equal(2)
			for _, obj in created do
				expect(obj.Destroyed).to.equal(true)
			end
		end)

		it("fails clean with nothing created when the first creation fails", function()
			local factory, created = makeFactory(1)
			local set, _ = ConstraintSet.build(mockRoot(), PARAMS, factory)
			expect(set).to.equal(nil)
			expect(#created).to.equal(0)
		end)
	end)

	describe("destroy", function()
		it("destroys a complete set and tolerates nil", function()
			local factory, created = makeFactory(nil)
			local set, _ = ConstraintSet.build(mockRoot(), PARAMS, factory)
			ConstraintSet.destroy(set)
			for _, obj in created do
				expect(obj.Destroyed).to.equal(true)
			end
			ConstraintSet.destroy(nil)
		end)
	end)

	describe("resolveMode", function()
		it("passes the three isolation modes through", function()
			expect(ConstraintSet.resolveMode("FORCE_ONLY")).to.equal("FORCE_ONLY")
			expect(ConstraintSet.resolveMode("WITH_YAW")).to.equal("WITH_YAW")
			expect(ConstraintSet.resolveMode("FULL")).to.equal("FULL")
		end)

		it("normalizes anything unrecognized to FULL", function()
			expect(ConstraintSet.resolveMode(nil)).to.equal("FULL")
			expect(ConstraintSet.resolveMode("")).to.equal("FULL")
			expect(ConstraintSet.resolveMode("force_only")).to.equal("FULL")
			expect(ConstraintSet.resolveMode(42)).to.equal("FULL")
		end)
	end)
end
