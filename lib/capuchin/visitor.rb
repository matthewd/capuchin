
class Capuchin::Visitor < RKelly::Visitors::Visitor
  class DeclScanner < RKelly::Visitors::Visitor
    def initialize(scope)
      @scope = scope
    end

    def visit_ResolveNode(o)
      @scope.need_arguments! if o.value.to_sym == :arguments
    end
    def visit_VarDeclNode(o)
      name = o.name.to_sym
      @scope.add_variable name, o

      # Scan the value
      accept o.value if o.value
    end
    def visit_FunctionDeclNode(o)
      name = o.value.to_sym
      @scope.add_variable name, o

      @scope.add_method do |g,v|
        v.pos(o)
        g.push_const :Capuchin
        g.find_const :Function
        g.push_literal o.value.to_sym
        g.create_block v.compile_method(o.line, o.value, o.arguments.map {|p| p.value }, o.function_body)
        g.send_with_block :new, 1

        var = g.state.scope.variables[o.value.to_sym]
        var.reference.set_bytecode(g)
        g.pop
      end
    end
    def visit_FunctionExprNode(o)
      # Don't scan function_body; it's a new scope
    end
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
    @g.create_block compile_method(o.line, o.value, o.arguments.map {|p| p.value }, o.function_body)
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

      body.accept DeclScanner.new(meth.state.scope)

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
      body.accept v

      meth.state.pop_name

      meth.local_count = meth.state.scope.local_count
      meth.local_names = meth.state.scope.local_names

      meth.push_nil
      meth.ret
      meth.close
    end

    meth
  end

  def visit_VarDeclNode(o)
    pos(o)

    var = @g.state.scope.variables[o.name.to_sym]
    if o.value
      accept o.value
      var.reference.set_bytecode(@g)
      @g.pop
    end
  end
  def visit_ResolveNode(o)
    pos(o)
    if ref = @g.state.scope.search_local(o.value.to_sym)
      ref.get_bytecode(@g)
    else
      @g.push_const :Capuchin
      @g.find_const :Globals
      @g.push_literal o.value.to_sym
      @g.send :[], 1
    end
  end
  def visit_ExpressionStatementNode(o)
    pos(o)
    accept o.value
    @g.pop
  end
  def visit_ArrayNode(o)
    pos(o)
    o.value.each do |entry|
      accept entry
    end
    @g.make_array o.value.size
  end
  def visit_DotAccessorNode(o)
    pos(o)
    accept o.value
    @g.push_literal o.accessor.to_sym
    @g.send :js_get, 1
    #@g.call_custom :js_get, 1
  end
  def key_safe?(o)
    RKelly::Nodes::NumberNode === o && Fixnum === o.value
  end
  def visit_BracketAccessorNode(o)
    pos(o)
    accept o.value
    accept o.accessor
    @g.send :js_key, 0 unless key_safe?(o.accessor)
    @g.send :js_get, 1
    #@g.call_custom :js_get, 1
  end
  def visit_RegexpNode(o)
    # o.value
    raise NotImplementedError, "regexp"
  end
  def visit_StringNode(o)
    pos(o)
    str = o.value[1, o.value.size - 2]
    # FIXME: Escapes: \\, \", \n, \u..., \0..
    str.gsub!(/\\([n'"\\])/) do
      case $1
      when 'n'; "\n"
      else; $1
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
    pos(o)
    accept o.conditions
    after = @g.new_label
    if o.else
      alternate = @g.new_label
      @g.giz alternate, o.conditions
      accept o.value
      @g.goto after
      alternate.set!
      accept o.else
    else
      @g.giz after, o.conditions
      accept o.value
    end
    after.set!
  end
  def visit_TypeOfNode(o)
    pos(o)
    accept o.value
    @g.send :js_typeof, 0
  end
  def visit_VoidNode(o)
    pos(o)
    accept o.value
    @g.pop
    @g.push_nil
  end
  def visit_CommaNode(o)
    pos(o)
    accept o.left
    @g.pop
    accept o.value
  end
  def visit_NewExprNode(o)
    pos(o)
    accept o.value
    args = o.arguments.value
    args.each do |arg|
      accept arg
    end
    @g.send :js_new, args.size
  end
  def visit_ForInNode(o)
    # for (LEFT in RIGHT) VALUE
    lbl = @g.state.scope.current_line_label
    raise NotImplementedError, "for .. in"
  end
  def visit_BreakNode(o)
    @g.goto @g.state.scope.find_break_target(o.value && o.value.to_sym)
  end
  def visit_ContinueNode(o)
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

    pos(o)
    lbl = @g.state.scope.current_line_label
    done = @g.new_label

    accept o.left
    if cases = o.value.value
      has_default = false
      cases = cases.map {|c| [c, @g.new_label] }
      cases.each do |(c,code)|
        if c.left
          try_next = @g.new_label
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
          @g.pop
          @g.goto code
          has_default = true
          break
        end
      end
      unless has_default
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
      p o.init
      unless RKelly::Nodes::VarStatementNode === o.init
        @g.pop
      end
    end

    top = @g.new_label
    done = @g.new_label
    continue = @g.new_label

    top.set!
    if o.test
      accept o.test
      @g.giz done, o.test
    end

    @g.state.scope.with_loop(lbl, continue, done) do
      accept o.value
    end

    continue.set!
    if o.counter
      accept o.counter
      @g.pop
    end
    @g.goto top

    done.set!
  end
  def visit_DoWhileNode(o)
    pos(o)
    lbl = @g.state.scope.current_line_label
    again = @g.new_label

    again.set!
    accept o.left
    accept o.value
    @g.giz again, o.value
  end
  def visit_WhileNode(o)
    pos(o)
    lbl = @g.state.scope.current_line_label
    again = @g.new_label
    nope = @g.new_label

    again.set!
    accept o.left
    @g.giz nope, o.left

    accept o.value
    @g.goto again

    nope.set!
  end

  # Before yield, loads the current value from 'o' and puts it on the
  # stack. May put other things on the stack for its own use too; will
  # give the number of such elements in the yield, so you can reach past
  # them if you need to.
  #
  # When the yield returns, the stack must be the same height it was
  # when the yield began. Presumably you have modified the value at the
  # top; that value will be copied back into the variable referenced by
  # 'o'.
  #
  # Upon return, the stack will contain the calculated value (that is,
  # the value at the top of the stack after the yield); this function's
  # net stack impact is thus +1.
  def get_and_set(o)
    case o
    when RKelly::Nodes::ResolveNode
      if ref = @g.state.scope.search_local(o.value.to_sym)
        ref.get_bytecode(@g)
        yield 0
        ref.set_bytecode(@g)
      else
        @g.push_const :Capuchin
        @g.find_const :Globals
        @g.push_literal o.value.to_sym
        @g.dup_many 2
        @g.send :[], 1
        yield 2
        @g.send :[]=, 2
      end
    when RKelly::Nodes::DotAccessorNode
      accept o.value
      @g.push_literal o.accessor.to_sym
      @g.dup_many 2
      @g.send :js_get, 1
      yield 2
      @g.send :js_set, 2
    when RKelly::Nodes::BracketAccessorNode
      accept o.value
      accept o.accessor
      @g.send :js_key, 0 unless key_safe?(o.accessor)
      @g.dup_many 2
      @g.send :js_get, 1
      yield 2
      @g.send :js_set, 2
    else
      raise NotImplementedError, "Don't know how to get+set #{o.class}"
    end
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
    else
      @g.push_nil
    end
    @g.ret
  end

  def visit_PrefixNode(o)
    get_and_set(o.operand) do
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
    get_and_set(o.operand) do |n|
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
    @g.pop
  end

  [
    [ :Add,       :js_add,  :OpPlusEqual,   :meta_send_op_plus  ],
    [ :Subtract,  :-,       :OpMinusEqual,  :meta_send_op_minus ],
    [ :Greater,   :js_gt,   nil,            :meta_send_op_gt    ],
    [ :Less,      :js_lt,   nil,            :meta_send_op_lt    ],
  ].each do |name,op,eq,meta|
    define_method(:"visit_#{name}Node") do |o|
      pos(o)
      accept o.left
      accept o.value
      @g.__send__ meta, @g.find_literal(op)
    end
    if eq
      define_method(:"visit_#{eq}Node") do |o|
        pos(o)
        get_and_set(o.left) do
          accept o.value
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
      pos(o)
      accept o.left
      accept o.value
      @g.send op, 1
    end
    if eq
      define_method(:"visit_#{eq}Node") do |o|
        pos(o)
        get_and_set(o.left) do
          accept o.value
          @g.send op, 1
        end
      end
    end
  end

  def visit_LogicalNotNode(o)
    pos(o)
    a = @g.new_label
    b = @g.new_label
    accept o.value
    @g.gnz a, o.value
    @g.push_true
    @g.goto b
    a.set!
    @g.push_false
    b.set!
  end
  def visit_LogicalAndNode(o)
    pos(o)
    done = @g.new_label
    accept o.left
    @g.dup
    @g.giz done, o.left
    @g.pop
    accept o.value
    done.set!
  end
  def visit_LogicalOrNode(o)
    pos(o)
    done = @g.new_label
    accept o.left
    @g.dup
    @g.gnz done, o.left
    @g.pop
    accept o.value
    done.set!
  end
  def visit_ConditionalNode(o)
    pos(o)
    after = @g.new_label
    alternate = @g.new_label
    accept o.conditions
    @g.giz alternate, o.conditions
    accept o.value
    @g.goto after
    alternate.set!
    accept o.else
    after.set!
  end


  def visit_EqualNode(o)
    pos(o)
    accept o.left
    accept o.value
    @g.meta_send_op_equal @g.find_literal(:js_equal)
  end
  def visit_StrictEqualNode(o)
    pos(o)
    accept o.left
    accept o.value
    @g.meta_send_op_equal @g.find_literal(:js_strict_equal)
  end
  def visit_NotEqualNode(o)
    pos(o)
    accept o.left
    accept o.value
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
    pos(o)
    accept o.left
    accept o.value
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
    pos(o)
    accept o.value
    @g.send :~, 0
  end

  def visit_InstanceOfNode(o)
    pos(o)
    accept o.left
    accept o.value
    @g.swap
    @g.send :js_instance_of, 1
  end
  def visit_InNode(o)
    pos(o)
    accept o.left
    accept o.value
    @g.swap
    @g.send :js_in, 1
  end

  def visit_FunctionCallNode(o)
    callee = o.value
    args = o.arguments.value

    case callee
    when RKelly::Nodes::DotAccessorNode
      accept callee.value
      @g.push_literal callee.accessor.to_sym
      args.each do |arg|
        accept arg
      end
      #@g.call_custom :js_invoke, args.size + 1
      @g.send :js_invoke, args.size + 1

    when RKelly::Nodes::BracketAccessorNode
      accept callee.value
      accept callee.accessor
      @g.send :js_key, 0 unless key_safe?(o.accessor)
      args.each do |arg|
        accept arg
      end
      #@g.call_custom :js_invoke, args.size + 1
      @g.send :js_invoke, args.size + 1

    else
      # In the simplest case, this may be a ResolveNode. But it could be
      # any arbitrary [hopefully function returning!] expression.

      accept callee
      @g.push_nil
      args.each do |arg|
        accept arg
      end
      @g.send :js_call, args.size + 1

    end
  end
  def assign_to(o)
    pos(o)
    case o
    when RKelly::Nodes::ResolveNode
      if ref = @g.state.scope.search_local(o.value.to_sym)
        ref.set_bytecode(@g)
      else
        @g.push_const :Capuchin
        @g.find_const :Globals
        @g.swap
        @g.push_literal o.value.to_sym
        @g.swap
        @g.send :[]=, 2
      end
    when RKelly::Nodes::DotAccessorNode
      accept o.value
      @g.swap
      @g.push_literal o.accessor.to_sym
      @g.swap
      @g.send :js_set, 2
    when RKelly::Nodes::BracketAccessorNode
      accept o.value
      @g.swap
      accept o.accessor
      @g.send :js_key, 0 unless key_safe?(o.accessor)
      @g.swap
      @g.send :js_set, 2
    else
      raise NotImplementedError, "Don't know how to assign to #{o.class}"
    end
  end
  def visit_OpEqualNode(o)
    accept o.value
    assign_to o.left
  end
end

