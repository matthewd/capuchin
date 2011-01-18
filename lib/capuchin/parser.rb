require 'parslet'

module Capuchin; end

class Capuchin::ASTBuilder < Parslet::Transform
  rule(:left => subtree(:left), :ops => "") { left }
  rule(:right => subtree(:right), :ops => "") { right }
  rule(:cond => subtree(:cond), :ops => "") { cond }
  rule(:expr => subtree(:expr), :postfix_op => nil) { expr }
  rule(:expr => subtree(:expr), :calls => "") { expr }

  rule(:integer => simple(:x)) { Integer(x) }
  rule(:float => simple(:x)) { Float(x) }

  rule(:literal => 'null') { Capuchin::Nodes::NullNode.new }
  rule(:literal => 'true') { Capuchin::Nodes::TrueNode.new }
  rule(:literal => 'false') { Capuchin::Nodes::FalseNode.new }
  rule(:literal => { :string => simple(:x) }) { Capuchin::Nodes::StringNode.new(x) }
  rule(:literal => { :regexp => simple(:x) }) { Capuchin::Nodes::RegexpNode.new(x) }
  rule(:literal => simple(:num)) { Capuchin::Nodes::NumberNode.new(num) }

  rule(:this => 'this') { Capuchin::Nodes::ThisNode.new }
  rule(:ident => simple(:x)) { x }
  rule(:resolve => simple(:x)) { Capuchin::Nodes::ResolveNode.new(x) }

  rule(:name => simple(:name), :value => simple(:value)) { Capuchin::Nodes::PropertyNode.new(name, value) }
  rule(:object_literal => sequence(:properties)) { Capuchin::Nodes::ObjectLiteralNode.new(properties) }

  rule(:expr => simple(:value), :postfix_op => { :postfix => simple(:op) }) { Capuchin::Nodes::PostfixNode.new(op, value) }

  rule(:unary => 'delete', :expr => simple(:value)) { Capuchin::Nodes::DeleteNode.new(value) }
  rule(:unary => 'void', :expr => simple(:value)) { Capuchin::Nodes::VoidNode.new(value) }
  rule(:unary => 'typeof', :expr => simple(:value)) { Capuchin::Nodes::TypeOfNode.new(value) }
  rule(:unary => '++', :expr => simple(:value)) { Capuchin::Nodes::PrefixNode.new('++', value) }
  rule(:unary => '--', :expr => simple(:value)) { Capuchin::Nodes::PrefixNode.new('--', value) }

  rule(:unary => '+', :expr => simple(:value)) { Capuchin::Nodes::UnaryPlusNode.new(value) }
  rule(:unary => '-', :expr => simple(:value)) { Capuchin::Nodes::UnaryMinusNode.new(value) }
  rule(:unary => '~', :expr => simple(:value)) { Capuchin::Nodes::BitwiseNotNode.new(value) }
  rule(:unary => '!', :expr => simple(:value)) { Capuchin::Nodes::LogicalNotNode.new(value) }

  rule(:left => simple(:left), :ops => sequence(:ops)) do
    ops.inject(left) {|x,op| op.left = x; op }
  end
  rule(:right => simple(:right), :ops => sequence(:ops)) do
    ops.reverse.inject(right) {|x,op| op.value = x; op }
  end
  rule(:binary => '*', :right => simple(:right)) { Capuchin::Nodes::MultiplyNode.new(nil, right) }
  rule(:binary => '/', :right => simple(:right)) { Capuchin::Nodes::DivideNode.new(nil, right) }
  rule(:binary => '%', :right => simple(:right)) { Capuchin::Nodes::ModulusNode.new(nil, right) }
  rule(:binary => '+', :right => simple(:right)) { Capuchin::Nodes::AddNode.new(nil, right) }
  rule(:binary => '-', :right => simple(:right)) { Capuchin::Nodes::SubtractNode.new(nil, right) }
  rule(:binary => '<<', :right => simple(:right)) { Capuchin::Nodes::LeftShiftNode.new(nil, right) }
  rule(:binary => '>>', :right => simple(:right)) { Capuchin::Nodes::RightShiftNode.new(nil, right) }
  rule(:binary => '>>>', :right => simple(:right)) { Capuchin::Nodes::UnsignedRightShiftNode.new(nil, right) }
  rule(:binary => '<', :right => simple(:right)) { Capuchin::Nodes::LessNode.new(nil, right) }
  rule(:binary => '>', :right => simple(:right)) { Capuchin::Nodes::GreaterNode.new(nil, right) }
  rule(:binary => '<=', :right => simple(:right)) { Capuchin::Nodes::LessOrEqualNode.new(nil, right) }
  rule(:binary => '>=', :right => simple(:right)) { Capuchin::Nodes::GreaterOrEqualNode.new(nil, right) }
  rule(:binary => 'instanceof', :right => simple(:right)) { Capuchin::Nodes::InstanceOfNode.new(nil, right) }
  rule(:binary => 'in', :right => simple(:right)) { Capuchin::Nodes::InNode.new(nil, right) }
  rule(:binary => '==', :right => simple(:right)) { Capuchin::Nodes::EqualNode.new(nil, right) }
  rule(:binary => '!=', :right => simple(:right)) { Capuchin::Nodes::NotEqualNode.new(nil, right) }
  rule(:binary => '===', :right => simple(:right)) { Capuchin::Nodes::StrictEqualNode.new(nil, right) }
  rule(:binary => '!==', :right => simple(:right)) { Capuchin::Nodes::NotStrictEqualNode.new(nil, right) }
  rule(:binary => '&', :right => simple(:right)) { Capuchin::Nodes::BitAndNode.new(nil, right) }
  rule(:binary => '^', :right => simple(:right)) { Capuchin::Nodes::BitXOrNode.new(nil, right) }
  rule(:binary => '|', :right => simple(:right)) { Capuchin::Nodes::BitOrNode.new(nil, right) }
  rule(:binary => '&&', :right => simple(:right)) { Capuchin::Nodes::LogicalAndNode.new(nil, right) }
  rule(:binary => '||', :right => simple(:right)) { Capuchin::Nodes::LogicalOrNode.new(nil, right) }

  rule(:assignment => '=', :left => simple(:left)) { Capuchin::Nodes::OpEqualNode.new(left, nil) }
  rule(:assignment => '+=', :left => simple(:left)) { Capuchin::Nodes::OpPlusEqualNode.new(left, nil) }
  rule(:assignment => '-=', :left => simple(:left)) { Capuchin::Nodes::OpMinusEqualNode.new(left, nil) }
  rule(:assignment => '*=', :left => simple(:left)) { Capuchin::Nodes::OpMultiplyEqualNode.new(left, nil) }
  rule(:assignment => '/=', :left => simple(:left)) { Capuchin::Nodes::OpDivideEqualNode.new(left, nil) }
  rule(:assignment => '<<=', :left => simple(:left)) { Capuchin::Nodes::OpLShiftEqualNode.new(left, nil) }
  rule(:assignment => '>>=', :left => simple(:left)) { Capuchin::Nodes::OpRShiftEqualNode.new(left, nil) }
  rule(:assignment => '>>>=', :left => simple(:left)) { Capuchin::Nodes::OpURShiftEqualNode.new(left, nil) }
  rule(:assignment => '&=', :left => simple(:left)) { Capuchin::Nodes::OpAndEqualNode.new(left, nil) }
  rule(:assignment => '^=', :left => simple(:left)) { Capuchin::Nodes::OpXOrEqualNode.new(left, nil) }
  rule(:assignment => '|=', :left => simple(:left)) { Capuchin::Nodes::OpOrEqualNode.new(left, nil) }
  rule(:assignment => '%=', :left => simple(:left)) { Capuchin::Nodes::OpModEqualNode.new(left, nil) }

  rule(:binary => ',', :right => simple(:right)) { Capuchin::Nodes::CommaNode.new(nil, right) }

  rule(:var => simple(:var), :init => simple(:init)) { Capuchin::Nodes::VarDeclNode.new(var, init) }
  rule(:vars => simple(:var)) { Capuchin::Nodes::VarStatementNode.new([var]) }
  rule(:vars => sequence(:vars)) { Capuchin::Nodes::VarStatementNode.new(vars) }

  rule(:expr_statement => simple(:expr)) { Capuchin::Nodes::ExpressionStatementNode.new(expr) }
  rule(:statement => simple(:statement)) { statement }

  rule(:function_expr => { :name => simple(:name), :args => sequence(:args), :body => sequence(:body) }) { Capuchin::Nodes::FunctionExprNode.new(name || 'function', body, args) }
  rule(:function_expr => { :name => simple(:name), :args => simple(:arg), :body => sequence(:body) }) { Capuchin::Nodes::FunctionExprNode.new(name || 'function', body, arg ? [arg] : []) }

  rule(:function_declaration => { :name => simple(:name), :args => sequence(:args), :body => sequence(:body) }) { Capuchin::Nodes::FunctionDeclNode.new(name || 'function', body, args) }
  rule(:function_declaration => { :name => simple(:name), :args => simple(:arg), :body => sequence(:body) }) { Capuchin::Nodes::FunctionDeclNode.new(name || 'function', body, arg ? [arg] : []) }

  rule(:new => 'new', :expr => simple(:expr), :args => simple(:arg)) { Capuchin::Nodes::NewExprNode.new(expr, arg ? [arg] : []) }
  rule(:new => 'new', :expr => simple(:expr), :args => sequence(:args)) { Capuchin::Nodes::NewExprNode.new(expr, args) }

  rule(:expr => simple(:expr), :args => simple(:arg)) { Capuchin::Nodes::FunctionCallNode.new(expr, arg ? [arg] : []) }
  rule(:expr => simple(:expr), :args => sequence(:args)) { Capuchin::Nodes::FunctionCallNode.new(expr, args) }

  rule(:expr => simple(:left), :calls => sequence(:calls)) do
    calls.inject(left) {|x,call| call.value = x; call }
  end
  rule(:call => { :expr => simple(:expr) }) { Capuchin::Nodes::BracketAccessorNode.new(nil, expr) }
  rule(:call => { :name => simple(:name) }) { Capuchin::Nodes::DotAccessorNode.new(nil, name) }
  rule(:call => { :args => simple(:arg) }) { Capuchin::Nodes::FunctionCallNode.new(nil, arg ? [arg] : []) }
  rule(:call => { :args => sequence(:args) }) { Capuchin::Nodes::FunctionCallNode.new(nil, args) }

  rule(:break => simple(:value)) { Capuchin::Nodes::BreakNode.new(value) }
  rule(:continue => simple(:value)) { Capuchin::Nodes::ContinueNode.new(value) }
  rule(:return => simple(:value)) { Capuchin::Nodes::ReturnNode.new(value) }
  rule(:throw => simple(:value)) { Capuchin::Nodes::ThrowNode.new(value) }

  rule(:label => simple(:label), :labelled => simple(:statement)) { Capuchin::Nodes::LabelNode.new(label, statement) }

  rule(:block => sequence(:statements)) { Capuchin::Nodes::BlockNode.new(statements) }
  rule(:if_condition => simple(:cond), :true_part => simple(:t), :false_part => simple(:f)) { Capuchin::Nodes::IfNode.new(cond, t, f) }

  rule(:case => simple(:value), :code => sequence(:code)) { Capuchin::Nodes::CaseClauseNode.new(value, code) }
  rule(:default => 'default', :code => sequence(:code)) { Capuchin::Nodes::CaseClauseNode.new(nil, code) }
  rule(:switch_statement => { :switch => simple(:value), :cases => sequence(:options) }) { Capuchin::Nodes::SwitchNode.new(value, options) }

  rule(:init => simple(:init), :test => simple(:cond), :counter => simple(:counter), :code => simple(:code)) { Capuchin::Nodes::ForNode.new(init, cond, counter, code) }
end

class Capuchin::Parser < Parslet::Parser
  alias_method :`, :str

  rule(:source_file) do
    source_element >> source_file |
    sp?
  end
  root(:source_file)

  rule(:source_elements) do
    source_element.repeat
  end
  rule(:source_element) do
    sp? >> function_declaration.as(:function_declaration) | sp? >> statement.as(:statement)
  end
  rule(:statement) do
    block |
    variable_statement |
    const_statement |
    empty_statement |
    expr_statement |
    if_statement |
    iteration_statement |
    continue_statement |
    break_statement |
    return_statement |
    with_statement |
    switch_statement |
    labelled_statement |
    throw_statement |
    try_statement
  end
  rule(:literal) do
    `null` | `true` | `false` | number | string | regexp
  end
  rule(:property) do
    (ident | string | number).as(:name) >> sp? >> `:` >> sp? >> assignment_expr.as(:value) |
    ident.as(:name) >> sp >> ident.as(:prop_type) >> sp? >> `(` >> formal_parameter_list.maybe.as(:args) >> sp? >> `)` >> sp? >> `{` >> sp? >> function_body.as(:value) >> sp? >> `}`
  end
  rule(:property_list) do
    (property >> sp? >> `,` >> sp?).repeat >> property
  end
  rule(:primary_expr) do
    primary_expr_no_brace |
    `{` >> sp? >> (property_list.as(:object_literal) >> sp? >> (`,` >> sp?).maybe).maybe >> `}`
  end

  rule(:primary_expr_no_brace) do
    `this`.as(:this) |
    literal.as(:literal) |
    array_literal.as(:array) |
    ident.as(:resolve) |
    `(` >> sp? >> expr >> sp? >> `)`
  end

  rule(:array_literal) do
    `[` >> sp? >> element_list.maybe.as(:elements) >> sp? >> elision.maybe >> sp? >> `]`
  end

  rule(:element_list) do
    (elision >> sp?).maybe >> (assignment_expr.as(:element) >> sp? >> `,` >> sp? >> (elision >> sp?).maybe).repeat >> assignment_expr.as(:element)
  end

  rule(:elision) do
    `,`.as(:skip) >> (sp? >> `,`.as(:skip)).repeat
  end

  rule(:member_expr) do
    (
      primary_expr |
      function_expr.as(:function_expr) |
      `new`.as(:new) >> sp >> member_expr.as(:expr) >> sp? >> arguments
    ).as(:expr) >> (
      sp? >> `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident.as(:name)
    ).as(:call).repeat.as(:calls)
  end

  rule(:member_expr_no_bf) do
    (
      primary_expr_no_brace |
      `new`.as(:new) >> sp >> member_expr.as(:expr) >> sp? >> arguments
    ).as(:expr) >> (
      sp? >> `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident.as(:name)
    ).as(:call).repeat.as(:calls)
  end

  rule(:new_expr) do
    member_expr |
    `new`.as(:new) >> sp >> new_expr.as(:expr)
  end

  rule(:new_expr_no_bf) do
    member_expr_no_bf |
    `new`.as(:new) >> sp >> new_expr.as(:expr)
  end

  rule(:call_expr) do
    (member_expr.as(:expr) >> sp? >> arguments).as(:expr) >>
    (sp? >>
      (arguments |
      `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      `.` >> sp? >> ident.as(:name)
      )
    ).as(:call).repeat.as(:calls)
  end

  rule(:call_expr_no_bf) do
    (member_expr_no_bf.as(:expr) >> sp? >> arguments).as(:expr) >>
    (sp? >>
      (arguments |
      `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      `.` >> sp? >> ident.as(:name)
      )
    ).as(:call).repeat.as(:calls)
  end

  rule(:arguments) do
    `(` >> sp? >> argument_list.maybe.as(:args) >> sp? >> `)`
  end

  rule(:argument_list) do
    assignment_expr >> (sp? >> `,` >> sp? >> assignment_expr).repeat
  end

  rule(:left_hand_side_expr) do
    call_expr |
    new_expr
  end

  rule(:left_hand_side_expr_no_bf) do
    new_expr_no_bf |
    call_expr_no_bf
  end

  rule(:postfix_expr) do
    left_hand_side_expr.as(:expr) >> (sp? >> `++`.as(:postfix) | sp? >> `--`.as(:postfix)).maybe.as(:postfix_op)
  end

  rule(:postfix_expr_no_bf) do
    left_hand_side_expr_no_bf.as(:expr) >> (sp? >> `++`.as(:postfix) | sp? >> `--`.as(:postfix)).maybe.as(:postfix_op)
  end

  rule(:unary_expr_common) do
    (`delete` | `void` | `typeof` | `++` | `--` | `+` | `-` | `~` | `!`).as(:unary) >> sp? >> unary_expr.as(:expr)
  end

  rule(:unary_expr) do
    unary_expr_common |
    postfix_expr
  end

  rule(:unary_expr_no_bf) do
    unary_expr_common |
    postfix_expr_no_bf
  end

  rule(:multiplicative_expr) do
    unary_expr.as(:left) >> (sp? >> (`*` | `/` | `%`).as(:binary) >> sp? >> unary_expr.as(:right)).repeat.as(:ops)
  end
  rule(:multiplicative_expr_no_bf) do
    unary_expr_no_bf.as(:left) >> (sp? >> (`*` | `/` | `%`).as(:binary) >> sp? >> unary_expr.as(:right)).repeat.as(:ops)
  end

  rule(:additive_expr) do
    multiplicative_expr.as(:left) >> (sp? >> (`+` | `-`).as(:binary) >> sp? >> multiplicative_expr.as(:right)).repeat.as(:ops)
  end
  rule(:additive_expr_no_bf) do
    multiplicative_expr_no_bf.as(:left) >> (sp? >> (`+` | `-`).as(:binary) >> sp? >> multiplicative_expr.as(:right)).repeat.as(:ops)
  end

  rule(:shift_expr) do
    additive_expr.as(:left) >> (sp? >> (`<<` | `>>>` | `>>`).as(:binary) >> sp? >> additive_expr.as(:right)).repeat.as(:ops)
  end
  rule(:shift_expr_no_bf) do
    additive_expr_no_bf.as(:left) >> (sp? >> (`<<` | `>>>` | `>>`).as(:binary) >> sp? >> additive_expr.as(:right)).repeat.as(:ops)
  end

  rule(:relational_expr) do
    shift_expr.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof` | `in`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end
  rule(:relational_expr_no_in) do
    shift_expr.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end
  rule(:relational_expr_no_bf) do
    shift_expr_no_bf.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof` | `in`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end

  rule(:equality_expr) do
    relational_expr.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr.as(:right)).repeat.as(:ops)
  end
  rule(:equality_expr_no_in) do
    relational_expr_no_in.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:equality_expr_no_bf) do
    relational_expr_no_bf.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_and_expr) do
    equality_expr.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_and_expr_no_in) do
    equality_expr_no_in.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_and_expr_no_bf) do
    equality_expr_no_bf.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_xor_expr) do
    bitwise_and_expr.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_xor_expr_no_in) do
    bitwise_and_expr_no_in.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_xor_expr_no_bf) do
    bitwise_and_expr_no_bf.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_or_expr) do
    bitwise_xor_expr.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_or_expr_no_in) do
    bitwise_xor_expr_no_in.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_or_expr_no_bf) do
    bitwise_xor_expr_no_bf.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr.as(:right)).repeat.as(:ops)
  end

  rule(:logical_and_expr) do
    bitwise_or_expr.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr.as(:right)).repeat.as(:ops)
  end
  rule(:logical_and_expr_no_in) do
    bitwise_or_expr_no_in.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:logical_and_expr_no_bf) do
    bitwise_or_expr_no_bf.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr.as(:right)).repeat.as(:ops)
  end

  rule(:logical_or_expr) do
    logical_and_expr.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr.as(:right)).repeat.as(:ops)
  end
  rule(:logical_or_expr_no_in) do
    logical_and_expr_no_in.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:logical_or_expr_no_bf) do
    logical_and_expr_no_bf.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr.as(:right)).repeat.as(:ops)
  end

  rule(:conditional_expr) do
    logical_or_expr.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr.as(:true_expr) >> sp? >> `:` >> sp? >> assignment_expr.as(:false_expr)).repeat.as(:ops)
  end
  rule(:conditional_expr_no_in) do
    logical_or_expr_no_in.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr_no_in.as(:true_expr) >> sp? >> `:` >> sp? >> assignment_expr_no_in.as(:false_expr)).repeat.as(:ops)
  end
  rule(:conditional_expr_no_bf) do
    logical_or_expr_no_bf.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr.as(:true_expr) >> sp? >> `:` >> sp? >> assignment_expr.as(:false_expr)).repeat.as(:ops)
  end

  rule(:assignment_expr) do
    (left_hand_side_expr.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat.as(:ops) >> conditional_expr.as(:right)
  end
  rule(:assignment_expr_no_in) do
    (left_hand_side_expr.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat.as(:ops) >> conditional_expr_no_in.as(:right)
  end
  rule(:assignment_expr_no_bf) do
    (left_hand_side_expr_no_bf.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat(0, 1).as(:ops) >> assignment_expr.as(:right)
  end

  rule(:assignment_operator) do
    `=` >> `=`.absnt? |
    `+=` |
    `-=` |
    `*=` |
    `/=` |
    `<<=` |
    `>>=` |
    `>>>=` |
    `&=` |
    `^=` |
    `|=` |
    `%=`
  end

  rule(:expr) do
    assignment_expr.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr.as(:right)).repeat.as(:ops)
  end
  rule(:expr_no_in) do
    assignment_expr_no_in.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:expr_no_bf) do
    assignment_expr_no_bf.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr.as(:right)).repeat.as(:ops)
  end

  rule(:block) do
    `{` >> sp? >> source_elements.as(:block) >> sp? >> `}`
  end

  rule(:variable_statement) do
    `var` >> sp >> variable_declaration_list.as(:vars) >> sp? >> (`;` | error)
  end

  rule(:variable_declaration_list) do
    variable_declaration >> (sp? >> `,` >> sp? >> variable_declaration).repeat
  end
  rule(:variable_declaration_list_no_in) do
    variable_declaration_no_in >> (sp? >> `,` >> sp? >> variable_declaration_no_in).repeat
  end

  rule(:variable_declaration) do
    ident.as(:var) >> (sp? >> `=` >> sp? >> assignment_expr).maybe.as(:init)
  end
  rule(:variable_declaration_no_in) do
    ident.as(:var) >> (sp? >> `=` >> sp? >> assignment_expr_no_in).maybe.as(:init)
  end

  rule(:const_statement) do
    `const` >> sp >> const_declaration_list >> sp? >> (`;` | error)
  end
  rule(:const_declaration_list) do
    (const_declaration >> sp? >> `,` >> sp?).repeat >> const_declaration
  end
  rule(:const_declaration) do
    ident.as(:const) >> (sp? >> `=` >> sp? >> assignment_expr.as(:init)).maybe
  end

  rule(:empty_statement) do
    `;`
  end

  rule(:expr_statement) do
    expr_no_bf.as(:expr_statement) >> sp? >> (`;` | error)
  end

  rule(:if_statement) do
    `if` >> sp? >> `(` >> sp? >> expr.as(:if_condition) >> sp? >> `)` >> sp? >> statement.as(:true_part) >> (sp? >> `else` >> sp? >> statement).maybe.as(:false_part)
  end

  rule(:iteration_statement) do
    `do` >> sp? >> statement.as(:code) >> sp? >> `while` >> sp? >> `(` >> sp? >> expr.as(:do_while) >> sp? >> `)` >> sp? >> (`;` | error) |
    `while` >> sp? >> `(` >> sp? >> expr.as(:while) >> sp? >> `)` >> sp? >> statement.as(:code) |
    `for` >> sp? >> `(` >> sp? >> (expr_no_in >> sp?).maybe.as(:init) >> `;` >> sp? >> (expr >> sp?).maybe.as(:test) >> `;` >> sp? >> (expr >> sp?).maybe.as(:counter) >> `)` >> sp? >> statement.as(:code) |
    `for` >> sp? >> `(` >> sp? >> (`var` >> sp >> variable_declaration_list_no_in.as(:vars)).as(:init) >> sp? >> `;` >> sp? >> (expr >> sp?).maybe.as(:test) >> `;` >> sp? >> (expr >> sp?).maybe.as(:counter) >> `)` >> sp? >> statement.as(:code) |
    `for` >> sp? >> `(` >> sp? >> (left_hand_side_expr.as(:left) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code) |
    `for` >> sp? >> `(` >> sp? >> ((`var` >> sp >> ident.as(:var)).as(:vars) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code) |
    `for` >> sp? >> `(` >> sp? >> ((`var` >> sp >> ident.as(:var) >> sp? >> `=` >> sp? >> assignment_expr_no_in.as(:expr)).as(:vars) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code)
  end

  rule(:continue_statement) do
    `continue` >> (sp >> ident).maybe.as(:continue) >> sp? >> (`;` | error)
  end
  rule(:break_statement) do
    `break` >> (sp >> ident).maybe.as(:break) >> sp? >> (`;` | error)
  end
  rule(:return_statement) do
    `return` >> sp? >> (expr >> sp?).maybe.as(:return) >> (`;` | error)
  end

  rule(:with_statement) do
    `with` >> sp? >> `(` >> sp? >> expr.as(:with_expr) >> sp? >> `)` >> sp? >> statement
  end

  rule(:switch_statement) do
    (`switch` >> sp? >> `(` >> sp? >> expr.as(:switch) >> sp? >> `)` >> sp? >> case_block.as(:cases)).as(:switch_statement)
  end

  rule(:case_block) do
    `{` >> sp? >> case_clause.repeat >> (default_clause >> case_clause.repeat).maybe >> `}`
  end
  rule(:case_clause) do
    `case` >> sp? >> expr.as(:case) >> sp? >> `:` >> sp? >> source_elements.as(:code) >> sp?
  end
  rule(:default_clause) do
    `default`.as(:default) >> sp? >> `:` >> sp? >> source_elements.as(:code) >> sp?
  end

  rule(:labelled_statement) do
    ident.as(:label) >> sp? >> `:` >> sp? >> statement.as(:labelled)
  end

  rule(:throw_statement) do
    `throw` >> sp? >> expr.as(:throw) >> sp? >> (`;` | error)
  end

  rule(:try_statement) do
    `try` >> sp? >> block >> sp? >> (
      `finally` >> sp? >> block |
      `catch` >> sp? >> `(` >> sp? >> ident >> sp? >> `)` >> sp? >> block >> (sp? >> `finally` >> sp? >> block).maybe
    )
  end

  rule(:function_declaration) do
    `function` >> sp >> ident.as(:name) >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe.as(:args) >> `)` >> sp? >> `{` >> sp? >> function_body.as(:body) >> sp? >> `}`
  end
  rule(:function_expr) do
    `function` >> (sp >> ident).maybe.as(:name) >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe.as(:args) >> `)` >> sp? >> `{` >> sp? >> function_body.as(:body) >> sp? >> `}`
  end

  rule(:formal_parameter_list) do
    ident >> (sp? >> `,` >> sp? >> ident).repeat
  end

  rule(:function_body) do
    source_elements
  end


  rule(:string) do
    (
      `"` >> (`\\` >> any | match(%([^"\]))).repeat >> `"` |
      `'` >> (`\\` >> any | match(%([^'\]))).repeat >> `'`
    ).as(:string)
  end

  rule(:number) do
    float.as(:float) | integer.as(:integer)
  end
  rule(:float) do
    digit.repeat(1) >> `.` >> digit.repeat >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe |
    digit.repeat(1) >> (`.` >> digit.repeat).maybe >> match['eE'] >> match['-+'].maybe >> digit.repeat(1) |
    `.` >> digit.repeat(1) >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe
  end
  rule(:integer) do
    `0` >> (match['xX'] >> match['0-9a-fA-F'].repeat(1) | match['0-7'].repeat) | digit.repeat(1)
  end
  rule(:digit) do
    match['0-9']
  end

  rule(:regexp) do
    `/` >> (
      match['^\[\/'].repeat(1) |
      `\\` >> any |
      `[` >> `^`.maybe >> `]`.maybe >> (match['^\]'].repeat(1) | `\\` >> any).repeat >> `]`
    ).repeat.as(:regexp) >> `/` >> match['gim'].repeat.as(:flags)
  end

  rule(:ident) do
    (
      (reserved >> match['A-Za-z0-9_$'].absnt?).absnt? >>
      match['A-Za-z_$'] >> match['A-Za-z0-9_$'].repeat
    ).as(:ident)
  end

  RESERVED_WORDS = %w(
    break case catch const continue default delete do else false finally
    for function if in instanceof new null return switch this throw true
    try typeof var void while with
  )
  rule(:reserved) do
    RESERVED_WORDS.map {|w| str(w) }.inject {|l,r| l | r }
  end

  rule(:error) do
    match("[ \t]").repeat >> `\n` | eof
  end

  rule(:eof) do
    any.absnt?
  end

  rule(:sp) do
    match("[ \t\r\n]").repeat(1) |
    `//` >> match("[^\r\n]").repeat.as(:comment) |
    `/*` >> (`*/`.absnt? >> any).repeat.as(:comment) >> `*/`
  end
  rule(:sp?) { sp.repeat }
end

