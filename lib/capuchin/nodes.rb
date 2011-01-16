
# For each of these: 
#
# get_bytecode(v, g) -- put the value on to the stack.
#
# set_bytecode(v, g, &block) -- yield to +block+ for the value to save.
# block's net stack effect should be +1.
#
# get_and_set_bytecode(v, g, &block) -- yield to +block+ as per
# +set_bytecode+, but with the current value on the top of the stack.
# block's net stack effect should be 0.
#
# block[n] -- given the number of "internal" stack entries have been
# added; these should be undisturbed when the block is finished.

module Capuchin::Nodes
class Node
  include Capuchin::Visitable
  def call_bytecode(v, g)
    v.pos(self)
    v.accept(self)
    g.push_nil
    arg_count = yield(2)
    g.send :js_call, arg_count + 1
  end

  def filename; end
  def line; 1; end
end
class RootNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
end

class ThisNode < Node; end
class NullNode < Node; end
class TrueNode < Node; end
class FalseNode < Node; end

class LiteralNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
end
class NumberNode < LiteralNode; end
class StringNode < LiteralNode; end
class RegexpNode < LiteralNode; end
class ObjectLiteralNode < LiteralNode; end

class FunctionDeclNode < Node
  attr_accessor :value, :function_body, :arguments
  def initialize(value, function_body, arguments)
    @value, @function_body, @arguments = value, function_body, arguments
  end
end
class FunctionExprNode < Node
  attr_accessor :value, :function_body, :arguments
  def initialize(value, function_body, arguments)
    @value, @function_body, @arguments = value, function_body, arguments
  end
end
class FunctionCallNode < Node
  attr_accessor :value, :arguments
  def initialize(value, arguments)
    @value, @arguments = value, arguments
  end
end
class NewExprNode < FunctionCallNode; end

class ReturnNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
end
class ExpressionStatementNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
end

class UnaryNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
end
class PrefixNode < UnaryNode
  attr_accessor :operand
  def initialize(value, operand)
    super(value)
    @operand = operand
  end
end
class PostfixNode < UnaryNode
  attr_accessor :operand
  def initialize(value, operand)
    super(value)
    @operand = operand
  end
end
class DeleteNode < UnaryNode; end
class VoidNode < UnaryNode; end
class TypeOfNode < UnaryNode; end
class UnaryPlusNode < UnaryNode; end
class UnaryMinusNode < UnaryNode; end
class BitwiseNotNode < UnaryNode; end
class LogicalNotNode < UnaryNode; end

class BinaryNode < Node
  attr_accessor :left, :value
  def initialize(left, value)
    @left, @value = left, value
  end
end
class MultiplyNode < BinaryNode; end
class DivideNode < BinaryNode; end
class ModulusNode < BinaryNode; end
class AddNode < BinaryNode; end
class SubtractNode < BinaryNode; end
class LeftShiftNode < BinaryNode; end
class RightShiftNode < BinaryNode; end
class UnsignedRightShiftNode < BinaryNode; end
class LessNode < BinaryNode; end
class GreaterNode < BinaryNode; end
class LessOrEqualNode < BinaryNode; end
class GreaterOrEqualNode < BinaryNode; end
class InstanceOfNode < BinaryNode; end
class InNode < BinaryNode; end
class EqualNode < BinaryNode; end
class NotEqualNode < BinaryNode; end
class StrictEqualNode < BinaryNode; end
class NotStrictEqualNode < BinaryNode; end
class BitAndNode < BinaryNode; end
class BitXOrNode < BinaryNode; end
class BitOrNode < BinaryNode; end
class LogicalAndNode < BinaryNode; end
class LogicalOrNode < BinaryNode; end

class OpEqualNode < BinaryNode; end
class OpPlusEqualNode < BinaryNode; end
class OpMinusEqualNode < BinaryNode; end
class OpMultiplyEqualNode < BinaryNode; end
class OpDivideEqualNode < BinaryNode; end
class OpLShiftEqualNode < BinaryNode; end
class OpRShiftEqualNode < BinaryNode; end
class OpURShiftEqualNode < BinaryNode; end
class OpAndEqualNode < BinaryNode; end
class OpXOrEqualNode < BinaryNode; end
class OpOrEqualNode < BinaryNode; end
class OpModEqualNode < BinaryNode; end

class CommaNode < BinaryNode; end

class ConditionalNode < Node
  attr_accessor :conditions, :value, :else
  def initialize(conditions, value, else_)
    @conditions, @value, @else = conditions, value, else_
  end
end

class VarDeclNode < Node
  attr_accessor :name, :value, :const
  def initialize(name, value, const=false)
    @name, @value, @const = name, value, const
  end
end
class PropertyNode < Node
  attr_accessor :name, :value
  def initialize(name, value)
    @name, @value = name, value
  end
end

class IfNode < Node
  attr_accessor :conditions, :value, :else
  def initialize(conditions, value, else_)
    @conditions, @value, @else = conditions, value, else_
  end
end
class BlockNode < Node
  attr_accessor :statements
  def initialize(statements)
    @statements = statements
  end
end

class DotAccessorNode < Node
  attr_accessor :value, :accessor
  def initialize(value, accessor)
    @value, @accessor = value, accessor
  end
  def get_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    g.push_literal self.accessor.to_sym
    g.send :js_get, 1
  end
  def set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    g.push_literal self.accessor.to_sym
    yield 2
    g.send :js_set, 2
  end
  def get_and_set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    g.push_literal self.accessor.to_sym
    g.dup_many 2
    g.send :js_get, 1
    yield 2
    g.send :js_set, 2
  end
  def call_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.pos(self)
    g.push_literal self.accessor.to_sym
    arg_count = yield(2)
    g.send :js_invoke, arg_count + 1
  end
end
class BracketAccessorNode < Node
  attr_accessor :value, :accessor
  def initialize(value, accessor)
    @value, @accessor = value, accessor
  end
  def get_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless v.key_safe?(self.accessor)
      v.pos(self.accessor)
      g.send :js_key, 0
    end
    g.send :js_get, 1
  end
  def set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless v.key_safe?(self.accessor)
      v.pos(self.accessor)
      g.send :js_key, 0
    end
    yield 2
    g.send :js_set, 2
  end
  def get_and_set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless v.key_safe?(self.accessor)
      v.pos(self.accessor)
      g.send :js_key, 0
    end
    g.dup_many 2
    g.send :js_get, 1
    yield 2
    g.send :js_set, 2
  end
  def call_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.pos(self)
    v.accept self.accessor
    unless v.key_safe?(self.accessor)
      v.pos(self.accessor)
      g.send :js_key, 0
    end
    arg_count = yield(2)
    g.send :js_invoke, arg_count + 1
  end
end
class ResolveNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def get_bytecode(v, g)
    v.pos(self)
    if ref = g.state.scope.search_local(self.value.to_sym)
      ref.get_bytecode(g)
    else
      g.push_const :Capuchin
      g.find_const :Globals
      g.push_literal self.value.to_sym
      g.send :[], 1
    end
  end
  def set_bytecode(v, g)
    v.pos(self)
    if ref = g.state.scope.search_local(self.value.to_sym)
      yield 0
      ref.set_bytecode(g)
    else
      g.push_const :Capuchin
      g.find_const :Globals
      g.push_literal self.value.to_sym
      yield 2
      g.send :[]=, 2
    end
  end
  def get_and_set_bytecode(v, g)
    v.pos(self)
    if ref = g.state.scope.search_local(self.value.to_sym)
      ref.get_bytecode(g)
      yield 0
      ref.set_bytecode(g)
    else
      g.push_const :Capuchin
      g.find_const :Globals
      g.push_literal self.value.to_sym
      g.dup_many 2
      g.send :[], 1
      yield 2
      g.send :[]=, 2
    end
  end
end
end

