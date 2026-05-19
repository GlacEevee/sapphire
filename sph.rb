#!/usr/bin/env ruby
# sph.rb — Sapphire Package Manager
# Usage:
#   sph install <package>              Install a built-in package
#   sph install <user>/<repo>          Install a community package from GitHub
#   sph install <user>/<repo>@<tag>    Install a specific release
#   sph remove <package>               Remove a package
#   sph list                           List installed packages
#   sph search <query>                 Search built-in + community packages
#   sph init                           Create a new sapphire.json project file
#   sph info <package>                 Show package details
#   sph update [pkg]                   Update packages

require 'json'
require 'fileutils'
require 'net/http'
require 'net/https'
require 'uri'
require 'open-uri'

module Sapphire
  module PackageManager
    VERSION = "2.0.0"

    GITHUB_API    = "https://api.github.com"
    GITHUB_TOPIC  = "sapphire-package"   # repos must have this topic to appear in search
    GITHUB_RAW    = "https://raw.githubusercontent.com"

    # ── Directory helpers ──────────────────────────────────────────────────────

    def self.packages_dir
      File.expand_path("~/.sapphire/packages")
    end

    def self.stdlib_dir
      File.join(__dir__, 'stdlib')
    end

    def self.project_file
      File.join(Dir.pwd, 'sapphire.json')
    end

    def self.meta_dir
      File.expand_path("~/.sapphire/meta")
    end

    def self.ensure_dirs
      FileUtils.mkdir_p(packages_dir)
      FileUtils.mkdir_p(stdlib_dir)
      FileUtils.mkdir_p(meta_dir)
    end

    # ── Built-in registry ─────────────────────────────────────────────────────
    BUILTIN_REGISTRY = {
      "math"        => { version: "1.0.0", description: "Extended math: primes, gcd, fibonacci, statistics", stdlib: true,  file: "math.sp" },
      "strings"     => { version: "1.0.0", description: "String utilities: capitalize, truncate, palindrome, indent", stdlib: true,  file: "strings.sp" },
      "collections" => { version: "1.0.0", description: "Collection utilities: chunk, group_by, frequencies, compact", stdlib: true,  file: "collections.sp" },
      "io"          => { version: "1.0.0", description: "IO helpers: read_lines, write_lines, prompt, print_table", stdlib: true,  file: "io.sp" },
      "json"        => { version: "1.0.0", description: "JSON encode/decode support (native bridge)", stdlib: true,  file: "json.sp" },
      "datetime"    => { version: "1.0.0", description: "Date and time utilities", stdlib: true,  file: "datetime.sp" },
      "test"        => { version: "1.0.0", description: "Minimalist unit testing framework for Sapphire", stdlib: true,  file: "test.sp" },
      "http"        => { version: "1.0.0", description: "Simple HTTP client (get/post)", stdlib: true,  file: "http.sp" },
      "media"       => { version: "1.0.0", description: "Photo and video viewer — headless Pi friendly (framebuffer, no X needed)", stdlib: true,  file: "media.sp" },
      "discordsph"  => {
        version: "1.4.0",
        description: "Discord bot framework: client, commands, embeds, gateway events",
        stdlib: false, file: "discordsph.sp", source: :bundled,
        versions: {
          "1.0.0" => "discordsph_v1.0.sp", "1.1.0" => "discordsph_v1.1.sp",
          "1.2.0" => "discordsph_v1.2.sp", "1.3.0" => "discordsph_v1.3.sp",
          "1.4.0" => "discordsph_v1.4.sp",
        }
      },
      "dotenv"      => { version: "1.0.0", description: "Load environment variables from a .env file into Sys.env()", stdlib: false, file: "dotenv.sp", source: :bundled },
    }.freeze

    # ── CLI entry point ────────────────────────────────────────────────────────

    def self.run(args)
      ensure_dirs
      cmd = args.shift

      case cmd
      when 'install', 'add'
        if args.empty?
          install_from_project
        else
          pkg_name = args.shift
          version  = args.shift   # nil if not given
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
      when 'help', '--help', '-h'
        puts_help
      else
        puts_help
      end
    end

    # ── Install dispatcher ─────────────────────────────────────────────────────

    def self.install(name, requested_version = nil)
      # Community package: user/repo or user/repo@tag
      if name.include?('/')
        repo_spec, inline_tag = name.split('@', 2)
        tag = inline_tag || requested_version
        return install_community(repo_spec, tag)
      end

      name = name.downcase
      pkg  = BUILTIN_REGISTRY[name]

      if pkg.nil?
        puts "\e[31m✗\e[0m Package '#{name}' not found in built-in registry."
        puts "  Tip: community packages use \e[36msph install <user>/<repo>\e[0m"
        puts "  Run \e[36msph search #{name}\e[0m to search community packages."
        return false
      end

      install_builtin(name, pkg, requested_version)
    end

    # ── Built-in install ───────────────────────────────────────────────────────

    def self.install_builtin(name, pkg, requested_version = nil)
      if requested_version && pkg[:versions]
        v = requested_version.gsub(/\Av/i, '')
        v = "#{v}.0" if v.count('.') == 1
        unless pkg[:versions].key?(v)
          puts "\e[31m✗\e[0m Version '#{requested_version}' not found for '#{name}'."
          puts "  Available: #{pkg[:versions].keys.join(', ')}"
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

      target = pkg[:stdlib] ? File.join(stdlib_dir, pkg[:file]) : File.join(packages_dir, pkg[:file])

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
        bundled_source = File.join(__dir__, source_file) unless File.exist?(bundled_source)
        unless File.exist?(bundled_source)
          puts "\e[31m✗\e[0m Bundled source missing: #{bundled_source}"
          return false
        end
        FileUtils.cp(bundled_source, target)
      else
        puts "\e[31m✗\e[0m Remote registry not yet supported for '#{name}'."
        return false
      end

      save_installed_version(name, resolved_version)
      save_package_meta(name, { source: "builtin", version: resolved_version })

      puts "\e[32m✓\e[0m Installed \e[1m#{name}\e[0m v#{resolved_version}"
      puts "  #{pkg[:description]}"
      puts "\n  Usage in .sp files:"
      puts "  \e[36mimport #{name}\e[0m"
      puts "  \e[36mfrom #{name} import function_name\e[0m"

      if pkg[:versions] && Gem::Version.new(resolved_version) < Gem::Version.new(pkg[:version])
        puts "\n  \e[33m⬆  A newer version is available: v#{pkg[:version]}\e[0m"
        puts "  \e[36m   sph install #{name} #{pkg[:version]}\e[0m"
      end

      add_to_project(name, resolved_version)
      true
    end

    # ── Community package install (GitHub) ────────────────────────────────────

    def self.install_community(repo_spec, tag = nil)
      user, repo = repo_spec.split('/', 2)
      if user.nil? || repo.nil?
        puts "\e[31m✗\e[0m Invalid package spec. Use \e[36muser/repo\e[0m or \e[36muser/repo@tag\e[0m"
        return false
      end

      puts "\e[34m↓\e[0m Fetching package info for \e[1m#{repo_spec}\e[0m..."

      # Fetch sapphire.json (package manifest) from GitHub
      ref = tag || "main"
      manifest_url = "#{GITHUB_RAW}/#{user}/#{repo}/#{ref}/sapphire.json"
      manifest = fetch_json(manifest_url)

      if manifest.nil?
        # Try master branch
        ref = tag || "master"
        manifest_url = "#{GITHUB_RAW}/#{user}/#{repo}/#{ref}/sapphire.json"
        manifest = fetch_json(manifest_url)
      end

      if manifest.nil?
        puts "\e[31m✗\e[0m Could not fetch sapphire.json from #{repo_spec}@#{ref}."
        puts "  Make sure the repo has a valid sapphire.json in the root."
        puts "  See \e[36mCOMMUNITY_PACKAGES.md\e[0m for the required format."
        return false
      end

      pkg_name    = (manifest["name"] || repo).downcase
      pkg_version = manifest["version"] || "0.0.0"
      pkg_main    = manifest["main"]    || "#{pkg_name}.sp"
      pkg_desc    = manifest["description"] || ""

      # Download the main .sp file
      file_url    = "#{GITHUB_RAW}/#{user}/#{repo}/#{ref}/#{pkg_main}"
      sp_source   = fetch_raw(file_url)

      if sp_source.nil?
        puts "\e[31m✗\e[0m Could not fetch source file '#{pkg_main}' from #{repo_spec}."
        return false
      end

      target = File.join(packages_dir, "#{pkg_name}.sp")
      File.write(target, sp_source)
      save_installed_version(pkg_name, pkg_version)
      save_package_meta(pkg_name, {
        source:      "community",
        repo:        "#{user}/#{repo}",
        ref:         ref,
        version:     pkg_version,
        description: pkg_desc
      })

      puts "\e[32m✓\e[0m Installed \e[1m#{pkg_name}\e[0m v#{pkg_version} from \e[36m#{user}/#{repo}@#{ref}\e[0m"
      puts "  #{pkg_desc}" unless pkg_desc.empty?
      puts "\n  Usage in .sp files:"
      puts "  \e[36mimport #{pkg_name}\e[0m"

      add_to_project(pkg_name, pkg_version)
      true
    rescue => e
      puts "\e[31m✗\e[0m Install failed: #{e.message}"
      false
    end

    # ── Search: built-in + GitHub community ───────────────────────────────────

    def self.search(query)
      puts "\e[34m🔍 Searching for '\e[1m#{query}\e[0m\e[34m'...\e[0m"
      puts ""

      # ── Built-in results ──
      builtin_results = BUILTIN_REGISTRY.select do |name, pkg|
        name.include?(query.downcase) || pkg[:description].downcase.include?(query.downcase)
      end

      unless builtin_results.empty?
        puts "\e[1m── Built-in packages ───────────────────────────────\e[0m"
        builtin_results.each do |name, pkg|
          if pkg[:stdlib]
            installed = File.exist?(File.join(stdlib_dir, pkg[:file]))
            status = installed ? "\e[32m[installed]\e[0m" : "\e[33m[stdlib — always available]\e[0m"
          else
            installed = File.exist?(File.join(packages_dir, pkg[:file]))
            status = installed ? "\e[32m[installed]\e[0m" : "\e[90m[run: sph install #{name}]\e[0m"
          end
          puts "  \e[1m#{name}\e[0m v#{pkg[:version]} #{status}"
          puts "  #{pkg[:description]}"
          puts ""
        end
      end

      # ── Community (GitHub) results ──
      puts "\e[1m── Community packages (GitHub) ─────────────────────\e[0m"

      gh_results = search_github(query)

      if gh_results.nil?
        puts "  \e[33m⚠  GitHub search unavailable (network error or rate limit).\e[0m"
        puts "  Browse manually: \e[36mhttps://github.com/topics/#{GITHUB_TOPIC}\e[0m"
        puts ""
      elsif gh_results.empty?
        if query.empty?
          puts "  Browse all: \e[36mhttps://github.com/topics/#{GITHUB_TOPIC}\e[0m"
        else
          puts "  No community packages found for '#{query}'."
          puts "  Browse all: \e[36mhttps://github.com/topics/#{GITHUB_TOPIC}\e[0m"
        end
        puts ""
      else
        gh_results.each do |r|
          installed_meta = load_package_meta(r[:name])
          status = if installed_meta && installed_meta["source"] == "community"
            "\e[32m[installed v#{installed_meta['version']}]\e[0m"
          else
            "\e[90m[run: sph install #{r[:full_name]}]\e[0m"
          end
          stars = r[:stars] > 0 ? " \e[33m★#{r[:stars]}\e[0m" : ""
          puts "  \e[1m#{r[:name]}\e[0m#{stars}  \e[36m#{r[:full_name]}\e[0m  #{status}"
          puts "  #{r[:description]}" unless r[:description].to_s.empty?
          puts ""
        end
        puts "  More results: \e[36mhttps://github.com/topics/#{GITHUB_TOPIC}\e[0m"
        puts ""
      end

      puts "  Tip: install any community package with \e[36msph install <user>/<repo>\e[0m" if builtin_results.empty? && (gh_results.nil? || gh_results.empty?)
    end

    # ── GitHub API search ──────────────────────────────────────────────────────

    def self.search_github(query)
      # Build the search query: always filter by topic, optionally add query term
      q_parts = ["topic:#{GITHUB_TOPIC}"]
      q_parts << query unless query.to_s.strip.empty?
      q = q_parts.join("+")

      url = "#{GITHUB_API}/search/repositories?q=#{URI.encode_www_form_component(q_parts.join(' '))}&sort=stars&per_page=10"

      data = fetch_json(url, github_headers)
      return nil if data.nil?

      items = data["items"] || []
      items.map do |item|
        {
          name:        item["name"].downcase.gsub(/[-_]sapphire$|^sapphire[-_]/, ''),
          full_name:   item["full_name"],
          description: item["description"],
          stars:       item["stargazers_count"].to_i,
          url:         item["html_url"],
        }
      end
    rescue => _e
      nil
    end

    # ── Remove ────────────────────────────────────────────────────────────────

    def self.remove(name)
      name = name.split('/').last if name.include?('/')  # allow user/repo syntax
      name = name.downcase

      pkg = BUILTIN_REGISTRY[name]
      if pkg&.dig(:stdlib)
        puts "\e[33m⚠\e[0m '#{name}' is a stdlib package and cannot be removed."
        return
      end

      target = File.join(packages_dir, "#{name}.sp")
      if File.exist?(target)
        File.delete(target)
        File.delete(File.join(packages_dir, ".#{name}.version")) rescue nil
        File.delete(File.join(meta_dir, "#{name}.json")) rescue nil
        puts "\e[32m✓\e[0m Removed '#{name}'"
        remove_from_project(name)
      else
        puts "\e[33m~\e[0m '#{name}' is not installed."
      end
    end

    # ── List ──────────────────────────────────────────────────────────────────

    def self.list_packages
      puts "\e[34m📦 Installed Packages\e[0m"
      puts ""

      stdlib_installed = BUILTIN_REGISTRY.select { |n, p| p[:stdlib] && File.exist?(File.join(stdlib_dir, p[:file])) }
      user_sp_files    = Dir[File.join(packages_dir, "*.sp")].map { |f| File.basename(f, ".sp") }

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
      if user_sp_files.empty?
        puts "  (none)"
      else
        user_sp_files.each do |name|
          meta          = load_package_meta(name)
          builtin_pkg   = BUILTIN_REGISTRY[name]
          installed_ver = installed_version(name) || (builtin_pkg ? builtin_pkg[:version] : "?")
          source_label  = if meta && meta["source"] == "community"
            "\e[35m[community: #{meta['repo']}]\e[0m"
          elsif builtin_pkg
            "\e[34m[bundled]\e[0m"
          else
            ""
          end

          upgrade_hint = ""
          if builtin_pkg && builtin_pkg[:versions] && installed_ver != "?"
            latest = builtin_pkg[:version]
            if Gem::Version.new(installed_ver) < Gem::Version.new(latest)
              upgrade_hint = "  \e[33m⬆  v#{latest} available — sph install #{name} #{latest}\e[0m"
            end
          end

          puts "  \e[32m●\e[0m #{name.ljust(16)} v#{installed_ver}  #{source_label}#{upgrade_hint}"
        end
      end
    end

    # ── Info ──────────────────────────────────────────────────────────────────

    def self.info(name)
      return puts "Usage: sph info <package>" if name.nil?

      # Community package info from meta
      clean_name = name.split('/').last if name.include?('/')
      clean_name ||= name.downcase

      meta = load_package_meta(clean_name)

      if meta && meta["source"] == "community"
        installed = File.exist?(File.join(packages_dir, "#{clean_name}.sp"))
        puts "\e[1m#{clean_name}\e[0m v#{meta['version']}  \e[32m[community — installed]\e[0m"
        puts meta['description'] unless meta['description'].to_s.empty?
        puts "Source: \e[36mhttps://github.com/#{meta['repo']}\e[0m"
        puts "\nImport with:"
        puts "  \e[36mimport #{clean_name}\e[0m"
        return
      end

      pkg = BUILTIN_REGISTRY[clean_name]
      if pkg.nil?
        puts "\e[31m✗\e[0m Package '#{name}' not found."
        puts "  Use \e[36msph search #{name}\e[0m to look it up."
        return
      end

      installed = pkg[:stdlib] ? File.exist?(File.join(stdlib_dir, pkg[:file])) : File.exist?(File.join(packages_dir, pkg[:file]))
      status_label = installed ? "\e[32mInstalled\e[0m" : "\e[33mNot installed\e[0m"
      type_label   = pkg[:stdlib] ? "Standard Library" : (pkg[:source] == :bundled ? "Bundled Package" : "User Package")

      puts "\e[1m#{clean_name}\e[0m v#{pkg[:version]}  #{status_label}"
      puts pkg[:description]
      puts "Type: #{type_label}"
      puts ""
      if installed
        puts "Import with:"
        puts "  \e[36mimport #{clean_name}\e[0m"
        puts "  \e[36mfrom #{clean_name} import function_name\e[0m"
      else
        puts "\e[33mInstall first:\e[0m  \e[36msph install #{clean_name}\e[0m"
      end
    end

    # ── Update ────────────────────────────────────────────────────────────────

    def self.update_all
      puts "Updating all installed packages..."
      Dir[File.join(packages_dir, "*.sp")].each do |f|
        name = File.basename(f, ".sp")
        meta = load_package_meta(name)
        if meta && meta["source"] == "community"
          puts "\e[34m↓\e[0m Updating community package \e[1m#{name}\e[0m..."
          install_community(meta["repo"])
        elsif BUILTIN_REGISTRY[name]
          install_builtin(name, BUILTIN_REGISTRY[name])
        end
      end
    end

    def self.update(name)
      install(name)
    end

    # ── Project file helpers ──────────────────────────────────────────────────

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
      puts "\nEdit sapphire.json to configure your project."
      puts "Run \e[36msapphire run main.sp\e[0m to execute your main file."

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

    # ── Version/meta persistence ──────────────────────────────────────────────

    def self.installed_version(name)
      marker = File.join(packages_dir, ".#{name}.version")
      File.exist?(marker) ? File.read(marker).strip : nil
    end

    def self.save_installed_version(name, version)
      File.write(File.join(packages_dir, ".#{name}.version"), version)
    end

    def self.save_package_meta(name, data)
      File.write(File.join(meta_dir, "#{name}.json"), JSON.pretty_generate(data))
    end

    def self.load_package_meta(name)
      path = File.join(meta_dir, "#{name}.json")
      return nil unless File.exist?(path)
      JSON.parse(File.read(path))
    rescue
      nil
    end

    def self.upgradeable_packages
      BUILTIN_REGISTRY.filter_map do |name, pkg|
        next unless pkg[:versions]
        installed = installed_version(name)
        next unless installed
        next unless Gem::Version.new(installed) < Gem::Version.new(pkg[:version])
        { name: name, installed: installed, latest: pkg[:version] }
      end
    end

    # ── HTTP helpers ──────────────────────────────────────────────────────────

    def self.fetch_json(url, extra_headers = {})
      raw = fetch_raw(url, extra_headers)
      return nil if raw.nil?
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def self.fetch_raw(url, extra_headers = {})
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 15

      req = Net::HTTP::Get.new(uri.request_uri)
      req['User-Agent'] = "sph/#{VERSION} Sapphire-Package-Manager"
      req['Accept']     = 'application/json'
      extra_headers.each { |k, v| req[k] = v }

      res = http.request(req)
      return nil unless res.is_a?(Net::HTTPSuccess)
      res.body
    rescue => _e
      nil
    end

    def self.github_headers
      token = ENV['GITHUB_TOKEN'] || ENV['GH_TOKEN']
      token ? { 'Authorization' => "Bearer #{token}" } : {}
    end

    # ── Project dep helpers ───────────────────────────────────────────────────

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

    # ── Help ──────────────────────────────────────────────────────────────────

    def self.puts_help
      puts "Sapphire Package Manager (sph) v#{VERSION}"
      puts ""
      puts "Usage: sph <command> [args]"
      puts ""
      puts "Commands:"
      puts "  install [pkg...]           Install packages (or all from sapphire.json)"
      puts "  install <user>/<repo>      Install a community package from GitHub"
      puts "  install <user>/<repo>@tag  Install a specific release"
      puts "  remove <pkg>               Remove a package"
      puts "  list                       List installed packages"
      puts "  search [query]             Search built-in + community packages"
      puts "  info <pkg>                 Show package details"
      puts "  init                       Create sapphire.json in current dir"
      puts "  update [pkg]               Update packages"
      puts "  version                    Show sph version"
      puts ""
      puts "Community packages:"
      puts "  \e[36msph search\e[0m                         Browse all community packages"
      puts "  \e[36msph install foxie/sph-colors\e[0m       Install from GitHub"
      puts "  \e[36msph install foxie/sph-colors@v1.2\e[0m  Install specific tag"
      puts ""
      puts "  Set GITHUB_TOKEN env var to avoid API rate limits."
      puts "  See COMMUNITY_PACKAGES.md to publish your own package."
    end
  end
end

Sapphire::PackageManager.run(ARGV.dup) if __FILE__ == $0 || File.basename($0) == 'sph'
