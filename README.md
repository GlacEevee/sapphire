# 📦 Sapphire Community Packages

This is the `packages` branch of the Sapphire repository. It contains community-published packages installable via `sph`.

---

## Installing a Package

```bash
sph install username/packagename
```

For example:
```bash
sph install foxie/colors
sph install foxie/uuid
```

---

## Browsing Packages

All available packages are listed in [`registry.json`](registry.json).

Each entry looks like this:

```json
{
  "colors": {
    "version": "1.0.0",
    "description": "ANSI color helpers for terminal output",
    "author": "foxie",
    "file": "packages/colors.sp",
    "updated_at": "2026-05-30"
  }
}
```

---

## Publishing Your Own Package

You don't need to open a pull request or manually edit this branch. Just run:

```bash
sph publish
```

from inside your package folder and `sph` handles everything — forking, branch creation, uploading your `.sp` file, and updating `registry.json`.

First time you'll be asked for your GitHub username and a personal access token with the `repo` scope.

See the full guide: [COMMUNITY_PACKAGES.md](../main/COMMUNITY_PACKAGES.md)

---

## Structure

```
packages/
├── registry.json      ← index of all packages on this fork
├── hello.sp
├── colors.sp
└── ...
```

---

## Searching

```bash
sph search colors      # search by name or description
sph search             # browse all community packages
```

---

*This branch is managed automatically by `sph publish`. Do not edit files here manually.*
