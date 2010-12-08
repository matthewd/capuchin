
class Capuchin::Generator < Rubinius::Generator
  # Nodes that are guaranteed to leave a VM true or false (or nil) on
  # the stack, meaning we don't need to do a full truthiness check.
  BoolSafeNodes = %w(
    RKelly::Nodes::TrueNode
    RKelly::Nodes::FalseNode
    RKelly::Nodes::NullNode
    RKelly::Nodes::LogicalNotNode
    RKelly::Nodes::LogicalAndNode
    RKelly::Nodes::LogicalOrNode
    RKelly::Nodes::EqualNode
    RKelly::Nodes::StrictEqualNode
    RKelly::Nodes::NotEqualNode
    RKelly::Nodes::NotStrictEqualNode
    RKelly::Nodes::InstanceOfNode
    RKelly::Nodes::InNode
    RKelly::Nodes::GreaterNode
    RKelly::Nodes::GreaterOrEqualNode
    RKelly::Nodes::LessNode
    RKelly::Nodes::LessOrEqualNode
    RKelly::Nodes::VoidNode
  )

  def giz(label, src=nil)
    if src && BoolSafeNodes.include?(src.class.name)
      gif label
    else
      not_easy = new_label

      dup
      git not_easy
      pop
      goto label

      not_easy.set!
      send :js_truthy?, 0
      gif label
    end
  end
  def gnz(label, src=nil)
    if src && BoolSafeNodes.include?(src.class.name)
      git label
    else
      do_pop = new_label
      the_end = new_label

      dup
      gif do_pop
      send :js_truthy?, 0
      gif the_end
      goto label

      do_pop.set!
      pop
      the_end.set!
    end
  end

  #def encode
  #  @iseq = Rubinius::InstructionSequence.new @stream.to_tuple
  #  @generators.each {|x| @literals[x].encode }
  #end
end

