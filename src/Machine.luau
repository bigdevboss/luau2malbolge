--!strict

local Machine = {}

Machine.MEM_SIZE = 59049
Machine.LAST_ADDR = 59048

Machine.XLAT1 = "+b(29e*j1VMEKLyC})8&m#~W>qxdRp0wkrUo[D7,XTcA\"lI"
	.. ".v%{gJh4G\\-=O@5`_3i<?Z';FNQuY]szf$!BS/|t:Pn6^Ha"

Machine.XLAT2 = "5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1C"
	.. "B6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@"

Machine.OPCODES = "ji*p</vo"

local P9 = { 1, 9, 81, 729, 6561 }
Machine.P9 = P9

local CRAZY = {
	{ 4, 3, 3, 1, 0, 0, 1, 0, 0 },
	{ 4, 3, 5, 1, 0, 2, 1, 0, 2 },
	{ 5, 5, 4, 2, 2, 1, 2, 2, 1 },
	{ 4, 3, 3, 1, 0, 0, 7, 6, 6 },
	{ 4, 3, 5, 1, 0, 2, 7, 6, 8 },
	{ 5, 5, 4, 2, 2, 1, 8, 8, 7 },
	{ 7, 6, 6, 7, 6, 6, 4, 3, 3 },
	{ 7, 6, 8, 7, 6, 8, 4, 3, 5 },
	{ 8, 8, 7, 8, 8, 7, 5, 5, 4 },
}
Machine.CRAZY = CRAZY

function Machine.crazy(x: number, y: number): number
	local result = 0
	for j = 1, 5 do
		local p = P9[j]
		local yd = (y // p) % 9
		local xd = (x // p) % 9

		result += CRAZY[yd + 1][xd + 1] * p
	end
	return result
end

function Machine.rotateRight(v: number): number
	return v // 3 + (v % 3) * 19683
end

function Machine.decodeAt(value: number, addr: number): string
	local idx = (value - 33 + addr) % 94
	return Machine.XLAT1:sub(idx + 1, idx + 1)
end

function Machine.encodeAt(op: string, addr: number): number?
	local pos = Machine.XLAT1:find(op, 1, true)
	if not pos then
		return nil
	end

	local value = ((pos - 1 - addr) % 94) + 33
	if value < 33 or value > 126 then
		return nil
	end
	return value
end

function Machine.encrypt(value: number): number
	if value < 33 or value > 126 then
		return value
	end
	return string.byte(Machine.XLAT2, value - 33 + 1)
end

return Machine
