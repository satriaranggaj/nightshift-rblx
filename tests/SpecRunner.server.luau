--!strict
-- NIGHTSHIFT Studio spec runner (TestEZ).
-- Discovers every ModuleScript named `*.spec` under TestService/Tests and runs
-- it with the text reporter. Server-side is sufficient while specs cover pure
-- shared logic; client-only specs (adapters, UI) will need a client runner later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local TestEZ = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("TestEZ"))

local specs: { ModuleScript } = {}
for _, descendant in TestService:WaitForChild("Tests"):GetDescendants() do
	if descendant:IsA("ModuleScript") and descendant.Name:match("%.spec$") then
		table.insert(specs, descendant)
	end
end

TestEZ.TestBootstrap:run(specs, TestEZ.Reporters.TextReporter)
