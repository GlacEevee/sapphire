# Sapphire Parser
# Recursive-descent parser that builds an AST from tokens

module Sapphire
  class Parser
    def initialize(tokens, filename = '<stdin>')
      @tokens   = tokens
      @pos      = 0
      @filename = filename
    end

    def parse
      stmts = []
      stmts << parse_statement while !at_end? && current.type != :EOF
      AST::Program.new(stmts)
    end

    # Public so the REPL/template parser can call parse_expr directly
    def parse_expr = parse_assign

    private

    # ─── Token helpers ────────────────────────────────────────────────────────

    def current      = @tokens[@pos]
    def peek(n = 1)  = @tokens[@pos + n]
    def at_end?      = current.type == :EOF
    def advance      = @tokens[@pos].tap { @pos += 1 }

    def expect(type)
      tok = advance
      error("Expected #{type}, got #{tok.type} ('#{tok.value}')", tok) unless tok.type == type
      tok
    end

    def check(*types)  = types.include?(current.type)
    def match(*types)
      advance if types.include?(current.type)
    end

    def skip_semis
      advance while check(:SEMI)
    end

    def error(msg, tok = current)
      raise SapphireError, "#{@filename}:#{tok.line}:#{tok.col} — #{msg}"
    end

    # ─── Statements ───────────────────────────────────────────────────────────

    def parse_statement
      skip_semis
      result = case current.type
               when :LET, :CONST   then parse_let
               when :FN            then parse_fn
               when :CLASS         then parse_class
               when :RETURN        then parse_return
               when :IF            then parse_if
               when :WHILE         then parse_while
               when :FOR           then parse_for
               when :MATCH         then parse_match
               when :BREAK         then AST::Break.new(advance)
               when :CONTINUE      then AST::Continue.new(advance)
               when :PASS          then AST::Pass.new(advance)
               when :RAISE         then parse_raise
               when :TRY           then parse_try
               when :IMPORT, :FROM then parse_import
               when :PRINT         then parse_print(newline: false)
               when :PRINTLN       then parse_print(newline: true)
               else
                 parse_expression_statement
               end
      skip_semis
      result
    end

    def parse_let
      mutable = current.type == :LET
      advance  # consume let/const
      name = expect(:IDENT).value
      type_hint = nil
      if check(:COLON)
        advance
        type_hint = advance.value
      end
      value = nil
      if check(:ASSIGN)
        advance
        value = parse_expr
      end
      AST::LetDecl.new(name, value, mutable, type_hint)
    end

    def parse_fn(is_method: false)
      advance  # consume fn
      name = expect(:IDENT).value
      params = parse_params
      body = parse_block
      AST::FnDecl.new(name, params, body, is_method)
    end

    def parse_params
      expect(:LPAREN)
      params = []
      until check(:RPAREN)
        splat = false
        if check(:STAR)
          advance; splat = true
        end
        pname = expect(:IDENT).value
        type_hint = nil
        if check(:COLON)
          advance; type_hint = advance.value
        end
        default = nil
        if check(:ASSIGN)
          advance; default = parse_expr
        end
        params << AST::Param.new(pname, default, type_hint, splat)
        break unless check(:COMMA)
        advance
      end
      expect(:RPAREN)
      params
    end

    def parse_class
      advance  # consume class
      name = expect(:IDENT).value
      superclass = nil
      if check(:LT)
        advance
        superclass = expect(:IDENT).value
      end
      body = parse_class_body
      AST::ClassDecl.new(name, superclass, body)
    end

    def parse_class_body
      expect(:LBRACE)
      stmts = []
      skip_semis
      until check(:RBRACE)
        stmts << (current.type == :FN ? parse_fn(is_method: true) : parse_statement)
        skip_semis
      end
      expect(:RBRACE)
      AST::Block.new(stmts)
    end

    def parse_return
      advance  # consume return
      value = at_end? || check(:SEMI, :RBRACE) ? nil : parse_expr
      AST::Return.new(value)
    end

    def parse_if
      advance  # consume if
      cond = parse_expr
      then_block = parse_block
      elif_clauses = []
      while check(:ELIF)
        advance
        elif_cond = parse_expr
        elif_body = parse_block
        elif_clauses << [elif_cond, elif_body]
      end
      else_block = nil
      if check(:ELSE)
        advance
        else_block = parse_block
      end
      AST::If.new(cond, then_block, elif_clauses, else_block)
    end

    def parse_while
      advance
      cond = parse_expr
      body = parse_block
      AST::While.new(cond, body)
    end

    def parse_for
      advance  # consume for
      var = expect(:IDENT).value
      expect(:IN)
      iterable = parse_expr
      body = parse_block
      AST::For.new(var, iterable, body)
    end

    def parse_match
      advance  # consume match
      subject = parse_expr
      expect(:LBRACE)
      cases = []
      skip_semis
      until check(:RBRACE)
        # Wildcard: _ => body
        pattern = if check(:UNDERSCORE)
                    advance
                    AST::Wildcard.new(nil)
                  else
                    parse_expr
                  end
        expect(:FAT_ARROW)
        body = check(:LBRACE) ? parse_block : begin
          s = parse_statement; AST::Block.new([s])
        end
        cases << AST::MatchCase.new(pattern, body)
        skip_semis
      end
      expect(:RBRACE)
      AST::Match.new(subject, cases)
    end

    def parse_raise
      advance
      AST::Raise.new(parse_expr)
    end

    def parse_try
      advance  # consume try
      body = parse_block
      catch_var  = nil
      catch_body = nil
      if check(:CATCH)
        advance
        if check(:LPAREN)
          advance
          catch_var = expect(:IDENT).value
          expect(:RPAREN)
        end
        catch_body = parse_block
      end
      finally_body = nil
      if check(:FINALLY)
        advance
        finally_body = parse_block
      end
      AST::TryCatch.new(body, catch_var, catch_body, finally_body)
    end

    def parse_import
      if current.type == :FROM
        advance
        path = expect(:IDENT).value
        expect(:IMPORT)
        names = [expect(:IDENT).value]
        while check(:COMMA)
          advance; names << expect(:IDENT).value
        end
        AST::ImportDecl.new(path, names)
      else
        advance
        path = expect(:IDENT).value
        AST::ImportDecl.new(path, nil)
      end
    end

    def parse_print(newline:)
      advance
      expect(:LPAREN)
      args = []
      until check(:RPAREN)
        args << parse_expr
        break unless check(:COMMA)
        advance
      end
      expect(:RPAREN)
      AST::Print.new(args, newline)
    end

    def parse_block
      expect(:LBRACE)
      stmts = []
      skip_semis
      until check(:RBRACE)
        stmts << parse_statement
        skip_semis
      end
      expect(:RBRACE)
      AST::Block.new(stmts)
    end

    def parse_expression_statement
      expr = parse_expr
      # Compound assignment: x += 1, x -= 1, etc.
      if check(:PLUS_EQ, :MINUS_EQ, :MUL_EQ, :DIV_EQ)
        op = advance.value
        rhs = parse_expr
        return AST::CompoundAssign.new(op, expr, rhs)
      end
      expr
    end

    # ─── Expressions ──────────────────────────────────────────────────────────

    def parse_assign
      left = parse_ternary
      if check(:ASSIGN)
        advance
        right = parse_assign
        return AST::Assign.new(left, right)
      end
      left
    end

    # Ternary: expr ? expr : expr
    def parse_ternary
      left = parse_or
      if check(:QUESTION)
        advance
        then_val = parse_expr
        expect(:COLON)
        else_val = parse_expr
        return AST::Ternary.new(left, then_val, else_val)
      end
      left
    end

    def parse_or
      left = parse_and
      while check(:OR)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_and)
      end
      left
    end

    def parse_and
      left = parse_not
      while check(:AND)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_not)
      end
      left
    end

    def parse_not
      if check(:NOT)
        op = advance.value
        return AST::UnaryOp.new(op, parse_not)
      end
      parse_equality
    end

    def parse_equality
      left = parse_comparison
      while check(:EQ, :NEQ)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_comparison)
      end
      left
    end

    def parse_comparison
      left = parse_range
      while check(:LT, :GT, :LTE, :GTE)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_range)
      end
      left
    end

    def parse_range
      left = parse_add
      if check(:RANGE)
        advance
        right = parse_add
        return AST::RangeLit.new(left, right, false)
      end
      left
    end

    def parse_add
      left = parse_mul
      while check(:PLUS, :MINUS)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_mul)
      end
      left
    end

    def parse_mul
      left = parse_pow
      while check(:STAR, :SLASH, :MOD)
        op = advance.value
        left = AST::BinOp.new(op, left, parse_pow)
      end
      left
    end

    def parse_pow
      left = parse_unary
      if check(:POW)
        advance
        right = parse_pow  # right-associative
        return AST::BinOp.new('**', left, right)
      end
      left
    end

    def parse_unary
      if check(:MINUS)
        op = advance.value
        return AST::UnaryOp.new(op, parse_unary)
      end
      if check(:BANG)
        op = advance.value
        return AST::UnaryOp.new('!', parse_unary)
      end
      if check(:TYPEOF)
        advance
        return AST::TypeOf.new(parse_unary)
      end
      parse_call
    end

    def parse_call
      expr = parse_primary
      loop do
        if check(:LPAREN)
          args, kwargs = parse_arguments
          expr = AST::Call.new(expr, args, kwargs)
        elsif check(:DOT)
          advance
          name = expect(:IDENT).value
          expr = AST::GetAttr.new(expr, name)
        elsif check(:LBRACKET)
          advance
          idx = parse_expr
          expect(:RBRACKET)
          expr = AST::Index.new(expr, idx)
        elsif check(:SCOPE)
          advance
          name = expect(:IDENT).value
          expr = AST::ScopeAccess.new(expr, name)
        else
          break
        end
      end
      expr
    end

    def parse_arguments
      expect(:LPAREN)
      args   = []
      kwargs = {}
      until check(:RPAREN)
        if current.type == :IDENT && peek.type == :COLON
          k = advance.value; advance
          kwargs[k] = parse_expr
        else
          args << parse_expr
        end
        break unless check(:COMMA)
        advance
      end
      expect(:RPAREN)
      [args, kwargs]
    end

    def parse_primary
      tok = current
      case tok.type
      when :INTEGER, :FLOAT
        advance; AST::NumberLit.new(tok.value)
      when :STRING
        advance; AST::StringLit.new(tok.value)
      when :TEMPLATE_STRING
        advance; parse_template(tok)
      when :TRUE
        advance; AST::BoolLit.new(true)
      when :FALSE
        advance; AST::BoolLit.new(false)
      when :NIL
        advance; AST::NilLit.new(nil)
      when :IDENT
        advance; AST::Identifier.new(tok.value, tok.line)
      when :SELF
        advance; AST::Identifier.new('self', tok.line)
      when :NEW
        parse_new
      when :LPAREN
        advance; expr = parse_expr; expect(:RPAREN); expr
      when :LBRACKET
        parse_array
      when :LBRACE
        parse_hash_or_lambda
      when :FN
        parse_lambda
      when :UNDERSCORE
        advance; AST::Wildcard.new(nil)
      else
        error("Unexpected token '#{tok.value}' (#{tok.type})", tok)
      end
    end

    def parse_template(tok)
      parts  = []
      source = tok.value
      i = 0
      buf = +""
      while i < source.length
        if source[i] == '#' && source[i+1] == '{'
          parts << AST::StringLit.new(buf) unless buf.empty?
          buf = +""
          i += 2
          expr_src = +""
          depth = 1
          while i < source.length && depth > 0
            depth += 1 if source[i] == '{'
            depth -= 1 if source[i] == '}'
            expr_src << source[i] unless depth == 0
            i += 1
          end
          inner_tokens = Lexer.new(expr_src, '<template>').tokenize
          inner_expr   = Parser.new(inner_tokens, '<template>').parse_expr
          parts << inner_expr
        else
          buf << source[i]; i += 1
        end
      end
      parts << AST::StringLit.new(buf) unless buf.empty?
      AST::TemplateLit.new(parts)
    end

    def parse_new
      advance  # consume new
      cls = expect(:IDENT).value
      args, kwargs = parse_arguments
      AST::New.new(cls, args, kwargs)
    end

    def parse_array
      advance  # [
      elements = []
      skip_semis
      until check(:RBRACKET)
        elements << parse_expr
        break unless check(:COMMA)
        advance
        skip_semis
      end
      expect(:RBRACKET)
      AST::ArrayLit.new(elements)
    end

    def parse_hash_or_lambda
      # Detect lambda: { |x| ... } or {} (empty lambda shorthand)
      save = @pos
      if current.type == :LBRACE
        @pos += 1
        skip_semis
        if check(:PIPE) || (check(:RBRACE))
          @pos = save
          return parse_lambda_block
        end
        @pos = save
      end

      advance  # {
      pairs = []
      skip_semis
      until check(:RBRACE)
        # Allow bare identifier as hash key: { name: "x" }
        key = if current.type == :IDENT && peek.type == :COLON
                tok = advance
                AST::StringLit.new(tok.value)
              else
                parse_expr
              end
        expect(:COLON)
        val = parse_expr
        pairs << [key, val]
        break unless check(:COMMA)
        advance
        skip_semis
      end
      expect(:RBRACE)
      AST::HashLit.new(pairs)
    end

    def parse_lambda
      advance  # fn
      params = check(:LPAREN) ? parse_params : []
      body   = parse_block
      AST::Lambda.new(params, body)
    end

    def parse_lambda_block
      advance  # {
      params = []
      if check(:PIPE)
        advance
        until check(:PIPE)
          pname = expect(:IDENT).value
          params << AST::Param.new(pname, nil, nil, false)
          break unless check(:COMMA)
          advance
        end
        expect(:PIPE)
      end
      stmts = []
      skip_semis
      until check(:RBRACE)
        stmts << parse_statement
        skip_semis
      end
      expect(:RBRACE)
      AST::Lambda.new(params, AST::Block.new(stmts))
    end
  end
end
