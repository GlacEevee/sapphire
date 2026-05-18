#!/usr/bin/env ruby
# spm.rb — Sapphire Manager
# Manages the Sapphire interpreter: versioning, updates, self-install from GitHub.
# Also proxies all sph package commands.
#
# Usage:
#   spm version                   Show installed Sapphire version + changelog
#   spm check-update              Check GitHub for a newer Sapphire release
#   spm self-update               Download and install latest Sapphire from GitHub
#   spm status                    Full environment status report
#   spm changelog                 Print the changelog
#   spm install <pkg> [ver]       Install a package (proxied to sph)
#   spm remove <pkg>              Remove a package (proxied to sph)
#   spm list                      List packages (proxied to sph)
#   spm search [query]            Search packages (proxied to sph)
#   spm info <pkg>                Package info (proxied to sph)
#   spm update [pkg]              Update packages (proxied to sph)
#   spm init                      Init project (proxied to sph)

require 'json'
require 'fileutils'
require 'net/http'
require 'net/https'
require 'uri'
require 'tmpdir'

$LOAD_PATH.unshift(__dir__) unless $LOAD_PATH.include?(__dir__)

module Sapphire
  module Manager
    SPM_VERSION  = "1.1.0"
    SAPPHIRE_DIR = File.expand_path(__dir__)

    # ── GitHub config ──────────────────────────────────────────────────────────
    # Fill in your GitHub username once you've created the repo.
    GITHUB_USER       = "GlacEevee"
    GITHUB_REPO       = "sapphire"
    GITHUB_BRANCH     = "main"
    GITHUB_BASE       = "https://raw.githubusercontent.com/#{GITHUB_USER}/#{GITHUB_REPO}/#{GITHUB_BRANCH}"
    RELEASES_MANIFEST = "#{GITHUB_BASE}/releases/latest.json"
    GITHUB_API_LATEST = "https://api.github.com/repos/#{GITHUB_USER}/#{GITHUB_REPO}/releases/latest"

    # Local paths
    VERSION_FILE   = File.join(SAPPHIRE_DIR, 'SAPPHIRE_VERSION')
    CHANGELOG_FILE = File.join(SAPPHIRE_DIR, 'CHANGELOG.md')
    CACHE_FILE     = File.join(Dir.home, '.sapphire', 'update_cache.json')
    CACHE_TTL      = 3600   # seconds between remote checks

    SPH_COMMANDS = %w[install add remove rm uninstall list ls search info update init publish].freeze

    # ── colour helpers ─────────────────────────────────────────────────────────

    def self.bold(s)   = "\e[1m#{s}\e[0m"
    def self.green(s)  = "\e[32m#{s}\e[0m"
    def self.yellow(s) = "\e[33m#{s}\e[0m"
    def self.red(s)    = "\e[31m#{s}\e[0m"
    def self.cyan(s)   = "\e[36m#{s}\e[0m"
    def self.dim(s)    = "\e[90m#{s}\e[0m"
    def self.gem_ver(v)= Gem::Version.new(v) rescue Gem::Version.new("0")

    # ── version helpers ────────────────────────────────────────────────────────

    def self.installed_version
      if File.exist?(VERSION_FILE)
        File.read(VERSION_FILE).strip
      elsif defined?(Sapphire::VERSION)
        Sapphire::VERSION
      else
        "unknown"
      end
    end

    # ── remote manifest ────────────────────────────────────────────────────────

    def self.github_configured?
      GITHUB_USER != "YOUR_USERNAME"
    end

    # Fetch the releases/latest.json from GitHub, with local cache
    def self.fetch_manifest(force: false)
      FileUtils.mkdir_p(File.dirname(CACHE_FILE))

      # Return cached data if fresh
      unless force
        if File.exist?(CACHE_FILE)
          cache = JSON.parse(File.read(CACHE_FILE)) rescue nil
          if cache && cache["fetched_at"] && (Time.now.to_i - cache["fetched_at"]) < CACHE_TTL
            return cache["manifest"]
          end
        end
      end

      unless github_configured?
        return nil
      end

      begin
        uri  = URI.parse(RELEASES_MANIFEST)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = 5
        http.read_timeout = 10

        resp = http.get(uri.path)
        return nil unless resp.code == "200"

        manifest = JSON.parse(resp.body)

        # Cache it
        File.write(CACHE_FILE, JSON.generate({ "fetched_at" => Time.now.to_i, "manifest" => manifest }))
        manifest
      rescue => e
        nil   # network unavailable — silently degrade
      end
    end

    def self.latest_version
      manifest = fetch_manifest
      manifest ? manifest["version"] : nil
    end

    def self.update_available?
      remote = latest_version
      return false unless remote
      gem_ver(remote) > gem_ver(installed_version)
    end

    # ── commands ───────────────────────────────────────────────────────────────

    def self.cmd_version
      iv = installed_version
      puts ""
      puts "  #{bold('Sapphire')}          v#{iv}"
      puts "  #{bold('Sapphire Manager')} v#{SPM_VERSION}"
      puts "  #{bold('Ruby')}             v#{RUBY_VERSION}"
      puts ""

      manifest = fetch_manifest
      if !github_configured?
        puts "  #{dim('GitHub not configured — remote version check unavailable.')}"
        puts "  #{dim('Set GITHUB_USER in spm.rb once your repo is live.')}"
      elsif manifest.nil?
        puts "  #{dim('Could not reach GitHub — running offline.')}"
      else
        remote = manifest["version"]
        if gem_ver(remote) > gem_ver(iv)
          puts "  #{yellow("⬆  Sapphire v#{remote} is available")}  (#{manifest['released']})"
          puts "  #{cyan('   spm self-update')} to upgrade"
        else
          puts "  #{green("✓  You are on the latest version")}"
        end
      end
      puts ""
    end

    def self.cmd_check_update(force: false)
      iv = installed_version
      puts ""
      puts "  #{bold('Checking for updates...')}"
      puts ""

      if !github_configured?
        puts "  #{yellow("⚠")}  GitHub not configured yet."
        puts "  #{dim('Edit GITHUB_USER in spm.rb once your repository is live.')}"
        puts ""
        return
      end

      manifest = fetch_manifest(force: force)
      if manifest.nil?
        puts "  #{yellow("⚠")}  Could not reach GitHub. Check your connection."
        puts ""
        return
      end

      remote = manifest["version"]
      puts "  Installed:  Sapphire v#{iv}"
      puts "  Available:  Sapphire v#{remote}  (#{manifest['released']})"
      puts ""

      if gem_ver(remote) > gem_ver(iv)
        puts "  #{yellow("⬆  Update available!")}"
        puts "  #{dim(manifest['notes'])}" if manifest['notes']
        puts ""
        puts "  Run #{cyan('spm self-update')} to upgrade."
      else
        puts "  #{green("✓  Sapphire is up to date.")}"
      end

      # Also check packages
      begin
        require_relative 'sph'
        upgrades = Sapphire::PackageManager.upgradeable_packages
        unless upgrades.empty?
          puts ""
          puts "  #{bold('Package upgrades available:')}"
          upgrades.each do |u|
            puts "    #{yellow('⬆')} #{u[:name].ljust(14)} v#{u[:installed]} → v#{u[:latest]}"
            puts "       #{cyan("spm install #{u[:name]} #{u[:latest]}")}"
          end
        end
      rescue LoadError; end

      puts ""
    end

    def self.cmd_self_update
      iv = installed_version
      puts ""

      if !github_configured?
        puts "  #{yellow("⚠")}  GitHub not configured — cannot auto-update."
        puts "  Set GITHUB_USER in spm.rb once your repo is live."
        puts ""
        return
      end

      manifest = fetch_manifest(force: true)
      if manifest.nil?
        puts "  #{red("✗")}  Could not reach GitHub. Check your connection."
        puts ""
        return
      end

      remote = manifest["version"]

      if gem_ver(remote) <= gem_ver(iv)
        puts "  #{green("✓  Already on the latest version")} (v#{iv})"
        puts ""
        return
      end

      puts "  #{bold("Updating Sapphire")} v#{iv} → v#{remote}..."
      puts ""

      # Strategy 1: run install.sh from GitHub
      install_url = manifest["install_script"]
      if install_url
        puts "  #{dim("Fetching install script from GitHub...")}"
        begin
          script_body = fetch_url(install_url)
          if script_body
            tmp = Tempfile.new(['sapphire_install', '.sh'])
            tmp.write(script_body)
            tmp.chmod(0755)
            tmp.close

            puts "  #{dim("Running installer...")}"
            puts ""
            success = system("bash #{tmp.path} --user")
            tmp.unlink

            if success
              # Update local version file
              File.write(VERSION_FILE, remote)
              # Bust cache
              File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
              puts ""
              puts "  #{green("✓  Sapphire updated to v#{remote}")}"
            else
              puts "  #{red("✗  Installer exited with an error.")}"
            end
            puts ""
            return
          end
        rescue => e
          puts "  #{yellow("⚠")}  Could not fetch install script: #{e.message}"
        end
      end

      # Strategy 2: fall back to local install.sh
      local_install = File.join(SAPPHIRE_DIR, 'install.sh')
      if File.exist?(local_install)
        puts "  #{dim("Falling back to local install.sh...")}"
        system("bash #{local_install} --user")
        File.write(VERSION_FILE, remote)
        File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
        puts "  #{green("✓  Done. Restart your shell if needed.")}"
      else
        puts "  #{red("✗")}  No install script available."
        puts "  Download manually: #{manifest['download']}"
      end
      puts ""
    end

    def self.cmd_status
      iv = installed_version
      manifest = fetch_manifest

      puts ""
      puts bold("╔══════════════════════════════════════════════════╗")
      puts bold("║  Sapphire Environment Status                     ║")
      puts bold("╚══════════════════════════════════════════════════╝")
      puts ""

      remote    = manifest ? manifest["version"] : nil
      up_to_date = remote && gem_ver(remote) <= gem_ver(iv)
      ver_note  = if !github_configured?
        dim("  (GitHub not configured)")
      elsif remote.nil?
        yellow("  (offline)")
      elsif up_to_date
        green("  ✓ latest")
      else
        yellow("  ⬆  v#{remote} available")
      end

      puts "  #{bold('Sapphire')}         v#{iv}#{ver_note}"
      puts "  #{bold('Sapphire Manager')} v#{SPM_VERSION}"
      puts "  #{bold('Ruby')}             v#{RUBY_VERSION}"
      puts "  #{bold('Sapphire dir')}     #{SAPPHIRE_DIR}"
      puts "  #{bold('GitHub')}           #{github_configured? ? "#{GITHUB_USER}/#{GITHUB_REPO}" : dim("not configured")}"
      puts ""

      # Package status
      begin
        require_relative 'sph'
        pm      = Sapphire::PackageManager
        pkg_dir = pm.packages_dir
        puts "  #{bold('Packages dir')}     #{pkg_dir}"
        puts ""

        user_pkgs = Dir[File.join(pkg_dir, "*.sp")].map { |f| File.basename(f, ".sp") }
        if user_pkgs.empty?
          puts "  #{dim('No user packages installed.')}"
        else
          puts "  #{bold('Installed packages:')}"
          user_pkgs.each do |name|
            reg          = Sapphire::PackageManager::BUILTIN_REGISTRY[name]
            installed_v  = pm.installed_version(name) || (reg ? reg[:version] : "?")
            latest_v     = reg ? reg[:version] : nil
            upgrade      = ""
            if reg && reg[:versions] && latest_v && installed_v != "?" &&
               gem_ver(installed_v) < gem_ver(latest_v)
              upgrade = "  #{yellow("⬆  v#{latest_v} available — spm install #{name} #{latest_v}")}"
            end
            puts "    #{green("●")} #{name.ljust(16)} v#{installed_v}#{upgrade}"
          end
        end
      rescue LoadError
        puts "  #{yellow("⚠")}  sph not available"
      end

      # Runtime gems
      puts ""
      puts "  #{bold('Runtime gems:')}"
      [["websocket-driver", "websocket/driver"], ["json", "json"]].each do |gem_name, req|
        begin
          require req
          puts "    #{green("●")} #{gem_name.ljust(20)} #{green("ok")}"
        rescue LoadError
          puts "    #{red("○")} #{gem_name.ljust(20)} #{red("missing")}  →  #{cyan("gem install #{gem_name}")}"
        end
      end
      puts ""
    end

    def self.cmd_changelog
      if File.exist?(CHANGELOG_FILE)
        puts File.read(CHANGELOG_FILE)
      elsif github_configured?
        puts ""
        puts "  #{dim("Fetching changelog from GitHub...")}"
        body = fetch_url("#{GITHUB_BASE}/CHANGELOG.md")
        if body
          puts body
        else
          puts "  #{yellow("⚠")}  Could not fetch changelog."
        end
      else
        puts "  #{yellow("⚠")}  No local CHANGELOG.md and GitHub not configured."
      end
    end

    # ── fetch helper ───────────────────────────────────────────────────────────

    def self.fetch_url(url)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 8
      http.read_timeout = 15
      resp = http.get(uri.request_uri)
      resp.code == "200" ? resp.body : nil
    rescue
      nil
    end

    # ── proxy to sph ──────────────────────────────────────────────────────────

    def self.proxy_to_sph(args)
      require_relative 'sph'
      Sapphire::PackageManager.run(args)
    rescue LoadError
      puts red("  ✗  sph.rb not found.")
      exit 1
    end

    # ── help ──────────────────────────────────────────────────────────────────

    def self.puts_help
      puts ""
      puts bold("  Sapphire Manager (spm) v#{SPM_VERSION}")
      puts ""
      puts "  #{bold('Interpreter:')}"
      puts "    #{cyan('spm version')}              Version info + update check"
      puts "    #{cyan('spm check-update')}         Check GitHub for a newer release"
      puts "    #{cyan('spm self-update')}          Download and install latest Sapphire"
      puts "    #{cyan('spm status')}               Full environment status"
      puts "    #{cyan('spm changelog')}            View the changelog"
      puts ""
      puts "  #{bold('Packages')} #{dim('(same as sph):')}"
      puts "    #{cyan('spm install <pkg> [ver]')}  Install a package or specific version"
      puts "    #{cyan('spm remove <pkg>')}         Remove a package"
      puts "    #{cyan('spm list')}                 List installed packages"
      puts "    #{cyan('spm search [query]')}       Search the registry"
      puts "    #{cyan('spm info <pkg>')}           Package details"
      puts "    #{cyan('spm update [pkg]')}         Update packages"
      puts "    #{cyan('spm init')}                 Initialise a new project"
      puts ""
    end

    # ── entry point ───────────────────────────────────────────────────────────

    def self.run(args)
      cmd = args.first

      case cmd
      when 'version', '--version', '-v'
        cmd_version
      when 'check-update', 'check'
        cmd_check_update(force: args.include?('--force'))
      when 'self-update', 'selfupdate', 'upgrade'
        cmd_self_update
      when 'status', 'env'
        cmd_status
      when 'changelog', 'changes'
        cmd_changelog
      when 'help', '--help', '-h', nil
        puts_help
      else
        if SPH_COMMANDS.include?(cmd)
          proxy_to_sph(args)
        else
          puts red("  Unknown command: #{cmd}")
          puts_help
          exit 1
        end
      end
    end
  end
end

Sapphire::Manager.run(ARGV.dup) if __FILE__ == $0 || File.basename($0) == 'spm'
