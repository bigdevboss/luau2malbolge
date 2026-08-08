# luau2malbolge

A Malbolge program generator written in Luau. You give it a string and it hands back a Malbolge program that prints that string when run. There is also a Malbolge interpreter so you can watch the output, plus some analysis helpers.

The name suggests a Luau to Malbolge compiler. It isn't one. It is written in Luau, and it produces Malbolge. The hard part is the same either way, so read on.

## The problem

Malbolge isn't hard because the rules are complicated. It is hard because the program text and the program state are tangled together. Every instruction rewrites itself after it runs. So you can't just write code that prints a string. You have to find, for each byte you want in memory, a walk through the self-modifying state machine that lands on it. Do that for a whole string and you've earned your Malbolge.

## What's in `src/`

- **Machine.luau**: the Malbolge virtual machine. The two translation tables, the crazy ternary operation, the rotate-right, and the encode/decode trick that maps a character to the instruction producing it at a given address.
- **Generator.luau**: the main generator. It runs a breadth-first search over the crazy operation to find an instruction sequence that reaches each target byte, then assembles those normalized ops into valid Malbolge source.
- **GeneratorJI.luau**: a second generator with a different layout, building a more compact program around a leading jump.
- **Interpreter.luau**: runs the Malbolge you just made, so you can prove it works.
- **Tracer.luau** and **LoopFinder.luau**: analysis helpers the generator leans on.
- **test.luau**: a small test that generates strings, runs them, and checks the output matches.

## Run it

You need a Luau runtime. Roblox Studio works, or the standalone Luau CLI.

```lua
local gen = require(path .. ".src.Generator")
local out = gen.printString("hi")
if out.ok then
    print(out.source) -- a real, runnable Malbolge program
    local result = require(path .. ".src.Interpreter").run(out.source)
    print(result.output) -- hi
end
```

## Notes

The BFS has a depth limit (default 40). Very long strings can fail to find a path, which is just the nature of the language, not a bug. Start small.

License: MIT.
