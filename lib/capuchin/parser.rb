require 'parslet'

module Capuchin; end
class Capuchin::Parser < Parslet::Parser
  alias_method :`, :str

  rule(:source_file) do
    source_element.repeat >> sp?
  end
  root(:source_file)

  rule(:source_elements) do
    source_element.repeat
  end
  rule(:source_element) do
    sp? >> function_declaration | sp? >> statement
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
    (ident | string | number) >> sp? >> `:` >> sp? >> assignment_expr |
    ident >> sp >> ident >> sp? >> `(` >> formal_parameter_list.maybe >> sp? >> `)` >> sp? >> `{` >> sp? >> function_body >> sp? >> `}`
  end
  rule(:property_list) do
    (property >> sp? >> `,` >> sp?).repeat >> property
  end
  rule(:primary_expr) do
    primary_expr_no_brace |
    `{` >> sp? >> (property_list >> sp? >> (`,` >> sp?).maybe).maybe >> `}`
  end

  rule(:primary_expr_no_brace) do
    `this` |
    literal |
    array_literal |
    ident |
    `(` >> sp? >> expr >> sp? >> `)`
  end

  rule(:array_literal) do
    `[` >> sp? >> element_list.maybe >> sp? >> elision.maybe >> sp? >> `]`
  end

  rule(:element_list) do
    (elision >> sp?).maybe >> (assignment_expr >> sp? >> `,` >> sp? >> (elision >> sp?).maybe).repeat >> assignment_expr
  end

  rule(:elision) do
    `,` >> (sp? >> `,`).repeat
  end

  rule(:member_expr) do
    (
      primary_expr |
      function_expr |
      `new` >> sp >> member_expr >> sp? >> arguments
    ) >> (
      sp? >> `[` >> sp? >> expr >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident
    ).repeat
  end

  rule(:member_expr_no_bf) do
    (
      primary_expr_no_brace |
      `new` >> sp >> member_expr >> sp? >> arguments
    ) >> (
      sp? >> `[` >> sp? >> expr >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident
    ).repeat
  end

  rule(:new_expr) do
    `new` >> sp >> new_expr |
    member_expr
  end

  rule(:new_expr_no_bf) do
    `new` >> sp >> new_expr |
    member_expr_no_bf
  end

  rule(:call_expr) do
    member_expr >> sp? >> arguments >>
    (sp? >> call_expr >> sp? >>
      (arguments |
      `[` >> sp? >> expr >> sp? >> `]` |
      `.` >> sp? >> ident
      )
    ).repeat
  end

  rule(:call_expr_no_bf) do
    member_expr_no_bf >> sp? >> arguments >>
    (sp? >> call_expr >> sp? >>
      (arguments |
      `[` >> sp? >> expr >> sp? >> `]` |
      `.` >> sp? >> ident
      )
    ).repeat
  end

  rule(:arguments) do
    `(` >> sp? >> argument_list.maybe >> sp? >> `)`
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
    left_hand_side_expr >> (sp? >> `++` | sp? >> `--`).maybe
  end

  rule(:postfix_expr_no_bf) do
    left_hand_side_expr_no_bf >> (sp? >> `++` | sp? >> `--`).maybe
  end

  rule(:unary_expr_common) do
    `delete` >> sp >> unary_expr |
    `void` >> sp >> unary_expr |
    `typeof` >> sp >> unary_expr |
    `++` >> sp? >> unary_expr |
    `--` >> sp? >> unary_expr |
    `+` >> sp? >> unary_expr |
    `-` >> sp? >> unary_expr |
    `~` >> sp? >> unary_expr |
    `!` >> sp? >> unary_expr
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
    unary_expr >> (sp? >> (`*` >> sp? >> unary_expr |
                    `/` >> sp? >> unary_expr |
                    `%` >> sp? >> unary_expr
                    )
               ).repeat
  end
  rule(:multiplicative_expr_no_bf) do
    unary_expr_no_bf >> (sp? >> (`*` >> sp? >> unary_expr |
                          `/` >> sp? >> unary_expr |
                          `%` >> sp? >> unary_expr
                          )
                     ).repeat
  end

  rule(:additive_expr) do
    multiplicative_expr >> (sp? >> (`+` >> sp? >> multiplicative_expr |
                             `-` >> sp? >> multiplicative_expr
                             )
                        ).repeat
  end
  rule(:additive_expr_no_bf) do
    multiplicative_expr_no_bf >> (sp? >> (`+` >> sp? >> multiplicative_expr |
                                   `-` >> sp? >> multiplicative_expr
                                   )
                              ).repeat
  end

  rule(:shift_expr) do
    additive_expr >> (sp? >> (`<<` >> sp? >> additive_expr |
                       `>>` >> sp? >> additive_expr |
                       `>>>` >> sp? >> additive_expr
                       )
                  ).repeat
  end
  rule(:shift_expr_no_bf) do
    additive_expr_no_bf >> (sp? >> (`<<` >> sp? >> additive_expr |
                             `>>` >> sp? >> additive_expr |
                             `>>>` >> sp? >> additive_expr
                             )
                        ).repeat
  end

  rule(:relational_expr) do
    shift_expr >> (sp? >> `<` >> sp? >> shift_expr |
               sp? >> `>` >> sp? >> shift_expr |
               sp? >> `<=` >> sp? >> shift_expr |
               sp? >> `>=` >> sp? >> shift_expr |
               sp >> `instanceof` >> sp >> shift_expr |
               sp >> `in` >> sp >> shift_expr
               ).repeat
  end
  rule(:relational_expr_no_in) do
    shift_expr_no_in >> (sp? >> `<` >> sp? >> shift_expr |
                     sp? >> `>` >> sp? >> shift_expr |
                     sp? >> `<=` >> sp? >> shift_expr |
                     sp? >> `>=` >> sp? >> shift_expr |
                     sp >> `instanceof` >> sp >> shift_expr
                     ).repeat
  end
  rule(:relational_expr_no_bf) do
    shift_expr_no_bf >> (sp? >> `<` >> sp? >> shift_expr |
                     sp? >> `>` >> sp? >> shift_expr |
                     sp? >> `<=` >> sp? >> shift_expr |
                     sp? >> `>=` >> sp? >> shift_expr |
                     sp >> `instanceof` >> sp >> shift_expr |
                     sp >> `in` >> sp >> shift_expr
                     ).repeat
  end

  rule(:equality_expr) do
    relational_expr >> (sp? >> (`==` >> sp? >> relational_expr |
                         `!=` >> sp? >> relational_expr |
                         `===` >> sp? >> relational_expr |
                         `!==` >> sp? >> relational_expr
                         )
                    ).repeat
  end
  rule(:equality_expr_no_in) do
    relational_expr_no_in >> (sp? >> (`==` >> sp? >> relational_expr_no_in |
                               `!=` >> sp? >> relational_expr_no_in |
                               `===` >> sp? >> relational_expr_no_in |
                               `!==` >> sp? >> relational_expr_no_in
                               )
                          ).repeat
  end
  rule(:equality_expr_no_bf) do
    relational_expr_no_bf >> (sp? >> (`==` >> sp? >> relational_expr |
                               `!=` >> sp? >> relational_expr |
                               `===` >> sp? >> relational_expr |
                               `!==` >> sp? >> relational_expr
                               )
                          ).repeat
  end

  rule(:bitwise_and_expr) do
    equality_expr >> (sp? >> `&` >> sp? >> equality_expr).repeat
  end
  rule(:bitwise_and_expr_no_in) do
    equality_expr_no_in >> (sp? >> `&` >> sp? >> equality_expr_no_in).repeat
  end
  rule(:bitwise_and_expr_no_bf) do
    equality_expr_no_bf >> (sp? >> `&` >> sp? >> equality_expr).repeat
  end

  rule(:bitwise_xor_expr) do
    bitwise_and_expr >> (sp? >> `^` >> sp? >> bitwise_and_expr).repeat
  end
  rule(:bitwise_xor_expr_no_in) do
    bitwise_and_expr_no_in >> (sp? >> `^` >> sp? >> bitwise_and_expr_no_in).repeat
  end
  rule(:bitwise_xor_expr_no_bf) do
    bitwise_and_expr_no_bf >> (sp? >> `^` >> sp? >> bitwise_and_expr).repeat
  end

  rule(:bitwise_or_expr) do
    bitwise_xor_expr >> (sp? >> `|` >> sp? >> bitwise_xor_expr).repeat
  end
  rule(:bitwise_or_expr_no_in) do
    bitwise_xor_expr_no_in >> (sp? >> `|` >> sp? >> bitwise_xor_expr_no_in).repeat
  end
  rule(:bitwise_or_expr_no_bf) do
    bitwise_xor_expr_no_bf >> (sp? >> `|` >> sp? >> bitwise_xor_expr).repeat
  end

  rule(:logical_and_expr) do
    bitwise_or_expr >> (sp? >> `&&` >> sp? >> bitwise_or_expr).repeat
  end
  rule(:logical_and_expr_no_in) do
    bitwise_or_expr_no_in >> (sp? >> `&&` >> sp? >> bitwise_or_expr_no_in).repeat
  end
  rule(:logical_and_expr_no_bf) do
    bitwise_or_expr_no_bf >> (sp? >> `&&` >> sp? >> bitwise_or_expr).repeat
  end

  rule(:logical_or_expr) do
    logical_and_expr >> (sp? >> `||` >> sp? >> logical_and_expr).repeat
  end
  rule(:logical_or_expr_no_in) do
    logical_and_expr_no_in >> (sp? >> `||` >> sp? >> logical_and_expr_no_in).repeat
  end
  rule(:logical_or_expr_no_bf) do
    logical_and_expr_no_bf >> (sp? >> `||` >> sp? >> logical_and_expr).repeat
  end

  rule(:conditional_expr) do
    logical_or_expr >> (sp? >> `?` >> sp? >> assignment_expr >> sp? >> `:` >> sp? >> assignment_expr).repeat
  end
  rule(:conditional_expr_no_in) do
    logical_or_expr_no_in >> (sp? >> `?` >> sp? >> assignment_expr_no_in >> sp? >> `:` >> sp? >> assignment_expr_no_in).repeat
  end
  rule(:conditional_expr_no_bf) do
    logical_or_expr_no_bf >> (sp? >> `?` >> sp? >> assignment_expr >> sp? >> `:` >> sp? >> assignment_expr).repeat
  end

  rule(:assignment_expr) do
    (left_hand_side_expr >> sp? >> assignment_operator >> sp?).repeat >> conditional_expr
  end
  rule(:assignment_expr_no_in) do
    (left_hand_side_expr >> sp? >> assignment_operator >> sp?).repeat >> conditional_expr_no_in
  end
  rule(:assignment_expr_no_bf) do
    (left_hand_side_expr_no_bf >> sp? >> assignment_operator >> sp?).maybe >> assignment_expr
  end

  rule(:assignment_operator) do
    `=` |
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
    assignment_expr >> (sp? >> `,` >> sp? >> assignment_expr).repeat
  end
  rule(:expr_no_in) do
    assignment_expr_no_in >> (sp? >> `,` >> sp? >> assignment_expr_no_in).repeat
  end
  rule(:expr_no_bf) do
    assignment_expr_no_bf >> (sp? >> `,` >> sp? >> assignment_expr).repeat
  end

  rule(:block) do
    `{` >> sp? >> source_elements >> sp? >> `}`
  end

  rule(:variable_statement) do
    `var` >> sp >> variable_declaration_list >> sp? >> (`;` | error)
  end

  rule(:variable_declaration_list) do
    variable_declaration >> (sp? >> `,` >> sp? >> variable_declaration).repeat
  end
  rule(:variable_declaration_list_no_in) do
    variable_declaration_no_in >> (sp? >> `,` >> sp? >> variable_declaration_no_in).repeat
  end

  rule(:variable_declaration) do
    ident >> sp? >> `=` >> sp? >> assignment_expr
  end
  rule(:variable_declaration_no_in) do
    ident >> (sp? >> `=` >> sp? >> assignment_expr_no_in).maybe
  end

  rule(:const_statement) do
    `const` >> sp >> const_declaration_list >> sp? >> (`;` | error)
  end
  rule(:const_declaration_list) do
    (const_declaration >> sp? >> `,` >> sp?).repeat >> const_declaration
  end
  rule(:const_declaration) do
    ident >> (sp? >> `=` >> sp? >> assignment_expr).maybe
  end

  rule(:empty_statement) do
    `;`
  end

  rule(:expr_statement) do
    expr_no_bf >> sp? >> (`;` | error)
  end

  rule(:if_statement) do
    `if` >> sp? >> `(` >> sp? >> expr >> sp? >> `)` >> sp? >> statement >> (sp? >> `else` >> sp? >> statement).maybe
  end

  rule(:iteration_statement) do
    `do` >> sp? >> statement >> sp? >> `while` >> sp? >> `(` >> sp? >> expr >> sp? >> `)` >> sp? >> (`;` | error) |
    `while` >> sp? >> `(` >> sp? >> expr >> sp? >> `)` >> sp? >> statement |
    `for` >> sp? >> `(` >> sp? >> (expr_no_in >> sp?).maybe >> `;` >> sp? >> (expr >> sp?).maybe >> `;` >> sp? >> (expr >> sp?).maybe >> `)` >> sp? >> statement |
    `for` >> sp? >> `(` >> sp? >> `var` >> sp >> variable_declaration_list_no_in >> sp? >> `;` >> sp? >> (expr >> sp?).maybe >> `;` >> sp? >> (expr >> sp?).maybe >> `)` >> sp? >> statement |
    `for` >> `(` >> left_hand_side_expr >> sp >> `in` >> sp >> (expr >> sp?).maybe >> `)` >> sp? >> statement |
    `for` >> `(` >> `var` >> sp >> ident >> sp >> `in` >> sp >> (expr >> sp?).maybe >> `)` >> sp? >> statement |
    `for` >> `(` >> `var` >> sp >> ident >> sp? >> `=` >> sp? >> assignment_expr_no_in >> sp >> `in` >> sp >> (expr >> sp?).maybe >> `)` >> sp? >> statement
  end

  rule(:continue_statement) do
    `continue` >> (sp >> ident).maybe >> sp? >> (`;` | error)
  end
  rule(:break_statement) do
    `break` >> (sp >> ident).maybe >> sp? >> (`;` | error)
  end
  rule(:return_statement) do
    `return` >> sp? >> (expr >> sp?) >> (`;` | error)
  end

  rule(:with_statement) do
    `with` >> sp? >> `(` >> sp? >> expr >> sp? >> `)` >> sp? >> statement
  end

  rule(:switch_statement) do
    `switch` >> sp? >> `(` >> sp? >> expr >> sp? >> `)` >> sp? >> case_block
  end

  rule(:case_block) do
    `{` >> sp? >> case_clause.repeat >> (default_clause >> case_clause.repeat).maybe >> `}`
  end
  rule(:case_clause) do
    `case` >> sp? >> expr >> sp? >> `:` >> sp? >> source_elements >> sp?
  end
  rule(:case_clause) do
    `default` >> sp? >> `:` >> sp? >> source_elements >> sp?
  end

  rule(:labelled_statement) do
    ident >> sp? >> `:` >> sp? >> statement
  end

  rule(:throw_statement) do
    `throw` >> sp? >> expr >> sp? >> (`;` | error)
  end

  rule(:try_statement) do
    `try` >> sp? >> block >> sp? >> (`finally` >> sp? >> block |
                        `catch` >> sp? >> `(` >> sp? >> ident >> sp? >> `)` >> sp? >> block >> (sp? >> `finally` >> sp? >> block).maybe
                        )
  end

  rule(:function_declaration) do
    `function` >> sp >> ident >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe >> `)` >> sp? >> `{` >> sp? >> function_body >> sp? >> `}`
  end
  rule(:function_expr) do
    `function` >> (sp >> ident).maybe >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe >> `)` >> sp? >> `{` >> sp? >> function_body >> sp? >> `}`
  end

  rule(:formal_parameter_list) do
    ident >> (sp? >> `,` >> sp? >> ident).repeat
  end

  rule(:function_body) do
    source_elements
  end


  rule(:string) do
    `"` >> (`\\` >> any | match(%([^"\]))).repeat >> `"` |
    `'` >> (`\\` >> any | match(%([^'\]))).repeat >> `'`
  end

  rule(:number) do
    float | integer
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
    ).repeat >> `/` >> match['gim'].repeat
  end

  rule(:ident) do
    reserved >> match['A-Za-z0-9_$'].repeat(1) |
    reserved.absnt? >> match['A-Za-z_$'] >> match['A-Za-z0-9_$'].repeat
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
    match("[ \t\n]").repeat(1) |
    `//` >> any.repeat |
    `/*` >> (`*/`.absnt? >> any).repeat >> `*/`
  end
  rule(:sp?) { sp.repeat }
end

