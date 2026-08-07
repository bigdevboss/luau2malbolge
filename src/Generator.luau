--!strict

local Machine = require("./Machine")

local Generator = {}

export type GenResult = {
	ok: boolean,
	source: string,
	normalized: string,
	error: string?,
}

local function safeWrite(v: number): boolean
	return v >= 33 and v <= 126
end

local function findPath(
	startA: number,
	startAddr: number,
	targetByte: number,
	maxDepth: number
): ({ string }?, number?)
	if startA % 256 == targetByte then
		return {}, startA
	end

	local frontier: { [number]: { string } } = { [startA] = {} }

	for depth = 1, maxDepth do
		local addr = startAddr + depth - 1
		local vStar = Machine.encodeAt("*", addr)
		local vP = Machine.encodeAt("p", addr)
		local vO = Machine.encodeAt("o", addr)

		local nextFrontier: { [number]: { string } } = {}

		for a, ops in pairs(frontier) do

			if vStar then
				local na = Machine.rotateRight(vStar)
				if nextFrontier[na] == nil then
					local t = table.clone(ops)
					table.insert(t, "*")
					nextFrontier[na] = t
				end
			end

			if vP then
				local na = Machine.crazy(a, vP)
				if nextFrontier[na] == nil then
					local t = table.clone(ops)
					table.insert(t, "p")
					nextFrontier[na] = t
				end
			end

			if vO then
				if nextFrontier[a] == nil then
					local t = table.clone(ops)
					table.insert(t, "o")
					nextFrontier[a] = t
				end
			end
		end

		frontier = nextFrontier

		for a, ops in pairs(frontier) do
			if a % 256 == targetByte then
				return ops, a
			end
		end

		local empty = true
		for _ in pairs(frontier) do
			empty = false
			break
		end
		if empty then
			break
		end
	end

	return nil, nil
end

function Generator.printString(text: string, maxDepth: number?): GenResult
	local depth = maxDepth or 40
	local ops: { string } = {}
	local a = 0
	local addr = 0

	for i = 1, #text do
		local target = string.byte(text, i)
		local path, newA = findPath(a, addr, target, depth)
		if not path then
			return {
				ok = false,
				source = "",
				normalized = "",
				error = `не найден путь для символа #{i} ('{string.char(target)}') на адресе {addr}`,
			}
		end

		for _, op in path do
			table.insert(ops, op)
			addr += 1
		end

		table.insert(ops, "<")
		addr += 1
		a = newA :: number
	end

	table.insert(ops, "v")

	local normalized = table.concat(ops)

	local chars: { string } = {}
	for i, op in ops do
		local v = Machine.encodeAt(op, i - 1)
		if not v then
			return {
				ok = false,
				source = "",
				normalized = normalized,
				error = `невозможно закодировать '{op}' на адресе {i - 1}`,
			}
		end
		table.insert(chars, string.char(v))
	end

	return {
		ok = true,
		source = table.concat(chars),
		normalized = normalized,
		error = nil,
	}
end

function Generator.assemble(normalized: string): GenResult
	local chars: { string } = {}
	for i = 1, #normalized do
		local op = normalized:sub(i, i)
		local v = Machine.encodeAt(op, i - 1)
		if not v then
			return {
				ok = false,
				source = "",
				normalized = normalized,
				error = `невозможно закодировать '{op}' на адресе {i - 1}`,
			}
		end
		table.insert(chars, string.char(v))
	end
	return { ok = true, source = table.concat(chars), normalized = normalized, error = nil }
end

return Generator
