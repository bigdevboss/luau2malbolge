--!strict

local Machine = require("./Machine")

local Interpreter = {}

export type RunResult = {
	ok: boolean,
	output: string,
	steps: number,
	reason: string,
}

export type RunOptions = {
	input: string?,
	maxSteps: number?,
}

function Interpreter.load(source: string): ({ number }?, string?)
	local mem: { number } = table.create(Machine.MEM_SIZE, 0)
	local i = 0

	for k = 1, #source do
		local ch = string.byte(source, k)

		if ch == 32 or ch == 9 or ch == 10 or ch == 13 or ch == 11 or ch == 12 then
			continue
		end

		if ch < 127 and ch > 32 then
			local op = Machine.decodeAt(ch, i)
			if not Machine.OPCODES:find(op, 1, true) then
				return nil, `invalid character in source at position {k} (char {string.char(ch)}, decodes to '{op}')`
			end
		end

		if i >= Machine.MEM_SIZE then
			return nil, "input file too long"
		end

		mem[i + 1] = ch
		i += 1
	end

	if i == 0 then
		mem[1] = 0
		i = 1
	end
	if i == 1 then
		mem[2] = 0
		i = 2
	end

	while i < Machine.MEM_SIZE do
		mem[i + 1] = Machine.crazy(mem[i], mem[i - 1])
		i += 1
	end

	return mem, nil
end

function Interpreter.run(source: string, options: RunOptions?): RunResult
	local opts = options or {}
	local maxSteps = opts.maxSteps or 10000000
	local input = opts.input or ""
	local inputPos = 1

	local mem, err = Interpreter.load(source)
	if not mem then
		return { ok = false, output = "", steps = 0, reason = err or "load error" }
	end

	local a, c, d = 0, 0, 0
	local outParts: { string } = {}
	local steps = 0

	while steps < maxSteps do
		steps += 1

		local cell = mem[c + 1]

		if cell < 33 or cell > 126 then
			return {
				ok = false,
				output = table.concat(outParts),
				steps = steps,
				reason = "hang",
			}
		end

		local op = Machine.decodeAt(cell, c)

		if op == "j" then
			d = mem[d + 1]
		elseif op == "i" then
			c = mem[d + 1]
		elseif op == "*" then
			local v = Machine.rotateRight(mem[d + 1])
			mem[d + 1] = v
			a = v
		elseif op == "p" then
			local v = Machine.crazy(a, mem[d + 1])
			mem[d + 1] = v
			a = v
		elseif op == "<" then

			table.insert(outParts, string.char(a % 256))
		elseif op == "/" then

			if inputPos > #input then
				a = 59048
			else
				a = string.byte(input, inputPos)
				inputPos += 1
			end
		elseif op == "v" then
			return {
				ok = true,
				output = table.concat(outParts),
				steps = steps,
				reason = "halt",
			}
		end

		mem[c + 1] = Machine.encrypt(mem[c + 1])

		if c == Machine.LAST_ADDR then
			c = 0
		else
			c += 1
		end
		if d == Machine.LAST_ADDR then
			d = 0
		else
			d += 1
		end
	end

	return {
		ok = false,
		output = table.concat(outParts),
		steps = steps,
		reason = "maxsteps",
	}
end

return Interpreter
