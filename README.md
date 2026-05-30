<div align="center">

# 💎 Sapphire

**A clean, expressive scripting language built in Ruby.**

![Version](https://img.shields.io/badge/version-0.5.3-blue)
![Ruby](https://img.shields.io/badge/ruby-3.0%2B-red)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Raspberry%20Pi-lightgrey)

</div>

> [!IMPORTANT]
> **Please install v0.5.1 or newer manually.** Versions v0.4.0 and v0.5.0 contain a bug in `spm` that prevents downloading releases correctly. Starting from v0.5.1 this is fixed and future updates work automatically via `spm self-update`.
>
> ```bash
> git clone https://github.com/GlacEevee/sapphire.git ~/lang/sapphire
> cd ~/lang/sapphire
> bash install.sh --user
> ```

> [!NOTE]
> **`spm` is moving to its own branch soon.** Once that happens, Sapphire will check for interpreter updates automatically every 24 hours in the background and notify you — no more manual `git pull` needed. If you're already on v0.5.1+, `spm self-update` will handle the transition for you automatically.

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
- Package manager (`sph`) with versioned installs and community publishing
- System manager (`spm`) with GitHub-based auto-update
- Background update checker — notifies you once per 24h if a newer version is out
- Built-in `Log` object for structured logging
- `sapphire fmt` — auto-formatter for `.sp` files

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
- Node.js *(optional — only needed for `web`, `ui`, `canvas` packages)*

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

# Auto-format a file
sapphire fmt myfile.sp
sapphire fmt --check myfile.sp   # check only, exit 1 if unformatted
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
```

### Arrays

```sp
let nums = [10, 3, 7, 1, 9]

nums.map({ |n| n * 2 })
nums.filter({ |n| n % 2 == 0 })
nums.reduce({ |acc, n| acc + n }, 0)
nums.sort
nums.find({ |n| n > 7 })
nums.all?({ |n| n > 0 })
nums.each({ |n| println(n) })
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

### Logging

```sp
# Built-in — no import needed
Log.info("Server started")
Log.warn("Low memory")
Log.error("Connection failed")
Log.debug("x = " + str(x))

Log.level = "warn"           # hide debug and info
Log.output = "app.log"       # write to file
Log.format = "json"          # structured JSON output
```

### Modules

```sp
import math
from strings import capitalize, truncate

println(fibonacci(10))
println(capitalize("hello world"))
```

---

## Package Manager — `sph`

```bash
sph install discordsph          # install latest
sph install discordsph 1.2.0    # install specific version
sph list                        # show installed packages
sph search discord              # search registry + community packages
sph info discordsph             # package details
sph remove discordsph           # uninstall
sph init                        # create sapphire.json for a project
sph publish                     # publish your package to GitHub
```

### Installing community packages

```bash
sph install foxie/colors        # install from a user's packages branch
```

### Publishing your own package

```bash
cd mypackage/
sph publish    # first time: prompts for GitHub token, then auto-publishes
```

Others install it with `sph install yourname/packagename`. See [COMMUNITY_PACKAGES.md](COMMUNITY_PACKAGES.md) for the full guide.

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
| `media` | Photo and video viewer — headless Pi friendly (framebuffer, no X needed) |
| `colors` | Terminal color helpers — `red()`, `bold()`, `success()`, etc. |
| `args` | CLI argument parser — `--flags`, `--option value`, positional args |
| `yml` | YAML file read/write |
| `csv` | CSV file read/write |
| `crypto` | SHA256, MD5, base64, HMAC, UUID |
| `files` | File/directory utilities, glob, file watcher |
| `zip` | Create and extract zip archives |
| `env` | OS/platform detection, environment variables |
| `sqlite` | Embedded SQLite database *(requires `gem install sqlite3`)* |
| `web` | Web server with routing and WebSockets *(requires Node.js)* |

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

`spm` manages the Sapphire interpreter itself. Starting from v0.5.3, Sapphire checks for interpreter updates automatically in the background every 24 hours and shows a notice at the end of your script if a newer version is available — no manual checking needed.

```bash
spm version              # show Sapphire + spm version
spm check-update         # manually check for a newer release
spm self-update          # download and install latest Sapphire
spm install 0.5.0        # install a specific Sapphire version
spm releases             # list all known Sapphire versions
spm status               # full environment report
spm changelog            # view the full changelog
```

> **Coming soon:** `spm` is moving to its own dedicated branch. Once live, interpreter updates will be delivered directly through `spm` without needing to touch the main repo — fully automatic, fully seamless.

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

client.on_ready(fn(data) {
  println("Logged in as: " + data["user"]["username"])
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
├── formatter.rb         # Source code formatter (sapphire fmt)
├── ast.rb               # AST node definitions
├── types.rb             # Sapphire type system
├── environment.rb       # Variable scope/environment
├── sph.rb               # Package manager
├── spm.rb               # System manager
├── install.sh           # Installer script
├── SAPPHIRE_VERSION     # Current version
├── CHANGELOG.md         # Full version history
├── COMMUNITY_PACKAGES.md# Guide for publishing packages
├── js_bridge/           # Optional Node.js bridge
│   ├── bridge.rb
│   ├── runtime.js
│   └── packages/
├── releases/
│   ├── latest.json      # Release manifest (fetched by spm)
│   ├── v0.5.3.json
│   └── ...
├── stdlib/              # Standard library (.sp files)
│   ├── discordsph.sp
│   ├── math.sp
│   ├── strings.sp
│   └── ...
├── examples/
│   ├── fizzbuzz.sp
│   ├── showcase.sp
│   └── discord_bot.sp
└── bin/
    ├── sapphire
    ├── sph
    └── spm
```

---

## Updating Sapphire

Sapphire will tell you automatically at the end of a script run if a newer version is available. To update:

```bash
spm self-update
```

Or install a specific version:

```bash
spm install 0.5.2
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
