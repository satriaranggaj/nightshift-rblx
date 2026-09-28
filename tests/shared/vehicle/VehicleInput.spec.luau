--!nonstrict
-- NIGHTSHIFT VehicleInput spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- Lint coverage for those globals comes from the testez std layer (testez.yml).

local VehicleInput = require(game:GetService("ReplicatedStorage").Shared.vehicle.VehicleInput)

return function()
	describe("neutral", function()
		it("reports all-zero, no-action defaults", function()
			local state = VehicleInput.neutral()
			expect(state.throttle).to.equal(0)
			expect(state.brake).to.equal(0)
			expect(state.steer).to.equal(0)
			expect(state.drift).to.equal(false)
			expect(state.nitro).to.equal(false)
			expect(VehicleInput.isNeutral(state)).to.equal(true)
		end)
	end)

	describe("bounds", function()
		it("clamps throttle above 1 and below 0", function()
			expect(VehicleInput.sanitize({ throttle = 1.5 }).throttle).to.equal(1)
			expect(VehicleInput.sanitize({ throttle = -0.2 }).throttle).to.equal(0)
		end)

		it("clamps brake above 1 and below 0", function()
			expect(VehicleInput.sanitize({ brake = 4 }).brake).to.equal(1)
			expect(VehicleInput.sanitize({ brake = -1 }).brake).to.equal(0)
		end)

		it("clamps steer above 1 and below -1", function()
			expect(VehicleInput.sanitize({ steer = 2 }).steer).to.equal(1)
			expect(VehicleInput.sanitize({ steer = -3 }).steer).to.equal(-1)
		end)

		it("preserves valid in-range values exactly", function()
			local state = VehicleInput.sanitize({
				throttle = 0.5,
				brake = 0.25,
				steer = -0.75,
				drift = true,
				nitro = true,
			})
			expect(state.throttle).to.equal(0.5)
			expect(state.brake).to.equal(0.25)
			expect(state.steer).to.equal(-0.75)
			expect(state.drift).to.equal(true)
			expect(state.nitro).to.equal(true)
			expect(VehicleInput.isNeutral(state)).to.equal(false)
		end)
	end)

	describe("booleans", function()
		it("passes literal true and defaults everything else to false", function()
			expect(VehicleInput.sanitize({ drift = true }).drift).to.equal(true)
			expect(VehicleInput.sanitize({ nitro = true }).nitro).to.equal(true)
			expect(VehicleInput.sanitize({ drift = 1 }).drift).to.equal(false)
			expect(VehicleInput.sanitize({ nitro = "yes" }).nitro).to.equal(false)
			expect(VehicleInput.sanitize({}).drift).to.equal(false)
		end)
	end)

	describe("invalid input", function()
		it("maps NaN numerics to neutral without contaminating state", function()
			local nan = 0 / 0
			local state = VehicleInput.sanitize({ throttle = nan, brake = nan, steer = nan })
			expect(state.throttle).to.equal(0)
			expect(state.brake).to.equal(0)
			expect(state.steer).to.equal(0)
			expect(VehicleInput.isNeutral(state)).to.equal(true)
		end)

		it("clamps infinities to bounds", function()
			expect(VehicleInput.sanitize({ throttle = math.huge }).throttle).to.equal(1)
			expect(VehicleInput.sanitize({ steer = -math.huge }).steer).to.equal(-1)
		end)

		it("maps non-tables and wrong-typed fields to neutral", function()
			expect(VehicleInput.isNeutral(VehicleInput.sanitize(nil))).to.equal(true)
			expect(VehicleInput.isNeutral(VehicleInput.sanitize(42))).to.equal(true)
			local state = VehicleInput.sanitize({ throttle = "full", steer = {} })
			expect(state.throttle).to.equal(0)
			expect(state.steer).to.equal(0)
		end)
	end)

	describe("simultaneous input", function()
		it("resolves left+right steer to neutral", function()
			expect(VehicleInput.combineSteer(true, true)).to.equal(0)
			expect(VehicleInput.combineSteer(false, false)).to.equal(0)
			expect(VehicleInput.combineSteer(true, false)).to.equal(-1)
			expect(VehicleInput.combineSteer(false, true)).to.equal(1)
		end)

		it("reports throttle and brake independently (no arbitration)", function()
			local state = VehicleInput.sanitize({ throttle = 1, brake = 1 })
			expect(state.throttle).to.equal(1)
			expect(state.brake).to.equal(1)
		end)
	end)

	describe("equality", function()
		it("compares field by field", function()
			expect(VehicleInput.equals(VehicleInput.neutral(), VehicleInput.neutral())).to.equal(true)
			local pressed = VehicleInput.sanitize({ throttle = 1 })
			expect(VehicleInput.equals(VehicleInput.neutral(), pressed)).to.equal(false)
			expect(VehicleInput.equals(pressed, VehicleInput.sanitize({ throttle = 1 }))).to.equal(true)
		end)
	end)
end
