# Sapphire Changelog

All notable changes to the Sapphire language are documented here.
Format: `## [version] — YYYY-MM-DD`

---

## [0.4.0] — 2026-05-17

### Language
- Gateway WebSocket connection via `websocket/driver` gem
- Fixed dynamic constant assignment in `GATEWAY` native (`GATEWAY_URL` → local var)

### Standard Library
- `discordsph` updated to v1.4.0
  - Middleware/hooks for command router (`router.use`)
  - `router.on_unknown` catch-all handler
  - `client.on_message_update` / `on_message_delete` events
  - `make_modal` builder for slash command interactions
  - `make_webhook` / `client.create_webhook` — webhook support
  - `guild.search_members`, `guild.get_member_count`
  - `msg.fetch_reference` — fetch replied-to message
  - `DISCORDSPH_VERSION` global constant

### Tooling
- `sph install <pkg> <version>` — versioned package installs
- `sph list` shows upgrade hints for outdated packages
- `sapphire` prints upgrade banner on boot when imported packages are outdated
- `spm` rewritten as Sapphire Manager (interpreter updates, status, self-update)
- `spm check-update` checks interpreter + all packages
- `spm status` — full environment report

---

## [0.3.0] — 2026-03-10

### Language
- `else if` chaining in conditionals
- `for` loop support (`for i in 0..10`)
- String interpolation with `#{}`
- `break` and `next` in loops

### Standard Library
- `datetime.sp` — date/time utilities
- `collections.sp` — chunk, group_by, frequencies, compact
- `dotenv.sp` — load `.env` files into `Sys.env()`
- `discordsph` v1.0.0 initial release

### Tooling
- `sph` package manager initial release
- `sph init` creates `sapphire.json`
- `sph install` / `remove` / `list` / `search`

---

## [0.2.0] — 2026-01-20

### Language
- Hash literals and hash access
- `fn` closures / first-class functions
- `import` and `from X import Y` module system
- `nil` type and nil checks
- `return` from functions

### Standard Library
- `math.sp` — primes, gcd, fibonacci, statistics
- `strings.sp` — capitalize, truncate, palindrome, indent
- `io.sp` — read_lines, write_lines, prompt, print_table
- `test.sp` — minimalist unit testing framework

### Tooling
- `sapphire repl` — interactive REPL
- `sapphire check <file>` — syntax check without running

---

## [0.1.0] — 2025-11-05

### Language
- Initial release
- Variables (`let`), basic types (int, float, string, bool, array)
- Arithmetic and comparison operators
- `if` / `else` conditionals
- `while` loops
- `fn` function definitions
- `println` / `print` builtins
- `HTTP.get` / `HTTP.post` native bridge
- `Sys.env` / `Sys.time` / `Sys.exit` natives

---
