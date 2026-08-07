--!strict
local Machine = require("./Machine")
local Generator = require("./Generator")
local GeneratorJI = require("./GeneratorJI")
local Interpreter = require("./Interpreter")

local pass, fail = 0, 0
local function check(name: string, cond: boolean, detail: string?)
	if cond then pass += 1; print("  [PASS] " .. name)
	else fail += 1; print("  [FAIL] " .. name .. "  " .. (detail or "")) end
end

print("canonical cat")
local norm = "jpoo*pjoooop*ojoopoo*ojoooooppjoivvvo/i<ivivi<vvvvvvvvvvvvvoji"
local catBytes: { number } = {}
for i = 1, #norm do
	local v = Machine.encodeAt(norm:sub(i, i), i - 1) :: number
	table.insert(catBytes, v)
end
local catSrc = string.char(table.unpack(catBytes :: {any}))
local r = Interpreter.run(catSrc, { input = "Hi", maxSteps = 300_000 })
check("cat echoes hi", r.output:sub(1, 2) == "Hi",
	string.format("got %q (steps=%d reason=%s)", r.output:sub(1, 16), r.steps, r.reason))

print("machine crazy")
check("crazy(0,0)==29524", Machine.crazy(0, 0) == 29524, "got " .. tostring(Machine.crazy(0, 0)))
check("crazy(1,0)==29523", Machine.crazy(1, 0) == 29523, "got " .. tostring(Machine.crazy(1, 0)))

print("generatorji")
for _, s in { "Hi", "A", "ABC", "Hello!", "Luau" } do
	local res = GeneratorJI.printString(s, 10)
	if not res.ok then
		check("genji " .. s, false, res.error)
	else
		local rr = Interpreter.run(res.source, { maxSteps = 5_000_000 })
		check(string.format("genji %s matches", s), rr.output == s,
			string.format("got %q want %q", rr.output, s))
	end
end

print("generator")
for _, s in { "H", "Hi", "ABC", "Hello, World!", "Luau2Malbolge" } do
	local res = Generator.printString(s, 60)
	if not res.ok then
		check("gen " .. s, false, res.error)
	else
		local rr = Interpreter.run(res.source, { maxSteps = 8_000_000 })
		check(string.format("gen %s matches", s), rr.output == s,
			string.format("got %q want %q", rr.output, s))
	end
end

print("interpreter")
local haltSrc = string.char(Machine.encodeAt("v", 0) :: number)
local r2 = Interpreter.run(haltSrc, { maxSteps = 100 })
check("v halts", r2.reason == "halt", "reason=" .. r2.reason)

print(string.format("result: %d passed, %d failed", pass, fail))
