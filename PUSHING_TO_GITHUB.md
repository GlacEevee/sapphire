# Pushing Sapphire to GitHub

## First time — create the repo and push everything

```bash
# 1. Go to https://github.com/new and create a repo called "sapphire"
#    - Set it to Public
#    - Do NOT initialise with README, .gitignore, or license (you already have files)

# 2. On your Pi, go to your sapphire directory
cd ~/lang/sapphire

# 3. If there's no git repo yet, initialise one
git init
git branch -M main

# 4. Stage everything
git add .

# 5. Commit
git commit -m "Sapphire v0.5.0"

# 6. Point it at your GitHub repo (replace GlacEevee with your GitHub username)
git remote add origin https://github.com/GlacEevee/sapphire.git

# 7. Push
git push -u origin main
```

## Tag the release so spm self-update can find it

```bash
git tag v0.5.0
git push origin v0.5.0
```

## Update releases/latest.json download URL

Once pushed, edit `releases/latest.json` and `releases/v0.4.0.json` and replace
`YOUR_USERNAME` with `GlacEevee` in the download URLs:

```json
"download": "https://github.com/GlacEevee/sapphire/archive/refs/tags/v0.5.0.zip"
```

Then commit and push again:

```bash
git add releases/
git commit -m "Fix release download URLs"
git push
```

## Future releases (e.g. v0.6.0)

```bash
# Make your changes, then:
echo "0.6.0" > SAPPHIRE_VERSION
git add .
git commit -m "Sapphire v0.6.0"
git tag v0.6.0
git push origin main
git push origin v0.6.0
```

Then update `releases/latest.json` to the new version and add `releases/v0.6.0.json`.

## If you already have a remote set up

```bash
cd ~/lang/sapphire
git add .
git commit -m "Sapphire v0.5.0"
git push
```
