require 'citrus'
Citrus.load( File.dirname(__FILE__) + '/parser' )

class << Capuchin::Parser
  def nodes(string, root=nil)
    self.parse(string, :consume => true, :root => root).value
  end
end

