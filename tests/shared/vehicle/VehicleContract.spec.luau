--!nonstrict
-- NIGHTSHIFT VehicleContract regression spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- Mocks stand in for Instances (plain tables with FindFirstChild/IsA), so the
-- structural contract is verified deterministically without replication.
-- Regression target: Phase 2A attach failure ("model needs a BasePart
-- PrimaryPart") caused by relying on PrimaryPart replication instead of an
-- explicit ready structure.

local VehicleContract = require(game:GetService("ReplicatedStorage").Shared.vehicle.VehicleContract)

local function mockPart(isBasePart: boolean): any
	return {
		IsA = function(_self: any, className: string): boolean
			return isBasePart and className == "BasePart"
		end,
	}
end

local function mockModel(root: any): any
	return {
		FindFirstChild = function(_self: any, name: string): any
			if name == VehicleContract.ROOT_PART_NAME then
				return root
			end
			return nil
		end,
	}
end

return function()
	describe("contract constants", function()
		it("pins the shared root name and readiness attribute", function()
			expect(VehicleContract.ROOT_PART_NAME).to.equal("Chassis")
			expect(VehicleContract.READY_ATTRIBUTE).to.equal("NIGHTSHIFT_Ready")
		end)

		it("pins the interaction structure names and driver attribute", function()
			expect(VehicleContract.DRIVER_SEAT_NAME).to.equal("DriverSeat")
			expect(VehicleContract.DRIVER_ENTRY_NAME).to.equal("DriverEntry")
			expect(VehicleContract.DRIVER_EXIT_NAME).to.equal("DriverExitPoint")
			expect(VehicleContract.DRIVER_ATTRIBUTE).to.equal("NIGHTSHIFT_DriverUserId")
		end)
	end)

	describe("isComplete (structure; distinct from the replication attribute)", function()
		it("accepts a model with a BasePart root", function()
			local ok, _ = VehicleContract.isComplete(mockModel(mockPart(true)))
			expect(ok).to.equal(true)
		end)

		it("rejects a model missing its root part", function()
			local ok, reason = VehicleContract.isComplete(mockModel(nil))
			expect(ok).to.equal(false)
			expect(string.find(reason, VehicleContract.ROOT_PART_NAME) ~= nil).to.equal(true)
		end)

		it("rejects a root part that is not a BasePart", function()
			local ok, _ = VehicleContract.isComplete(mockModel(mockPart(false)))
			expect(ok).to.equal(false)
		end)

		it("rejects non-models and children-less tables", function()
			local ok, _ = VehicleContract.isComplete(nil)
			expect(ok).to.equal(false)
			ok, _ = VehicleContract.isComplete(42)
			expect(ok).to.equal(false)
			ok, _ = VehicleContract.isComplete({})
			expect(ok).to.equal(false)
		end)
	end)

	describe("resolveRoot", function()
		it("returns the named root and nothing else", function()
			local root = mockPart(true)
			expect(VehicleContract.resolveRoot(mockModel(root))).to.equal(root)
		end)

		it("returns nil for incomplete models", function()
			expect(VehicleContract.resolveRoot(mockModel(nil))).to.equal(nil)
			expect(VehicleContract.resolveRoot(mockModel(mockPart(false)))).to.equal(nil)
			expect(VehicleContract.resolveRoot(nil)).to.equal(nil)
		end)
	end)

	describe("findSeat", function()
		local function mockSeat(isSeat: boolean): any
			return {
				IsA = function(_self: any, className: string): boolean
					return isSeat and className == "Seat"
				end,
			}
		end
		local function mockModelWithSeat(seat: any): any
			return {
				FindFirstChild = function(_self: any, name: string): any
					if name == VehicleContract.DRIVER_SEAT_NAME then
						return seat
					end
					return nil
				end,
			}
		end

		it("returns the driver seat when present", function()
			local seat = mockSeat(true)
			expect(VehicleContract.findSeat(mockModelWithSeat(seat))).to.equal(seat)
		end)

		it("returns nil when the seat is missing or not a Seat", function()
			expect(VehicleContract.findSeat(mockModelWithSeat(nil))).to.equal(nil)
			expect(VehicleContract.findSeat(mockModelWithSeat(mockSeat(false)))).to.equal(nil)
			expect(VehicleContract.findSeat(nil)).to.equal(nil)
			expect(VehicleContract.findSeat({})).to.equal(nil)
		end)
	end)
end
