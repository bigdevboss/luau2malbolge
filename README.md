# luau2malbolge

A Malbolge toolkit written in Luau. Includes a spec-correct VM, a code generator that produces Malbolge programs to print strings, an interpreter, a tracer, and a loop-finder for stable self-modifying loops.

Malbolge is an esoteric language designed by Ben Olmstead in 1998 to be nearly impossible to program in. It uses ternary arithmetic, self-modifying encrypted code, and the "crazy" operation. The first Hello World took two years and was found by a search program.

## What it actually is

Not a Luau-to-Malbolge transpiler (yet). The name suggests a transpiler, but currently it's a toolkit: a Malbolge VM, an interpreter, two string-to-program generators, and a loop research module. A full transpiler would need control flow (loops, conditionals), which is what `LoopFinder` is building toward.

## Components

### Machine (`Machine.luau`)
The Malbolge VM primitives:
- `crazy(x, y)` — tritwise crazy operation via a 9x9 pair table covering all 10 trits (`P9 = {1,9,81,729,6561}` = 3^0,3^2,3^4,3^6,3^8)
- `rotateRight(v)` — tritwise rotate right
- `encodeAt`/`decodeAt` — XLAT1 encryption/decryption
- `encrypt` — XLAT2 post-execution cipher
- Constants: `MEM_SIZE = 59049`, `OPCODES = "ji*p</vo"`

### Interpreter (`Interpreter.luau`)
Full Malbolge interpreter. Loads source, fills memory with crazy operation, executes all 8 opcodes (`j`, `i`, `*`, `p`, `<`, `/`, `v`, `o`). Supports input via `/` opcode, output via `<`, halt via `v`. Step limit configurable.

### Generator (`Generator.luau`)
Generates Malbolge code to print a string. Uses BFS pathfinding through accumulator state space to find sequences of `*` (rotr) and `p` (crazy) operations that produce each target byte, then `<` to output.

### GeneratorJI (`GeneratorJI.luau`)
Second generator using `j`/`i` instructions with a separated code/data memory layout. More expressive than the basic generator. Both generators were verified via round-trip testing on Lute.

### LoopFinder (`LoopFinder.luau`)
Research module for finding stable self-modifying loops. Key concepts:
- `orbit(addr, op)` — how many encryption steps until an opcode returns to itself
- `solveStability()` — searches for loop configurations where opcode orbits divide evenly into the loop length (LCM)
- `bodyFor(spec)` — picks gate opcodes whose orbits are compatible with the loop period

### Tracer (`Tracer.luau`)
Debug interpreter that records every execution step: register values, opcode, memory state, and a human-readable note for each operation.

## Verification

Tested on Lute (official Luau runtime) with a standalone Python reference interpreter as oracle:
- Interpreter passes the canonical Malbolge Cat program (from esolangs.org)
- `crazy(0,0) = 29524` (all-ones trits, verified against spec)
- `rotateRight(1) = 19683` (3^9)
- `encodeAt`/`decodeAt` round-trip across all 94 addresses
- Both generators produce correct output for test strings

### Known issue (fixed in this repo)
The basic `Generator.printString` had a `safeWrite()` filter that was too strict. It rejected accumulator values outside [33,126] even though the `<` opcode outputs `a % 256`. Removing the filter (matching `GeneratorJI` which never had it) fixes generation from `a = 0`.

## Usage

```lua
local GeneratorJI = require("./GeneratorJI")
local Interpreter = require("./Interpreter")

local res = GeneratorJI.printString("Hello, World!")
if res.ok then
    local r = Interpreter.run(res.source, { maxSteps = 5000000 })
    print(r.output) -- "Hello, World!"
end
```

Run tests:
```bash
lute run test.luau
```

## Structure

```
src/
├── Machine.luau       — VM primitives (crazy, rotr, encode/decode, encrypt)
├── Interpreter.luau   — full Malbolge interpreter
├── Generator.luau     — string-to-program generator (BFS)
├── GeneratorJI.luau   — j/i-based generator with code/data separation
├── LoopFinder.luau    — stable loop research (orbit analysis + LCM)
├── Tracer.luau        — step-by-step debug tracer
└── test.luau          — test suite (14 tests, all passing)
```

## License

MIT
