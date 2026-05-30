# formatter.rb — Sapphire source code formatter
# Usage: sapphire fmt <file.sp>
#        sapphire fmt --check <file.sp>   (exits 1 if changes needed)

module Sapphire
  class Formatter
    INDENT = "  "

    def initialize(source)
      @source = source
    end

    def format
      lines   = @source.lines
      output  = []
      depth   = 0
      prev_blank = false

      lines.each_with_index do |raw, i|
        line = raw.chomp

        # Preserve blank lines but collapse multiple into one
        if line.strip.empty?
          output << "" unless prev_blank || output.empty?
          prev_blank = true
          next
        end
        prev_blank = false

        # Decrease indent before closing brace
        depth -= 1 if line.strip.start_with?('}') && depth > 0

        # Format the line
        formatted = format_line(line.strip, depth)
        output << formatted

        # Increase indent after opening brace
        depth += 1 if line.strip.end_with?('{')

        # Decrease after one-liner: `if x { y }` — no change needed
      end

      # Ensure single trailing newline
      output.join("\n").gsub(/\n{3,}/, "\n\n").rstrip + "\n"
    end

    private

    def format_line(line, depth)
      return "" if line.empty?

      # Format operators with spaces
      line = format_operators(line)

      # Format commas
      line = line.gsub(/\s*,\s*/, ', ')

      # Remove trailing whitespace
      line = line.rstrip

      # Apply indentation
      INDENT * depth + line
    end

    def format_operators(line)
      # Skip comments and strings
      return line if line.start_with?('#')

      # Add spaces around operators (but not in strings or already spaced)
      line = line.gsub(/([^\s=!<>])([=!<>]=|[=])([^\s=!>])/) { "#{$1} #{$2} #{$3}" }
      line = line.gsub(/([^\s\+\-\*\/])([\+\-\*\/])([^\s\+\-\*\/=])/) { "#{$1} #{$2} #{$3}" }

      line
    end
  end

  def self.fmt_file(path, check: false)
    unless File.exist?(path)
      $stderr.puts "\e[31m[Error]\e[0m File not found: #{path}"
      exit 1
    end

    source    = File.read(path)
    formatted = Formatter.new(source).format

    if check
      if source == formatted
        puts "\e[32m✓\e[0m #{path} — already formatted"
      else
        puts "\e[33m~\e[0m #{path} — needs formatting  (run: sapphire fmt #{path})"
        exit 1
      end
    else
      if source == formatted
        puts "\e[32m✓\e[0m #{path} — already formatted"
      else
        File.write(path, formatted)
        puts "\e[32m✓\e[0m #{path} — formatted"
      end
    end
  end
end
