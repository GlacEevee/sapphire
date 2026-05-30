#!/usr/bin/env ruby
# Sapphire Language — Main Entry Point
# Usage:
#   sapphire run <file.sp>       Run a Sapphire source file
#   sapphire repl                Start the interactive REPL
#   sapphire check <file.sp>     Parse-check without running
#   sapphire version             Print version info

$LOAD_PATH.unshift(__dir__)

module Sapphire
  _version_file = File.join(__dir__, 'SAPPHIRE_VERSION')
  VERSION = File.exist?(_version_file) ? File.read(_version_file).strip : "0.4.0"
  class SapphireError < StandardError; end
end

require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require_relative 'ast'
require_relative 'types'
require_relative 'environment'
require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'

module Sapphire

  def self.run_source(source, filename = '<stdin>', interpreter: nil)
    interp = interpreter || Interpreter.new
    tokens = Lexer.new(source, filename).tokenize
    ast    = Parser.new(tokens, filename).parse
    interp.run(ast)
  rescue SapphireError => e
    $stderr.puts "\e[31m[Sapphire Error]\e[0m #{e.message}"
    exit 1
  rescue => e
    $stderr.puts "\e[31m[Internal Error]\e[0m #{e.message}"
    $stderr.puts e.backtrace.first(5).join("\n") if $DEBUG
    exit 1
  end

  def self.run_file(path)
    unless File.exist?(path)
      $stderr.puts "\e[31m[Error]\e[0m File not found: #{path}"
      exit 1
    end
    source = File.read(path)
    check_interpreter_update   # non-blocking background check
    check_package_upgrades(source)
    run_source(source, path)
  end

  # ── Background interpreter update nudge ───────────────────────────────────
  # Checks at most once per INTERPRETER_UPDATE_TTL seconds (default 24 h).
  # Runs in a thread so it never delays startup; prints a one-line hint at exit.
  INTERPRETER_UPDATE_TTL = 86_400   # seconds

  def self.check_interpreter_update
    stamp_file = File.expand_path('~/.sapphire/interpreter_update_stamp')
    # Throttle: skip if checked recently
    if File.exist?(stamp_file)
      last = File.read(stamp_file).strip.to_i
      return if (Time.now.to_i - last) < INTERPRETER_UPDATE_TTL
    end

    # Spin up a background thread so startup is never delayed
    Thread.new do
      begin
        require_relative 'spm'
        # Refresh the manifest (uses its own cache layer on top of our stamp)
        manifest = Sapphire::Manager.fetch_manifest(force: false)
        File.write(stamp_file, Time.now.to_i.to_s) rescue nil

        next unless manifest
        remote   = manifest['version']
        current  = VERSION
        next unless remote

        require 'rubygems'
        if Gem::Version.new(remote) > Gem::Version.new(current)
          at_exit do
            puts ""
            puts "\e[33m  ⬆  Sapphire v#{remote} is available  (you have v#{current})\e[0m"
            puts "\e[36m     Run: spm self-update\e[0m"
            puts ""
          end
        end
      rescue
        # silently ignore — network down, spm missing, anything
      end
    end
  rescue
    # Thread creation failed — skip silently
  end

  # Scan the source for `import <pkg>` lines and warn if a newer version exists.
  def self.check_package_upgrades(source)
    require_relative 'sph'
    upgrades = Sapphire::PackageManager.upgradeable_packages
    return if upgrades.empty?

    # Only warn about packages that are actually imported in this file
    imported = source.scan(/^\s*import\s+(\w+)/).flatten +
               source.scan(/^\s*from\s+(\w+)\s+import/).flatten
    relevant = upgrades.select { |u| imported.include?(u[:name]) }
    return if relevant.empty?

    puts ""
    puts "\e[33m╔══════════════════════════════════════════════════╗"
    puts "║  📦 Package upgrades available                   ║"
    relevant.each do |u|
      line = "║  • #{u[:name]}  v#{u[:installed]} → v#{u[:latest]}"
      line = line.ljust(51) + "║"
      puts line
      cmd_line = "║    sph install #{u[:name]} #{u[:latest]}"
      cmd_line = cmd_line.ljust(51) + "║"
      puts cmd_line
    end
    puts "╚══════════════════════════════════════════════════╝\e[0m"
    puts ""
  rescue LoadError
    # sph not available — silently skip
  end

  def self.check_file(path)
    unless File.exist?(path)
      $stderr.puts "\e[31m[Error]\e[0m File not found: #{path}"
      exit 1
    end
    source = File.read(path)
    tokens = Lexer.new(source, path).tokenize
    Parser.new(tokens, path).parse
    puts "\e[32m✓\e[0m #{path} — OK"
  rescue SapphireError => e
    $stderr.puts "\e[31m[Parse Error]\e[0m #{e.message}"
    exit 1
  end

  def self.repl
    require 'readline'
    interp = Interpreter.new
    puts "\e[34m╔══════════════════════════════════╗"
    puts "║   Sapphire v#{VERSION} REPL              ║"
    puts "║   Type 'exit' or Ctrl+D to quit  ║"
    puts "╚══════════════════════════════════╝\e[0m"

    history_file = File.expand_path("~/.sapphire_history")
    if File.exist?(history_file)
      File.readlines(history_file).each { |l| Readline::HISTORY << l.chomp }
    end

    buffer = ""
    prompt_main = "\e[36msp>\e[0m "
    prompt_cont = "\e[36m..\e[0m "

    loop do
      prompt = buffer.empty? ? prompt_main : prompt_cont
      line = Readline.readline(prompt, true)

      if line.nil?  # Ctrl+D
        puts "\nGoodbye!"
        break
      end

      line = line.strip
      next if line.empty?

      if line == 'exit' && buffer.empty?
        puts "Goodbye!"
        break
      end

      # Save to history
      File.open(history_file, 'a') { |f| f.puts line }

      buffer += line + "\n"

      # Heuristic: if line ends with { or the buffer is "open", wait for more
      open_braces  = buffer.count('{') - buffer.count('}')
      open_parens  = buffer.count('(') - buffer.count(')')
      open_brackets= buffer.count('[') - buffer.count(']')

      next if open_braces > 0 || open_parens > 0 || open_brackets > 0

      begin
        tokens = Lexer.new(buffer, '<repl>').tokenize
        ast    = Parser.new(tokens, '<repl>').parse
        result = interp.run(ast)
        unless result.nil?
          puts "\e[33m=> #{interp.send(:sapphire_to_s, result)}\e[0m"
        end
      rescue SapphireError => e
        puts "\e[31m[Error]\e[0m #{e.message}"
      rescue => e
        puts "\e[31m[Internal]\e[0m #{e.message}"
      end

      buffer = ""
    end
  end
end

# ─── CLI dispatch ─────────────────────────────────────────────────────────────

case ARGV[0]
when 'run'
  if ARGV[1]
    Sapphire.run_file(ARGV[1])
  else
    $stderr.puts "Usage: sapphire run <file.sp>"
    exit 1
  end
when 'repl', nil
  Sapphire.repl
when 'check'
  if ARGV[1]
    Sapphire.check_file(ARGV[1])
  else
    $stderr.puts "Usage: sapphire check <file.sp>"
    exit 1
  end
when 'fmt', 'format'
  check_mode = ARGV[1] == '--check'
  file_arg   = check_mode ? ARGV[2] : ARGV[1]
  if file_arg
    require_relative 'formatter'
    Sapphire.fmt_file(file_arg, check: check_mode)
  else
    $stderr.puts "Usage: sapphire fmt <file.sp>"
    $stderr.puts "       sapphire fmt --check <file.sp>"
    exit 1
  end
when 'version', '--version', '-v'
  puts "Sapphire \#{Sapphire::VERSION}"
when 'help', '--help', '-h'
  puts "\e[34m╔══════════════════════════════════════════╗"
  puts "║   Sapphire v#{Sapphire::VERSION} — Programming Language  ║"
  puts "╚══════════════════════════════════════════╝\e[0m"
  puts ""
  puts "Usage:"
  puts "  \e[36msapphire <file.sp>\e[0m              Run a .sp file directly"
  puts "  \e[36msapphire run <file.sp>\e[0m          Run a .sp file"
  puts "  \e[36msapphire repl\e[0m                   Start interactive REPL"
  puts "  \e[36msapphire check <file.sp>\e[0m        Check syntax without running"
  puts "  \e[36msapphire fmt <file.sp>\e[0m          Auto-format a .sp file"
  puts "  \e[36msapphire fmt --check <file.sp>\e[0m  Check formatting without writing"
  puts "  \e[36msapphire version\e[0m                Show version"
  puts ""
  puts "Package Manager:"
  puts "  \e[36msph install <package>\e[0m           Install a package"
  puts "  \e[36msph list\e[0m                        List installed packages"
  puts "  \e[36mspm search <query>\e[0m              Search packages"
  puts "  \e[36msph init\e[0m                        Initialize a new project"
  puts ""
  puts "Examples:"
  puts "  \e[36msapphire hello.sp\e[0m"
  puts "  \e[36msapphire run examples/fizzbuzz.sp\e[0m"
  puts "  \e[36msph install math\e[0m"
else
  # KEY FEATURE: if ARGV[0] looks like a file, run it directly
  # This makes `sapphire myfile.sp` work just like `ruby myfile.rb`
  arg = ARGV[0]
  if arg && (arg.end_with?('.sp') || File.exist?(arg))
    Sapphire.run_file(arg)
  else
    puts "\e[34mSapphire #{Sapphire::VERSION}\e[0m"
    puts ""
    puts "Usage:"
    puts "  \e[36msapphire <file.sp>\e[0m          Run a .sp file"
    puts "  \e[36msapphire repl\e[0m               Start interactive REPL"
    puts "  \e[36msapphire check <file.sp>\e[0m    Check syntax"
    puts "  \e[36msapphire help\e[0m               Show all commands"
    puts "  \e[36msph help\e[0m                    Package manager help"
    puts ""
    puts "Try: \e[36msapphire examples/fizzbuzz.sp\e[0m"
  end
end
