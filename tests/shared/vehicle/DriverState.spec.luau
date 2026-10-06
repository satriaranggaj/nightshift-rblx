--!nonstrict
-- NIGHTSHIFT DriverState spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- Pins the server-authoritative occupancy transitions without Roblox seating.

local DriverState = require(game:GetService("ReplicatedStorage").Shared.vehicle.DriverState)

return function()
	describe("tryEnter", function()
		it("allows entry into an unoccupied vehicle", function()
			local ok, driver = DriverState.tryEnter(0, 123)
			expect(ok).to.equal(true)
			expect(driver).to.equal(123)
			expect(DriverState.isOccupied(driver)).to.equal(true)
		end)

		it("rejects a second driver while occupied", function()
			local ok, reason = DriverState.tryEnter(123, 456)
			expect(ok).to.equal(false)
			expect(reason).to.equal("occupied")
		end)

		it("rejects re-entry by the current driver", function()
			local ok, reason = DriverState.tryEnter(123, 123)
			expect(ok).to.equal(false)
			expect(reason).to.equal("already driving")
		end)

		it("rejects an invalid requester", function()
			local ok, _ = DriverState.tryEnter(0, 0)
			expect(ok).to.equal(false)
		end)
	end)

	describe("tryExit", function()
		it("allows the driver to exit", function()
			local ok, driver = DriverState.tryExit(123, 123)
			expect(ok).to.equal(true)
			expect(driver).to.equal(0)
			expect(DriverState.isOccupied(driver)).to.equal(false)
		end)

		it("rejects exit from an unoccupied vehicle", function()
			local ok, reason = DriverState.tryExit(0, 123)
			expect(ok).to.equal(false)
			expect(reason).to.equal("unoccupied")
		end)

		it("rejects exit by a non-driver", function()
			local ok, reason = DriverState.tryExit(123, 456)
			expect(ok).to.equal(false)
			expect(reason).to.equal("not the driver")
		end)
	end)
end
