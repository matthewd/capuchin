
class Capuchin::Generator < Rubinius::Generator
  def giz(label)
    not_easy = new_label

    dup
    git not_easy
    pop
    goto label

    not_easy.set!
    send :js_truthy?, 0
    gif label
  end
  def gnz(label)
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

  #def encode
  #  @iseq = Rubinius::InstructionSequence.new @stream.to_tuple
  #  @generators.each {|x| @literals[x].encode }
  #end
end

