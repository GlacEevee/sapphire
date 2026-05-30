# Sapphire Changelog

All notable changes to the Sapphire language are documented here.
Format: `## [version] — YYYY-MM-DD`

---

## [0.5.3] — 2026-05-30

### spm — Automatic interpreter update nudge
- Sapphire now performs a background update check (at most once per 24 hours) when you run a script
- If a newer version is available it prints a one-line hint at program exit — startup is never delayed
- The last-checked timestamp is stored in `~/.sapphire/interpreter_update_stamp`
- `spm self-update` still performs the actual upgrade

### Built-in `Log` — structured logger (no import needed)
- `Log.debug(msg)` / `.info()` / `.warn()` / `.error()` / `.fatal()` — levelled output to stderr
- `Log.set_level("warn")` — filter to warn/error/fatal only
- `Log.set_output("/var/log/app.log")` — redirect to a file
- `Log.set_timestamp(false)` — hide timestamps
- `Log.set_format("json")` — emit newline-delimited JSON instead of plain text
- `Log.fatal()` logs and then calls `exit(1)`

### Built-in `fmt` — string formatting (no import needed)
- `fmt.sprintf("%s has %d items", name, n)` — printf-style formatting
- `fmt.pad_left(s, len, ch)` / `fmt.pad_right` / `fmt.center`
- `fmt.truncate(s, max, suffix)` — safe truncation
- `fmt.strip_ansi(s)` — remove ANSI escape codes
- `fmt.hex(n)` / `fmt.bin(n)` / `fmt.oct(n)` — number base formatting
- `fmt.comma(n)` — `1234567` → `"1,234,567"`
- `fmt.plural(n, "item")` — `1 item` / `2 items`
- `fmt.duration(90)` — `"1m 30s"`
- `fmt.bytes(1_500_000)` — `"1.43 MB"`
- `fmt.json(value)` — pretty-printed JSON string
- `fmt.table(rows, headers)` — ASCII table
- `fmt.repeat(s, n)` — repeat a string n times
- `stdlib/fmt.sp` — optional import that exposes everything as top-level functions

### New string methods
- `s.count(sub)` — count non-overlapping occurrences of a substring
- `s.match?(pattern)` — regex test
- `s.scan(pattern)` — return all regex matches as an array
- `s.format(args...)` — `"%s: %d".format(name, n)`
- `s.center(len, ch)` — center with padding
- `s.delete(sub)` — remove all occurrences of a substring
- `s.squeeze` — collapse consecutive duplicate characters
- `s.wrap(width)` — word-wrap to a given column width



### New Packages (Pure Ruby — works on any OS)
- `colors` — terminal color/style helpers (`red()`, `bold()`, `underline()`, `success()`, etc.)
- `args` — CLI argument parser (`--flags`, `--option value`, positional args)
- `yml` — YAML file read/write
- `csv` — CSV file read/write
- `crypto` — SHA256, MD5, SHA512, base64, HMAC, UUID generation
- `files` — file/directory utilities, glob, file watcher
- `zip` — create/extract zip archives
- `env` — OS/platform detection, environment variables, Raspberry Pi detection
- `sqlite` — embedded SQLite database (requires `gem install sqlite3`)
- `web` — web server with routing and WebSockets (**requires Node.js**)

### JavaScript Bridge
- New `js_bridge/` folder — Ruby↔Node.js bridge for packages Ruby can't do well
- `bridge.rb` — spawns Node.js process, communicates over JSON stdio
- `runtime.js` — Node.js side receives calls and dispatches to JS packages
- Post-install reminder when installing Node.js-backed packages
- Clear message with install instructions when Node.js is not found

### sph publish
- `sph publish` — publish your package to your GitHub fork's `packages` branch
- First-time CLI registration — saves token to `~/.sapphire/auth.json` (chmod 600)
- Auto-forks `GlacEevee/sapphire` if needed
- Creates `packages` branch automatically
- Updates `packages/registry.json` on your fork
- Others install with: `sph install username/packagename`

### Package Encryption
- Community and fork packages are encrypted with AES-256-GCM on install
- Key stored in `~/.sapphire/pkg.key` (owner read-only)
- Interpreter decrypts at load time — transparent to users
- Tampered packages fail checksum and won't load

---

## [0.5.1] — 2026-05-19

### New Features
- `media` stdlib package — view photos and play videos directly from Sapphire scripts
  - `media.view(path)` — show an image (framebuffer via `fim` when headless, `feh` when X is available)
  - `media.view_ascii(path)` — show an image as ASCII/ANSI art, works over any plain SSH connection
  - `media.play(path)` — play a video (`mpv --vo=drm` for headless Pi, no X needed)
  - `media.slideshow(paths, delay)` — cycle through multiple images
  - `media.image_info(path)` / `media.video_info(path)` — get file metadata
  - `media.status()` — show which viewers are installed
  - `media.setup()` — auto-install `fim`, `mpv`, `jp2a`, `ffmpeg` via apt
- `Media` native object in interpreter exposing all media operations to Sapphire

---

## [0.5.0] — 2026-05-18

### Bug Fixes
- Fixed `Ctrl+C` (SIGINT) crash — now exits cleanly from both the gateway WebSocket loop and the interpreter top-level
- `OpenSSL::SSL::SSLErrorWaitReadable` now handled correctly in the gateway read loop (no more spurious stack trace on interrupt)

### Tooling
- `sph search` now searches community packages published on GitHub (repos tagged `sapphire-package`)
- `sph install <user>/<repo>` installs a community package directly from a GitHub repository
- `sph install <user>/<repo>@<tag>` installs a specific release tag
- Added `COMMUNITY_PACKAGES.md` — guide for publishing your own Sapphire package

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
