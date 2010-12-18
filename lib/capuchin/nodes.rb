
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

class RKelly::Nodes::Node
  def call_bytecode(v, g)
    v.pos(self)
    v.accept(self)
    g.push_nil
    arg_count = yield(2)
    g.send :js_call, arg_count + 1
  end
end
class RKelly::Nodes::DotAccessorNode
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
class RKelly::Nodes::BracketAccessorNode
  def get_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless key_safe?(o.left.accessor)
      pos(o.left.accessor)
      @g.send :js_key, 0
    end
    g.send :js_get, 1
  end
  def set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless key_safe?(o.left.accessor)
      pos(o.left.accessor)
      @g.send :js_key, 0
    end
    yield 2
    g.send :js_set, 2
  end
  def get_and_set_bytecode(v, g)
    v.pos(self)
    v.accept self.value
    v.accept self.accessor
    unless key_safe?(o.left.accessor)
      pos(o.left.accessor)
      @g.send :js_key, 0
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
    unless key_safe?(o.left.accessor)
      pos(o.left.accessor)
      @g.send :js_key, 0
    end
    arg_count = yield(2)
    g.send :js_invoke, arg_count + 1
  end
end
class RKelly::Nodes::ResolveNode
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
      g.send :[]=, 1
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
      g.send :[]=, 1
    end
  end
end

