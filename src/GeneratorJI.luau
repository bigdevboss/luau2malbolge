--!strict

local Machine = require("./Machine")

local GeneratorJI = {}

export type GenResult = {
	ok: boolean,
	source: string,
	normalized: string,
	steps: number?,
	error: string?,
}

local DATA_OFFSET = 40
local MAX_CODE_POS = 40

type Choice = { op: string, value: number }

local function dataChoices(addr: number): { Choice }
	local out: { Choice } = {}
	local seen: { [number]: boolean } = {}
	for i = 1, #Machine.OPCODES do
		local op = Machine.OPCODES:sub(i, i)
		local v = Machine.encodeAt(op, addr)
		if v and not seen[v] then
			seen[v] = true
			table.insert(out, { op = op, value = v })
		end
	end
	return out
end

type Step = { codeOp: string, dataOp: string }

local function findPath(
	startA: number,
	startPos: number,
	targetByte: number,
	maxDepth: number
): { Step }?
	if startA % 256 == targetByte then
		return {}
	end

	local frontier: { [number]: { Step } } = { [startA] = {} }

	for depth = 1, maxDepth do
		local pos = startPos + depth - 1
		if pos > MAX_CODE_POS then
			return nil
		end

		local choices = dataChoices(pos + DATA_OFFSET)
		local nextFrontier: { [number]: { Step } } = {}

		local function offer(a: number, path: { Step })
			if nextFrontier[a] == nil then
				nextFrontier[a] = path
			end
		end

		for a, path in pairs(frontier) do

			for _, ch in choices do
				local na = Machine.rotateRight(ch.value)
				if nextFrontier[na] == nil then
					local t = table.clone(path)
					table.insert(t, { codeOp = "*", dataOp = ch.op })
					offer(na, t)
				end
			end

			for _, ch in choices do
				local na = Machine.crazy(a, ch.value)
				if nextFrontier[na] == nil then
					local t = table.clone(path)
					table.insert(t, { codeOp = "p", dataOp = ch.op })
					offer(na, t)
				end
			end

			local t = table.clone(path)
			table.insert(t, { codeOp = "o", dataOp = "o" })
			offer(a, t)
		end

		frontier = nextFrontier

		for a, path in pairs(frontier) do
			if a % 256 == targetByte then
				return path
			end
		end
	end

	return nil
end

function GeneratorJI.printString(text: string, maxDepth: number?): GenResult
	local depth = maxDepth or 6
	local steps: { Step } = {}
	local a = 0

	for i = 1, #text do
		local target = string.byte(text, i)
		local pos = #steps + 1

		local path = findPath(a, pos, target, depth)
		if not path then
			return {
				ok = false,
				source = "",
				normalized = "",
				error = `не найден путь для символа #{i} ('{string.char(target)}'), позиция {pos}`,
			}
		end

		for _, st in path do
			table.insert(steps, st)

			local dpos = #steps + DATA_OFFSET
			local v = Machine.encodeAt(st.dataOp, dpos)
			if st.codeOp == "*" then
				a = Machine.rotateRight(v :: number)
			elseif st.codeOp == "p" then
				a = Machine.crazy(a, v :: number)
			end
		end

		table.insert(steps, { codeOp = "<", dataOp = "o" })

		if #steps > MAX_CODE_POS - 1 then
			return {
				ok = false,
				source = "",
				normalized = "",
				error = `строка не помещается: нужно {#steps + 1} позиций кода, доступно {MAX_CODE_POS}`,
			}
		end
	end

	table.insert(steps, { codeOp = "v", dataOp = "o" })

	local K = #steps
	if K > MAX_CODE_POS then
		return {
			ok = false,
			source = "",
			normalized = "",
			error = `программа слишком длинная: {K} > {MAX_CODE_POS}`,
		}
	end

	local total = K + DATA_OFFSET + 1
	local bytes: { number } = table.create(total, 0)

	local vj = Machine.encodeAt("j", 0)
	if not vj then
		return { ok = false, source = "", normalized = "", error = "невозможно закодировать 'j' на 0" }
	end
	bytes[1] = vj

	for p = 1, K do
		local v = Machine.encodeAt(steps[p].codeOp, p)
		if not v then
			return {
				ok = false,
				source = "",
				normalized = "",
				error = `невозможно закодировать '{steps[p].codeOp}' на {p}`,
			}
		end
		bytes[p + 1] = v
	end

	for p = K + 1, DATA_OFFSET do
		local v = Machine.encodeAt("o", p)
		if not v then
			return { ok = false, source = "", normalized = "", error = `наполнитель на {p}` }
		end
		bytes[p + 1] = v
	end

	for p = 1, K do
		local dpos = p + DATA_OFFSET
		local v = Machine.encodeAt(steps[p].dataOp, dpos)
		if not v then
			return {
				ok = false,
				source = "",
				normalized = "",
				error = `невозможно закодировать данные '{steps[p].dataOp}' на {dpos}`,
			}
		end
		bytes[dpos + 1] = v
	end

	local chars: { string } = {}
	for i = 1, total do
		chars[i] = string.char(bytes[i])
	end

	local normParts: { string } = { "j" }
	for p = 1, K do
		table.insert(normParts, steps[p].codeOp)
	end

	return {
		ok = true,
		source = table.concat(chars),
		normalized = table.concat(normParts),
		steps = K,
		error = nil,
	}
end

return GeneratorJI
