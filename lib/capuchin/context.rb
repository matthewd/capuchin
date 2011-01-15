
class Capuchin::Context
  def initialize(debug=$DEBUG)
    @debug = debug

    #@parser = RKelly::Parser.new
    #class << @parser
    #  # A mostly-futile attempt to get the parser to tell us why it fails
    #  def yyerror; yyabort; end
    #  def yyabort
    #    raise ParseError, sprintf("\nparse error on value %s (%s)",
    #                              @racc_val.inspect, token_to_str(@racc_t) || '?')
    #  end
    #end
    @parser = Capuchin::Parser.new
  end
  attr_accessor :debug
  def parse_expression(expression, filename=nil)
    ast = @parser.parse(expression)
    raise "Parse of #{filename ? filename.inspect : 'expression'} failed :(" if ast.nil?
    ast = Capuchin::ASTBuilder.new.apply(ast)
    Rubinius::AST::AsciiGrapher.new(Capuchin::Nodes::RootNode.new(ast), Capuchin::Nodes::Node).print if @debug
    ast
  rescue Parslet::ParseFailed => error
    puts error, @parser.root.error_tree
    raise error
  end
  def parse(filename)
    ast = @parser.parse(File.read(filename))
    raise "Parse of #{filename.inspect} failed :(" if ast.nil?
    ast = Capuchin::ASTBuilder.new.apply(ast)
    Rubinius::AST::AsciiGrapher.new(Capuchin::Nodes::RootNode.new(ast), Capuchin::Nodes::Node).print if @debug
    ast
  rescue Parslet::ParseFailed => error
    puts error, @parser.root.error_tree
    raise error
  end
  def load(filename)
    ast = parse(filename)
    code = compile(ast, filename)
    code.call
  end
  def eval(expression, filename='(eval)')
    ast = parse_expression(expression, filename)
    code = compile(ast, filename)
    code.call
  end
  def compile(ast, filename)
    code = Object.new

    g = Capuchin::Generator.new
    g.name = :call
    g.file = filename.intern
    g.set_line 1

    g.required_args = 0
    g.total_args = 0
    g.splat_index = nil

    g.local_count = 0
    g.local_names = []

    scope = Capuchin::CompileVisitor::Scope.new(nil)
    visitor = Capuchin::CompileVisitor.new(g, scope)

    trees = Array === ast ? ast : [ast]
    trees.each do |tree|
      Capuchin::CompileVisitor::DeclScanner.new(scope).accept(tree)
    end
    scope.append_buffered_definitions g, visitor
    trees.each do |tree|
      visitor.accept(tree)
    end

    g.set_line 0

    g.push_nil
    g.ret
    g.close

    g.local_count = g.state.scope.local_count
    g.local_names = g.state.scope.local_names

    g.encode
    cm = g.package ::Rubinius::CompiledMethod

    if @debug
      p = Rubinius::Compiler::MethodPrinter.new
      p.bytecode = true
      p.print_method(cm)
    end

    ss = ::Rubinius::StaticScope.new Object
    ::Rubinius.attach_method g.name, cm, ss, code

    code
  end
end

