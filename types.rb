# Sapphire Built-in Types

module Sapphire
  # ─── Control flow signals ────────────────────────────────────────────────────
  class ReturnSignal   < StandardError; attr_reader :value; def initialize(v); @value = v; end; end
  class BreakSignal    < StandardError; end
  class ContinueSignal < StandardError; end
  class RaiseSignal    < StandardError; attr_reader :value; def initialize(v); @value = v; end; end

  # ─── Sapphire Function ───────────────────────────────────────────────────────
  class SapphireFunction
    attr_reader :name, :params, :body, :closure

    def initialize(name, params, body, closure)
      @name    = name
      @params  = params
      @body    = body
      @closure = closure
    end

    def to_s = "<fn #{@name}>"
    def sapphire_type = "Function"
    def arity = @params.count { |p| p.default.nil? && !p.splat }
  end

  # ─── Sapphire Lambda ─────────────────────────────────────────────────────────
  class SapphireLambda < SapphireFunction
    def initialize(params, body, closure)
      super('<lambda>', params, body, closure)
    end
    def to_s = "<lambda>"
    def sapphire_type = "Lambda"
  end

  # ─── Sapphire Class ──────────────────────────────────────────────────────────
  class SapphireClass
    attr_reader :name, :methods, :superclass

    def initialize(name, methods, superclass = nil)
      @name       = name
      @methods    = methods
      @superclass = superclass
    end

    def find_method(name)
      @methods[name] || @superclass&.find_method(name)
    end

    def to_s = "<class #{@name}>"
    def sapphire_type = "Class"
  end

  # ─── Sapphire Instance ───────────────────────────────────────────────────────
  class SapphireInstance
    attr_reader :klass
    attr_accessor :fields

    def initialize(klass)
      @klass  = klass
      @fields = {}
    end

    def get(name)
      return @fields[name] if @fields.key?(name)
      method = @klass.find_method(name)
      raise SapphireError, "Undefined property '#{name}' on #{@klass.name}" unless method
      BoundMethod.new(self, method)
    end

    def set(name, value)
      @fields[name] = value
    end

    def to_s = "<#{@klass.name} instance>"
    def sapphire_type = @klass.name
  end

  # ─── Bound Method ────────────────────────────────────────────────────────────
  class BoundMethod
    attr_reader :receiver, :method

    def initialize(receiver, method)
      @receiver = receiver
      @method   = method
    end

    def to_s = "<bound #{@method.name}>"
    def sapphire_type = "BoundMethod"
    def name    = @method.name
    def params  = @method.params
    def body    = @method.body
    def closure = @method.closure
  end

  # ─── Native Function ─────────────────────────────────────────────────────────
  class NativeFunction
    attr_reader :name, :arity

    def initialize(name, arity: -1, &block)
      @name  = name
      @arity = arity
      @block = block
    end

    def call(*args)
      @block.call(*args)
    end

    def to_s = "<native fn #{@name}>"
    def sapphire_type = "NativeFunction"
  end

  # ─── Sapphire Array ──────────────────────────────────────────────────────────
  class SapphireArray
    attr_accessor :elements

    def initialize(elements = [])
      @elements = elements
    end

    # NOTE: map/filter/each/sort_by take a callable (fn/lambda) and a caller block
    # The interpreter patches these after creation via make_higher_order
    def get(name)
      case name
      when 'length'    then @elements.length
      when 'push'      then NativeFunction.new('push')     { |v| @elements << v; self }
      when 'pop'       then NativeFunction.new('pop')      { @elements.pop }
      when 'shift'     then NativeFunction.new('shift')    { @elements.shift }
      when 'unshift'   then NativeFunction.new('unshift')  { |v| @elements.unshift(v); self }
      when 'first'     then @elements.first
      when 'last'      then @elements.last
      when 'reverse'   then SapphireArray.new(@elements.reverse)
      when 'join'      then NativeFunction.new('join')     { |sep = ', '| @elements.map { |e| e.is_a?(String) ? e : sapphire_to_s(e) }.join(sep) }
      when 'include?'  then NativeFunction.new('include?') { |v| @elements.include?(v) }
      when 'empty?'    then @elements.empty?
      when 'flatten'   then SapphireArray.new(@elements.flatten)
      when 'uniq'      then SapphireArray.new(@elements.uniq)
      when 'sort'      then SapphireArray.new(@elements.sort)
      when 'min'       then @elements.min
      when 'max'       then @elements.max
      when 'sum'       then @elements.sum
      when 'slice'     then NativeFunction.new('slice')    { |from, len| SapphireArray.new(@elements.slice(from, len) || []) }
      when 'index_of'  then NativeFunction.new('index_of') { |v| @elements.index(v) || -1 }
      when 'to_string' then to_s
      when 'contains?' then NativeFunction.new('contains?'){ |v| @elements.include?(v) }
      when 'count'     then @elements.length
      # Higher-order methods — interpreter must wrap these:
      when 'map', 'filter', 'each', 'reduce', 'find', 'any?', 'all?', 'none?', 'sort_by', 'flat_map'
        HigherOrderMarker.new(name, self)
      else
        raise SapphireError, "Array has no property '#{name}'"
      end
    end

    def [](i)   = @elements[i]
    def []=(i,v); @elements[i] = v; end

    def to_s
      "[#{@elements.map { |e| sapphire_to_s(e) }.join(', ')}]"
    end

    def sapphire_type = "Array"

    private

    def sapphire_to_s(v)
      case v
      when String   then "\"#{v}\""
      when NilClass then "nil"
      else v.to_s
      end
    end
  end

  # Marker so the interpreter knows it needs to wrap the call with a fn caller
  class HigherOrderMarker
    attr_reader :method_name, :receiver
    def initialize(name, receiver)
      @method_name = name
      @receiver    = receiver
    end
    def sapphire_type = "HigherOrderMethod"
    def to_s = "<higher-order #{@method_name}>"
  end

  # ─── Sapphire Hash ───────────────────────────────────────────────────────────
  class SapphireHash
    attr_accessor :map

    def initialize(map = {})
      @map = map
    end

    def get(name)
      return @map[name] if @map.key?(name)
      case name
      when 'keys'      then SapphireArray.new(@map.keys)
      when 'values'    then SapphireArray.new(@map.values)
      when 'length'    then @map.length
      when 'has?'      then NativeFunction.new('has?')    { |k| @map.key?(k) }
      when 'delete'    then NativeFunction.new('delete')  { |k| @map.delete(k); self }
      when 'merge'     then NativeFunction.new('merge')   { |other| SapphireHash.new(@map.merge(other.is_a?(SapphireHash) ? other.map : {})) }
      when 'to_string' then to_s
      when 'each'      then HigherOrderMarker.new('hash_each', self)
      when 'map'       then HigherOrderMarker.new('hash_map', self)
      when 'to_array'  then SapphireArray.new(@map.map { |k, v| SapphireArray.new([k, v]) })
      else nil  # hash misses return nil
      end
    end

    def []=(k, v); @map[k] = v; end
    def [](k)    = @map[k]

    def to_s
      pairs = @map.map do |k, v|
        val_str = case v
                  when String         then "\"#{v}\""
                  when SapphireArray  then v.to_s
                  when SapphireHash   then v.to_s
                  when NilClass       then "nil"
                  when TrueClass, FalseClass then v.to_s
                  else v.to_s
                  end
        "#{k}: #{val_str}"
      end.join(', ')
      "{#{pairs}}"
    end

    def sapphire_type = "Hash"
  end
end
