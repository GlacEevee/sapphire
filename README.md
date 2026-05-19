<div align="center">

# 💎 Sapphire

**A clean, expressive scripting language built in Ruby.**

![Version](https://img.shields.io/badge/version-0.4.0-blue)
![Ruby](https://img.shields.io/badge/ruby-3.0%2B-red)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Raspberry%20Pi-lightgrey)

</div>

---

## What is Sapphire?

Sapphire is a dynamically typed scripting language with a clean syntax inspired by Ruby and JavaScript. It runs on top of Ruby and comes with a built-in package manager (`sph`) and a system manager (`spm`) that handles interpreter updates straight from GitHub.

It's designed to be simple enough to pick up in an afternoon, powerful enough to build real bots and tools with, and easy to extend with packages.

```sp
fn greet(name, greeting = "Hello") {
  return `#{greeting}, #{name}!`
}

println(greet("world"))
println(greet("Sapphire", greeting: "Welcome to"))
```

---

## Features

- Clean, readable syntax with `fn`, `let`, `const`, `class`
- String interpolation with `` `#{expr}` ``
- First-class functions and closures
- Pattern matching with `match`
- Classes with inheritance (`class Dog < Animal`)
- Error handling with `try` / `catch` / `finally`
- Arrays, hashes, ranges, and a full set of iterators
- Variadic functions (`fn sum(*nums)`)
- Default and named arguments
- `import` / `from X import Y` module system
- Built-in HTTP client and gateway WebSocket support
- Discord bot framework via `discordsph`
- Package manager (`sph`) with versioned installs
- System manager (`spm`) with GitHub-based auto-update

---

## Installation

### Quick install (recommended)

```bash
git clone https://github.com/GlacEevee/sapphire.git ~/lang/sapphire
cd ~/lang/sapphire
bash install.sh --user
```

This installs three commands into `~/bin`:

| Command | What it does |
|---|---|
| `sapphire` | Run `.sp` files and the REPL |
| `sph` | Package manager |
| `spm` | Sapphire system manager (updates, status) |

If `~/bin` isn't on your `PATH` yet, the installer will tell you and show you the one-liner to fix it.

### Requirements

- Ruby 3.0 or newer
- The `websocket-driver` gem (installed automatically by the installer)

### Verify

```bash
sapphire version
spm status
```

---

## Running Sapphire

```bash
# Run a file
sapphire myfile.sp
sapphire run myfile.sp   # same thing

# Interactive REPL
sapphire repl

# Syntax check without running
sapphire check myfile.sp
```

---

## Language Tour

### Variables and types

```sp
let name    = "Sapphire"
const PI    = 3.14159
let active  = true
let nothing = nil
let nums    = [1, 2, 3, 4, 5]
let person  = { name: "Alice", age: 30 }
```

### String interpolation

```sp
let x = 10
println(`x squared is #{x ** 2}`)
println(`is even? #{x % 2 == 0 ? "yes" : "no"}`)
```

### Functions

```sp
fn add(a, b) {
  return a + b
}

# Default arguments
fn greet(name, greeting = "Hello") {
  return `#{greeting}, #{name}!`
}

# Named arguments at call site
greet("Alice", greeting: "Hi")

# Variadic
fn sum(*nums) {
  return nums.reduce({ |acc, n| acc + n }, 0)
}

# Closures
fn make_adder(n) {
  return { |x| x + n }
}
let add10 = make_adder(10)
println(add10(5))   # 15
```

### Control flow

```sp
if x > 100 {
  println("big")
} elif x > 50 {
  println("medium")
} else {
  println("small")
}

# Ternary
let label = x > 50 ? "large" : "small"

# While
while condition {
  # ...
  break
  next
}

# For with range
for i in 1..10 {
  println(i)
}
```

### Pattern matching

```sp
match day {
  "Saturday" => println("Weekend!")
  "Sunday"   => println("Weekend!")
  "Monday"   => println("Back to work...")
  _          => println(`${day} is a weekday`)
}

match true {
  score >= 90 => println("A")
  score >= 80 => println("B")
  _           => println("C or below")
}
```

### Arrays

```sp
let nums = [10, 3, 7, 1, 9]

nums.map({ |n| n * 2 })         # double each
nums.filter({ |n| n % 2 == 0 }) # keep evens
nums.reduce({ |acc, n| acc + n }, 0) # sum
nums.sort                        # sorted copy
nums.find({ |n| n > 7 })        # first match
nums.all?({ |n| n > 0 })        # predicate
nums.each({ |n| println(n) })   # iterate
```

### Hashes

```sp
let user = { name: "Bob", age: 25 }
println(user["name"])
user["job"] = "Developer"
println(user.keys)
```

### Classes

```sp
class Animal {
  fn init(name, sound) {
    self.name  = name
    self.sound = sound
  }

  fn speak() {
    return `#{self.name} says: #{self.sound}!`
  }
}

class Dog < Animal {
  fn init(name) {
    self.name   = name
    self.sound  = "Woof"
    self.tricks = []
  }

  fn learn(trick) {
    self.tricks.push(trick)
  }
}

let dog = new Dog("Rex")
dog.learn("sit")
println(dog.speak())
```

### Error handling

```sp
try {
  if b == 0 { raise "Cannot divide by zero!" }
  return a / b
} catch (err) {
  println(`Error: #{err}`)
} finally {
  println("always runs")
}
```

### Modules

```sp
import math
from strings import capitalize, truncate

println(math.fibonacci(10))
println(capitalize("hello world"))
```

---

## Package Manager — `sph`

```bash
sph install discordsph          # install latest
sph install discordsph 1.2.0    # install specific version
sph list                        # show installed packages
sph search discord              # search registry
sph info discordsph             # package details
sph remove discordsph           # uninstall
sph init                        # create sapphire.json for a project
```

### Available packages

| Package | Description |
|---|---|
| `discordsph` | Discord bot framework — commands, embeds, gateway, threads, webhooks |
| `dotenv` | Load `.env` files into `Sys.env()` |
| `math` | Extended math: primes, GCD, fibonacci, statistics |
| `strings` | String utilities: capitalize, truncate, palindrome, indent |
| `collections` | chunk, group_by, frequencies, compact |
| `io` | read_lines, write_lines, prompt, print_table |
| `datetime` | Date and time utilities |
| `test` | Minimalist unit testing framework |

### `sapphire.json`

```json
{
  "name": "my-bot",
  "version": "0.1.0",
  "main": "bot.sp",
  "dependencies": {
    "discordsph": "^1.4.0",
    "dotenv": "^1.0.0"
  }
}
```

Run `sph install` with no arguments to install everything listed.

---

## System Manager — `spm`

`spm` manages the Sapphire interpreter itself.

```bash
spm version          # show Sapphire + spm version, note if update available
spm check-update     # check GitHub for a newer release
spm self-update      # download and install latest Sapphire from GitHub
spm status           # full environment report (versions, packages, gems)
spm changelog        # view the full changelog
```

Package commands also work through `spm` — it forwards them to `sph`:

```bash
spm install discordsph 1.3.0
spm list
```

---

## Discord Bots with `discordsph`

```sp
import discordsph

let client   = discord_client(Sys.env("DISCORD_TOKEN"))
let commands = client.use_commands("!")

commands.register("ping", fn(msg, args) {
  msg.reply("Pong! 🏓")
})

commands.register_with_cooldown("daily", 86400, fn(msg, args) {
  msg.reply("Here's your daily reward!")
})

commands.use(fn(msg, cmd_name, args) {
  # Middleware — return false to block a command
  if msg.is_bot() { return false }
  return true
})

client.on_ready(fn(data) {
  println("Logged in as: " + data["user"]["username"])
})

client.on_reaction_add(fn(data) {
  println("Reaction added: " + data["emoji"]["name"])
})

client.login()
```

See [`stdlib/discordsph_README.md`](stdlib/discordsph_README.md) for the full API reference.

---

## Project Structure

```
sapphire/
├── sapphire.rb          # Main interpreter entry point
├── lexer.rb             # Tokeniser
├── parser.rb            # AST parser
├── interpreter.rb       # Tree-walking interpreter
├── ast.rb               # AST node definitions
├── types.rb             # Sapphire type system
├── environment.rb       # Variable scope/environment
├── sph.rb               # Package manager
├── spm.rb               # System manager
├── install.sh           # Installer script
├── SAPPHIRE_VERSION     # Current version (single source of truth)
├── CHANGELOG.md         # Full version history
├── releases/
│   └── latest.json      # Release manifest (fetched by spm)
├── stdlib/              # Standard library (.sp files)
│   ├── discordsph.sp
│   ├── math.sp
│   ├── strings.sp
│   └── ...
├── examples/            # Example programs
│   ├── fizzbuzz.sp
│   ├── showcase.sp
│   └── discord_bot.sp
└── bin/
    ├── sapphire         # Wrapper
    ├── sph              # Wrapper
    └── spm              # Wrapper
```

---

## Examples

```bash
sapphire examples/fizzbuzz.sp
sapphire examples/showcase.sp
sapphire examples/discord_bot.sp
```

---

## Updating Sapphire

```bash
spm check-update   # see if a new version is out
spm self-update    # install it
```

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push: `git push origin my-feature`
5. Open a pull request

---

## License

CUSTOM — see [LICENSE](LICENSE) for details.
