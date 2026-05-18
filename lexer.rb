# Sapphire Language Lexer
# Converts raw source code into a flat stream of tokens

module Sapphire
  Token = Struct.new(:type, :value, :line, :col)

  KEYWORDS = %w[
    let const fn return if elif else while for in
    class new self import from true false nil
    and or not match case break continue pass
    try catch finally raise typeof print println
  ].freeze

  OPERATORS = {
    '==' => :EQ,      '!=' => :NEQ,    '<=' => :LTE,    '>=' => :GTE,
    '->' => :ARROW,   '=>' => :FAT_ARROW, '..' => :RANGE,
    '&&' => :AND,     '||' => :OR,     '**' => :POW,
    '+=' => :PLUS_EQ, '-=' => :MINUS_EQ, '*=' => :MUL_EQ, '/=' => :DIV_EQ,
    '::' => :SCOPE,
  }.freeze

  SINGLE_OPS = {
    '+' => :PLUS,  '-' => :MINUS, '*' => :STAR,  '/' => :SLASH,
    '%' => :MOD,   '<' => :LT,    '>' => :GT,    '=' => :ASSIGN,
    '!' => :BANG,  '.' => :DOT,   ',' => :COMMA, ':' => :COLON,
    ';' => :SEMI,  '(' => :LPAREN,')'=> :RPAREN, '[' => :LBRACKET,
    ']' => :RBRACKET, '{' => :LBRACE, '}' => :RBRACE, '&' => :AMPERSAND,
    '|' => :PIPE,  '^' => :CARET, '~' => :TILDE, '@' => :AT,
    '?' => :QUESTION, '_' => :UNDERSCORE,
  }.freeze

  class Lexer
    def initialize(source, filename = '<stdin>')
      @source   = source
      @filename = filename
      @pos      = 0
      @line     = 1
      @col      = 1
      @tokens   = []
    end

    def tokenize
      until at_end?
        skip_whitespace_and_comments
        break if at_end?
        read_token
      end
      @tokens << Token.new(:EOF, nil, @line, @col)
      @tokens
    end

    private

    def at_end? = @pos >= @source.length
    def current  = @source[@pos]
    def peek(n=1)= @source[@pos + n]

    def advance
      ch = @source[@pos]
      @pos += 1
      if ch == "\n"
        @line += 1
        @col = 1
      else
        @col += 1
      end
      ch
    end

    def skip_whitespace_and_comments
      loop do
        if current =~ /[ \t\r\n]/
          advance

        # Multi-line comment: #* ... *#  (must check BEFORE single-line)
        elsif current == '#' && peek == '*'
          advance; advance  # consume #*
          until at_end?
            if current == '*' && peek == '#'
              advance; advance; break
            end
            advance
          end
          raise SapphireError, "Unterminated block comment" if at_end?

        # Single-line comment: # ...
        elsif current == '#'
          advance while !at_end? && current != "\n"

        # Single-line comment: // ...
        elsif current == '/' && peek == '/'
          advance while !at_end? && current != "\n"

        else
          break
        end
      end
    end

    def read_token
      line, col = @line, @col

      # String literals
      if current == '"' || current == "'"
        return @tokens << read_string(line, col)
      end

      # Interpolated / template strings
      if current == '`'
        return @tokens << read_template_string(line, col)
      end

      # Numbers (integer or float, optional leading minus only when unambiguous)
      if current =~ /[0-9]/ || (current == '-' && peek =~ /[0-9]/ && !@tokens.last&.value&.match?(/[0-9a-z_)\]]/i))
        return @tokens << read_number(line, col)
      end

      # Identifiers / Keywords
      if current =~ /[a-zA-Z_]/
        return @tokens << read_identifier(line, col)
      end

      # Two-char operators (check before single-char)
      two = @source[@pos, 2]
      if OPERATORS.key?(two)
        advance; advance
        return @tokens << Token.new(OPERATORS[two], two, line, col)
      end

      # Single-char operators
      if SINGLE_OPS.key?(current)
        ch = advance
        return @tokens << Token.new(SINGLE_OPS[ch], ch, line, col)
      end

      raise SapphireError, "Unexpected character '#{current}' at #{@filename}:#{line}:#{col}"
    end

    def read_string(line, col)
      quote = advance  # consume opening quote
      buf = +""
      until at_end? || current == quote
        if current == '\\'
          advance
          buf << case current
                 when 'n'  then "\n"
                 when 't'  then "\t"
                 when 'r'  then "\r"
                 when '\\' then "\\"
                 when '"'  then '"'
                 when "'"  then "'"
                 when '0'  then "\0"
                 else "\\#{current}"
                 end
          advance
        else
          buf << advance
        end
      end
      raise SapphireError, "Unterminated string at #{@filename}:#{line}:#{col}" if at_end?
      advance  # closing quote
      Token.new(:STRING, buf, line, col)
    end

    def read_template_string(line, col)
      advance  # consume `
      buf = +""
      until at_end? || current == '`'
        if current == '\\'
          advance
          buf << case current
                 when 'n'  then "\n"
                 when 't'  then "\t"
                 when 'r'  then "\r"
                 when '\\' then "\\"
                 when '`'  then '`'
                 when '#'  then '#'
                 else "\\#{current}"
                 end
          advance
        else
          buf << advance
        end
      end
      raise SapphireError, "Unterminated template string at #{@filename}:#{line}:#{col}" if at_end?
      advance  # closing `
      Token.new(:TEMPLATE_STRING, buf, line, col)
    end

    def read_number(line, col)
      buf = +""
      buf << advance if current == '-'

      # Hex: 0x...
      if current == '0' && peek =~ /[xX]/
        buf << advance << advance
        buf << advance while !at_end? && current =~ /[0-9a-fA-F_]/
        buf.delete!('_')
        return Token.new(:INTEGER, buf.to_i(16), line, col)
      end

      # Binary: 0b...
      if current == '0' && peek =~ /[bB]/
        buf << advance << advance
        buf << advance while !at_end? && current =~ /[01_]/
        buf.delete!('_')
        return Token.new(:INTEGER, buf.to_i(2), line, col)
      end

      is_float = false
      while !at_end?
        if current =~ /[0-9]/
          buf << advance
        elsif current == '_' && peek =~ /[0-9]/
          advance  # skip separator
        elsif current == '.' && peek =~ /[0-9]/ && !is_float
          is_float = true
          buf << advance
        else
          break
        end
      end

      # Scientific notation: 1.5e10
      if !at_end? && current =~ /[eE]/
        is_float = true
        buf << advance
        buf << advance if !at_end? && current =~ /[+-]/
        buf << advance while !at_end? && current =~ /[0-9]/
      end

      is_float ? Token.new(:FLOAT, buf.to_f, line, col)
               : Token.new(:INTEGER, buf.to_i, line, col)
    end

    def read_identifier(line, col)
      buf = +""
      buf << advance while !at_end? && current =~ /[a-zA-Z0-9_?!]/

      type = if KEYWORDS.include?(buf)
               buf.upcase.to_sym
             else
               :IDENT
             end
      type = :TRUE  if buf == 'true'
      type = :FALSE if buf == 'false'
      type = :NIL   if buf == 'nil'
      Token.new(type, buf, line, col)
    end
  end
end
