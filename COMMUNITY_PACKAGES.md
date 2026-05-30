# Publishing Sapphire Packages

Anyone can publish a Sapphire package and make it installable via `sph install`. This guide covers everything you need.

---

## How it works

When you run `sph publish`, it:

1. Asks for your GitHub credentials the first time (saved to `~/.sapphire/auth.json`)
2. Forks `GlacEevee/sapphire` into your GitHub account (if not already forked)
3. Creates a `packages` branch on your fork
4. Uploads your `.sp` file to `packages/yourpackage.sp`
5. Updates `packages/registry.json` on your fork

Others install your package with:
```bash
sph install yourname/packagename
```

---

## Quick Start

```bash
# 1. Create a folder for your package
mkdir mypackage && cd mypackage

# 2. Initialise a sapphire.json
sph init

# 3. Write your package
nano mypackage.sp

# 4. Publish
sph publish
```

First time running `sph publish` you'll be prompted for your GitHub username and a personal access token.

---

## sapphire.json (Required)

```json
{
  "name": "mypackage",
  "version": "1.0.0",
  "description": "A short description of what your package does",
  "main": "mypackage.sp",
  "author": "your-github-username",
  "sapphire_version": ">=0.5.3",
  "license": "MIT"
}
```

### Fields

| Field              | Required | Description |
|--------------------|----------|-------------|
| `name`             | ✓        | Package name (lowercase, letters/digits/hyphens). This is what users type in `import`. |
| `version`          | ✓        | Semver string, e.g. `"1.0.0"` |
| `description`      | ✓        | One-line summary shown in `sph search` |
| `main`             | ✓        | Relative path to the `.sp` file to publish |
| `author`           |          | Your GitHub username |
| `sapphire_version` |          | Minimum Sapphire version required |
| `license`          |          | SPDX license identifier, e.g. `"MIT"` |

---

## Writing Your Package

Functions defined at the top level of your `.sp` file become the package's public API. Users call them directly after importing — no dot notation needed.

```sapphire
# mypackage.sp

fn greet(name) {
  println("Hello, " + name + "!")
}

fn version() {
  return "1.0.0"
}
```

Users install and use it like this:

```bash
sph install yourname/mypackage
```

```sapphire
import mypackage

greet("world")      # not mypackage.greet()
println(version())  # not mypackage.version()
```

Or import specific functions:

```sapphire
from mypackage import greet
greet("world")
```

---

## GitHub Token

`sph publish` requires a GitHub personal access token with the **`repo`** scope.

Create one at: **https://github.com/settings/tokens/new**

- Token type: **Classic token** (not fine-grained)
- Scope: check **`repo`** (full repository access)

The token is saved to `~/.sapphire/auth.json` with owner-only permissions (`chmod 600`). To log out and clear it:

```bash
rm ~/.sapphire/auth.json
```

---

## Encryption

Packages installed via `sph install username/packagename` are automatically encrypted with AES-256-GCM on your machine. The key lives at `~/.sapphire/pkg.key` and is unique to your install. This prevents casual tampering — if a package file is modified, it will fail to load.

This is transparent to users — they just `import` the package as normal.

---

## Naming Conventions

- Keep names short, lowercase, and descriptive: `colors`, `uuid`, `validate`
- Avoid clashing with built-in packages: `math`, `strings`, `io`, `collections`, `test`, `datetime`, `http`, `json`, `dotenv`, `discordsph`, `media`, `colors`, `args`, `yml`, `csv`, `crypto`, `files`, `zip`, `env`, `sqlite`, `web`

---

## Versioning

Use [semantic versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **PATCH** — bug fixes, no API changes
- **MINOR** — new functions, backwards compatible
- **MAJOR** — breaking changes

To release a new version, bump `"version"` in `sapphire.json` and run `sph publish` again.

---

## Example: Complete Package

**`sapphire.json`**
```json
{
  "name": "colors",
  "version": "1.0.0",
  "description": "ANSI color helpers for terminal output",
  "main": "colors.sp",
  "author": "foxie"
}
```

**`colors.sp`**
```sapphire
fn red(s)    { return "\e[31m" + s + "\e[0m" }
fn green(s)  { return "\e[32m" + s + "\e[0m" }
fn yellow(s) { return "\e[33m" + s + "\e[0m" }
fn bold(s)   { return "\e[1m"  + s + "\e[0m" }
```

**Publish:**
```bash
sph publish
```

**Install:**
```bash
sph install foxie/colors
```

**Use:**
```sapphire
import colors

println(red("Error!"))
println(green("Success!"))
println(bold("Important"))
```

---

## Pre-publish Checklist

- [ ] `sapphire.json` present with all required fields
- [ ] `name` is lowercase and doesn't clash with a built-in package
- [ ] `main` points to a valid `.sp` file
- [ ] GitHub token has `repo` scope (classic token)
- [ ] Version is bumped if updating an existing package
