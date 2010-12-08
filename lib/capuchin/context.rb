
class Capuchin::Context
  def initialize(debug=$DEBUG)
    @debug = debug

    @parser = RKelly::Parser.new
    class << @parser
      # A mostly-futile attempt to get the parser to tell us why it fails
      def yyerror; yyabort; end
      def yyabort
        raise ParseError, sprintf("\nparse error on value %s (%s)",
                                  @racc_val.inspect, token_to_str(@racc_t) || '?')
      end
    end
  end
  def parse(filename)
    ast = @parser.parse(File.read(filename), filename)
    raise "Parse of #{filename.inspect} failed :(" if ast.nil?
    Rubinius::AST::AsciiGrapher.new(ast, RKelly::Nodes::Node).print if @debug
    ast
  end
  def load(filename)
    ast = parse(filename)
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

    scope = Capuchin::Visitor::Scope.new(nil)
    visitor = Capuchin::Visitor.new(g, scope)

    trees = Array === ast ? ast : [ast]
    trees.each do |tree|
      tree.accept(Capuchin::Visitor::DeclScanner.new(scope))
    end
    scope.append_buffered_definitions g, visitor
    trees.each do |tree|
      tree.accept(visitor)
    end

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

