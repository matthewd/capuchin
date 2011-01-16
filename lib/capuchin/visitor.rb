
module Capuchin::Visitable
  # Based off the visitor pattern from RubyGarden
  def accept(visitor, &block)
    klass = self.class.ancestors.find { |ancestor|
      visitor.respond_to?("visit_#{ancestor.name.split(/::/)[-1]}")
    }

    if klass
      visitor.send(:"visit_#{klass.name.split(/::/)[-1]}", self, &block)
    else
      raise "#{visitor.class}: No visitor for '#{self.class}'"
    end
  end
end

class Capuchin::Visitor
  def accept(target)
    if Array === target
      target.each do |x|
        accept(x)
      end
    else
      target.accept(self)
    end
  end
end

class Capuchin::CompileVisitor < Capuchin::Visitor
  class DeclScanner < Capuchin::Visitor
    def initialize(scope)
      @scope = scope
    end

    def visit_ResolveNode(o)
      @scope.need_arguments! if o.value.to_sym == :arguments
    end
    def visit_VarDeclNode(o)
      name = o.name.to_sym
      @scope.add_variable name, o
    end
    def visit_FunctionDeclNode(o)
      name = o.value.to_sym
      @scope.add_variable name, o

      @scope.add_method do |g,v|
        v.pos(o)
        g.push_const :Capuchin
        g.find_const :Function
        g.push_literal o.value.to_sym
        g.create_block v.compile_method(o.line, o.value, o.arguments, o.function_body)
        g.send_with_block :new, 1

        var = g.state.scope.variables[o.value.to_sym]
        var.reference.set_bytecode(g)
        g.pop
      end
    end

    # Anything we haven't defined a particular visitor for, we just
    # ignore; we're only looking for a few statements that can only
    # appear at the top level.
    def visit_Node(o); end
  end

  class Scope
    include Rubinius::Compiler::LocalVariables
    def initialize(parent)
      @parent = parent
      @buffered_variables = []
      @methods = []
      @need_arguments = false
      @loops = []
      @labels = []
    end
    def need_arguments!; @need_arguments = true; end
    def need_arguments?; @need_arguments; end

    def add_variable(name, o)
      if @buffered_variables.include?(name)
        # Don't complain; just silently ignore it.
        #raise "Duplicate variable #{name}? (#{o.filename}:#{o.line})"
      else
        @buffered_variables << name
      end
    end
    def new_local(name)
      variable = Rubinius::Compiler::LocalVariable.new allocate_slot
      variables[name] = variable
    end
    def new_nested_local(name)
      new_local(name).nested_reference
    end

    def add_method(&block)
      @methods << block
    end
    def append_buffered_definitions(g, v)
      @buffered_variables.each do |var|
        new_local(var)
      end
      @methods.each do |defn|
        defn.call(g, v)
      end
    end

    # This is confusing; line_label_name is a symbol, containing the
    # name assigned to the line within the JS source (where it's known
    # as a label). continue_label and break_label, on the other hand,
    # are Rubinius generator labels for use in goto insns.
    def with_loop(line_label_name, continue_label, break_label)
      @loops << [line_label_name, continue_label, break_label]
      yield
    ensure
      @loops.pop
    end

    def with_line_label(label)
      @labels << label
      yield
    ensure
      @labels.pop
    end

    def current_line_label
      return nil if @labels.empty?
      label = @labels.pop
      @labels.push nil
      return label
    end

    def find_continue_target(target=nil)
      loops = @loops
      loops = loops.select {|l| l[0] == target } if target
      loops = loops.select {|l| l[1] }
      return loops.last[1] unless loops.empty?
      find_break_target(target)
    end

    def find_break_target(target=nil)
      loops = @loops
      loops = loops.select {|l| l[0] == target } if target
      loops.last[2]
    end


    def search_local(name)
      if variable = variables[name]
        variable.nested_reference
      elsif @parent && reference = @parent.search_local(name)
        reference.depth += 1
        reference
      end
    end
  end

  def initialize(g, scope=nil)
    @g = g
    @scope = scope || Scope.new(nil)
    @g.push_state scope if scope
  end
  def pos(o)
    @g.file = o.filename.intern if o.filename
    @g.set_line o.line unless o.line.nil?
  end
  def with_scope(scope=Scope.new(@scope))
    old_scope, @scope = @scope, scope
    @g.push_state @scope
    yield
  ensure
    @g.pop_state
    @scope = old_scope
  end

  def visit_TrueNode(o)
    pos(o)
    @g.push_true
  end
  def visit_FalseNode(o)
    pos(o)
    @g.push_false
  end
  def visit_NullNode(o)
    pos(o)
    @g.push_nil
  end
  def visit_ThisNode(o)
    pos(o)
    @g.push_self
  end
  def visit_FunctionExprNode(o)
    pos(o)
    @g.push_const :Capuchin
    @g.find_const :Function
    @g.push_literal o.value.to_sym
    @g.create_block compile_method(o.line, o.value, o.arguments, o.function_body)
    @g.send_with_block :new, 1
  end
  def visit_FunctionDeclNode(o)
    # The entire definition was pulled up by DeclScanner; nothing to do
    # now.
  end

  def new_generator(name, arguments=[])
    meth = @g.class.new
    meth.name = name.to_sym
    meth.file = @g.file

    meth.required_args = #0
    meth.total_args = arguments.size

    meth
  end
  def new_visitor(g)
    self.class.new(g)
  end
  def compile_method(line, name, arguments, body)
    meth = new_generator(name, arguments)

    v = new_visitor(meth)

    v.with_scope(Scope.new(@scope)) do
      #meth.state.push_super self

      meth.state.push_name name

      meth.set_line line

      DeclScanner.new(meth.state.scope).accept(body)

      if meth.state.scope.need_arguments? || arguments.size > 0
        # We use "block-style" arguments; our parameters are in an
        # array-like object on the stack
        meth.cast_for_splat_block_arg

        if meth.state.scope.need_arguments?
          unless arguments.empty?
            meth.dup
            meth.send :dup, 0
          end
          var = meth.state.scope.new_local(:arguments)
          var.reference.set_bytecode(meth)
          meth.pop
        end

        unless arguments.empty?
          arguments.each do |a|
            var = meth.state.scope.new_local(a.to_sym)
            meth.shift_array
            var.reference.set_bytecode(meth)
            meth.pop
          end
          meth.pop
        end

        # Marker between arg processing and function body, for quick scanning of
        # the generated bytecode
        meth.noop
      end

      meth.state.scope.append_buffered_definitions meth, v
      v.accept(body)

      meth.state.pop_name

      meth.local_count = meth.state.scope.local_count
      meth.local_names = meth.state.scope.local_names

      meth.set_line line

      meth.push_nil
      meth.ret
      meth.close
    end

    meth
  end

  def visit_VarDeclNode(o)
    var = @g.state.scope.variables[o.name.to_sym]
    if o.value
      accept o.value

      pos(o)
      var.reference.set_bytecode(@g)
      @g.pop
    end
  end
  def visit_ResolveNode(o)
    o.get_bytecode(self, @g)
  end
  def visit_ExpressionStatementNode(o)
    accept o.value
    pos(o)
    @g.pop
  end
  def visit_ArrayNode(o)
    o.value.each do |entry|
      accept entry
    end
    pos(o)
    @g.make_array o.value.size
  end
  def visit_DotAccessorNode(o)
    o.get_bytecode(self, @g)
  end
  def key_safe?(o)
    Capuchin::Nodes::NumberNode === o && Fixnum === o.value
  end
  def visit_BracketAccessorNode(o)
    o.get_bytecode(self, @g)
  end
  def visit_RegexpNode(o)
    unless o.value =~ %r{^/(.*)/([a-z]*)$}
      raise ArgumentError, "Unexpected RegexpNode format"
    end

    regexp_string = $1
    flags = $2


    slot = @g.add_literal(nil)
    done = @g.new_label

    @g.push_literal_at(slot)
    @g.dup
    @g.git done
    @g.pop

    @g.push_const :Capuchin
    @g.find_const :Globals
    @g.push_literal :RegExp
    @g.send :[], 1
    @g.push_literal regexp_string
    if flags != ''
      @g.push_literal flags
      @g.send :js_new, 2
    else
      @g.send :js_new, 1
    end
    @g.set_literal slot

    done.set!
    @g.send :dup, 0
  end
  def visit_StringNode(o)
    pos(o)
    str = o.value[1, o.value.size - 2]
    str.gsub!(/\\(?:([bfnrtv'"\\])|([0-3][0-7]{0,2}|[4-7][0-7]?)|x([A-Fa-f0-9]{2})|u([A-Fa-f0-9]{4}))/) do
      if $1
        case $1
        when 'b'; "\b"
        when 'f'; "\f"
        when 'n'; "\n"
        when 'r'; "\r"
        when 't'; "\t"
        when 'v'; "\v"
        else; $1
        end
      elsif $2
        $2.to_i(8).chr
      elsif $3
        $3.to_i(16).chr
      else
        codepoint = $4.to_i(16)
        if codepoint > 255
          raise NotImplementedError, "utf-16"
        else
          codepoint.chr
        end
      end
    end
    @g.push_literal str
  end
  def visit_NumberNode(o)
    pos(o)
    @g.push_literal o.value
  end
  def visit_ObjectLiteralNode(o)
    @g.push_const :Hash
    @g.send :new, 0
    o.value.each do |prop|
      accept prop
    end
  end
  def visit_PropertyNode(o)
    @g.dup
    @g.push_literal o.name.to_sym
    accept o.value
    @g.send :[]=, 2
    @g.pop
  end
  def visit_IfNode(o)
    accept o.conditions
    pos(o)
    after = @g.new_label
    if o.else
      alternate = @g.new_label
      @g.giz alternate, o.conditions
      accept o.value
      pos(o.else)
      @g.goto after
      alternate.set!
      accept o.else
    else
      @g.giz after, o.conditions
      accept o.value
    end
    after.set!
  end
  def visit_BlockNode(o)
    o.statements.each do |st|
      accept st
    end
  end
  def visit_TypeOfNode(o)
    accept o.value
    pos(o)
    @g.send :js_typeof, 0
  end
  def visit_VoidNode(o)
    accept o.value
    pos(o)
    @g.pop
    @g.push_nil
  end
  def visit_CommaNode(o)
    accept o.left
    pos(o)
    @g.pop
    accept o.value
  end
  def visit_NewExprNode(o)
    # see also: call_bytecode in nodes.rb
    accept o.value
    args = o.arguments
    o.arguments.each do |arg|
      accept arg
    end
    pos(o)
    @g.send :js_new, args.size
  end
  def visit_ForInNode(o)
    # for (LEFT in RIGHT) VALUE
    lbl = @g.state.scope.current_line_label
    raise NotImplementedError, "for .. in"
  end
  def visit_BreakNode(o)
    pos(o)
    @g.goto @g.state.scope.find_break_target(o.value && o.value.to_sym)
  end
  def visit_ContinueNode(o)
    pos(o)
    @g.goto @g.state.scope.find_continue_target(o.value && o.value.to_sym)
  end
  def visit_ThrowNode(o)
    # o.value
    raise NotImplementedError, "throw"
  end
  def visit_DeleteNode(o)
    # o.value
    raise NotImplementedError, "delete"
  end

  def visit_SwitchNode(o)
    # We cheat here, and reach down into our case nodes, because we loop
    # through them twice: once to build the sequence of compare+gotos,
    # then again to output the actual code blocks.

    lbl = @g.state.scope.current_line_label
    done = @g.new_label

    accept o.left
    pos(o)
    if cases = o.value.value
      has_default = false
      cases = cases.map {|c| [c, @g.new_label] }
      cases.each do |(c,code)|
        if c.left
          try_next = @g.new_label
          pos(c.left)
          @g.dup
          accept c.left
          @g.meta_send_op_equal @g.find_literal(:js_equal)
          @g.gif try_next

          # We've found a match, so ditch the spare copy of our
          # comparison value, then run this case block. We must do the
          # pop here because control structures aren't permitted to
          # leave values on the stack while running arbitrary
          # statements; it would interfere with break/continue handling.
          @g.pop
          @g.goto code
          try_next.set!
        else
          pos(c)
          @g.pop
          @g.goto code
          has_default = true
          break
        end
      end
      unless has_default
        pos(o)
        @g.pop
        @g.goto done
      end
      @g.state.scope.with_loop lbl, nil, done do
        cases.each do |(c,code)|
          code.set!
          accept c.value
        end
      end
    end
    done.set!
  end

  def visit_WithNode(o)
    # o.left, o.value
    raise NotImplementedError, "with"
  end

  def visit_LabelNode(o)
    pos(o)
    @g.state.scope.with_line_label(o.name.to_sym) do
      accept o.value
    end
  end

  def visit_ForNode(o)
    pos(o)
    lbl = @g.state.scope.current_line_label

    if o.init
      accept o.init
      unless Capuchin::Nodes::VarStatementNode === o.init
        pos(o.init)
        @g.pop
      end
    end

    top = @g.new_label
    done = @g.new_label
    continue = @g.new_label

    top.set!
    if o.test
      accept o.test
      pos(o.test)
      @g.giz done, o.test
    end

    @g.state.scope.with_loop(lbl, continue, done) do
      accept o.value
    end

    continue.set!
    if o.counter
      accept o.counter
      pos(o.counter)
      @g.pop
    end
    pos(o)
    @g.goto top

    done.set!
  end
  def visit_DoWhileNode(o)
    lbl = @g.state.scope.current_line_label
    again = @g.new_label

    again.set!
    accept o.left
    accept o.value
    pos(o)
    @g.giz again, o.value
  end
  def visit_WhileNode(o)
    lbl = @g.state.scope.current_line_label
    again = @g.new_label
    nope = @g.new_label

    again.set!
    accept o.left
    pos(o)
    @g.giz nope, o.left

    accept o.value
    pos(o)
    @g.goto again

    nope.set!
  end

  def visit_TryNode(o)
    # FIXME: Ignores catch
    accept o.value
    accept o.finally_block if o.finally_block
  end

  def visit_ReturnNode(o)
    pos(o)

    if o.value
      accept o.value
      pos(o)
    else
      @g.push_nil
    end
    @g.ret
  end

  def visit_PrefixNode(o)
    o.operand.get_and_set_bytecode(self, @g) do |n|
      @g.meta_push_1
      case o.value
      when '++'
        @g.meta_send_op_plus @g.find_literal(:+)
      when '--'
        @g.meta_send_op_minus @g.find_literal(:-)
      end
    end
  end
  def visit_PostfixNode(o)
    o.operand.get_and_set_bytecode(self, @g) do |n|
      @g.dup
      @g.move_down n + 1 if n > 0
      @g.meta_push_1
      case o.value
      when '++'
        @g.meta_send_op_plus @g.find_literal(:+)
      when '--'
        @g.meta_send_op_minus @g.find_literal(:-)
      end
    end
    pos(o)
    @g.pop
  end

  [
    [ :Add,       :js_add,  :OpPlusEqual,   :meta_send_op_plus  ],
    [ :Subtract,  :-,       :OpMinusEqual,  :meta_send_op_minus ],
    [ :Greater,   :js_gt,   nil,            :meta_send_op_gt    ],
    [ :Less,      :js_lt,   nil,            :meta_send_op_lt    ],
  ].each do |name,op,eq,meta|
    define_method(:"visit_#{name}Node") do |o|
      accept o.left
      accept o.value
      pos(o)
      @g.__send__ meta, @g.find_literal(op)
    end
    if eq
      define_method(:"visit_#{eq}Node") do |o|
        o.left.get_and_set_bytecode(self, @g) do |n|
          accept o.value
          pos(o)
          @g.__send__ meta, @g.find_literal(op)
        end
      end
    end
  end

  [
    [ :BitAnd,              :&,       :OpAndEqual      ],
    [ :BitOr,               :|,       :OpOrEqual       ],
    [ :BitXOr,              :^,       :OpXOrEqual      ],
    [ :Divide,              :js_div,  :OpDivideEqual   ],
    [ :LeftShift,           :<<,      :OpLShiftEqual   ],
    [ :Modulus,             :%,       :OpModEqual      ],
    [ :Multiply,            :*,       :OpMultiplyEqual ],
    [ :RightShift,          :>>,      :OpRShiftEqual   ],
    [ :UnsignedRightShift,  :">>>",   :OpURShiftEqual  ],
    [ :GreaterOrEqual,      :js_gte,  nil              ],
    [ :LessOrEqual,         :js_lte,  nil              ],
  ].each do |name,op,eq|
    define_method(:"visit_#{name}Node") do |o|
      accept o.left
      accept o.value
      pos(o)
      @g.send op, 1
    end
    if eq
      define_method(:"visit_#{eq}Node") do |o|
        o.left.get_and_set_bytecode(self, @g) do |n|
          accept o.value
          pos(o)
          @g.send op, 1
        end
      end
    end
  end

  def visit_LogicalNotNode(o)
    a = @g.new_label
    b = @g.new_label
    accept o.value
    pos(o)
    @g.gnz a, o.value
    @g.push_true
    @g.goto b
    a.set!
    @g.push_false
    b.set!
  end
  def visit_LogicalAndNode(o)
    done = @g.new_label
    accept o.left
    pos(o)
    @g.dup
    @g.giz done, o.left
    @g.pop
    accept o.value
    done.set!
  end
  def visit_LogicalOrNode(o)
    done = @g.new_label
    accept o.left
    pos(o)
    @g.dup
    @g.gnz done, o.left
    @g.pop
    accept o.value
    done.set!
  end
  def visit_ConditionalNode(o)
    after = @g.new_label
    alternate = @g.new_label
    accept o.conditions
    pos(o)
    @g.giz alternate, o.conditions
    accept o.value
    pos(o)
    @g.goto after
    alternate.set!
    accept o.else
    after.set!
  end


  def visit_EqualNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.meta_send_op_equal @g.find_literal(:js_equal)
  end
  def visit_StrictEqualNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.meta_send_op_equal @g.find_literal(:js_strict_equal)
  end
  def visit_NotEqualNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.meta_send_op_equal @g.find_literal(:js_equal)

    alt = @g.new_label
    done = @g.new_label
    @g.git alt
    @g.push_true
    @g.goto done

    alt.set!
    @g.push_false
    done.set!
  end
  def visit_NotStrictEqualNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.meta_send_op_equal @g.find_literal(:js_strict_equal)

    alt = @g.new_label
    done = @g.new_label
    @g.git alt
    @g.push_true
    @g.goto done

    alt.set!
    @g.push_false
    done.set!
  end

  def visit_BitwiseNotNode(o)
    accept o.value
    pos(o)
    @g.send :~, 0
  end

  def visit_InstanceOfNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.swap
    @g.send :js_instance_of, 1
  end
  def visit_InNode(o)
    accept o.left
    accept o.value
    pos(o)
    @g.swap
    @g.send :js_in, 1
  end

  def visit_FunctionCallNode(o)
    pos(o)
    o.value.call_bytecode(self, @g) do
      o.arguments.each do |arg|
        accept arg
      end

      # block must return the number of arguments
      o.arguments.size
    end
  end
  def visit_OpEqualNode(o)
    pos(o)
    o.left.set_bytecode(self, @g) do
      accept o.value
    end
  end
end

