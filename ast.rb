# Sapphire AST Node Definitions
module Sapphire
  module AST
    Node = Struct.new(:type)

    # Literals
    NumberLit    = Struct.new(:value)
    StringLit    = Struct.new(:value)
    TemplateLit  = Struct.new(:parts)       # array of StringLit or Expr
    BoolLit      = Struct.new(:value)
    NilLit       = Struct.new(:keyword)
    ArrayLit     = Struct.new(:elements)
    HashLit      = Struct.new(:pairs)       # [[key, val], ...]
    RangeLit     = Struct.new(:from, :to, :exclusive)
    Wildcard     = Struct.new(:_unused)     # _ in match patterns

    # Identifiers & Access
    Identifier   = Struct.new(:name, :line)
    GetAttr      = Struct.new(:object, :name)       # obj.name
    Index        = Struct.new(:object, :index)      # obj[idx]
    ScopeAccess  = Struct.new(:namespace, :name)    # Ns::Name

    # Declarations
    LetDecl      = Struct.new(:name, :value, :mutable, :type_hint)
    FnDecl       = Struct.new(:name, :params, :body, :is_method)
    ClassDecl    = Struct.new(:name, :superclass, :body)
    ImportDecl   = Struct.new(:path, :names)

    # Param
    Param        = Struct.new(:name, :default, :type_hint, :splat)

    # Expressions
    BinOp          = Struct.new(:op, :left, :right)
    UnaryOp        = Struct.new(:op, :operand)
    Assign         = Struct.new(:target, :value)
    CompoundAssign = Struct.new(:op, :target, :value)
    Call           = Struct.new(:callee, :args, :kwargs)
    New            = Struct.new(:class_name, :args, :kwargs)
    Lambda         = Struct.new(:params, :body)
    TypeOf         = Struct.new(:expr)
    Ternary        = Struct.new(:cond, :then_val, :else_val)   # cond ? a : b

    # Statements
    Block        = Struct.new(:stmts)
    Return       = Struct.new(:value)
    If           = Struct.new(:cond, :then_block, :elif_clauses, :else_block)
    While        = Struct.new(:cond, :body)
    For          = Struct.new(:var, :iterable, :body)
    Match        = Struct.new(:subject, :cases)
    MatchCase    = Struct.new(:pattern, :body)
    Break        = Struct.new(:keyword)
    Continue     = Struct.new(:keyword)
    Pass         = Struct.new(:keyword)
    Raise        = Struct.new(:value)
    TryCatch     = Struct.new(:body, :catch_var, :catch_body, :finally_body)
    Print        = Struct.new(:args, :newline)

    # Program root
    Program      = Struct.new(:stmts)
  end
end
