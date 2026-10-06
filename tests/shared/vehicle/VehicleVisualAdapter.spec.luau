--!nonstrict
-- NIGHTSHIFT VehicleVisualAdapter spec (TestEZ).
-- Non-strict by exception: TestEZ injects describe/it/expect as globals.
-- Mock instances stand in for Studio geometry; no mesh names are hardcoded.
-- Regression targets: recursive discovery, visual-only flags, weld strategy,
-- transform preservation, idempotency, seating-class exclusion.

local Adapter = require(game:GetService("ReplicatedStorage").Shared.vehicle.VehicleVisualAdapter)

local function tracked(init: any): any
	local obj: any = init or {}
	obj._sets = {}
	obj.Destroyed = false
	obj.Destroy = function(self: any)
		self.Destroyed = true
	end
	return setmetatable(obj, {
		__newindex = function(t: any, k: string, v: any)
			t._sets[k] = v
			rawset(t, k, v)
		end,
	})
end

local function mockPart(name: string, classes: any, childWeld: any): any
	local set = {}
	for _, c in classes do
		set[c] = true
	end
	local obj = tracked({ Name = name })
	obj.IsA = function(_self: any, className: string): boolean
		return set[className] == true
	end
	obj.FindFirstChild = function(_self: any, _child: string): any
		return childWeld
	end
	return obj
end

local function makeFactory(created: any, failAt: any): any
	local count = 0
	return function(className: string): any
		count += 1
		if failAt ~= nil and count == failAt then
			error("boom:" .. className)
		end
		local obj = tracked({ ClassName = className })
		table.insert(created, obj)
		return obj
	end
end

return function()
	describe("collect", function()
		it("discovers BaseParts recursively and skips seating classes", function()
			local body = mockPart("BodyPanel", { "BasePart" }, nil)
			local seat = mockPart("DriveSeat", { "BasePart", "Seat" }, nil)
			local decal = mockPart("Logo", { "Decal" }, nil)
			local spawn = mockPart("Pad", { "BasePart", "SpawnLocation" }, nil)
			local root = tracked(nil)
			root.GetDescendants = function()
				return { body, seat, decal, spawn }
			end
			local scan = Adapter.collect(root)
			expect(#scan.parts).to.equal(1)
			expect(scan.parts[1]).to.equal(body)
			expect(#scan.skipped).to.equal(2)
		end)

		it("ignores non-BasePart objects entirely", function()
			local mesh = mockPart("Mesh", { "SpecialMesh" }, nil)
			local root = tracked(nil)
			root.GetDescendants = function()
				return { mesh }
			end
			local scan = Adapter.collect(root)
			expect(#scan.parts).to.equal(0)
			expect(#scan.skipped).to.equal(0)
		end)

		it("returns empty scans for unusable roots", function()
			local scan = Adapter.collect(nil)
			expect(#scan.parts).to.equal(0)
			expect(#scan.skipped).to.equal(0)
		end)
	end)

	describe("attach", function()
		it("configures visual-only flags and welds to the chassis", function()
			local chassis = mockPart("Chassis", { "BasePart" }, nil)
			local panel = mockPart("Door", { "BasePart", "MeshPart" }, nil)
			local created: any = {}
			local stats = Adapter.attach(chassis, { panel }, makeFactory(created, nil))
			expect(stats.welded).to.equal(1)
			expect(stats.failed).to.equal(0)
			expect(panel._sets.Anchored).to.equal(false)
			expect(panel._sets.Massless).to.equal(true)
			expect(panel._sets.CanCollide).to.equal(false)
			expect(panel._sets.CanTouch).to.equal(false)
			expect(panel._sets.CanQuery).to.equal(false)
			expect(#created).to.equal(1)
			local weld = created[1]
			expect(weld._sets.Name).to.equal(Adapter.WELD_NAME)
			expect(weld._sets.Part0).to.equal(chassis)
			expect(weld._sets.Part1).to.equal(panel)
			expect(weld._sets.Parent).to.equal(chassis)
		end)

		it("never modifies part transforms", function()
			local chassis = mockPart("Chassis", { "BasePart" }, nil)
			local panel = mockPart("Fender", { "BasePart" }, nil)
			local created: any = {}
			Adapter.attach(chassis, { panel }, makeFactory(created, nil))
			expect(panel._sets.CFrame).to.equal(nil)
			expect(panel._sets.Position).to.equal(nil)
		end)

		it("skips parts already carrying our weld (idempotent)", function()
			local chassis = mockPart("Chassis", { "BasePart" }, nil)
			local oldWeld = tracked(nil)
			oldWeld.IsA = function()
				return true
			end
			oldWeld.Part0 = chassis
			local panel = mockPart("Hood", { "BasePart" }, oldWeld)
			local created: any = {}
			local stats = Adapter.attach(chassis, { panel }, makeFactory(created, nil))
			expect(stats.welded).to.equal(0)
			expect(stats.alreadyWelded).to.equal(1)
			expect(#created).to.equal(0)
		end)

		it("skips the chassis itself", function()
			local chassis = mockPart("Chassis", { "BasePart" }, nil)
			local created: any = {}
			local stats = Adapter.attach(chassis, { chassis }, makeFactory(created, nil))
			expect(stats.welded).to.equal(0)
			expect(#created).to.equal(0)
		end)

		it("counts failures without aborting the batch", function()
			local chassis = mockPart("Chassis", { "BasePart" }, nil)
			local a = mockPart("A", { "BasePart" }, nil)
			local b = mockPart("B", { "BasePart" }, nil)
			local created: any = {}
			local stats = Adapter.attach(chassis, { a, b }, makeFactory(created, 2))
			expect(stats.welded).to.equal(1)
			expect(stats.failed).to.equal(1)
		end)
	end)
end
