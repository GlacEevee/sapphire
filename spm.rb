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
require 'tempfile'

$LOAD_PATH.unshift(__dir__) unless $LOAD_PATH.include?(__dir__)

module Sapphire
  module Manager
    SPM_VERSION  = "1.1.0"
    # Resolve the real directory of spm.rb regardless of how it was invoked
    SAPPHIRE_DIR = begin
      File.expand_path(File.dirname(File.realpath(__FILE__)))
    rescue NotImplementedError
      File.expand_path(__dir__)
    end

    # ── GitHub config ──────────────────────────────────────────────────────────
    # Fill in your GitHub username once you've created the repo.
    GITHUB_USER       = "GlacEevee"
    GITHUB_REPO       = "sapphire"
    GITHUB_BRANCH     = "main"
    GITHUB_BASE       = "https://raw.githubusercontent.com/#{GITHUB_USER}/#{GITHUB_REPO}/#{GITHUB_BRANCH}"
    RELEASES_MANIFEST  = "#{GITHUB_BASE}/releases/latest.json"
    RELEASES_INDEX     = "#{GITHUB_BASE}/releases"   # versioned jsons live here as v0.4.0.json etc.
    GITHUB_API_LATEST = "https://api.github.com/repos/#{GITHUB_USER}/#{GITHUB_REPO}/releases/latest"

    # Local paths
    SAPPHIRE_SRC   = File.join(Dir.home, '.sapphire', 'src')
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

    # Install a specific Sapphire interpreter version
    def self.cmd_install_version(version)
      version = version.gsub(/\Av/i, '')  # strip leading 'v'
      iv = installed_version
      puts ""

      if gem_ver(version) == gem_ver(iv)
        puts "  #{green("✓")}  Sapphire v#{version} is already installed."
        puts ""
        return
      end

      puts "  #{bold("Installing Sapphire v#{version}...")} (current: v#{iv})"
      puts ""

      # Try local releases/v0.4.0.json first, then GitHub
      local_manifest_path = File.join(SAPPHIRE_DIR, 'releases', "v#{version}.json")
      manifest = if File.exist?(local_manifest_path)
        JSON.parse(File.read(local_manifest_path)) rescue nil
      elsif github_configured?
        manifest_url = "#{RELEASES_INDEX}/v#{version}.json"
        begin
          body = fetch_url(manifest_url)
          body ? JSON.parse(body) : nil
        rescue
          nil
        end
      end

      if manifest.nil?
        puts "  #{red("✗")}  Could not find release manifest for v#{version}."
        puts "  Run #{cyan('spm releases')} to see available versions."
        puts ""
        return
      end

      # Try local bundled zip first (releases/sapphire0_4_0.zip etc.)
      local_zip = File.join(SAPPHIRE_DIR, 'releases', "sapphire#{version.gsub('.','_')}.zip")
      # Also try with leading zero stripped for patch (0.4.0 -> sapphire0_4_0.zip)
      local_zip_alt = File.join(SAPPHIRE_DIR, 'releases', "sapphire0_#{version.split('.')[1]}_#{version.split('.')[2]}.zip")

      download_url = manifest["download"]
      use_local_zip = File.exist?(local_zip) || File.exist?(local_zip_alt)

      if use_local_zip
        puts "  " + dim("Using bundled v#{version} zip...")
      else
        puts "  " + dim("Downloading from #{download_url}...")
      end

      Dir.mktmpdir do |tmpdir|
        if use_local_zip
          zip_path = File.exist?(local_zip) ? local_zip : local_zip_alt
        else
          zip_path = File.join(tmpdir, "sapphire-#{version}.zip")
          downloaded, dl_err = download_file(download_url, zip_path)
          unless downloaded
            puts "  #{red("✗")}  Download failed: #{dl_err}"
            puts "  URL: #{download_url}"
            puts ""
            return
          end
        end

        puts "  #{dim("Extracting...")}"
        result = system("unzip -q '#{zip_path}' -d '#{tmpdir}'")
        unless result
          puts "  #{red("✗")}  Extraction failed. Is 'unzip' installed?"
          puts ""
          return
        end

        # Find the extracted sapphire dir (zip may be named sapphire-0.5.0/ or sapphire/)
        extracted = Dir[File.join(tmpdir, "sapphire*/")].first || Dir[File.join(tmpdir, "*/")].first
        unless extracted
          puts "  #{red("✗")}  Could not find extracted directory."
          puts ""
          return
        end

        # Copy extracted zip files into ~/.sapphire/src
        puts "  #{dim("Installing v#{version} to #{SAPPHIRE_SRC}...")}"
        src_dest = SAPPHIRE_SRC
        FileUtils.mkdir_p(src_dest)

        Dir[File.join(extracted, '*')].each do |f|
          FileUtils.cp_r(f, src_dest)
        end

        # Always write the correct version — never trust what's in the zip
        File.write(File.join(src_dest, 'SAPPHIRE_VERSION'), version)

        # Rewrite bin wrappers directly — never run install.sh from the zip
        # (old zips have hardcoded versions in install.sh)
        puts "  #{dim("Updating bin wrappers...")}"
        bin_dir   = File.join(Dir.home, 'bin')
        FileUtils.mkdir_p(bin_dir)
        wrappers  = { 'sapphire' => 'sapphire.rb', 'sph' => 'sph.rb', 'spm' => 'spm.rb' }
        wrappers.each do |name, script|
          wrapper_path = File.join(bin_dir, name)
          wrapper_content = "#!/usr/bin/env ruby\n" \
                            "$LOAD_PATH.unshift('#{src_dest}')\n" \
                            "load '#{src_dest}/#{script}'\n"
          File.write(wrapper_path, wrapper_content)
          File.chmod(0755, wrapper_path)
        end

        puts ""
        puts "  #{green("✓  Sapphire v#{version} installed successfully.")}"
        puts "  Run: source ~/.bashrc  (or open a new terminal)"

        File.delete(CACHE_FILE) if File.exist?(CACHE_FILE)
      end
      puts ""
    end

    # List all known release versions
    def self.cmd_releases
      puts ""
      puts bold("  Known Sapphire releases:")
      puts ""

      # Local releases dir
      releases_dir = File.join(SAPPHIRE_DIR, 'releases')
      local_jsons  = Dir[File.join(releases_dir, 'v*.json')].sort

      if local_jsons.empty?
        puts "  #{dim("No local release manifests found in releases/")}"
      else
        local_jsons.each do |path|
          data = JSON.parse(File.read(path)) rescue {}
          ver  = data["version"] || File.basename(path, '.json').sub('v','')
          date = data["released"] ? "  (#{data['released']})" : ""
          note = data["notes"] ? "  #{dim(data['notes'])}" : ""
          current = gem_ver(ver) == gem_ver(installed_version) ? "  #{green("← current")}" : ""
          puts "    #{cyan("v#{ver}")}#{date}#{current}"
          puts "    #{note}" unless note.empty?
          puts ""
        end
      end

      puts "  Install a version:  #{cyan("spm install <version>")}"
      puts "  Example:            #{cyan("spm install 0.4.0")}"
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

    def self.fetch_url(url, redirect_limit = 10)
      return nil if redirect_limit == 0
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == 'https'
      http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = 15
      http.read_timeout = 30
      req = Net::HTTP::Get.new(uri.request_uri)
      req['User-Agent'] = "spm/#{SPM_VERSION} Sapphire-Package-Manager"
      resp = http.request(req)
      case resp.code
      when "200"
        resp.body
      when "301", "302", "303", "307", "308"
        fetch_url(resp['location'], redirect_limit - 1)
      else
        nil
      end
    rescue
      nil
    end

    def self.download_file(url, dest, redirect_limit = 10)
      return [false, "Too many redirects"] if redirect_limit == 0
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == 'https',
                      verify_mode: OpenSSL::SSL::VERIFY_PEER,
                      open_timeout: 15, read_timeout: 300) do |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        req['User-Agent'] = "spm/#{SPM_VERSION} Sapphire-Package-Manager"
        # Stream response directly to disk — avoids loading entire zip into memory
        http.request(req) do |resp|
          case resp.code
          when "200"
            File.open(dest, 'wb') do |f|
              resp.read_body { |chunk| f.write(chunk) }
            end
            return [true, nil]
          when "301", "302", "303", "307", "308"
            new_url = resp['location']
            return download_file(new_url, dest, redirect_limit - 1)
          else
            return [false, "HTTP #{resp.code}"]
          end
        end
      end
    rescue => e
      [false, e.message]
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
      puts "    #{cyan('spm install <version>')}     Install a specific Sapphire version (e.g. 0.4.0)"
      puts "    #{cyan('spm releases')}              List all known Sapphire releases"
      puts "    #{cyan('spm install <pkg> [ver]')}   Install a package (proxied to sph)"
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
      when 'install', 'add'
        # If arg looks like a version number (e.g. 0.4.0 or v0.4.0), install that Sapphire version.
        # Otherwise proxy to sph for package installs.
        second = args[1]
        if second && second.match?(/\Av?\d+\.\d+/)
          cmd_install_version(second)
        else
          proxy_to_sph(args)
        end
      when 'releases', 'versions'
        cmd_releases
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
