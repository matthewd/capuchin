
class Capuchin::Generator < Rubinius::Generator
  # Nodes that are guaranteed to leave a VM true or false (or nil) on
  # the stack, meaning we don't need to do a full truthiness check.
  BoolSafeNodes = %w(
    Capuchin::Nodes::TrueNode
    Capuchin::Nodes::FalseNode
    Capuchin::Nodes::NullNode
    Capuchin::Nodes::LogicalNotNode
    Capuchin::Nodes::EqualNode
    Capuchin::Nodes::StrictEqualNode
    Capuchin::Nodes::NotEqualNode
    Capuchin::Nodes::NotStrictEqualNode
    Capuchin::Nodes::InstanceOfNode
    Capuchin::Nodes::InNode
    Capuchin::Nodes::GreaterNode
    Capuchin::Nodes::GreaterOrEqualNode
    Capuchin::Nodes::LessNode
    Capuchin::Nodes::LessOrEqualNode
    Capuchin::Nodes::VoidNode
  )

  def bool_safe?(o)
    if BoolSafeNodes.include?(o.class.name)
      return true
    end

    if Capuchin::Nodes::LogicalAndNode === o || Capuchin::Nodes::LogicalOrNode === o
      bool_safe?(o.left) && bool_safe?(o.value)
    end

    false
  end

  def giz(label, src=nil)
    if src && bool_safe?(src)
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
    if src && bool_safe?(src)
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

