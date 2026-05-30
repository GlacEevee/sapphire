# Sapphire Interpreter
# Tree-walking interpreter that evaluates the AST

module Sapphire
  class Interpreter
    attr_reader :globals

    def initialize
      @globals    = Environment.new
      @modules    = {}
      @call_stack = []   # for stack traces
      setup_globals
    end

    def run(program)
      eval_node(program, @globals)
    rescue ReturnSignal => e
      e.value
    rescue Interrupt
      # Clean Ctrl+C exit — stop any running gateway and exit silently
      @_gateway_running = false if defined?(@_gateway_running)
      puts ""   # newline after the ^C that the terminal prints
      exit 0
    end

    private

    # ─── Core dispatcher ──────────────────────────────────────────────────────

    def eval_node(node, env)
      case node
      when AST::Program        then eval_program(node, env)
      when AST::Block          then eval_block(node, env)
      when AST::NumberLit      then node.value
      when AST::StringLit      then node.value
      when AST::TemplateLit    then eval_template(node, env)
      when AST::BoolLit        then node.value
      when AST::NilLit         then nil
      when AST::Wildcard       then :wildcard
      when AST::Identifier     then node.name == '_' ? :wildcard : env.get(node.name)
      when AST::ArrayLit       then eval_array(node, env)
      when AST::HashLit        then eval_hash(node, env)
      when AST::RangeLit       then eval_range(node, env)
      when AST::GetAttr        then eval_get_attr(node, env)
      when AST::Index          then eval_index(node, env)
      when AST::ScopeAccess    then eval_scope_access(node, env)
      when AST::LetDecl        then eval_let(node, env)
      when AST::FnDecl         then eval_fn_decl(node, env)
      when AST::ClassDecl      then eval_class(node, env)
      when AST::ImportDecl     then eval_import(node, env)
      when AST::Return         then raise ReturnSignal.new(node.value ? eval_node(node.value, env) : nil)
      when AST::If             then eval_if(node, env)
      when AST::While          then eval_while(node, env)
      when AST::For            then eval_for(node, env)
      when AST::Match          then eval_match(node, env)
      when AST::Break          then raise BreakSignal
      when AST::Continue       then raise ContinueSignal
      when AST::Pass           then nil
      when AST::Raise          then raise RaiseSignal.new(eval_node(node.value, env))
      when AST::TryCatch       then eval_try(node, env)
      when AST::Print          then eval_print(node, env)
      when AST::BinOp          then eval_binop(node, env)
      when AST::UnaryOp        then eval_unary(node, env)
      when AST::Assign         then eval_assign(node, env)
      when AST::CompoundAssign then eval_compound_assign(node, env)
      when AST::Call           then eval_call(node, env)
      when AST::New            then eval_new(node, env)
      when AST::Lambda         then eval_lambda(node, env)
      when AST::TypeOf         then eval_typeof(node, env)
      when AST::Ternary        then eval_ternary(node, env)
      else
        raise SapphireError, "Unknown AST node: #{node.class}"
      end
    end

    def eval_program(node, env)
      result = nil
      node.stmts.each { |s| result = eval_node(s, env) }
      result
    end

    def eval_block(node, env)
      result = nil
      node.stmts.each { |s| result = eval_node(s, env) }
      result
    end

    # ─── Literals ─────────────────────────────────────────────────────────────

    def eval_template(node, env)
      node.parts.map do |part|
        part.is_a?(AST::StringLit) ? part.value : sapphire_to_s(eval_node(part, env))
      end.join
    end

    def eval_array(node, env)
      SapphireArray.new(node.elements.map { |e| eval_node(e, env) })
    end

    def eval_hash(node, env)
      m = {}
      node.pairs.each do |k, v|
        key = eval_node(k, env)
        m[sapphire_to_s(key)] = eval_node(v, env)
      end
      SapphireHash.new(m)
    end

    def eval_range(node, env)
      f = eval_node(node.from, env)
      t = eval_node(node.to,   env)
      raise SapphireError, "Range bounds must be integers" unless f.is_a?(Integer) && t.is_a?(Integer)
      SapphireArray.new((f..t).to_a)
    end

    def eval_ternary(node, env)
      truthy?(eval_node(node.cond, env)) ? eval_node(node.then_val, env) : eval_node(node.else_val, env)
    end

    # ─── Variables ────────────────────────────────────────────────────────────

    def eval_let(node, env)
      value = node.value ? eval_node(node.value, env) : nil
      env.define(node.name, value, const: !node.mutable)
      value
    end

    def eval_assign(node, env)
      value  = eval_node(node.value, env)
      target = node.target
      case target
      when AST::Identifier
        env.set(target.name, value)
      when AST::GetAttr
        obj = eval_node(target.object, env)
        obj_set(obj, target.name, value)
      when AST::Index
        obj = eval_node(target.object, env)
        idx = eval_node(target.index, env)
        if obj.is_a?(SapphireArray)
          obj[idx] = value
        elsif obj.is_a?(SapphireHash)
          obj[sapphire_to_s(idx)] = value
        else
          raise SapphireError, "Cannot index-assign on #{sapphire_type(obj)}"
        end
      else
        raise SapphireError, "Invalid assignment target"
      end
      value
    end

    def eval_compound_assign(node, env)
      op          = node.op[0]   # '+', '-', '*', '/'
      current_val = eval_node(node.target, env)
      new_val     = eval_node(node.value, env)
      result      = apply_binop(op, current_val, new_val)
      # Write back
      case node.target
      when AST::Identifier
        env.set(node.target.name, result)
      when AST::GetAttr
        obj = eval_node(node.target.object, env)
        obj_set(obj, node.target.name, result)
      when AST::Index
        obj = eval_node(node.target.object, env)
        idx = eval_node(node.target.index, env)
        obj.is_a?(SapphireArray) ? (obj[idx] = result) : (obj[sapphire_to_s(idx)] = result)
      end
      result
    end

    # ─── Attribute Access ─────────────────────────────────────────────────────

    def eval_get_attr(node, env)
      obj  = eval_node(node.object, env)
      name = node.name
      obj_get(obj, name)
    end

    def obj_get(obj, name)
      case obj
      when SapphireInstance      then obj.get(name)
      when SapphireArray         then obj.get(name)
      when SapphireHash          then obj.get(name)
      when SapphireClass         then obj.find_method(name) || raise(SapphireError, "No class method '#{name}' on #{obj.name}")
      when String                then string_method(obj, name)
      when Integer, Float        then number_method(obj, name)
      when TrueClass, FalseClass then bool_method(obj, name)
      else raise SapphireError, "Cannot get property '#{name}' on #{sapphire_type(obj)}"
      end
    end

    def obj_set(obj, name, value)
      case obj
      when SapphireInstance then obj.set(name, value)
      when SapphireHash     then obj[name] = value
      else raise SapphireError, "Cannot set property '#{name}' on #{sapphire_type(obj)}"
      end
    end

    def eval_index(node, env)
      obj = eval_node(node.object, env)
      idx = eval_node(node.index, env)
      case obj
      when SapphireArray then obj[idx]
      when SapphireHash  then obj[sapphire_to_s(idx)]
      when String        then obj[idx]
      else raise SapphireError, "Cannot index #{sapphire_type(obj)}"
      end
    end

    def eval_scope_access(node, env)
      ns = eval_node(node.namespace, env)
      ns.respond_to?(:find_method) ? ns.find_method(node.name) : obj_get(ns, node.name)
    end

    # ─── Built-in type methods ────────────────────────────────────────────────

    def string_method(str, name)
      case name
      when 'length'       then str.length
      when 'upcase'       then str.upcase
      when 'downcase'     then str.downcase
      when 'capitalize'   then str.capitalize
      when 'reverse'      then str.reverse
      when 'trim'         then str.strip
      when 'trim_start'   then str.lstrip
      when 'trim_end'     then str.rstrip
      when 'split'        then NativeFunction.new('split')       { |sep = ' '| SapphireArray.new(str.split(sep)) }
      when 'includes?'    then NativeFunction.new('includes?')   { |s| str.include?(s) }
      when 'starts_with?' then NativeFunction.new('starts_with?'){ |s| str.start_with?(s) }
      when 'ends_with?'   then NativeFunction.new('ends_with?')  { |s| str.end_with?(s) }
      when 'replace'      then NativeFunction.new('replace')     { |a, b| str.gsub(a, b) }
      when 'replace_first'then NativeFunction.new('replace_first'){ |a, b| str.sub(a, b) }
      when 'to_number'    then str.include?('.') ? str.to_f : str.to_i
      when 'to_int'       then str.to_i
      when 'to_float'     then str.to_f
      when 'chars'        then SapphireArray.new(str.chars)
      when 'bytes'        then SapphireArray.new(str.bytes)
      when 'to_string'    then str
      when 'repeat'       then NativeFunction.new('repeat')      { |n| str * n.to_i }
      when 'index_of'     then NativeFunction.new('index_of')    { |s| str.index(s) || -1 }
      when 'slice'        then NativeFunction.new('slice')       { |i, len| str[i, len] || "" }
      when 'empty?'       then str.empty?
      when 'lines'        then SapphireArray.new(str.lines.map(&:chomp))
      when 'pad_start'    then NativeFunction.new('pad_start')   { |len, ch = ' '| str.rjust(len, ch) }
      when 'pad_end'      then NativeFunction.new('pad_end')     { |len, ch = ' '| str.ljust(len, ch) }
      when 'count'        then NativeFunction.new('count')       { |sub| str.scan(Regexp.escape(sub)).length }
      when 'match?'       then NativeFunction.new('match?')      { |pat| !str.match(Regexp.new(pat)).nil? }
      when 'scan'         then NativeFunction.new('scan')        { |pat| SapphireArray.new(str.scan(Regexp.new(pat)).flatten) }
      when 'format'       then NativeFunction.new('format')      { |*args| str.gsub(/%s|%d|%f|%\d*\.?\d*[sdf]/) { |m| args.shift.to_s } }
      when 'center'       then NativeFunction.new('center')      { |len, ch = ' '| str.center(len, ch) }
      when 'delete'       then NativeFunction.new('delete')      { |sub| str.gsub(Regexp.escape(sub), '') }
      when 'squeeze'      then str.squeeze
      when 'wrap'         then NativeFunction.new('wrap')        { |width = 80|
        words = str.split(' ')
        lines, cur = [], ''
        words.each do |w|
          if cur.empty? then cur = w
          elsif (cur + ' ' + w).length <= width then cur += ' ' + w
          else lines << cur; cur = w end
        end
        lines << cur unless cur.empty?
        lines.join("\n")
      }
      else raise SapphireError, "String has no method '#{name}'"
      end
    end

    def number_method(num, name)
      case name
      when 'to_string' then num.to_s
      when 'abs'       then num.abs
      when 'ceil'      then num.ceil
      when 'floor'     then num.floor
      when 'round'     then NativeFunction.new('round') { |n = 0| num.round(n) }
      when 'to_int'    then num.to_i
      when 'to_float'  then num.to_f
      when 'to_binary' then num.to_i.to_s(2)
      when 'to_hex'    then num.to_i.to_s(16)
      when 'even?'     then num.to_i.even?
      when 'odd?'      then num.to_i.odd?
      when 'clamp'     then NativeFunction.new('clamp') { |lo, hi| num.clamp(lo, hi) }
      when 'times'     then HigherOrderMarker.new('times', num)
      else raise SapphireError, "Number has no method '#{name}'"
      end
    end

    def bool_method(bool, name)
      case name
      when 'to_string' then bool.to_s
      else raise SapphireError, "Bool has no method '#{name}'"
      end
    end

    # ─── Functions ────────────────────────────────────────────────────────────

    def eval_fn_decl(node, env)
      fn = SapphireFunction.new(node.name, node.params, node.body, env)
      env.define(node.name, fn)
      fn
    end

    def eval_lambda(node, env)
      SapphireLambda.new(node.params, node.body, env)
    end

    def eval_call(node, env)
      callee = eval_node(node.callee, env)
      args   = node.args.map { |a| eval_node(a, env) }
      kwargs = node.kwargs.transform_values { |v| eval_node(v, env) }

      # Handle higher-order methods (map, filter, each, etc.)
      if callee.is_a?(HigherOrderMarker)
        return eval_higher_order(callee, args, env)
      end

      call_fn(callee, args, kwargs)
    end

    def eval_higher_order(marker, args, env)
      fn  = args.first
      rec = marker.receiver

      case marker.method_name
      when 'map'
        SapphireArray.new(rec.elements.map { |e| call_fn(fn, [e]) })
      when 'filter'
        SapphireArray.new(rec.elements.select { |e| truthy?(call_fn(fn, [e])) })
      when 'each'
        rec.elements.each_with_index { |e, i| call_fn(fn, [e, i]) }
        rec
      when 'reduce'
        init = args[1]
        rec.elements.reduce(init) { |acc, e| call_fn(fn, [acc, e]) }
      when 'find'
        rec.elements.find { |e| truthy?(call_fn(fn, [e])) }
      when 'any?'
        rec.elements.any? { |e| truthy?(call_fn(fn, [e])) }
      when 'all?'
        rec.elements.all? { |e| truthy?(call_fn(fn, [e])) }
      when 'none?'
        rec.elements.none? { |e| truthy?(call_fn(fn, [e])) }
      when 'sort_by'
        SapphireArray.new(rec.elements.sort_by { |e| call_fn(fn, [e]) })
      when 'flat_map'
        result = rec.elements.flat_map do |e|
          r = call_fn(fn, [e])
          r.is_a?(SapphireArray) ? r.elements : [r]
        end
        SapphireArray.new(result)
      when 'hash_each'
        rec.map.each { |k, v| call_fn(fn, [k, v]) }
        rec
      when 'hash_map'
        result = {}
        rec.map.each { |k, v| result[k] = call_fn(fn, [k, v]) }
        SapphireHash.new(result)
      when 'times'
        n = rec.to_i
        n.times { |i| call_fn(fn, [i]) }
        nil
      else
        raise SapphireError, "Unknown higher-order method: #{marker.method_name}"
      end
    end

    def call_fn(callee, args, kwargs = {})
      case callee
      when NativeFunction
        callee.call(*args)
      when BoundMethod
        call_sapphire_fn(callee, args, kwargs, receiver: callee.receiver)
      when SapphireFunction, SapphireLambda
        call_sapphire_fn(callee, args, kwargs)
      else
        raise SapphireError, "#{sapphire_to_s(callee)} is not callable"
      end
    end

    def call_sapphire_fn(callee, args, kwargs, receiver: nil)
      @call_stack.push(callee.name)
      fn_env = callee.closure.child
      fn_env.define('self', receiver) if receiver
      bind_params(callee.params, args, kwargs, fn_env)
      result = eval_block(callee.body, fn_env)
      @call_stack.pop
      result
    rescue ReturnSignal => e
      @call_stack.pop
      e.value
    end

    def bind_params(params, args, kwargs, env)
      args = args.dup
      params.each do |param|
        if param.splat
          env.define(param.name, SapphireArray.new(args.dup))
          args = []
        elsif kwargs.key?(param.name)
          env.define(param.name, kwargs[param.name])
        elsif !args.empty?
          env.define(param.name, args.shift)
        elsif param.default
          env.define(param.name, eval_node(param.default, env))
        else
          env.define(param.name, nil)
        end
      end
    end

    # ─── Classes ──────────────────────────────────────────────────────────────

    def eval_class(node, env)
      superclass = node.superclass ? env.get(node.superclass) : nil
      if superclass && !superclass.is_a?(SapphireClass)
        raise SapphireError, "'#{node.superclass}' is not a class"
      end
      methods = {}
      node.body.stmts.each do |stmt|
        next unless stmt.is_a?(AST::FnDecl)
        fn = SapphireFunction.new(stmt.name, stmt.params, stmt.body, env)
        methods[stmt.name] = fn
      end
      klass = SapphireClass.new(node.name, methods, superclass)
      env.define(node.name, klass)
      klass
    end

    def eval_new(node, env)
      klass = env.get(node.class_name)
      raise SapphireError, "'#{node.class_name}' is not a class" unless klass.is_a?(SapphireClass)
      instance = SapphireInstance.new(klass)
      if (init_fn = klass.find_method('init'))
        args   = node.args.map   { |a| eval_node(a, env) }
        kwargs = (node.kwargs || {}).transform_values { |v| eval_node(v, env) }
        call_fn(BoundMethod.new(instance, init_fn), args, kwargs)
      end
      instance
    end

    # ─── Control Flow ─────────────────────────────────────────────────────────

    def eval_if(node, env)
      if truthy?(eval_node(node.cond, env))
        eval_block(node.then_block, env.child)
      else
        node.elif_clauses.each do |cond, body|
          if truthy?(eval_node(cond, env))
            return eval_block(body, env.child)
          end
        end
        node.else_block ? eval_block(node.else_block, env.child) : nil
      end
    end

    def eval_while(node, env)
      result = nil
      loop do
        break unless truthy?(eval_node(node.cond, env))
        begin
          result = eval_block(node.body, env.child)
        rescue BreakSignal
          break
        rescue ContinueSignal
          next
        end
      end
      result
    end

    def eval_for(node, env)
      iterable = eval_node(node.iterable, env)
      items = case iterable
              when SapphireArray then iterable.elements
              when String        then iterable.chars
              when SapphireHash  then iterable.map.map { |k, v| SapphireArray.new([k, v]) }
              else raise SapphireError, "#{sapphire_type(iterable)} is not iterable"
              end
      result = nil
      items.each_with_index do |item, _i|
        loop_env = env.child
        loop_env.define(node.var, item)
        begin
          result = eval_block(node.body, loop_env)
        rescue BreakSignal
          break
        rescue ContinueSignal
          next
        end
      end
      result
    end

    def eval_match(node, env)
      subject = eval_node(node.subject, env)
      node.cases.each do |mc|
        pattern = eval_node(mc.pattern, env)
        if pattern_matches?(pattern, subject)
          match_env = env.child
          # Bind subject to _ implicitly if wildcard
          return eval_block(mc.body, match_env)
        end
      end
      nil
    end

    def pattern_matches?(pattern, subject)
      return true  if pattern == :wildcard
      return false if pattern.nil? && !subject.nil?
      case pattern
      when SapphireArray
        subject.is_a?(SapphireArray) &&
          pattern.elements.length == subject.elements.length &&
          pattern.elements.zip(subject.elements).all? { |p, s| pattern_matches?(p, s) }
      else
        pattern == subject
      end
    end

    def eval_try(node, env)
      eval_block(node.body, env.child)
    rescue RaiseSignal => e
      if node.catch_body
        catch_env = env.child
        catch_env.define(node.catch_var, e.value) if node.catch_var
        eval_block(node.catch_body, catch_env)
      end
    rescue SapphireError => e
      if node.catch_body
        catch_env = env.child
        catch_env.define(node.catch_var, e.message) if node.catch_var
        eval_block(node.catch_body, catch_env)
      end
    ensure
      eval_block(node.finally_body, env.child) if node.finally_body
    end

    # ─── Operators ────────────────────────────────────────────────────────────

    def eval_binop(node, env)
      # Short-circuit
      if node.op == 'and' || node.op == '&&'
        left = eval_node(node.left, env)
        return truthy?(left) ? eval_node(node.right, env) : left
      end
      if node.op == 'or' || node.op == '||'
        left = eval_node(node.left, env)
        return truthy?(left) ? left : eval_node(node.right, env)
      end

      left  = eval_node(node.left, env)
      right = eval_node(node.right, env)
      apply_binop(node.op, left, right)
    end

    def apply_binop(op, left, right)
      case op
      when '+'
        if left.is_a?(String) || right.is_a?(String)
          sapphire_to_s(left) + sapphire_to_s(right)
        elsif left.is_a?(SapphireArray) && right.is_a?(SapphireArray)
          SapphireArray.new(left.elements + right.elements)
        else
          num(left) + num(right)
        end
      when '-'  then num(left) - num(right)
      when '*'
        if left.is_a?(String) && right.is_a?(Integer)
          left * right
        elsif left.is_a?(SapphireArray) && right.is_a?(Integer)
          SapphireArray.new(left.elements * right)
        else
          num(left) * num(right)
        end
      when '/'
        r = num(right)
        raise SapphireError, "Division by zero" if r == 0
        result = num(left) / r.to_f
        result == result.to_i ? result.to_i : result
      when '%'  then num(left) % num(right)
      when '**' then num(left) ** num(right)
      when '==' then sapphire_eq(left, right)
      when '!=' then !sapphire_eq(left, right)
      when '<'  then compare(left, right) < 0
      when '>'  then compare(left, right) > 0
      when '<=' then compare(left, right) <= 0
      when '>=' then compare(left, right) >= 0
      else raise SapphireError, "Unknown operator '#{op}'"
      end
    end

    def compare(left, right)
      if left.is_a?(String) && right.is_a?(String)
        left <=> right
      else
        num(left) <=> num(right)
      end
    end

    def eval_unary(node, env)
      val = eval_node(node.operand, env)
      case node.op
      when '-'   then -num(val)
      when '!'   then !truthy?(val)
      when 'not' then !truthy?(val)
      else raise SapphireError, "Unknown unary op '#{node.op}'"
      end
    end

    def eval_typeof(node, env)
      val = eval_node(node.expr, env)
      sapphire_type(val)
    end

    # ─── Print ────────────────────────────────────────────────────────────────

    def eval_print(node, env)
      parts = node.args.map { |a| sapphire_to_s(eval_node(a, env)) }
      if node.newline
        $stdout.puts(parts.join(' '))
      else
        $stdout.print(parts.join(' '))
      end
      nil
    end

    # ─── Imports ──────────────────────────────────────────────────────────────


    # Decrypt an encrypted .spe package file
    def decrypt_package(enc_path)
      require 'openssl'
      key_file = File.join(Dir.home, '.sapphire', 'pkg.key')
      return nil unless File.exist?(key_file)
      key      = [File.read(key_file).strip].pack('H*')
      payload  = File.binread(enc_path)
      iv         = payload[0, 12]
      tag        = payload[12, 16]
      ciphertext = payload[28..]
      cipher     = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key       = key
      cipher.iv        = iv
      cipher.auth_tag  = tag
      cipher.auth_data = ""
      cipher.update(ciphertext) + cipher.final
    rescue => e
      nil
    end

    def eval_import(node, env)
      mod = load_module(node.path, env)
      if node.names
        node.names.each { |n| env.define(n, mod[n]) if mod[n] }
      else
        mod.each { |k, v| env.define(k, v) }
      end
    end

    # Packages that live in stdlib/ as source but require `sph install` before use.
    # The interpreter will NOT load them directly from stdlib/ — only from packages_dir.
    INSTALL_REQUIRED = %w[discordsph dotenv].freeze

    def load_module(name, env)
      return @modules[name] if @modules.key?(name)

      packages_dir = File.expand_path("~/.sapphire/packages")

      # Packages in INSTALL_REQUIRED are intentionally excluded from the stdlib
      # search path — they must be installed via `sph install <name>` first.
      if INSTALL_REQUIRED.include?(name)
        installed_path = File.join(packages_dir, "#{name}.sp")
        unless File.exist?(installed_path)
          raise SapphireError,
            "Package '#{name}' is not installed.\n" \
            "Run the following command first:\n\n" \
            "  sph install #{name}\n"
        end
        search_paths = [installed_path]
      else
        # Search order for regular modules:
        # 1. stdlib/ next to interpreter
        # 2. ~/.sapphire/packages/
        # 3. ./packages/ (project-local)
        # 4. Relative .sp file in current working dir
        search_paths = [
          File.join(__dir__, 'stdlib', "#{name}.sp"),
          File.join(packages_dir, "#{name}.sp"),
          File.join(Dir.pwd, 'packages', "#{name}.sp"),
          File.join(Dir.pwd, "#{name}.sp"),
        ]
      end

      # Also check for encrypted .spe versions in packages dir
      enc_search = search_paths.map { |p| p.sub(/\.sp$/, '.spe') }
      found_path  = search_paths.find { |p| File.exist?(p) }
      found_enc   = enc_search.find   { |p| File.exist?(p) } unless found_path

      if found_path
        mod_env = Environment.new(@globals)
        src     = File.read(found_path)
        tokens  = Lexer.new(src, found_path).tokenize
        ast     = Parser.new(tokens, found_path).parse
        eval_program(ast, mod_env)
        @modules[name] = mod_env.store
      elsif found_enc
        # Decrypt the package before loading
        src = decrypt_package(found_enc)
        if src.nil?
          raise SapphireError,
            "Package '#{name}' is encrypted and could not be decrypted.\n"             "The package may be corrupted. Try reinstalling:\n  sph install #{name}"
        end
        mod_env = Environment.new(@globals)
        tokens  = Lexer.new(src, found_enc).tokenize
        ast     = Parser.new(tokens, found_enc).parse
        eval_program(ast, mod_env)
        @modules[name] = mod_env.store
      else
        raise SapphireError, "Module '#{name}' not found.\nSearched:\n" +
          search_paths.map { |p| "  #{p}" }.join("\n") +
          "\n\nRun: sph install #{name}"
      end
    end

    # ─── Globals ──────────────────────────────────────────────────────────────

    def setup_globals
      # Math
      @globals.define('Math', SapphireHash.new({
        'PI'      => Math::PI,
        'E'       => Math::E,
        'TAU'     => Math::PI * 2,
        'INF'     => Float::INFINITY,
        'sqrt'    => NativeFunction.new('sqrt')    { |n| Math.sqrt(n) },
        'cbrt'    => NativeFunction.new('cbrt')    { |n| Math.cbrt(n) },
        'abs'     => NativeFunction.new('abs')     { |n| n.abs },
        'floor'   => NativeFunction.new('floor')   { |n| n.floor },
        'ceil'    => NativeFunction.new('ceil')    { |n| n.ceil },
        'round'   => NativeFunction.new('round')   { |n, d = 0| n.round(d) },
        'pow'     => NativeFunction.new('pow')     { |b, e| b ** e },
        'log'     => NativeFunction.new('log')     { |n| Math.log(n) },
        'log2'    => NativeFunction.new('log2')    { |n| Math.log2(n) },
        'log10'   => NativeFunction.new('log10')   { |n| Math.log10(n) },
        'sin'     => NativeFunction.new('sin')     { |n| Math.sin(n) },
        'cos'     => NativeFunction.new('cos')     { |n| Math.cos(n) },
        'tan'     => NativeFunction.new('tan')     { |n| Math.tan(n) },
        'asin'    => NativeFunction.new('asin')    { |n| Math.asin(n) },
        'acos'    => NativeFunction.new('acos')    { |n| Math.acos(n) },
        'atan'    => NativeFunction.new('atan')    { |n| Math.atan(n) },
        'atan2'   => NativeFunction.new('atan2')   { |y, x| Math.atan2(y, x) },
        'hypot'   => NativeFunction.new('hypot')   { |a, b| Math.hypot(a, b) },
        'min'     => NativeFunction.new('min')     { |a, b| [a, b].min },
        'max'     => NativeFunction.new('max')     { |a, b| [a, b].max },
        'sign'    => NativeFunction.new('sign')    { |n| n <=> 0 },
        'trunc'   => NativeFunction.new('trunc')   { |n| n.to_i },
        'random'  => NativeFunction.new('random')  { rand },
        'rand_int'=> NativeFunction.new('rand_int'){ |n| rand(n) },
        'clamp'   => NativeFunction.new('clamp')   { |v, lo, hi| v.clamp(lo, hi) },
      }))

      # IO
      @globals.define('IO', SapphireHash.new({
        'read'      => NativeFunction.new('read')      { $stdin.gets.chomp },
        'read_line' => NativeFunction.new('read_line') { |prompt = ''| print prompt; $stdin.gets&.chomp },
        'write'     => NativeFunction.new('write')     { |s| print s },
        'writeln'   => NativeFunction.new('writeln')   { |s| puts s },
        'read_file' => NativeFunction.new('read_file') { |path| File.read(path) rescue nil },
        'write_file'=> NativeFunction.new('write_file'){ |path, content| File.write(path, content); nil },
        'file_exists?'=> NativeFunction.new('file_exists?'){ |path| File.exist?(path) },
      }))

      # Sys
      @globals.define('Sys', SapphireHash.new({
        'args'    => SapphireArray.new(ARGV.dup),
        'env'     => NativeFunction.new('env')  { |k| ENV[k] },
        'exit'    => NativeFunction.new('exit') { |code = 0| Kernel.exit(code) },
        'time'    => NativeFunction.new('time') { Time.now.to_f },
        'platform'  => RUBY_PLATFORM,
        'set_env'   => NativeFunction.new('set_env') { |k, v| ENV[k] = v.to_s; nil },
        'load_env'  => NativeFunction.new('load_env') { |path = '.env'|
          begin
            File.readlines(path).each do |line|
              line = line.chomp.strip
              next if line.empty? || line.start_with?('#')
              # Split only on the FIRST = so values containing = are preserved
              eq = line.index('=')
              next if eq.nil? || eq == 0
              key   = line[0, eq].strip
              value = line[eq + 1..].strip
              # Strip surrounding quotes
              if (value.start_with?('"') && value.end_with?('"')) ||
                 (value.start_with?("'") && value.end_with?("'"))
                value = value[1..-2]
              end
              ENV[key] = value
            end
            true
          rescue => e
            nil
          end
        },
      }))

      # String
      @globals.define('String', SapphireHash.new({
        'from'   => NativeFunction.new('from')  { |v| v.to_s },
        'is?'    => NativeFunction.new('is?')   { |v| v.is_a?(String) },
        'ascii'  => NativeFunction.new('ascii') { |n| n.chr },
        'ord'    => NativeFunction.new('ord')   { |s| s.ord },
      }))

      # Number
      @globals.define('Number', SapphireHash.new({
        'parse'      => NativeFunction.new('parse')     { |s| s.to_s.include?('.') ? s.to_f : s.to_i },
        'is?'        => NativeFunction.new('is?')       { |v| v.is_a?(Numeric) },
        'is_int?'    => NativeFunction.new('is_int?')   { |v| v.is_a?(Integer) },
        'is_float?'  => NativeFunction.new('is_float?') { |v| v.is_a?(Float) },
        'is_nan?'    => NativeFunction.new('is_nan?')   { |v| v.is_a?(Float) && v.nan? },
        'is_finite?' => NativeFunction.new('is_finite?'){ |v| v.is_a?(Float) && v.finite? },
        'INF'        => Float::INFINITY,
        'NAN'        => Float::NAN,
      }))

      # Array
      @globals.define('Array', SapphireHash.new({
        'new'   => NativeFunction.new('new')   { |*args| SapphireArray.new(args.flatten) },
        'from'  => NativeFunction.new('from')  { |v| v.is_a?(SapphireArray) ? v : SapphireArray.new([v]) },
        'is?'   => NativeFunction.new('is?')   { |v| v.is_a?(SapphireArray) },
        'fill'  => NativeFunction.new('fill')  { |n, v| SapphireArray.new(Array.new(n, v)) },
        'range' => NativeFunction.new('range') { |a, b| SapphireArray.new((a..b).to_a) },
        'zip'   => NativeFunction.new('zip')   { |a, b| SapphireArray.new(a.elements.zip(b.elements).map { |p| SapphireArray.new(p) }) },
      }))

      # Hash
      @globals.define('Hash', SapphireHash.new({
        'new'  => NativeFunction.new('new') { SapphireHash.new({}) },
        'is?'  => NativeFunction.new('is?') { |v| v.is_a?(SapphireHash) },
      }))

      # Type conversion
      @globals.define('int',   NativeFunction.new('int')  { |v| v.to_i })
      @globals.define('float', NativeFunction.new('float'){ |v| v.to_f })
      @globals.define('str',   NativeFunction.new('str')  { |v| sapphire_to_s(v) })
      @globals.define('bool',  NativeFunction.new('bool') { |v| truthy?(v) })

      # Utilities
      @globals.define('len',    NativeFunction.new('len')   { |v|
        case v
        when SapphireArray then v.elements.length
        when SapphireHash  then v.map.length
        when String        then v.length
        else raise SapphireError, "len() not supported for #{sapphire_type(v)}"
        end
      })
      @globals.define('type',   NativeFunction.new('type')  { |v| sapphire_type(v) })
      @globals.define('input',  NativeFunction.new('input') { |prompt = ''| print prompt; $stdin.gets&.chomp })
      @globals.define('exit',   NativeFunction.new('exit')  { |code = 0| Kernel.exit(code) })
      @globals.define('sleep',  NativeFunction.new('sleep') { |n| sleep(n) })
      @globals.define('assert', NativeFunction.new('assert'){ |cond, msg = 'Assertion failed'|
        raise SapphireError, msg unless truthy?(cond)
      })
      @globals.define('range',  NativeFunction.new('range') { |a, b| SapphireArray.new((a..b).to_a) })
      @globals.define('make_hash', NativeFunction.new('make_hash') { SapphireHash.new({}) })
      @globals.define('zip',    NativeFunction.new('zip')   { |a, b|
        a.elements.zip(b.elements).map { |p| SapphireArray.new(p) }.then { |r| SapphireArray.new(r) }
      })

      # ── Log native ─────────────────────────────────────────────────────────
      # A simple structured logger available as Log.debug/info/warn/error/fatal
      # in every Sapphire program without any import.
      #
      # Log.level = "warn"        # only warn, error, fatal pass through
      # Log.output = "/tmp/a.log" # redirect to file (default: stderr)
      # Log.timestamp = false     # hide timestamps
      # Log.format = "plain"      # "plain" | "json"
      log_state = {
        level:     'debug',   # debug < info < warn < error < fatal
        output:    nil,       # nil → stderr
        timestamp: true,
        format:    'plain',   # "plain" | "json"
      }
      log_levels = %w[debug info warn error fatal]
      log_colors = { 'debug' => "\e[90m", 'info' => "\e[36m", 'warn' => "\e[33m",
                     'error' => "\e[31m", 'fatal' => "\e[35m" }

      log_write = lambda do |level, msg|
        threshold = log_levels.index(log_state[:level]) || 0
        return if log_levels.index(level) < threshold

        ts   = log_state[:timestamp] ? Time.now.strftime('%Y-%m-%dT%H:%M:%S') : nil
        line = if log_state[:format] == 'json'
          parts = { level: level.upcase }
          parts[:time] = ts if ts
          parts[:msg]  = sapphire_to_s(msg)
          ::JSON.generate(parts)
        else
          color  = log_colors[level] || ''
          reset  = "\e[0m"
          label  = "[#{level.upcase}]".ljust(7)
          prefix = ts ? "#{color}#{ts} #{label}#{reset} " : "#{color}#{label}#{reset} "
          "#{prefix}#{sapphire_to_s(msg)}"
        end

        if log_state[:output]
          File.open(log_state[:output], 'a') { |f| f.puts line } rescue nil
        else
          $stderr.puts line
        end
        nil
      end

      @globals.define('Log', SapphireHash.new({
        'debug' => NativeFunction.new('debug') { |m| log_write.call('debug', m) },
        'info'  => NativeFunction.new('info')  { |m| log_write.call('info',  m) },
        'warn'  => NativeFunction.new('warn')  { |m| log_write.call('warn',  m) },
        'error' => NativeFunction.new('error') { |m| log_write.call('error', m) },
        'fatal' => NativeFunction.new('fatal') { |m| log_write.call('fatal', m); Kernel.exit(1) },
        # Config setters
        'set_level'     => NativeFunction.new('set_level')     { |l| log_state[:level]     = l.to_s.downcase; nil },
        'set_output'    => NativeFunction.new('set_output')    { |p| log_state[:output]     = p; nil },
        'set_timestamp' => NativeFunction.new('set_timestamp') { |b| log_state[:timestamp]  = b; nil },
        'set_format'    => NativeFunction.new('set_format')    { |f| log_state[:format]     = f.to_s.downcase; nil },
        # Introspection
        'level'  => NativeFunction.new('level')  { log_state[:level] },
        'format' => NativeFunction.new('format') { log_state[:format] },
      }))

      # ── fmt native ─────────────────────────────────────────────────────────
      # fmt — string formatting and inspection helpers.
      # Available globally; no import required.
      #
      # fmt.sprintf("%s has %d items", name, count)   → formatted string
      # fmt.pad_left("hi", 10)                        → "        hi"
      # fmt.pad_right("hi", 10)                       → "hi        "
      # fmt.center("hi", 10)                          → "    hi    "
      # fmt.table(rows, headers)                      → ASCII table string
      # fmt.json(value)                               → pretty JSON
      # fmt.hex(255)                                  → "ff"
      # fmt.bin(255)                                  → "11111111"
      # fmt.comma(1234567)                            → "1,234,567"
      # fmt.plural(1, "item")                         → "1 item"  /  "2 items"
      # fmt.duration(90)                              → "1m 30s"
      # fmt.bytes(1_500_000)                          → "1.43 MB"
      # fmt.repeat(str, n)                            → str * n
      # fmt.truncate(str, max, suffix)                → truncated string
      # fmt.strip_ansi(str)                           → removes ANSI escape codes
      @globals.define('fmt', SapphireHash.new({
        'sprintf' => NativeFunction.new('sprintf') { |template, *args|
          # Supports %s %d %f %05d %.2f etc.
          i = 0
          template.to_s.gsub(/%[-+ #0]*\d*\.?\d*[sdfeExXobBgG]/) do |m|
            val = args[i] || ''
            i  += 1
            begin; Kernel.sprintf(m, val); rescue; val.to_s; end
          end
        },
        'pad_left'  => NativeFunction.new('pad_left')  { |s, len, ch = ' '| s.to_s.rjust(len.to_i,  ch.to_s[0] || ' ') },
        'pad_right' => NativeFunction.new('pad_right') { |s, len, ch = ' '| s.to_s.ljust(len.to_i,  ch.to_s[0] || ' ') },
        'center'    => NativeFunction.new('center')    { |s, len, ch = ' '| s.to_s.center(len.to_i, ch.to_s[0] || ' ') },
        'repeat'    => NativeFunction.new('repeat')    { |s, n| s.to_s * n.to_i },
        'truncate'  => NativeFunction.new('truncate')  { |s, max, suffix = '...'|
          s = s.to_s; max = max.to_i
          s.length <= max ? s : s[0, [max - suffix.to_s.length, 0].max] + suffix.to_s
        },
        'strip_ansi'=> NativeFunction.new('strip_ansi'){ |s| s.to_s.gsub(/\e\[[0-9;]*[A-Za-z]/, '') },
        'hex'       => NativeFunction.new('hex')       { |n| n.to_i.to_s(16) },
        'bin'       => NativeFunction.new('bin')       { |n| n.to_i.to_s(2)  },
        'oct'       => NativeFunction.new('oct')       { |n| n.to_i.to_s(8)  },
        'comma'     => NativeFunction.new('comma')     { |n|
          i, f = n.to_s.split('.')
          i = i.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
          f ? "#{i}.#{f}" : i
        },
        'plural'    => NativeFunction.new('plural')    { |n, word, plural_word = nil|
          plural_word ||= word.to_s + 's'
          n.to_i == 1 ? "#{n} #{word}" : "#{n} #{plural_word}"
        },
        'duration'  => NativeFunction.new('duration')  { |secs|
          s = secs.to_i.abs
          d, s = s.divmod(86400)
          h, s = s.divmod(3600)
          m, s = s.divmod(60)
          parts = []
          parts << "#{d}d" if d > 0
          parts << "#{h}h" if h > 0
          parts << "#{m}m" if m > 0
          parts << "#{s}s" if s > 0 || parts.empty?
          parts.join(' ')
        },
        'bytes'     => NativeFunction.new('bytes')     { |n|
          n = n.to_f
          units = %w[B KB MB GB TB PB]
          i = 0
          while n >= 1024 && i < units.length - 1
            n /= 1024.0; i += 1
          end
          i == 0 ? "#{n.to_i} B" : "#{'%.2f' % n} #{units[i]}"
        },
        'json'      => NativeFunction.new('json')      { |v|
          require 'json'
          ::JSON.pretty_generate(sapphire_to_ruby(v)) rescue sapphire_to_s(v)
        },
        'table'     => NativeFunction.new('table')     { |rows_val, headers_val = nil|
          rows = rows_val.is_a?(SapphireArray) ? rows_val.elements.map { |r|
            r.is_a?(SapphireArray) ? r.elements.map { |c| sapphire_to_s(c) } : [sapphire_to_s(r)]
          } : []
          headers = headers_val.is_a?(SapphireArray) ? headers_val.elements.map { |h| sapphire_to_s(h) } : nil
          all_rows = headers ? [headers] + rows : rows
          next '' if all_rows.empty?
          cols = all_rows.map(&:length).max
          widths = Array.new(cols, 0)
          all_rows.each { |r| r.each_with_index { |c, i| widths[i] = [widths[i], c.to_s.length].max } }
          sep  = '+' + widths.map { |w| '-' * (w + 2) }.join('+') + '+'
          fmt_row = lambda { |r| '|' + r.each_with_index.map { |c, i| " #{c.to_s.ljust(widths[i])} " }.join('|') + '|' }
          lines = [sep]
          all_rows.each_with_index do |row, idx|
            lines << fmt_row.call(row)
            lines << sep if idx == 0 && headers
          end
          lines << sep unless headers
          lines.join("\n")
        },
      }))

      # ── JSON native ────────────────────────────────────────────────────────
      require 'json'
      @globals.define('JSON', SapphireHash.new({
        'parse'     => NativeFunction.new('parse') { |s|
          begin; ruby_to_sapphire(::JSON.parse(s)); rescue; nil; end
        },
        'stringify' => NativeFunction.new('stringify') { |v|
          sapphire_to_ruby(v).to_json
        },
      }))

      # ── HTTP native ────────────────────────────────────────────────────────
      require 'net/http'
      require 'net/https'
      require 'uri'
      @globals.define('HTTP', SapphireHash.new({
        'get' => NativeFunction.new('get') { |url, headers_hash = nil|
          begin
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            http.open_timeout = 10; http.read_timeout = 30
            req = Net::HTTP::Get.new(uri.request_uri)
            req['Content-Type'] = 'application/json'
            req['User-Agent']   = 'Sapphire/1.0'
            headers_hash.is_a?(SapphireHash) && headers_hash.map.each { |k,v| req[k] = v }
            res = http.request(req)
            ruby_to_sapphire(::JSON.parse(res.body))
          rescue => e; nil; end
        },
        'post' => NativeFunction.new('post') { |url, body_hash = nil, headers_hash = nil|
          begin
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            http.open_timeout = 10; http.read_timeout = 30
            req = Net::HTTP::Post.new(uri.request_uri)
            req['Content-Type'] = 'application/json'
            req['User-Agent']   = 'Sapphire/1.0'
            headers_hash.is_a?(SapphireHash) && headers_hash.map.each { |k,v| req[k] = v }
            req.body = body_hash.is_a?(SapphireHash) ? sapphire_to_ruby(body_hash).to_json : '{}'
            res = http.request(req)
            ruby_to_sapphire(::JSON.parse(res.body))
          rescue => e; nil; end
        },
        'patch' => NativeFunction.new('patch') { |url, body_hash = nil, headers_hash = nil|
          begin
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            req = Net::HTTP::Patch.new(uri.request_uri)
            req['Content-Type'] = 'application/json'
            headers_hash.is_a?(SapphireHash) && headers_hash.map.each { |k,v| req[k] = v }
            req.body = body_hash.is_a?(SapphireHash) ? sapphire_to_ruby(body_hash).to_json : '{}'
            res = http.request(req)
            ruby_to_sapphire(::JSON.parse(res.body))
          rescue => e; nil; end
        },
        'delete' => NativeFunction.new('delete') { |url, headers_hash = nil|
          begin
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            req = Net::HTTP::Delete.new(uri.request_uri)
            req['Content-Type'] = 'application/json'
            headers_hash.is_a?(SapphireHash) && headers_hash.map.each { |k,v| req[k] = v }
            res = http.request(req)
            res.code.to_i < 300 ? true : nil
          rescue => e; nil; end
        },
        'put' => NativeFunction.new('put') { |url, body_hash = nil, headers_hash = nil|
          begin
            uri = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            req = Net::HTTP::Put.new(uri.request_uri)
            req['Content-Type'] = 'application/json'
            headers_hash.is_a?(SapphireHash) && headers_hash.map.each { |k,v| req[k] = v }
            req.body = body_hash.is_a?(SapphireHash) ? sapphire_to_ruby(body_hash).to_json : '{}'
            res = http.request(req)
            res.code.to_i < 300 ? true : nil
          rescue => e; nil; end
        },
        'url_encode' => NativeFunction.new('url_encode') { |s| URI.encode_www_form_component(s) },
      }))

      # ── GATEWAY native — Discord WebSocket Gateway ────────────────────────
      @globals.define('GATEWAY', SapphireHash.new({
        'connect' => NativeFunction.new('connect') { |token, handler|
          @_gateway_running = true
          @_gateway_ws = nil

          require 'websocket/driver'
          require 'socket'
          require 'openssl'
          require 'json'

          gateway_url = "wss://gateway.discord.gg/?v=10&encoding=json"

          uri = URI.parse(gateway_url)
          tcp = TCPSocket.new(uri.host, 443)
          ssl_ctx = OpenSSL::SSL::SSLContext.new
          ssl_ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
          ssl = OpenSSL::SSL::SSLSocket.new(tcp, ssl_ctx)
          ssl.connect

          driver = WebSocket::Driver.client(
            Class.new do
              attr_reader :url
              def initialize(url, ssl); @url = url; @ssl = ssl; end
              def write(data); @ssl.write(data); end
            end.new(gateway_url, ssl)
          )

          heartbeat_interval = nil
          heartbeat_thread = nil
          sequence = nil

          driver.on(:message) do |msg|
            payload = JSON.parse(msg.data)
            op = payload['op']
            data = payload['d']
            t = payload['t']
            s = payload['s']
            sequence = s if s

            case op
            when 10 # Hello
              heartbeat_interval = data['heartbeat_interval'] / 1000.0
              heartbeat_thread = Thread.new do
                loop do
                  sleep heartbeat_interval
                  break unless @_gateway_running
                  driver.text(JSON.generate({ op: 1, d: sequence }))
                end
              end
              # Identify
              driver.text(JSON.generate({
                op: 2,
                d: {
                  token: token,
                  intents: 33281,
                  properties: { os: 'linux', browser: 'discordsph', device: 'discordsph' }
                }
              }))
            when 11 # Heartbeat ACK
              # ok
            when 0 # Dispatch
              begin
                call_fn(handler, [t, ruby_to_sapphire(data)]) if handler && t
              rescue => e
                puts "[GATEWAY] Handler error: #{e.message}"
              end
            end
          end

          driver.start

          loop do
            break unless @_gateway_running
            begin
              chunk = ssl.read_nonblock(65536)
              driver.parse(chunk)
            rescue Interrupt
              @_gateway_running = false
              break
            rescue IO::WaitReadable, OpenSSL::SSL::SSLErrorWaitReadable
              IO.select([ssl], nil, nil, 0.1)
            rescue => e
              puts "[GATEWAY] Connection error: #{e.message}"
              break
            end
          end

          heartbeat_thread&.kill
          ssl.close rescue nil
          tcp.close rescue nil
        },
        'disconnect' => NativeFunction.new('disconnect') { |token|
          @_gateway_running = false
        },
        'send_payload' => NativeFunction.new('send_payload') { |token, payload| nil },
      }))

      require 'digest'
      require 'base64'
      require 'securerandom'
      require 'fileutils'
      require 'find'
      require 'yaml'
      require 'csv'
      require 'rbconfig'
      require 'socket'
      require 'tmpdir'
      require 'openssl'

      # ── Args native ───────────────────────────────────────────────────────────
      @globals.define('Args', SapphireHash.new({
        'parse' => NativeFunction.new('parse') {
          argv = (defined?(ARGV) ? ARGV : []).dup
          parsed = { 'flags' => [], 'options' => {}, 'positional' => [] }
          i = 0
          while i < argv.length
            a = argv[i]
            if a.start_with?('--')
              key = a[2..]
              if i + 1 < argv.length && !argv[i+1].start_with?('-')
                parsed['options'][key] = argv[i+1]; i += 2
              else
                parsed['flags'] << key; i += 1
              end
            elsif a.start_with?('-')
              parsed['flags'] << a[1..]; i += 1
            else
              parsed['positional'] << a; i += 1
            end
          end
          ruby_to_sapphire(parsed)
        },
        'get' => NativeFunction.new('get') { |name|
          argv = defined?(ARGV) ? ARGV.dup : []
          idx  = argv.index("--#{name}")
          (idx && idx + 1 < argv.length) ? argv[idx + 1] : nil
        },
        'flag' => NativeFunction.new('flag') { |name|
          argv = defined?(ARGV) ? ARGV.dup : []
          argv.include?("--#{name}") || argv.include?("-#{name}")
        },
        'positional' => NativeFunction.new('positional') {
          argv = defined?(ARGV) ? ARGV.dup : []
          ruby_to_sapphire(argv.reject { |a| a.start_with?('-') })
        },
      }))

      # ── Yml native ────────────────────────────────────────────────────────────
      @globals.define('Yml', SapphireHash.new({
        'load' => NativeFunction.new('load') { |path|
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Yml.load: file not found: #{path}"; next nil
          end
          ruby_to_sapphire(YAML.safe_load(File.read(path), permitted_classes: [Symbol]) || {})
        },
        'load_str' => NativeFunction.new('load_str') { |text|
          ruby_to_sapphire(YAML.safe_load(text, permitted_classes: [Symbol]) || {})
        },
        'dump' => NativeFunction.new('dump') { |data|
          YAML.dump(sapphire_to_ruby(data))
        },
        'save' => NativeFunction.new('save') { |path, data|
          path = File.expand_path(path)
          File.write(path, YAML.dump(sapphire_to_ruby(data)))
          true
        },
      }))

      # ── Csv native ────────────────────────────────────────────────────────────
      @globals.define('Csv', SapphireHash.new({
        'read' => NativeFunction.new('read') { |path|
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Csv.read: file not found: #{path}"; next ruby_to_sapphire([])
          end
          rows = CSV.read(path)
          ruby_to_sapphire(rows)
        },
        'read_headers' => NativeFunction.new('read_headers') { |path|
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Csv.read_headers: file not found: #{path}"; next ruby_to_sapphire([])
          end
          rows = CSV.read(path, headers: true).map(&:to_h)
          ruby_to_sapphire(rows)
        },
        'write' => NativeFunction.new('write') { |path, rows|
          path = File.expand_path(path)
          CSV.open(path, 'w') do |csv|
            sapphire_to_ruby(rows).each { |row| csv << row }
          end
          true
        },
        'write_headers' => NativeFunction.new('write_headers') { |path, headers, rows|
          path = File.expand_path(path)
          CSV.open(path, 'w') do |csv|
            csv << sapphire_to_ruby(headers)
            sapphire_to_ruby(rows).each { |row| csv << row }
          end
          true
        },
        'parse' => NativeFunction.new('parse') { |text|
          ruby_to_sapphire(CSV.parse(text))
        },
        'stringify' => NativeFunction.new('stringify') { |rows|
          CSV.generate { |csv| sapphire_to_ruby(rows).each { |r| csv << r } }
        },
      }))

      # ── Crypto native ─────────────────────────────────────────────────────────
      @globals.define('Crypto', SapphireHash.new({
        'sha256'  => NativeFunction.new('sha256')  { |data| Digest::SHA256.hexdigest(data.to_s) },
        'sha512'  => NativeFunction.new('sha512')  { |data| Digest::SHA512.hexdigest(data.to_s) },
        'md5'     => NativeFunction.new('md5')     { |data| Digest::MD5.hexdigest(data.to_s) },
        'sha1'    => NativeFunction.new('sha1')    { |data| Digest::SHA1.hexdigest(data.to_s) },
        'base64_encode' => NativeFunction.new('base64_encode') { |data| Base64.strict_encode64(data.to_s) },
        'base64_decode' => NativeFunction.new('base64_decode') { |data| Base64.decode64(data.to_s) },
        'hex_encode'    => NativeFunction.new('hex_encode')    { |data| data.to_s.unpack1('H*') },
        'hex_decode'    => NativeFunction.new('hex_decode')    { |data| [data.to_s].pack('H*') },
        'hmac_sha256'   => NativeFunction.new('hmac_sha256')   { |key, data|
          OpenSSL::HMAC.hexdigest('SHA256', key.to_s, data.to_s)
        },
        'random_bytes' => NativeFunction.new('random_bytes') { |n| SecureRandom.bytes(n.to_i) },
        'random_hex'   => NativeFunction.new('random_hex')   { |n| SecureRandom.hex(n.to_i) },
        'uuid'         => NativeFunction.new('uuid')         { SecureRandom.uuid },
      }))

      # ── Files native ──────────────────────────────────────────────────────────
      @globals.define('Files', SapphireHash.new({
        'read'    => NativeFunction.new('read')    { |path| File.read(File.expand_path(path)) rescue nil },
        'write'   => NativeFunction.new('write')   { |path, data| File.write(File.expand_path(path), data.to_s); true },
        'append'  => NativeFunction.new('append')  { |path, data| File.open(File.expand_path(path), 'a') { |f| f.write(data.to_s) }; true },
        'delete'  => NativeFunction.new('delete')  { |path| File.delete(File.expand_path(path)) rescue false; true },
        'exists'  => NativeFunction.new('exists')  { |path| File.exist?(File.expand_path(path)) },
        'copy'    => NativeFunction.new('copy')    { |src, dst| FileUtils.cp(File.expand_path(src), File.expand_path(dst)); true },
        'move'    => NativeFunction.new('move')    { |src, dst| FileUtils.mv(File.expand_path(src), File.expand_path(dst)); true },
        'mkdir'   => NativeFunction.new('mkdir')   { |path| FileUtils.mkdir_p(File.expand_path(path)); true },
        'rmdir'   => NativeFunction.new('rmdir')   { |path| FileUtils.rm_rf(File.expand_path(path)); true },
        'ls'      => NativeFunction.new('ls')      { |path|
          ruby_to_sapphire(Dir.entries(File.expand_path(path)).reject { |e| e == '.' || e == '..' })
        },
        'ls_r'    => NativeFunction.new('ls_r')    { |path|
          results = []
          Find.find(File.expand_path(path)) { |p| results << p }
          ruby_to_sapphire(results)
        },
        'glob'    => NativeFunction.new('glob')    { |pat| ruby_to_sapphire(Dir.glob(pat)) },
        'basename'=> NativeFunction.new('basename'){ |path| File.basename(path.to_s) },
        'dirname' => NativeFunction.new('dirname') { |path| File.dirname(path.to_s) },
        'extname' => NativeFunction.new('extname') { |path| File.extname(path.to_s) },
        'join'    => NativeFunction.new('join')    { |a, b| File.join(a.to_s, b.to_s) },
        'expand'  => NativeFunction.new('expand')  { |path| File.expand_path(path.to_s) },
        'size'    => NativeFunction.new('size')    { |path| File.size(File.expand_path(path.to_s)) rescue 0 },
        'is_dir'  => NativeFunction.new('is_dir')  { |path| File.directory?(File.expand_path(path.to_s)) },
        'is_file' => NativeFunction.new('is_file') { |path| File.file?(File.expand_path(path.to_s)) },
        'watch'   => NativeFunction.new('watch')   { |path, callback|
          Thread.new do
            last_mtime = File.mtime(File.expand_path(path.to_s)) rescue nil
            loop do
              sleep 1
              mtime = File.mtime(File.expand_path(path.to_s)) rescue nil
              if mtime && mtime != last_mtime
                last_mtime = mtime
                callback.call(path)
              end
            end
          end
          true
        },
      }))

      # ── Zip native ────────────────────────────────────────────────────────────
      @globals.define('Zip', SapphireHash.new({
        'create' => NativeFunction.new('create') { |zip_path, files|
          require 'shellwords'
          zip_path = File.expand_path(zip_path)
          file_args = sapphire_to_ruby(files).map { |f| File.expand_path(f).shellescape }.join(' ')
          system("zip -r #{zip_path.shellescape} #{file_args} > /dev/null 2>&1")
        },
        'extract' => NativeFunction.new('extract') { |zip_path, dest|
          require 'shellwords'
          zip_path = File.expand_path(zip_path)
          dest     = File.expand_path(dest)
          FileUtils.mkdir_p(dest)
          system("unzip -q #{zip_path.shellescape} -d #{dest.shellescape}")
        },
        'list' => NativeFunction.new('list') { |zip_path|
          require 'shellwords'
          zip_path = File.expand_path(zip_path)
          out = `unzip -l #{zip_path.shellescape} 2>/dev/null`
          lines = out.lines[3..-3] || []
          ruby_to_sapphire(lines.map { |l| l.strip.split(/\s+/, 4).last }.compact)
        },
        'contains' => NativeFunction.new('contains') { |zip_path, file|
          require 'shellwords'
          zip_path = File.expand_path(zip_path)
          system("unzip -l #{zip_path.shellescape} | grep -q #{file.shellescape}")
        },
      }))

      # ── Env native ────────────────────────────────────────────────────────────
      @globals.define('Env', SapphireHash.new({
        'os' => NativeFunction.new('os') {
          case RbConfig::CONFIG['host_os']
          when /mswin|mingw|cygwin/ then 'windows'
          when /darwin/             then 'macos'
          when /linux/              then 'linux'
          else                           RbConfig::CONFIG['host_os']
          end
        },
        'arch'     => NativeFunction.new('arch')     { RbConfig::CONFIG['host_cpu'] },
        'home'     => NativeFunction.new('home')     { Dir.home },
        'user'     => NativeFunction.new('user')     { ENV['USER'] || ENV['USERNAME'] || 'unknown' },
        'hostname' => NativeFunction.new('hostname') { Socket.gethostname rescue 'unknown' },
        'cwd'      => NativeFunction.new('cwd')      { Dir.pwd },
        'tmp'      => NativeFunction.new('tmp')      { Dir.tmpdir },
        'get'      => NativeFunction.new('get')      { |key| ENV[key.to_s] },
        'set'      => NativeFunction.new('set')      { |key, val| ENV[key.to_s] = val.to_s; true },
        'has'      => NativeFunction.new('has')      { |key| ENV.key?(key.to_s) },
        'all'      => NativeFunction.new('all')      { ruby_to_sapphire(ENV.to_h) },
        'ruby_version' => NativeFunction.new('ruby_version') { RUBY_VERSION },
        'node_version' => NativeFunction.new('node_version') {
          out = `node --version 2>/dev/null`.strip
          out.empty? ? nil : out.sub('v','')
        },
        'has_node' => NativeFunction.new('has_node') {
          system("which node > /dev/null 2>&1") || system("where node > nul 2>&1")
        },
        'is_pi'    => NativeFunction.new('is_pi') {
          File.exist?('/sys/firmware/devicetree/base/model') &&
          File.read('/sys/firmware/devicetree/base/model').include?('Raspberry Pi') rescue false
        },
      }))

      # ── Sqlite native ─────────────────────────────────────────────────────────
      begin
        require 'sqlite3'
        @globals.define('Sqlite', SapphireHash.new({
          'open' => NativeFunction.new('open') { |path|
            path == ':memory:' ? SQLite3::Database.new(':memory:') : SQLite3::Database.new(File.expand_path(path))
          },
          'query' => NativeFunction.new('query') { |db, sql|
            rows = db.execute(sql)
            ruby_to_sapphire(rows)
          },
          'query_one' => NativeFunction.new('query_one') { |db, sql|
            row = db.get_first_row(sql)
            ruby_to_sapphire(row || [])
          },
          'execute' => NativeFunction.new('execute') { |db, sql|
            db.execute(sql); true
          },
          'execute_params' => NativeFunction.new('execute_params') { |db, sql, params|
            db.execute(sql, sapphire_to_ruby(params)); true
          },
          'close' => NativeFunction.new('close') { |db| db.close; true },
          'tables' => NativeFunction.new('tables') { |db|
            rows = db.execute("SELECT name FROM sqlite_master WHERE type='table'")
            ruby_to_sapphire(rows.map(&:first))
          },
          'create_table' => NativeFunction.new('create_table') { |db, name, cols|
            col_defs = sapphire_to_ruby(cols).map { |k, v| "#{k} #{v}" }.join(', ')
            db.execute("CREATE TABLE IF NOT EXISTS #{name} (#{col_defs})")
            true
          },
          'insert' => NativeFunction.new('insert') { |db, table, data|
            h = sapphire_to_ruby(data)
            cols = h.keys.join(', ')
            vals = (['?'] * h.size).join(', ')
            db.execute("INSERT INTO #{table} (#{cols}) VALUES (#{vals})", h.values)
            true
          },
          'select_all' => NativeFunction.new('select_all') { |db, table|
            db.results_as_hash = true
            rows = db.execute("SELECT * FROM #{table}")
            db.results_as_hash = false
            ruby_to_sapphire(rows)
          },
          'select_where' => NativeFunction.new('select_where') { |db, table, col, val|
            db.results_as_hash = true
            rows = db.execute("SELECT * FROM #{table} WHERE #{col} = ?", [val])
            db.results_as_hash = false
            ruby_to_sapphire(rows)
          },
          'update' => NativeFunction.new('update') { |db, table, data, where_col, where_val|
            h    = sapphire_to_ruby(data)
            sets = h.keys.map { |k| "#{k} = ?" }.join(', ')
            db.execute("UPDATE #{table} SET #{sets} WHERE #{where_col} = ?", h.values + [where_val])
            true
          },
          'delete_where' => NativeFunction.new('delete_where') { |db, table, col, val|
            db.execute("DELETE FROM #{table} WHERE #{col} = ?", [val])
            true
          },
        }))
      rescue LoadError
        # sqlite3 gem not installed — define a stub that tells the user what to do
        @globals.define('Sqlite', SapphireHash.new({
          'open' => NativeFunction.new('open') { |_|
            puts "[Sapphire] sqlite3 gem not installed."
            puts "  Install it with: gem install sqlite3"
            nil
          },
        }))
      end



      # ── JS Bridge native (Web, UI, Canvas — requires Node.js) ────────────────
      begin
        require_relative 'js_bridge/bridge'
        js_packages = ['web', 'ui', 'canvas']
        js_packages.each do |pkg|
          pkg_const = pkg.capitalize
          @globals.define(pkg_const, SapphireHash.new({
            '__js_package__' => pkg,
          }.merge(
            %w[create get post listen stop serve_static open draw].map { |fn|
              [fn, NativeFunction.new(fn) { |*args|
                Sapphire::JSBridge.call(pkg, fn, args)
              }]
            }.to_h
          )))
        end
      rescue LoadError
        # js_bridge not available — stubs defined when packages are imported
      end

      require 'shellwords'
      # ── Media native (images + video, headless Pi friendly) ───────────────────
      @globals.define('Media', SapphireHash.new({

        # Check if a command exists on the system
        'has_cmd' => NativeFunction.new('has_cmd') { |cmd|
          system("which #{cmd.shellescape} > /dev/null 2>&1")
        },

        # Detect if we have a display (X11 forwarding or local X)
        'has_display' => NativeFunction.new('has_display') {
          !ENV['DISPLAY'].to_s.empty? || !ENV['WAYLAND_DISPLAY'].to_s.empty?
        },

        # Install a package via apt (returns true on success)
        'apt_install' => NativeFunction.new('apt_install') { |pkg|
          puts "  Installing #{pkg} via apt..."
          system("sudo apt-get install -y #{pkg.shellescape} > /dev/null 2>&1")
        },

        # Show an image — uses fim (framebuffer, no X) or feh (X11)
        'show_image' => NativeFunction.new('show_image') { |path, opts = nil|
          require 'shellwords'
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Media.show_image: file not found: #{path}"
            next false
          end

          has_display = !ENV['DISPLAY'].to_s.empty? || !ENV['WAYLAND_DISPLAY'].to_s.empty?

          if has_display
            # X11 available — prefer feh, fallback to display (ImageMagick)
            if system("which feh > /dev/null 2>&1")
              system("feh #{path.shellescape}")
            elsif system("which display > /dev/null 2>&1")
              system("display #{path.shellescape}")
            elsif system("which eog > /dev/null 2>&1")
              system("eog #{path.shellescape}")
            else
              puts "No image viewer found. Install one with: spm media-setup"
              next false
            end
          else
            # Headless / SSH — use fim (framebuffer image viewer)
            if system("which fim > /dev/null 2>&1")
              system("fim -q #{path.shellescape}")
            elsif system("which fbi > /dev/null 2>&1")
              system("fbi -T 2 -noverbose #{path.shellescape}")
            else
              puts "No framebuffer image viewer found. Install with:"
              puts "  sudo apt-get install fim"
              next false
            end
          end
          true
        },

        # Play a video — uses mpv with DRM/framebuffer output for headless
        'play_video' => NativeFunction.new('play_video') { |path, opts = nil|
          require 'shellwords'
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Media.play_video: file not found: #{path}"
            next false
          end

          has_display = !ENV['DISPLAY'].to_s.empty? || !ENV['WAYLAND_DISPLAY'].to_s.empty?

          if system("which mpv > /dev/null 2>&1")
            if has_display
              system("mpv #{path.shellescape}")
            else
              # Headless: DRM output (direct to framebuffer, no X needed)
              system("mpv --vo=drm #{path.shellescape}")
            end
          elsif system("which vlc > /dev/null 2>&1")
            if has_display
              system("vlc #{path.shellescape}")
            else
              system("cvlc --vout fb #{path.shellescape}")
            end
          elsif system("which mplayer > /dev/null 2>&1")
            if has_display
              system("mplayer #{path.shellescape}")
            else
              system("mplayer -vo fbdev #{path.shellescape}")
            end
          else
            puts "No video player found. Install with:"
            puts "  sudo apt-get install mpv"
            next false
          end
          true
        },

        # Show image in terminal using ASCII/ANSI art (works over pure SSH with no framebuffer)
        'show_image_ascii' => NativeFunction.new('show_image_ascii') { |path, width = 80|
          require 'shellwords'
          path = File.expand_path(path)
          unless File.exist?(path)
            puts "Media.show_image_ascii: file not found: #{path}"
            next false
          end
          if system("which viu > /dev/null 2>&1")
            system("viu -w #{width.to_i} #{path.shellescape}")
          elsif system("which catimg > /dev/null 2>&1")
            system("catimg -w #{width.to_i} #{path.shellescape}")
          elsif system("which jp2a > /dev/null 2>&1")
            system("jp2a --width=#{width.to_i} #{path.shellescape}")
          else
            puts "No terminal image viewer found. Install one with:"
            puts "  cargo install viu        # best quality (requires Rust)"
            puts "  sudo apt-get install jp2a  # ASCII fallback"
            next false
          end
          true
        },

        # Slideshow: show multiple images one after another
        'slideshow' => NativeFunction.new('slideshow') { |paths, delay = 3|
          require 'shellwords'
          has_display = !ENV['DISPLAY'].to_s.empty? || !ENV['WAYLAND_DISPLAY'].to_s.empty?
          paths.elements.each do |path|
            path = File.expand_path(path)
            next unless File.exist?(path)
            if has_display && system("which feh > /dev/null 2>&1")
              pid = spawn("feh #{path.shellescape}")
              sleep(delay)
              Process.kill('TERM', pid) rescue nil
              Process.wait(pid) rescue nil
            elsif system("which fim > /dev/null 2>&1")
              system("fim -q -T #{delay.to_i} #{path.shellescape}")
            end
          end
          true
        },

        # Get image info (dimensions, format) using ImageMagick identify
        'image_info' => NativeFunction.new('image_info') { |path|
          require 'shellwords'
          path = File.expand_path(path)
          unless File.exist?(path)
            next SapphireHash.new({})
          end
          if system("which identify > /dev/null 2>&1")
            out = `identify -verbose #{path.shellescape} 2>/dev/null`
            info = {}
            out.each_line do |line|
              info['width']  = $1.to_i if line =~ /Geometry: (\d+)x/
              info['height'] = $1.to_i if line =~ /Geometry: \d+x(\d+)/
              info['format'] = $1       if line =~ /Format: (\w+)/
            end
            ruby_to_sapphire(info)
          else
            ruby_to_sapphire({ 'path' => path, 'exists' => true })
          end
        },

        # Get video info using ffprobe
        'video_info' => NativeFunction.new('video_info') { |path|
          require 'shellwords'
          require 'json'
          path = File.expand_path(path)
          unless File.exist?(path)
            next SapphireHash.new({})
          end
          if system("which ffprobe > /dev/null 2>&1")
            out = `ffprobe -v quiet -print_format json -show_format -show_streams #{path.shellescape} 2>/dev/null`
            begin
              data = ::JSON.parse(out)
              fmt  = data['format'] || {}
              ruby_to_sapphire({
                'duration' => fmt['duration'].to_f,
                'size'     => fmt['size'].to_i,
                'format'   => fmt['format_long_name'],
                'path'     => path,
              })
            rescue
              ruby_to_sapphire({ 'path' => path, 'exists' => true })
            end
          else
            ruby_to_sapphire({ 'path' => path, 'exists' => true })
          end
        },

        # Setup helper: install recommended tools for headless Pi
        'setup' => NativeFunction.new('setup') {
          puts "Installing media tools for headless Raspberry Pi..."
          puts ""
          tools = [
            ['fim',        'Framebuffer image viewer (no X needed)'],
            ['mpv',        'Video player with DRM/framebuffer output'],
            ['jp2a',       'ASCII image viewer (works over plain SSH)'],
            ['ffmpeg',     'Video processing + ffprobe for video info'],
            ['imagemagick','Image info and conversion'],
          ]
          tools.each do |pkg, desc|
            if system("which #{pkg.split('/').last.shellescape} > /dev/null 2>&1")
              puts "  ✓ #{pkg.ljust(14)} already installed"
            else
              print "  ↓ Installing #{pkg.ljust(14)} (#{desc})... "
              ok = system("sudo apt-get install -y #{pkg.shellescape} > /dev/null 2>&1")
              puts ok ? "done" : "FAILED (try manually: sudo apt install #{pkg})"
            end
          end
          puts ""
          puts "Done! Try: Media.show_image(\"path/to/photo.jpg\")"
        },

      }))


    end  # end setup_globals

    # ── Ruby <-> Sapphire conversion helpers ──────────────────────────────────

    def ruby_to_sapphire(val)
      case val
      when Hash  then SapphireHash.new(val.transform_values { |v| ruby_to_sapphire(v) })
      when Array then SapphireArray.new(val.map { |v| ruby_to_sapphire(v) })
      else val
      end
    end

    def sapphire_to_ruby(val)
      case val
      when SapphireHash  then val.map.transform_values { |v| sapphire_to_ruby(v) }
      when SapphireArray then val.elements.map { |v| sapphire_to_ruby(v) }
      else val
      end
    end

    # ─── Helpers ──────────────────────────────────────────────────────────────

    def truthy?(val)
      val != nil && val != false
    end

    def num(val)
      case val
      when Integer, Float then val
      when String
        begin
          val.include?('.') ? Float(val) : Integer(val)
        rescue ArgumentError
          raise SapphireError, "Cannot coerce '#{val}' to number"
        end
      when TrueClass  then 1
      when FalseClass then 0
      else raise SapphireError, "Expected number, got #{sapphire_type(val)}"
      end
    end

    def sapphire_to_s(val)
      case val
      when String          then val
      when NilClass        then "nil"
      when TrueClass       then "true"
      when FalseClass      then "false"
      when Integer, Float  then val.to_s
      when SapphireArray   then val.to_s
      when SapphireHash    then val.to_s
      when SapphireInstance
        if (m = val.klass.find_method('to_string'))
          call_fn(BoundMethod.new(val, m), []).to_s
        else
          val.to_s
        end
      else val.to_s
      end
    end

    def sapphire_type(val)
      case val
      when TrueClass, FalseClass then "Bool"
      when NilClass              then "Nil"
      when Integer               then "Int"
      when Float                 then "Float"
      when String                then "String"
      when SapphireArray         then "Array"
      when SapphireHash          then "Hash"
      when SapphireInstance      then val.sapphire_type
      when SapphireFunction      then "Function"
      when SapphireLambda        then "Lambda"
      when SapphireClass         then "Class"
      when BoundMethod           then "BoundMethod"
      when NativeFunction        then "NativeFunction"
      when HigherOrderMarker     then "Function"
      else "Unknown"
      end
    end

    def sapphire_eq(a, b)
      case a
      when SapphireArray
        b.is_a?(SapphireArray) && a.elements == b.elements
      when SapphireHash
        b.is_a?(SapphireHash) && a.map == b.map
      when NilClass
        b.nil?
      else
        a == b
      end
    end
  end
end
