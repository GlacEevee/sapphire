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
      "colors"      => { version: "1.0.0", description: "Terminal color and style helpers — red, bold, underline, bg_blue, etc.", stdlib: true,  file: "colors.sp" },
      "args"        => { version: "1.0.0", description: "CLI argument parser — --flags, --options, positional args", stdlib: true,  file: "args.sp" },
      "yml"         => { version: "1.0.0", description: "YAML file read/write support", stdlib: true,  file: "yml.sp" },
      "csv"         => { version: "1.0.0", description: "CSV file read/write support", stdlib: true,  file: "csv.sp" },
      "crypto"      => { version: "1.0.0", description: "Hashing (SHA256, MD5), base64, HMAC, UUID generation", stdlib: true,  file: "crypto.sp" },
      "files"       => { version: "1.0.0", description: "File and directory utilities — read, write, glob, watch", stdlib: true,  file: "files.sp" },
      "zip"         => { version: "1.0.0", description: "Create and extract zip archives", stdlib: true,  file: "zip.sp" },
      "env"         => { version: "1.0.0", description: "OS/platform detection, environment variables", stdlib: true,  file: "env.sp" },
      "sqlite"      => { version: "1.0.0", description: "Embedded SQLite database (requires sqlite3 gem)", stdlib: true,  file: "sqlite.sp" },
      "web"         => { version: "1.0.0", description: "Web server with routing and WebSockets (requires Node.js)", stdlib: true,  file: "web.sp",  requires_node: true },
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
      when 'publish'
        cmd_publish
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
      # Fork package: user/packagename (no .sp, installs from fork's packages branch)
      # Community repo: user/repo@tag (installs from a full repo with sapphire.json)
      if name.include?('/')
        parts = name.split('/', 2)
        user  = parts[0]
        pkg   = parts[1]

        # If it looks like a simple package name (no dots, no version tag) try fork first
        if !pkg.include?('@') && !pkg.include?('.')
          tag = requested_version
          fork_result = install_fork_package(user, pkg, tag)
          return fork_result unless fork_result.nil?
        end

        # Fall back to community repo install
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


    # ── Publish to packages branch ────────────────────────────────────────────

    PACKAGES_BRANCH = "packages"
    AUTH_FILE       = File.join(Dir.home, '.sapphire', 'auth.json')
    SAPPHIRE_REPO   = "GlacEevee/sapphire"

    def self.cmd_publish
      ensure_auth
      auth     = JSON.parse(File.read(AUTH_FILE))
      username = auth['username']
      token    = auth['token']

      # Read sapphire.json from current dir
      pkg_file = File.join(Dir.pwd, 'sapphire.json')
      unless File.exist?(pkg_file)
        puts "\e[31m✗\e[0m No sapphire.json found in current directory."
        puts "  Run \e[36msph init\e[0m to create one."
        return false
      end

      pkg = JSON.parse(File.read(pkg_file))
      name    = pkg['name']
      version = pkg['version']
      main    = pkg['main'] || "#{name}.sp"
      desc    = pkg['description'] || ""

      unless File.exist?(File.join(Dir.pwd, main))
        puts "\e[31m✗\e[0m Main file '#{main}' not found."
        return false
      end

      puts "\e[34m↑\e[0m Publishing \e[1m#{name}\e[0m v#{version} as \e[36m#{username}\e[0m..."
      puts ""

      # Step 1: Fork GlacEevee/sapphire if not already forked
      fork_name = "#{username}/sapphire"
      puts "  \e[2mChecking fork #{fork_name}...\e[0m"
      fork_exists = check_fork_exists(username, token)

      unless fork_exists
        puts "  \e[2mForking #{SAPPHIRE_REPO}...\e[0m"
        ok = create_fork(token)
        unless ok
          puts "\e[31m✗\e[0m Failed to fork #{SAPPHIRE_REPO}."
          return false
        end
        puts "  \e[32m✓\e[0m Forked to #{fork_name}"
        sleep 3  # GitHub needs a moment to set up the fork
      else
        puts "  \e[32m✓\e[0m Fork exists: #{fork_name}"
      end

      # Step 2: Ensure packages branch exists on fork
      puts "  \e[2mEnsuring packages branch...\e[0m"
      ensure_packages_branch(username, token)

      # Step 3: Upload the .sp file to packages/ folder
      puts "  \e[2mUploading #{main}...\e[0m"
      sp_content  = File.read(File.join(Dir.pwd, main))
      upload_ok   = upload_file(username, token, "packages/#{name}.sp", sp_content)
      unless upload_ok
        puts "\e[31m✗\e[0m Failed to upload package file."
        return false
      end

      # Step 4: Update registry.json on packages branch
      puts "  \e[2mUpdating registry...\e[0m"
      update_registry(username, token, name, version, desc, main)

      puts ""
      puts "\e[32m✓\e[0m Published \e[1m#{name}\e[0m v#{version}!"
      puts ""
      puts "  Others can install it with:"
      puts "  \e[36msph install #{username}/#{name}\e[0m"
      puts ""
      true
    end

    def self.ensure_auth
      return if File.exist?(AUTH_FILE)

      puts ""
      puts "\e[1mWelcome to sph publish!\e[0m"
      puts "You need a GitHub account to publish packages."
      puts ""
      print "GitHub username: "
      username = $stdin.gets.chomp.strip

      puts ""
      puts "GitHub personal access token"
      puts "  Create one at: \e[36mhttps://github.com/settings/tokens/new\e[0m"
      puts "  Required scope: \e[1mrepo\e[0m (for forking and file upload)"
      puts ""
      print "Token: "
      # Hide token input if possible
      begin
        require 'io/console'
        token = $stdin.noecho(&:gets).chomp
        puts ""
      rescue
        token = $stdin.gets.chomp.strip
      end

      if username.empty? || token.empty?
        puts "\e[31m✗\e[0m Username and token are required."
        exit 1
      end

      # Verify token works
      print "  Verifying token..."
      result = fetch_raw("https://api.github.com/user", { 'Authorization' => "Bearer #{token}" })
      if result.nil?
        puts " \e[31mfailed\e[0m"
        puts "\e[31m✗\e[0m Could not verify token. Check it and try again."
        exit 1
      end
      user_data = JSON.parse(result) rescue {}
      actual_user = user_data['login'] || username
      puts " \e[32m✓\e[0m"

      FileUtils.mkdir_p(File.dirname(AUTH_FILE))
      File.write(AUTH_FILE, JSON.pretty_generate({ 'username' => actual_user, 'token' => token }))
      File.chmod(0600, AUTH_FILE)  # owner read/write only

      puts "  \e[32m✓\e[0m Credentials saved to ~/.sapphire/auth.json"
      puts ""
    end

    def self.check_fork_exists(username, token)
      url    = "#{GITHUB_API}/repos/#{username}/sapphire"
      result = fetch_raw(url, { 'Authorization' => "Bearer #{token}" })
      !result.nil?
    end

    def self.create_fork(token)
      uri  = URI.parse("#{GITHUB_API}/repos/#{SAPPHIRE_REPO}/forks")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Authorization']  = "Bearer #{token}"
      req['Content-Type']   = 'application/json'
      req['User-Agent']     = "sph/#{VERSION}"
      req.body = '{}'
      resp = http.request(req)
      resp.code.to_i < 300
    rescue
      false
    end

    def self.ensure_packages_branch(username, token)
      # Check if branch exists
      url    = "#{GITHUB_API}/repos/#{username}/sapphire/branches/#{PACKAGES_BRANCH}"
      result = fetch_raw(url, { 'Authorization' => "Bearer #{token}" })
      if result
        puts "  \e[32m✓\e[0m packages branch exists"
        return true
      end

      puts "  \e[2mCreating packages branch...\e[0m"

      # Get default branch info
      repo_info = fetch_raw("#{GITHUB_API}/repos/#{username}/sapphire", { 'Authorization' => "Bearer #{token}" })
      unless repo_info
        puts "  \e[31m✗\e[0m Could not fetch repo info"
        return false
      end
      default_branch = JSON.parse(repo_info)['default_branch'] || 'main'

      # Get the SHA of the latest commit on default branch
      ref_info = fetch_raw("#{GITHUB_API}/repos/#{username}/sapphire/git/ref/heads/#{default_branch}", { 'Authorization' => "Bearer #{token}" })
      unless ref_info
        puts "  \e[31m✗\e[0m Could not fetch ref for #{default_branch}"
        return false
      end
      sha = JSON.parse(ref_info)['object']['sha']
      unless sha
        puts "  \e[31m✗\e[0m Could not get SHA from ref"
        return false
      end

      # Create the branch
      uri  = URI.parse("#{GITHUB_API}/repos/#{username}/sapphire/git/refs")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type']  = 'application/json'
      req['User-Agent']    = "sph/#{VERSION}"
      req.body = JSON.generate({ ref: "refs/heads/#{PACKAGES_BRANCH}", sha: sha })
      resp = http.request(req)
      if resp.code.to_i < 300
        puts "  \e[32m✓\e[0m Created packages branch"
        true
      else
        err = JSON.parse(resp.body) rescue {}
        puts "  \e[31m✗\e[0m Failed to create branch: HTTP #{resp.code} — #{err['message']}"
        false
      end
    rescue => e
      puts "  \e[31m✗\e[0m Branch error: #{e.message}"
      false
    end

    def self.upload_file(username, token, path, content)
      require 'base64'
      encoded = Base64.strict_encode64(content)

      # Check if file exists (need its SHA to update)
      url     = "#{GITHUB_API}/repos/#{username}/sapphire/contents/#{path}?ref=#{PACKAGES_BRANCH}"
      existing = fetch_raw(url, { 'Authorization' => "Bearer #{token}" })
      existing_sha = existing ? (JSON.parse(existing)['sha'] rescue nil) : nil

      body = { message: "sph: publish package", content: encoded, branch: PACKAGES_BRANCH }
      body[:sha] = existing_sha if existing_sha

      full_url = "#{GITHUB_API}/repos/#{username}/sapphire/contents/#{path}"
      puts "  \e[2mPUT #{full_url}\e[0m"
      uri  = URI.parse(full_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Put.new(uri.request_uri)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type']  = 'application/json'
      req['User-Agent']    = "sph/#{VERSION}"
      req.body = JSON.generate(body)
      resp = http.request(req)
      unless resp.code.to_i < 300
        err = JSON.parse(resp.body) rescue {}
        puts "  \e[2mGitHub API: HTTP #{resp.code} — #{err['message']}\e[0m"
        puts "  \e[2mFull response: #{resp.body[0,200]}\e[0m"
        return false
      end
      true
    rescue => e
      puts "  \e[2mupload error: #{e.message}\e[0m"
      false
    end

    def self.update_registry(username, token, name, version, desc, main)
      require 'base64'
      # Fetch existing registry.json
      url      = "#{GITHUB_API}/repos/#{username}/sapphire/contents/packages/registry.json?ref=#{PACKAGES_BRANCH}"
      existing = fetch_raw(url, { 'Authorization' => "Bearer #{token}" })
      if existing
        data     = JSON.parse(existing)
        registry = JSON.parse(Base64.decode64(data['content'])) rescue {}
        file_sha = data['sha']
      else
        registry = {}
        file_sha = nil
      end

      registry[name] = {
        'version'     => version,
        'description' => desc,
        'author'      => username,
        'file'        => "packages/#{name}.sp",
        'updated_at'  => Time.now.utc.strftime('%Y-%m-%d'),
      }

      new_content = JSON.pretty_generate(registry)
      body = { message: "sph: update registry for #{name}", content: Base64.strict_encode64(new_content), branch: PACKAGES_BRANCH }
      body[:sha] = file_sha if file_sha

      uri  = URI.parse("#{GITHUB_API}/repos/#{username}/sapphire/contents/packages/registry.json")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Put.new(uri.request_uri)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type']  = 'application/json'
      req['User-Agent']    = "sph/#{VERSION}"
      req.body = JSON.generate(body)
      resp = http.request(req)
      resp.code.to_i < 300
    rescue
      false
    end


    # ── Package encryption ────────────────────────────────────────────────────
    # Encrypts installed .sp files with AES-256-GCM to prevent casual tampering.
    # The key lives in ~/.sapphire/pkg.key — readable only by the owner.
    # Encrypted files get a .spe extension.

    ENCRYPTED_EXT = ".spe"
    KEY_FILE      = File.join(Dir.home, '.sapphire', 'pkg.key')

    def self.package_key
      unless File.exist?(KEY_FILE)
        FileUtils.mkdir_p(File.dirname(KEY_FILE))
        File.write(KEY_FILE, SecureRandom.hex(32))
        File.chmod(0600, KEY_FILE)
      end
      [File.read(KEY_FILE).strip].pack('H*')
    end

    def self.encrypt_package(path)
      require 'openssl'
      require 'securerandom'
      data   = File.read(path)
      key    = package_key
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.encrypt
      cipher.key = key
      iv         = cipher.random_iv
      cipher.iv  = iv
      cipher.auth_data = ""
      encrypted  = cipher.update(data) + cipher.final
      tag        = cipher.auth_tag
      # Format: 12-byte IV + 16-byte tag + ciphertext
      payload    = iv + tag + encrypted
      enc_path   = path.sub(/\.sp$/, ENCRYPTED_EXT)
      File.binwrite(enc_path, payload)
      File.delete(path)
      enc_path
    rescue => e
      # If encryption fails, keep the original file
      path
    end

    def self.decrypt_package(enc_path)
      require 'openssl'
      payload    = File.binread(enc_path)
      iv         = payload[0, 12]
      tag        = payload[12, 16]
      ciphertext = payload[28..]
      key        = package_key
      cipher     = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key      = key
      cipher.iv       = iv
      cipher.auth_tag = tag
      cipher.auth_data = ""
      cipher.update(ciphertext) + cipher.final
    rescue => e
      nil
    end

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
      if pkg[:requires_node]
        puts ""
        puts "  \e[33m⚠  This package requires Node.js (optional).\e[0m"
        has_node = system("which node > /dev/null 2>&1") || system("where node > nul 2>&1")
        if has_node
          puts "  \e[32m✓  Node.js is installed — you're good to go!\e[0m"
        else
          puts "  Node.js is not installed. Install it to use this package:"
          puts "  \e[36m  Linux/Pi:  sudo apt-get install nodejs npm\e[0m"
          puts "  \e[36m  macOS:     brew install node\e[0m"
          puts "  \e[36m  Windows:   https://nodejs.org\e[0m"
          puts "  (Everything else in Sapphire works without Node.js)"
        end
      end

      if pkg[:versions] && Gem::Version.new(resolved_version) < Gem::Version.new(pkg[:version])
        puts "\n  \e[33m⬆  A newer version is available: v#{pkg[:version]}\e[0m"
        puts "  \e[36m   sph install #{name} #{pkg[:version]}\e[0m"
      end

      add_to_project(name, resolved_version)
      true
    end


    # Install a package from a user's fork packages branch
    def self.install_fork_package(username, pkg_name, version = nil)
      branch   = "packages"
      base_url = "#{GITHUB_RAW}/#{username}/sapphire/#{branch}"

      # Fetch registry.json from their fork's packages branch
      registry_url = "#{base_url}/packages/registry.json"
      registry_raw = fetch_raw(registry_url)
      return nil if registry_raw.nil?  # fork doesn't have packages branch

      registry = JSON.parse(registry_raw) rescue nil
      return nil unless registry

      entry = registry[pkg_name]
      return nil unless entry  # package not in this fork's registry

      pkg_version = version || entry['version'] || '0.0.0'
      pkg_file    = entry['file'] || "packages/#{pkg_name}.sp"
      pkg_desc    = entry['description'] || ""

      # Download the .sp file
      file_url  = "#{GITHUB_RAW}/#{username}/sapphire/#{branch}/#{pkg_file}"
      sp_source = fetch_raw(file_url)

      if sp_source.nil?
        puts "\e[31m✗\e[0m Could not fetch #{pkg_name}.sp from #{username}'s packages."
        return false
      end

      target = File.join(packages_dir, "#{pkg_name}.sp")
      File.write(target, sp_source)
      # Encrypt the package to prevent casual tampering
      encrypt_package(target)
      save_installed_version(pkg_name, pkg_version)
      save_package_meta(pkg_name, {
        source:      "fork",
        author:      username,
        fork:        "#{username}/sapphire",
        branch:      branch,
        version:     pkg_version,
        description: pkg_desc
      })

      puts "\e[32m✓\e[0m Installed \e[1m#{pkg_name}\e[0m v#{pkg_version} from \e[36m#{username}/sapphire\e[0m (packages branch)"
      puts "  #{pkg_desc}" unless pkg_desc.empty?
      puts "\n  Usage in .sp files:"
      puts "  \e[36mimport #{pkg_name}\e[0m"

      add_to_project(pkg_name, pkg_version)
      true
    rescue => e
      puts "\e[31m✗\e[0m Fork install failed: #{e.message}"
      false
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
      encrypt_package(target)
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
