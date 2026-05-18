#!/usr/bin/env ruby
# spm.rb — Sapphire Manager
# Manages the Sapphire interpreter itself: updates, version info, self-install.
# Also proxies all sph package commands so `spm install discordsph` works too.
#
# Usage:
#   spm version                   Show installed Sapphire version
#   spm check-update              Check if a newer Sapphire is available
#   spm self-update               Update Sapphire to the latest version
#   spm status                    Full environment status report
#   spm install <pkg> [version]   Install a package (proxied to sph)
#   spm remove <pkg>              Remove a package (proxied to sph)
#   spm list                      List installed packages (proxied to sph)
#   spm search [query]            Search packages (proxied to sph)
#   spm info <pkg>                Package info (proxied to sph)
#   spm update [pkg]              Update packages (proxied to sph)
#   spm init                      Init a project (proxied to sph)

require 'json'
require 'fileutils'
require 'net/http'
require 'uri'
require 'open3'

$LOAD_PATH.unshift(__dir__) unless $LOAD_PATH.include?(__dir__)

module Sapphire
  module Manager
    VERSION = "1.0.0"

    # ── Sapphire release channel ───────────────────────────────────────────────
    # In a real setup this would point to a GitHub releases API or similar.
    # We simulate it with a local VERSION file + a known latest constant.
    LATEST_SAPPHIRE_VERSION = "0.4.0"   # bump this when new interpreter ships

    SAPPHIRE_DIR = File.expand_path(__dir__)
    VERSION_FILE = File.join(SAPPHIRE_DIR, 'SAPPHIRE_VERSION')

    SPH_COMMANDS = %w[install add remove rm uninstall list ls search info update init publish].freeze

    # ── helpers ────────────────────────────────────────────────────────────────

    def self.bold(s)  = "\e[1m#{s}\e[0m"
    def self.green(s) = "\e[32m#{s}\e[0m"
    def self.yellow(s)= "\e[33m#{s}\e[0m"
    def self.red(s)   = "\e[31m#{s}\e[0m"
    def self.cyan(s)  = "\e[36m#{s}\e[0m"
    def self.dim(s)   = "\e[90m#{s}\e[0m"

    def self.sapphire_version
      # Try VERSION constant from sapphire.rb, fall back to VERSION_FILE, then unknown
      if defined?(Sapphire::VERSION)
        Sapphire::VERSION
      elsif File.exist?(VERSION_FILE)
        File.read(VERSION_FILE).strip
      else
        "unknown"
      end
    end

    def self.gem_version(v) = Gem::Version.new(v) rescue nil

    def self.update_available?
      installed = gem_version(sapphire_version)
      latest    = gem_version(LATEST_SAPPHIRE_VERSION)
      return false unless installed && latest
      latest > installed
    end

    # ── commands ───────────────────────────────────────────────────────────────

    def self.cmd_version
      sv = sapphire_version
      puts ""
      puts "  #{bold('Sapphire')}          v#{sv}"
      puts "  #{bold('Sapphire Manager')} v#{VERSION}"
      if update_available?
        puts ""
        puts "  #{yellow("⬆  Sapphire v#{LATEST_SAPPHIRE_VERSION} is available")}"
        puts "  #{cyan('   spm self-update')} to upgrade"
      end
      puts ""
    end

    def self.cmd_check_update
      sv = sapphire_version
      puts ""
      puts "  Installed: Sapphire v#{sv}"
      puts "  Latest:    Sapphire v#{LATEST_SAPPHIRE_VERSION}"
      puts ""
      if update_available?
        puts "  #{yellow("⬆  Update available!")}  Run #{cyan('spm self-update')} to upgrade."
      else
        puts "  #{green("✓  You're up to date.")}"
      end
      puts ""

      # Also check packages via sph
      begin
        require_relative 'sph'
        upgrades = Sapphire::PackageManager.upgradeable_packages
        unless upgrades.empty?
          puts "  #{bold('Package upgrades available:')}"
          upgrades.each do |u|
            puts "    #{yellow('⬆')} #{u[:name].ljust(14)} v#{u[:installed]} → v#{u[:latest]}"
            puts "       #{cyan("spm install #{u[:name]} #{u[:latest]}")}"
          end
          puts ""
        end
      rescue LoadError
        # sph not available
      end
    end

    def self.cmd_self_update
      sv = sapphire_version
      puts ""
      unless update_available?
        puts "  #{green("✓  Sapphire v#{sv} is already the latest version.")}"
        puts ""
        return
      end

      puts "  #{bold("Updating Sapphire")} v#{sv} → v#{LATEST_SAPPHIRE_VERSION}..."
      puts ""

      # In a real setup: download and replace interpreter files.
      # Here we check if install.sh exists and re-run it.
      install_sh = File.join(SAPPHIRE_DIR, 'install.sh')
      if File.exist?(install_sh)
        puts "  Running #{cyan('install.sh')}..."
        puts ""
        system("bash #{install_sh}")
        puts ""
        puts "  #{green("✓  Sapphire updated to v#{LATEST_SAPPHIRE_VERSION}")}"
      else
        puts "  #{yellow("⚠")}  install.sh not found at #{SAPPHIRE_DIR}"
        puts "  Please re-run the Sapphire installer manually:"
        puts "  #{cyan("bash install.sh")}"
      end
      puts ""
    end

    def self.cmd_status
      sv   = sapphire_version
      ruby = RUBY_VERSION rescue "unknown"

      puts ""
      puts bold("╔══════════════════════════════════════════════════╗")
      puts bold("║  Sapphire Environment Status                     ║")
      puts bold("╚══════════════════════════════════════════════════╝")
      puts ""
      puts "  #{bold('Sapphire')}         v#{sv}#{update_available? ? "  #{yellow("⬆  v#{LATEST_SAPPHIRE_VERSION} available")}" : "  #{green("✓ latest")}"}"
      puts "  #{bold('Sapphire Manager')} v#{VERSION}"
      puts "  #{bold('Ruby')}             v#{ruby}"
      puts "  #{bold('Sapphire dir')}     #{SAPPHIRE_DIR}"
      puts ""

      # Package status
      begin
        require_relative 'sph'
        pm  = Sapphire::PackageManager
        pkg_dir = pm.packages_dir
        std_dir = pm.stdlib_dir

        puts "  #{bold('Packages dir')}     #{pkg_dir}"
        puts "  #{bold('Stdlib dir')}       #{std_dir}"
        puts ""

        user_pkgs = Dir[File.join(pkg_dir, "*.sp")].map { |f| File.basename(f, ".sp") }
        if user_pkgs.empty?
          puts "  #{dim('No user packages installed.')}"
        else
          puts "  #{bold('Installed packages:')}"
          user_pkgs.each do |name|
            reg = Sapphire::PackageManager::BUILTIN_REGISTRY[name]
            installed_ver = pm.installed_version(name) || (reg ? reg[:version] : "?")
            latest_ver    = reg ? reg[:version] : nil
            upgrade = ""
            if reg && reg[:versions] && latest_ver && installed_ver != "?" &&
               Gem::Version.new(installed_ver) < Gem::Version.new(latest_ver)
              upgrade = "  #{yellow("⬆  v#{latest_ver} available")}"
            end
            puts "    #{green("●")} #{name.ljust(16)} v#{installed_ver}#{upgrade}"
          end
        end
      rescue LoadError
        puts "  #{yellow("⚠")}  sph not available — package status unavailable"
      end

      # Ruby gems needed
      puts ""
      puts "  #{bold('Runtime gems:')}"
      check_gem("websocket-driver", "websocket/driver")
      check_gem("json", "json")
      puts ""
    end

    def self.check_gem(gem_name, require_name)
      begin
        require require_name
        puts "    #{green("●")} #{gem_name.ljust(20)} #{green("installed")}"
      rescue LoadError
        puts "    #{red("○")} #{gem_name.ljust(20)} #{red("missing")}  →  #{cyan("gem install #{gem_name}")}"
      end
    end

    # ── proxy to sph ──────────────────────────────────────────────────────────

    def self.proxy_to_sph(args)
      require_relative 'sph'
      Sapphire::PackageManager.run(args)
    rescue LoadError
      puts red("✗  sph.rb not found. Cannot run package commands.")
      exit 1
    end

    # ── help ──────────────────────────────────────────────────────────────────

    def self.puts_help
      puts ""
      puts bold("  Sapphire Manager (spm) v#{VERSION}")
      puts ""
      puts "  #{bold('Interpreter commands:')}"
      puts "    #{cyan('spm version')}              Sapphire + spm version info"
      puts "    #{cyan('spm check-update')}         Check for Sapphire & package updates"
      puts "    #{cyan('spm self-update')}          Update Sapphire interpreter"
      puts "    #{cyan('spm status')}               Full environment status report"
      puts ""
      puts "  #{bold('Package commands')} #{dim('(same as sph):')}"
      puts "    #{cyan('spm install <pkg> [ver]')}  Install a package"
      puts "    #{cyan('spm remove <pkg>')}         Remove a package"
      puts "    #{cyan('spm list')}                 List installed packages"
      puts "    #{cyan('spm search [query]')}       Search the registry"
      puts "    #{cyan('spm info <pkg>')}           Show package details"
      puts "    #{cyan('spm update [pkg]')}         Update packages"
      puts "    #{cyan('spm init')}                 Initialise a new project"
      puts ""
      puts "  #{dim('All package commands are forwarded to sph.')}"
      puts ""
    end

    # ── entry point ───────────────────────────────────────────────────────────

    def self.run(args)
      cmd = args.first

      case cmd
      when 'version', '--version', '-v'
        cmd_version
      when 'check-update', 'check'
        cmd_check_update
      when 'self-update', 'selfupdate', 'upgrade'
        cmd_self_update
      when 'status', 'env'
        cmd_status
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
