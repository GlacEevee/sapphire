#!/usr/bin/env ruby
# gem.rb — Sapphire Package Manager (sph)
# Usage:
#   spm install <package>         Install a package
#   spm remove <package>          Remove a package
#   spm list                      List installed packages
#   spm search <query>            Search available packages
#   spm init                      Create a new sapphire.json project file
#   spm publish                   Publish a package (stub)
#   spm info <package>            Show package details

require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

module Sapphire
  module PackageManager
    VERSION = "1.0.0"

    # Where packages live locally
    def self.packages_dir
      File.expand_path("~/.sapphire/packages")
    end

    def self.stdlib_dir
      File.join(__dir__, 'stdlib')
    end

    def self.project_file
      File.join(Dir.pwd, 'sapphire.json')
    end

    def self.ensure_dirs
      FileUtils.mkdir_p(packages_dir)
      FileUtils.mkdir_p(stdlib_dir)
    end

    # Built-in package registry (local simulation)
    # For packages with multiple versions, :versions lists all available ones
    # and :version is always the latest.
    BUILTIN_REGISTRY = {
      "math"        => { version: "1.0.0", description: "Extended math: primes, gcd, fibonacci, statistics", stdlib: true, file: "math.sp" },
      "strings"     => { version: "1.0.0", description: "String utilities: capitalize, truncate, palindrome, indent", stdlib: true, file: "strings.sp" },
      "collections" => { version: "1.0.0", description: "Collection utilities: chunk, group_by, frequencies, compact", stdlib: true, file: "collections.sp" },
      "io"          => { version: "1.0.0", description: "IO helpers: read_lines, write_lines, prompt, print_table", stdlib: true, file: "io.sp" },
      "json"        => { version: "1.0.0", description: "JSON encode/decode support (native bridge)", stdlib: true, file: "json.sp" },
      "datetime"    => { version: "1.0.0", description: "Date and time utilities", stdlib: true, file: "datetime.sp" },
      "test"        => { version: "1.0.0", description: "Minimalist unit testing framework for Sapphire", stdlib: true, file: "test.sp" },
      "http"        => { version: "1.0.0", description: "Simple HTTP client (get/post)", stdlib: true, file: "http.sp" },
      "discordsph"  => {
        version: "1.4.0",
        description: "Discord bot framework: client, commands, embeds, gateway events",
        stdlib: false,
        file: "discordsph.sp",
        source: :bundled,
        versions: {
          "1.0.0" => "discordsph_v1.0.sp",
          "1.1.0" => "discordsph_v1.1.sp",
          "1.2.0" => "discordsph_v1.2.sp",
          "1.3.0" => "discordsph_v1.3.sp",
          "1.4.0" => "discordsph_v1.4.sp",
        }
      },
      "dotenv"      => { version: "1.0.0", description: "Load environment variables from a .env file into Sys.env()", stdlib: false, file: "dotenv.sp", source: :bundled },
    }.freeze

    def self.run(args)
      ensure_dirs
      cmd = args.shift

      case cmd
      when 'install', 'add'
        if args.empty?
          install_from_project
        else
          # Support: sph install discordsph v1.2  OR  sph install discordsph 1.2.0
          pkg_name = args.shift
          version  = args.shift  # nil if not given
          install(pkg_name, version)
        end
      when 'remove', 'rm', 'uninstall'
        args.each { |pkg| remove(pkg) }
      when 'list', 'ls'
        list_packages
      when 'search'
        search(args.first || "")
      when 'init'
        init_project
      when 'info'
        info(args.first)
      when 'update'
        args.empty? ? update_all : args.each { |pkg| update(pkg) }
      when 'version', '--version', '-v'
        puts "Sapphire Package Manager (sph) v#{VERSION}"
      else
        puts_help
      end
    end

    def self.install(name, requested_version = nil)
      name = name.downcase
      pkg  = BUILTIN_REGISTRY[name]

      if pkg.nil?
        puts "\e[31m✗\e[0m Package '#{name}' not found in registry."
        puts "  Run \e[36msph search #{name}\e[0m to see similar packages."
        return false
      end

      # ── version resolution ──────────────────────────────────────────────────
      if requested_version && pkg[:versions]
        # Normalise: strip leading 'v', allow short form "1.2" -> "1.2.0"
        v = requested_version.gsub(/\Av/i, '')
        v = "#{v}.0" if v.count('.') == 1
        unless pkg[:versions].key?(v)
          available = pkg[:versions].keys.join(', ')
          puts "\e[31m✗\e[0m Version '#{requested_version}' not found for '#{name}'."
          puts "  Available: #{available}"
          return false
        end
        resolved_version = v
        source_file      = pkg[:versions][v]
      elsif requested_version && !pkg[:versions]
        puts "\e[33m~\e[0m '#{name}' does not support versioned installs. Installing latest."
        resolved_version = pkg[:version]
        source_file      = pkg[:file]
      else
        resolved_version = pkg[:version]
        source_file      = pkg[:versions] ? pkg[:versions][resolved_version] : pkg[:file]
      end

      target = if pkg[:stdlib]
        File.join(stdlib_dir, pkg[:file])
      else
        File.join(packages_dir, pkg[:file])
      end

      # Check if already installed at this exact version
      installed_ver = installed_version(name)
      if installed_ver == resolved_version && File.exist?(target)
        puts "\e[33m~\e[0m '#{name}' v#{resolved_version} is already installed."
        add_to_project(name, resolved_version)
        return true
      end

      puts "\e[34m↓\e[0m Installing \e[1m#{name}\e[0m v#{resolved_version}..."

      if pkg[:stdlib]
        unless File.exist?(target)
          puts "\e[31m✗\e[0m Stdlib file missing: #{target}"
          puts "  Re-run the Sapphire installer to restore stdlib files."
          return false
        end

      elsif pkg[:source] == :bundled
        bundled_source = File.join(stdlib_dir, source_file)
        # Also look next to this script for version files
        bundled_source = File.join(__dir__, source_file) unless File.exist?(bundled_source)
        unless File.exist?(bundled_source)
          puts "\e[31m✗\e[0m Bundled source missing: #{bundled_source}"
          puts "  Make sure the version files are in #{stdlib_dir} or #{__dir__}"
          return false
        end
        FileUtils.cp(bundled_source, target)

      else
        puts "\e[31m✗\e[0m Remote registry not yet supported for '#{name}'."
        return false
      end

      # Write installed version marker
      save_installed_version(name, resolved_version)

      puts "\e[32m✓\e[0m Installed \e[1m#{name}\e[0m v#{resolved_version}"
      puts "  #{pkg[:description]}"
      puts ""
      puts "  Usage in .sp files:"
      puts "  \e[36mimport #{name}\e[0m"
      puts "  \e[36mfrom #{name} import function_name\e[0m"

      # Hint if a newer version exists
      if pkg[:versions] && Gem::Version.new(resolved_version) < Gem::Version.new(pkg[:version])
        puts ""
        puts "  \e[33m⬆  A newer version is available: v#{pkg[:version]}\e[0m"
        puts "  \e[36m   sph install #{name} #{pkg[:version]}\e[0m"
      end

      add_to_project(name, resolved_version)
      true
    end

    def self.remove(name)
      pkg = BUILTIN_REGISTRY[name]
      if pkg&.dig(:stdlib)
        puts "\e[33m⚠\e[0m '#{name}' is a stdlib package and cannot be removed."
        return
      end
      target = File.join(packages_dir, "#{name}.sp")
      if File.exist?(target)
        File.delete(target)
        puts "\e[32m✓\e[0m Removed '#{name}'"
        remove_from_project(name)
      else
        puts "\e[33m~\e[0m '#{name}' is not installed."
      end
    end

    def self.installed_version(name)
      marker = File.join(packages_dir, ".#{name}.version")
      File.exist?(marker) ? File.read(marker).strip : nil
    end

    def self.save_installed_version(name, version)
      marker = File.join(packages_dir, ".#{name}.version")
      File.write(marker, version)
    end

    # Returns array of { name:, installed:, latest: } for packages with upgrades
    def self.upgradeable_packages
      BUILTIN_REGISTRY.filter_map do |name, pkg|
        next unless pkg[:versions]  # only versioned packages
        installed = installed_version(name)
        next unless installed
        next unless Gem::Version.new(installed) < Gem::Version.new(pkg[:version])
        { name: name, installed: installed, latest: pkg[:version] }
      end
    end

    def self.list_packages
      puts "\e[34m📦 Installed Packages\e[0m"
      puts ""

      stdlib_installed = BUILTIN_REGISTRY.select { |n, p| p[:stdlib] && File.exist?(File.join(stdlib_dir, p[:file])) }
      user_installed   = Dir[File.join(packages_dir, "*.sp")].map { |f| File.basename(f, ".sp") }

      puts "\e[1mStandard Library:\e[0m"
      if stdlib_installed.empty?
        puts "  (none)"
      else
        stdlib_installed.each do |name, pkg|
          puts "  \e[32m●\e[0m #{name.ljust(16)} v#{pkg[:version]}  #{pkg[:description]}"
        end
      end

      puts ""
      puts "\e[1mUser Packages:\e[0m"
      if user_installed.empty?
        puts "  (none)"
      else
        user_installed.each do |name|
          pkg = BUILTIN_REGISTRY[name]
          installed_ver = installed_version(name) || (pkg ? pkg[:version] : "?")
          latest_ver    = pkg ? pkg[:version] : nil
          upgrade_hint  = ""
          if pkg && pkg[:versions] && latest_ver && installed_ver != "?" &&
             Gem::Version.new(installed_ver) < Gem::Version.new(latest_ver)
            upgrade_hint = "  \e[33m⬆  v#{latest_ver} available — sph install #{name} #{latest_ver}\e[0m"
          end
          puts "  \e[32m●\e[0m #{name.ljust(16)} v#{installed_ver}#{upgrade_hint}"
        end
      end
    end

    def self.search(query)
      puts "\e[34m🔍 Searching for '#{query}'...\e[0m"
      puts ""

      results = BUILTIN_REGISTRY.select { |name, _| name.include?(query.downcase) || _[:description].downcase.include?(query.downcase) }

      if results.empty?
        puts "No packages found matching '#{query}'."
        return
      end

      results.each do |name, pkg|
        if pkg[:stdlib]
          installed = File.exist?(File.join(stdlib_dir, pkg[:file]))
          status = installed ? "\e[32m[installed]\e[0m" : "\e[33m[missing — reinstall Sapphire]\e[0m"
        else
          installed = File.exist?(File.join(packages_dir, pkg[:file]))
          status = installed ? "\e[32m[installed]\e[0m" : "\e[90m[not installed — run: sph install #{name}]\e[0m"
        end
        puts "  \e[1m#{name}\e[0m v#{pkg[:version]} #{status}"
        puts "  #{pkg[:description]}"
        puts ""
      end
    end

    def self.info(name)
      return puts "Usage: sph info <package>" if name.nil?
      pkg = BUILTIN_REGISTRY[name.downcase]
      if pkg.nil?
        puts "\e[31m✗\e[0m Package '#{name}' not found."
        return
      end
      installed = if pkg[:stdlib]
        File.exist?(File.join(stdlib_dir, pkg[:file]))
      else
        File.exist?(File.join(packages_dir, pkg[:file]))
      end
      status_label = installed ? "\e[32mInstalled\e[0m" : "\e[33mNot installed\e[0m"
      type_label   = pkg[:stdlib] ? "Standard Library" : (pkg[:source] == :bundled ? "Bundled Package (install required)" : "User Package")

      puts "\e[1m#{name}\e[0m v#{pkg[:version]}  #{status_label}"
      puts "#{pkg[:description]}"
      puts "Type: #{type_label}"
      puts ""
      if installed
        puts "Import with:"
        puts "  \e[36mimport #{name}\e[0m"
        puts "  \e[36mfrom #{name} import function_name\e[0m"
      else
        puts "\e[33mThis package must be installed before use:\e[0m"
        puts "  \e[36msph install #{name}\e[0m"
        puts ""
        puts "Then import with:"
        puts "  \e[36mimport #{name}\e[0m"
      end
    end

    def self.init_project
      if File.exist?(project_file)
        puts "\e[33m~\e[0m sapphire.json already exists."
        return
      end

      name = File.basename(Dir.pwd)
      proj = {
        "name"         => name,
        "version"      => "0.1.0",
        "description"  => "",
        "main"         => "main.sp",
        "author"       => "",
        "dependencies" => {}
      }

      File.write(project_file, JSON.pretty_generate(proj))
      puts "\e[32m✓\e[0m Created sapphire.json"
      puts ""
      puts "Edit sapphire.json to configure your project."
      puts "Run \e[36msapphire run main.sp\e[0m to execute your main file."

      # Also create a starter main.sp if it doesn't exist
      main_sp = File.join(Dir.pwd, "main.sp")
      unless File.exist?(main_sp)
        File.write(main_sp, "# #{name} — Sapphire project\n\nprintln(\"Hello from #{name}!\")\n")
        puts "\e[32m✓\e[0m Created main.sp"
      end
    end

    def self.install_from_project
      unless File.exist?(project_file)
        puts "\e[31m✗\e[0m No sapphire.json found. Run \e[36msph init\e[0m first."
        return
      end
      proj = JSON.parse(File.read(project_file))
      deps = proj["dependencies"] || {}
      if deps.empty?
        puts "No dependencies listed in sapphire.json."
        return
      end
      deps.each_key { |pkg| install(pkg) }
    end

    def self.update_all
      puts "Updating all packages..."
      BUILTIN_REGISTRY.each do |name, _|
        install(name)
      end
    end

    def self.update(name)
      install(name)
    end

    private

    def self.add_to_project(name, version)
      return unless File.exist?(project_file)
      proj = JSON.parse(File.read(project_file))
      proj["dependencies"] ||= {}
      proj["dependencies"][name] = "^#{version}"
      File.write(project_file, JSON.pretty_generate(proj))
    end

    def self.remove_from_project(name)
      return unless File.exist?(project_file)
      proj = JSON.parse(File.read(project_file))
      proj["dependencies"]&.delete(name)
      File.write(project_file, JSON.pretty_generate(proj))
    end

    def self.puts_help
      puts "Sapphire Package Manager (sph) v#{VERSION}"
      puts ""
      puts "Usage: sph <command> [args]"
      puts ""
      puts "Commands:"
      puts "  install [pkg...]   Install packages (or all from sapphire.json)"
      puts "  remove <pkg>       Remove a package"
      puts "  list               List installed packages"
      puts "  search [query]     Search the package registry"
      puts "  info <pkg>         Show package details"
      puts "  init               Create sapphire.json in current dir"
      puts "  update [pkg]       Update packages"
      puts "  version            Show spm version"
    end
  end
end

Sapphire::PackageManager.run(ARGV.dup) if __FILE__ == $0 || File.basename($0) == 'sph'
