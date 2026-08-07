--!strict

local Machine = require("./Machine")
local Interpreter = require("./Interpreter")

local Tracer = {}

export type TraceStep = {
	step: number,
	c: number,
	d: number,
	a: number,
	op: string,
	memD: number,
	note: string,
}

function Tracer.trace(source: string, maxSteps: number, input: string?): ({ TraceStep }, string, string)
	local mem, err = Interpreter.load(source)
	if not mem then
		return {}, "", err or "load error"
	end

	local a, c, d = 0, 0, 0
	local steps: { TraceStep } = {}
	local outParts: { string } = {}
	local inputStr = input or ""
	local inputPos = 1

	for step = 1, maxSteps do
		local cell = mem[c + 1]
		if cell < 33 or cell > 126 then
			return steps, table.concat(outParts), "hang"
		end

		local op = Machine.decodeAt(cell, c)
		local note = ""

		if op == "j" then
			d = mem[d + 1]
			note = `d := mem[d] = {d}`
		elseif op == "i" then
			c = mem[d + 1]
			note = `c := mem[d] = {c} (далее c+1 = {c + 1})`
		elseif op == "*" then
			local v = Machine.rotateRight(mem[d + 1])
			mem[d + 1] = v
			a = v
			note = `a := rotr = {v}`
		elseif op == "p" then
			local v = Machine.crazy(a, mem[d + 1])
			mem[d + 1] = v
			a = v
			note = `a := crazy = {v}`
		elseif op == "<" then
			local ch = a % 256
			table.insert(outParts, string.char(ch))
			note = `output {ch} '{string.char(ch)}'`
		elseif op == "/" then
			if inputPos > #inputStr then
				a = 59048
				note = "input EOF"
			else
				a = string.byte(inputStr, inputPos)
				inputPos += 1
				note = `input {a}`
			end
		elseif op == "v" then
			table.insert(steps, {
				step = step,
				c = c,
				d = d,
				a = a,
				op = op,
				memD = mem[d + 1],
				note = "HALT",
			})
			return steps, table.concat(outParts), "halt"
		else
			note = "nop"
		end

		table.insert(steps, {
			step = step,
			c = c,
			d = d,
			a = a,
			op = op,
			memD = mem[d + 1],
			note = note,
		})

		mem[c + 1] = Machine.encrypt(mem[c + 1])

		if c == Machine.LAST_ADDR then c = 0 else c += 1 end
		if d == Machine.LAST_ADDR then d = 0 else d += 1 end
	end

	return steps, table.concat(outParts), "maxsteps"
end

function Tracer.dump(steps: { TraceStep }, limit: number?)
	local n = math.min(#steps, limit or 60)
	print("step |    c |    d | op |     a | mem[d] | note")
	print("-----+------+------+----+-------+--------+------")
	for i = 1, n do
		local s = steps[i]
		print(string.format(
			"%4d | %4d | %4d |  %s | %5d | %6d | %s",
			s.step, s.c, s.d, s.op, s.a, s.memD, s.note
		))
	end
	if #steps > n then
		print(`... ещё {#steps - n} шагов`)
	end
end

return Tracer
