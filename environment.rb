# Sapphire Environment — lexical scoping via linked environments

module Sapphire
  class Environment
    attr_reader :store, :parent

    def initialize(parent = nil)
      @parent  = parent
      @store   = {}
      @consts  = {}
    end

    def define(name, value, const: false)
      @store[name] = value
      @consts[name] = true if const
      value
    end

    def get(name)
      return @store[name] if @store.key?(name)
      return @parent.get(name) if @parent
      raise SapphireError, "Undefined variable '#{name}'"
    end

    def set(name, value)
      if @store.key?(name)
        raise SapphireError, "Cannot reassign constant '#{name}'" if @consts[name]
        @store[name] = value
      elsif @parent
        @parent.set(name, value)
      else
        raise SapphireError, "Undefined variable '#{name}'"
      end
      value
    end

    def defined?(name)
      return true if @store.key?(name)
      @parent ? @parent.defined?(name) : false
    end

    def child = Environment.new(self)
  end
end
