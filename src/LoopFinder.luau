--!strict

local Machine = require("./Machine")

local LoopFinder = {}

function LoopFinder.transition(addr: number, op: string): string?
	local v = Machine.encodeAt(op, addr)
	if not v then
		return nil
	end
	return Machine.decodeAt(Machine.encrypt(v), addr)
end

function LoopFinder.orbit(addr: number, op: string): number
	local cur = op
	local len = 0
	repeat
		local nxt = LoopFinder.transition(addr, cur)
		if not nxt then
			return math.huge
		end
		cur = nxt
		len += 1
	until cur == op or len > 200
	return if cur == op then len else math.huge
end

local function gcd(a: number, b: number): number
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

local function lcm(a: number, b: number): number
	return a // gcd(a, b) * b
end

function LoopFinder.build(
	jPos: number,
	codeAt: { [number]: string },
	dataAt: { [number]: string },
	total: number
): string
	local bytes: { number } = {}
	for i = 0, total do
		bytes[i + 1] = Machine.encodeAt("o", i) :: number
	end
	bytes[jPos + 1] = Machine.encodeAt("j", jPos) :: number
	for p, op in pairs(codeAt) do
		local v = Machine.encodeAt(op, p)
		if v then
			bytes[p + 1] = v
		end
	end
	for p, op in pairs(dataAt) do
		local v = Machine.encodeAt(op, p)
		if v then
			bytes[p + 1] = v
		end
	end
	local chars: { string } = {}
	for i = 1, total + 1 do
		chars[i] = string.char(bytes[i])
	end
	return table.concat(chars)
end

function LoopFinder.offsetOf(jPos: number): number?
	local v = Machine.encodeAt("j", jPos)
	if not v then
		return nil
	end
	return v - jPos
end

function LoopFinder.offsets(): { { pos: number, off: number } }
	local out = {}
	for p = 0, 93 do
		local off = LoopFinder.offsetOf(p)
		if off and off > 0 then
			table.insert(out, { pos = p, off = off })
		end
	end
	return out
end

export type LoopSpec = {
	jPos: number,
	off: number,
	B: number,
	J2: number,
	L: number,
	Dj: number,
	dop: string,
	Ai: number,
	iop: string,
}

function LoopFinder.solveStability(): { LoopSpec }
	local sols: { LoopSpec } = {}
	for _, cfg in LoopFinder.offsets() do
		local OFF, jPos = cfg.off, cfg.pos
		for B = math.max(34, jPos + 1), 120 do
			for J2 = B + 1, 126 do
				local Dj = J2 + OFF
				local needVj = OFF + B - 2
				if needVj >= 33 and needVj <= 126 then
					local dop: string? = nil
					for k = 1, #Machine.OPCODES do
						local op = Machine.OPCODES:sub(k, k)
						if Machine.encodeAt(op, Dj) == needVj then
							dop = op
							break
						end
					end
					if dop then
						local Ai = needVj + 1
						local iop: string? = nil
						for k = 1, #Machine.OPCODES do
							local op = Machine.OPCODES:sub(k, k)
							if Machine.encodeAt(op, Ai) == B - 1 then
								iop = op
								break
							end
						end
						if iop then
							table.insert(sols, {
								jPos = jPos,
								off = OFF,
								B = B,
								J2 = J2,
								L = J2 + 2 - B,
								Dj = Dj,
								dop = dop :: string,
								Ai = Ai,
								iop = iop :: string,
							})
						end
					end
				end
			end
		end
	end
	return sols
end

function LoopFinder.bodyFor(spec: LoopSpec): { [number]: string }?
	local code: { [number]: string } = { [spec.J2] = "j", [spec.J2 + 1] = "i" }
	for a = spec.B, spec.J2 - 1 do
		local pick: string? = nil
		for _, c in { "o", "*", "p", "<", "/" } do
			local o = LoopFinder.orbit(a, c)
			if o < math.huge and spec.L % o == 0 then
				pick = c
				break
			end
		end
		if not pick then
			return nil
		end
		code[a] = pick :: string
	end
	if spec.L % LoopFinder.orbit(spec.J2, "j") ~= 0 then
		return nil
	end
	if spec.L % LoopFinder.orbit(spec.J2 + 1, "i") ~= 0 then
		return nil
	end
	return code
end

LoopFinder.lcm = lcm
LoopFinder.gcd = gcd

return LoopFinder
