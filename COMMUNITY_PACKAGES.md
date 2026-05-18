# Publishing Sapphire Packages

Anyone can publish a Sapphire package and make it installable via `sph install`. This guide covers everything you need.

---

## Quick Start

1. Create a public GitHub repository (e.g. `your-username/sph-mypackage`)
2. Add a `sapphire.json` manifest to the root
3. Add your `.sp` source file(s)
4. Tag your repository with the topic **`sapphire-package`** on GitHub
5. Done — it will appear in `sph search`

---

## Repository Structure

```
my-package/
├── sapphire.json        ← required: package manifest
├── mypackage.sp         ← main source file (referenced in sapphire.json)
├── README.md            ← optional but strongly recommended
└── examples/
    └── demo.sp          ← optional usage examples
```

---

## sapphire.json (Required)

This file is read by `sph` to learn about your package.

```json
{
  "name": "mypackage",
  "version": "1.0.0",
  "description": "A short description of what your package does",
  "main": "mypackage.sp",
  "author": "your-github-username",
  "sapphire_version": ">=0.5.0",
  "license": "MIT",
  "repository": "https://github.com/your-username/sph-mypackage"
}
```

### Fields

| Field              | Required | Description                                                  |
|--------------------|----------|--------------------------------------------------------------|
| `name`             | ✓        | Package name (lowercase, letters/digits/hyphens). This is what users type in `import`. |
| `version`          | ✓        | Semver string, e.g. `"1.0.0"`                               |
| `description`      | ✓        | One-line summary shown in `sph search`                       |
| `main`             | ✓        | Relative path to the `.sp` file to install                   |
| `author`           |          | Your GitHub username or name                                 |
| `sapphire_version` |          | Minimum Sapphire version required, e.g. `">=0.5.0"`         |
| `license`          |          | SPDX license identifier, e.g. `"MIT"`                       |
| `repository`       |          | Full GitHub URL                                              |

---

## Writing Your .sp File

Your package's public API is anything defined at the top level. Users will call these after importing.

```sapphire
# mypackage.sp

fn greet(name) {
  return "Hello, " + name + " from mypackage!"
}

fn add(a, b) {
  return a + b
}
```

Users install and use it like this:

```bash
sph install your-username/sph-mypackage
```

```sapphire
import mypackage

println(mypackage.greet("world"))
println(mypackage.add(1, 2))
```

Or import specific functions:

```sapphire
from mypackage import greet, add

println(greet("world"))
```

---

## Naming Conventions

- Repository names should be prefixed with `sph-` so they're easy to find: `sph-colors`, `sph-datetime-utils`
- The `name` field in `sapphire.json` is what users type in `import` — keep it short and lowercase: `colors`, `datetime_utils`
- Avoid names that clash with built-in stdlib packages (`math`, `strings`, `io`, `collections`, `test`, `datetime`, `http`, `json`, `dotenv`, `discordsph`)

---

## Versioning and Releases

Use [semantic versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **PATCH** — bug fixes, no API changes
- **MINOR** — new functions added, backwards compatible
- **MAJOR** — breaking changes

To release a new version:

1. Update `"version"` in `sapphire.json`
2. Commit and push
3. Create a GitHub release/tag: `v1.2.0`

Users can install specific versions:

```bash
sph install your-username/sph-mypackage@v1.2.0
```

---

## Making Your Package Discoverable

For your package to appear in `sph search`, your GitHub repository **must** have the topic `sapphire-package` added.

To add it:
1. Go to your repository on GitHub
2. Click the ⚙️ gear icon next to "About" on the right sidebar
3. Under "Topics", type `sapphire-package` and press Enter
4. Save changes

Your package will now appear when users run `sph search` or `sph search <keyword>`.

---

## GitHub Token (Rate Limits)

`sph search` uses the GitHub API. Unauthenticated requests are limited to 60/hour. To increase this, set a personal access token:

```bash
export GITHUB_TOKEN=your_token_here
```

Or add it to your shell profile. No special scopes are needed — a public-repo read token is sufficient.

---

## Example: Minimal Package

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
fn blue(s)   { return "\e[34m" + s + "\e[0m" }
fn bold(s)   { return "\e[1m"  + s + "\e[0m" }
```

**Install:**
```bash
sph install foxie/sph-colors
```

**Use:**
```sapphire
import colors
println(colors.red("Error!"))
println(colors.green("Success!"))
```

---

## Checklist Before Publishing

- [ ] `sapphire.json` is present in the root with all required fields
- [ ] `name` in `sapphire.json` is lowercase and doesn't clash with stdlib
- [ ] `main` points to a valid `.sp` file
- [ ] Repository topic `sapphire-package` is set on GitHub
- [ ] Repository is **public**
- [ ] `README.md` explains what the package does and how to use it
- [ ] Version is bumped and a GitHub release/tag is created
