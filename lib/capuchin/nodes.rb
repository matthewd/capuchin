
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
  def visit(g)
    g.accept value
  end
end

class ThisNode < Node
  def visit(g); end
end
class NullNode < Node
  def visit(g); end
end
class TrueNode < Node
  def visit(g); end
end
class FalseNode < Node
  def visit(g); end
end

class LiteralNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g); end
end
class NumberNode < LiteralNode; end
class StringNode < LiteralNode; end
class RegexpNode < LiteralNode; end
class ObjectLiteralNode < LiteralNode
  def visit(g)
    value.each do |prop|
      g.accept prop
    end
  end
end
class ArrayNode < LiteralNode
  def visit(g)
    value.each do |el|
      g.accept el
    end
  end
end

class FunctionDeclNode < Node
  attr_accessor :value, :function_body, :arguments
  def initialize(value, function_body, arguments)
    @value, @function_body, @arguments = value, function_body, arguments
  end
  def visit(g)
    g.accept function_body
  end
end
class FunctionExprNode < Node
  attr_accessor :value, :function_body, :arguments
  def initialize(value, function_body, arguments)
    @value, @function_body, @arguments = value, function_body, arguments
  end
  def visit(g)
    g.accept function_body
  end
end
class FunctionCallNode < Node
  attr_accessor :value, :arguments
  def initialize(value, arguments)
    @value, @arguments = value, arguments
  end
  def visit(g)
    g.accept value
    arguments.each do |arg|
      g.accept arg
    end
  end
end
class NewExprNode < FunctionCallNode; end

class BreakNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value if value
  end
end
class ContinueNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value if value
  end
end
class ReturnNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value if value
  end
end
class ThrowNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value
  end
end
class ExpressionStatementNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value
  end
end

class UnaryNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value
  end
end
class PrefixNode < UnaryNode
  attr_accessor :operand
  def initialize(value, operand)
    super(value)
    @operand = operand
  end
  def visit(g)
    g.accept operand
  end
end
class PostfixNode < UnaryNode
  attr_accessor :operand
  def initialize(value, operand)
    super(value)
    @operand = operand
  end
  def visit(g)
    g.accept operand
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
  def visit(g)
    g.accept left
    g.accept value
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
  def visit(g)
    g.accept conditions
    g.accept value
    g.accept self.else
  end
end

class VarStatementNode < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def visit(g)
    g.accept value
  end
end
class VarDeclNode < Node
  attr_accessor :name, :value, :const
  def initialize(name, value, const=false)
    @name, @value, @const = name, value, const
  end
  def visit(g)
    g.accept value if value
  end
end
class PropertyNode < Node
  attr_accessor :name, :value
  def initialize(name, value)
    @name, @value = name, value
  end
  def visit(g)
    g.accept value
  end
end

class ForNode < Node
  attr_accessor :init, :test, :counter, :value
  def initialize(init, test, counter, value)
    @init, @test, @counter, @value = init, test, counter, value
  end
  def visit(g)
    g.accept init if init
    g.accept test if test
    g.accept counter if counter
    g.accept value
  end
end
class DoWhileNode < Node
  attr_accessor :left, :value
  def initialize(left, value)
    @left, @value = left, value
  end
  def visit(g)
    g.accept left
    g.accept value
  end
end
class WhileNode < Node
  attr_accessor :left, :value
  def initialize(left, value)
    @left, @value = left, value
  end
  def visit(g)
    g.accept left
    g.accept value
  end
end
class IfNode < Node
  attr_accessor :conditions, :value, :else
  def initialize(conditions, value, else_)
    @conditions, @value, @else = conditions, value, else_
  end
  def visit(g)
    g.accept conditions
    g.accept value
    g.accept self.else if self.else
  end
end
class TryNode < Node
  attr_accessor :value, :catch_var, :catch_block, :finally_block
  def initialize(value, catch_var, catch_block, finally_block)
    @value, @catch_var, @catch_block, @finally_block = value, catch_var, catch_block, finally_block
  end
  def visit(g)
    g.accept value
    g.accept catch_block if catch_block
    g.accept finally_block if finally_block
  end
end
class SwitchNode < Node
  attr_accessor :left, :value
  def initialize(left, value)
    @left, @value = left, value
  end
  def visit(g)
    g.accept left
    g.accept value
  end
end
class CaseClauseNode < Node
  attr_accessor :left, :value
  def initialize(left, value)
    @left, @value = left, value
  end
  def visit(g)
    g.accept left if left
    g.accept value
  end
end
class BlockNode < Node
  attr_accessor :statements
  def initialize(statements)
    @statements = statements
  end
  def visit(g)
    statements.each do |st|
      g.accept st
    end
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
  def visit(g)
    g.accept value
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
  def visit(g)
    g.accept value
    g.accept accessor
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
  def visit(g)
  end
end
end

