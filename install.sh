#!/usr/bin/env bash
# install.sh — Install Sapphire language, sph, and spm to your system
# Usage: bash install.sh [--user]
# Installs to /usr/local/bin by default (requires sudo), or ~/bin with --user

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_INSTALL=false
SAPPHIRE_VERSION=$(cat "$SCRIPT_DIR/SAPPHIRE_VERSION" 2>/dev/null || echo "unknown")

for arg in "$@"; do
  [[ "$arg" == "--user" ]] && USER_INSTALL=true
done

# ── Check Ruby ────────────────────────────────────────────────────────────────

if ! command -v ruby &> /dev/null; then
  echo "❌  Ruby is required but not installed."
  echo "    Install it: https://www.ruby-lang.org/en/documentation/installation/"
  exit 1
fi

RUBY_VERSION=$(ruby -e "puts RUBY_VERSION")
echo "✓  Ruby $RUBY_VERSION found"

# ── Check for websocket-driver gem ───────────────────────────────────────────

if ruby -e "require 'websocket/driver'" 2>/dev/null; then
  echo "✓  websocket-driver gem found"
else
  echo "⬇  Installing websocket-driver gem..."
  gem install websocket-driver --quiet
  echo "✓  websocket-driver installed"
fi

# ── Determine install dir ─────────────────────────────────────────────────────

if $USER_INSTALL; then
  INSTALL_DIR="$HOME/bin"
  mkdir -p "$INSTALL_DIR"
else
  INSTALL_DIR="/usr/local/bin"
fi

# ── Create wrapper scripts ────────────────────────────────────────────────────

create_wrapper() {
  local name="$1"
  local script="$2"
  local dest="$INSTALL_DIR/$name"

  cat > /tmp/sapphire_wrapper_$name <<EOF
#!/usr/bin/env ruby
\$LOAD_PATH.unshift("$SCRIPT_DIR")
load "$SCRIPT_DIR/$script"
EOF

  if $USER_INSTALL; then
    cp /tmp/sapphire_wrapper_$name "$dest"
  else
    sudo cp /tmp/sapphire_wrapper_$name "$dest"
  fi
  chmod +x "$dest" 2>/dev/null || sudo chmod +x "$dest"
  rm /tmp/sapphire_wrapper_$name
}

echo "⬇  Installing sapphire → $INSTALL_DIR/sapphire"
create_wrapper "sapphire" "sapphire.rb"

echo "⬇  Installing sph → $INSTALL_DIR/sph"
create_wrapper "sph" "sph.rb"

echo "⬇  Installing spm → $INSTALL_DIR/spm"
create_wrapper "spm" "spm.rb"

# ── Write version marker ──────────────────────────────────────────────────────

echo "$SAPPHIRE_VERSION" > "$SCRIPT_DIR/SAPPHIRE_VERSION"
echo "✓  Version marker written ($SAPPHIRE_VERSION)"

# ── Set up ~/.sapphire directory ──────────────────────────────────────────────

SAPPHIRE_HOME="$HOME/.sapphire"
mkdir -p "$SAPPHIRE_HOME/packages"
echo "✓  Created $SAPPHIRE_HOME"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Sapphire v$SAPPHIRE_VERSION installed successfully! 💎  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  sapphire <file.sp>       Run a Sapphire file"
echo "  sapphire repl            Start interactive REPL"
echo ""
echo "  sph install <pkg>        Install a package"
echo "  sph install <pkg> <ver>  Install a specific version"
echo "  sph list                 List installed packages"
echo ""
echo "  spm version              Sapphire + spm version info"
echo "  spm check-update         Check for updates"
echo "  spm self-update          Update Sapphire"
echo "  spm status               Full environment status"
echo "  spm install <pkg>        Install a package (same as sph)"
echo ""
echo "Try: sapphire $SCRIPT_DIR/examples/fizzbuzz.sp"

if $USER_INSTALL; then
  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo ""
    echo "⚠️  Add $HOME/bin to your PATH:"
    echo '    echo '"'"'export PATH="$HOME/bin:$PATH"'"'"' >> ~/.bashrc'
    echo "    source ~/.bashrc"
  fi
fi
