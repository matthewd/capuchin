
module JSOpen
  def js_hash; @js_hash ||= Rubinius::LookupTable.new; end
  def _js_key?(k); js_hash.key?(k); end
  def _js_get(k); js_hash[k]; end
  def _js_set(k,v); js_hash[k] = v; end
end
class Hash
  def _js_key?(k); key?(k); end
  def _js_get(k); self[k]; end
  def _js_set(k,v); self[k] = v; end
end

module Kernel
  def _js_key?(k); false; end
  def js_value; js_invoke(:valueOf); end
  def js_div(n); self / n; end
  def js_add(other)
    if Numeric === self && Numeric === other
      self + other
    else
      "#{self}#{other}"
    end
  end
  def js_key; to_s.intern; end
  def js_truthy?; self; end
  def js_typeof; 'object'; end
  def js_equal(v); self == v; end
  def js_strictly_equal(v); eql?(v); end
  def js_in(k)
    if _js_key?(name)
      return true
    end

    respond_to?(:"js:#{k}")
  end
  def js_get(name)
    if _js_key?(name)
      return _js_get(name)
    end

    accessor = :"js:#{name}"
    if respond_to?(accessor)
      meth = js_method(accessor)
    end
  end
  def js_set(name, value)
    if UnboundMethod === value || Capuchin::Function === value
      metaclass.send(:_js_define_method, :"js:#{name}") do |*args|
        instance_exec(*args, &value)
      end
      return value
    end
    _js_set(name, value)
  end
  def js_invoke(name, *args)
    accessor = :"js:#{name}"
    if respond_to?(accessor)
      send(accessor, *args)
    elsif f = js_get(name)
      f.js_call(self, *args)
    else
      # Do the send anyway, for the exception
      send(accessor, *args)
    end
  end
  def js_method(name)
    meth = method(name)
    if meth.owner == metaclass
      t = metaclass.instance_variable_get(:@js_methods)
      t && t[name] || meth
    else
      meth
    end
  end
end
class Capuchin::Proto
  include JSOpen
end
class Capuchin::Function
  include JSOpen
  def initialize(name=nil, object=nil, mod=nil, &block)
    @name = name
    @block = block || lambda {}
    @proto = Capuchin::Proto.new
    @module = mod
    _js_set(:prototype, @proto)
    if object
      object.each do |k,v|
        _js_set(k, v)
      end
    end
  end
end
module JSComparable
  def js_lt(other); self.js_cmp < other.js_cmp; end
  def js_gt(other); self.js_cmp > other.js_cmp; end
  def js_lte(other); self.js_cmp <= other.js_cmp; end
  def js_gte(other); self.js_cmp >= other.js_cmp; end
end
class Class
  def js_new(*args); new(*args); end
  def js_instance_of(v); self === v; end
  def js_expose_method(*names)
    names.each do |name|
      alias_method :"js:#{name}", name
    end
  end
  def js_def(name, &block)
    _js_define_method(:"js:#{name}", &block)
  end
  def _js_define_method(name, &block)
    (@js_methods ||= Rubinius::LookupTable.new)[name] = Capuchin::Function.new(&block)
    define_method(name, &block)
  end
end

class Array
  js_expose_method :push

  def js_hash; @js_hash ||= Rubinius::LookupTable.new; end
  def _js_key?(k)
    case k
    when Fixnum; k <= size
    when :length; true
    else; js_hash.key?(k)
    end
  end
  def _js_get(k)
    case k
    when Fixnum; self[k]
    when :length; size
    else; js_hash[k]
    end
  end
  def _js_set(k,v)
    case k
    when Fixnum; self[k] = v
    when :length
      if v > size
        slice!(v, size)
      elsif v < size
        fill(0, size, v)
      end
    else; js_hash[k] = v
    end
  end

  def self.js_new(*args)
    if args.size == 1 && Fixnum === args.first
      new(args.first)
    else
      args
    end
  end
  def self.js_call(this)
    new
  end
end
class Numeric
  include JSComparable
  def js_cmp; self; end
  def js_typeof; 'number'; end
  js_def :valueOf do
    self
  end
end
class Fixnum
  def js_div(n); (0 == n ? self.to_f : self) / n; end
  def js_key; self; end
  def js_truthy?; 0 != self; end
end
class Float
  js_def :toFixed do |x|
    self.to_i
  end
  js_def :toPrecision do |digits|
    "%.#{digits}f" % self
  end
end
class Symbol
  def js_key; self; end
end
class String
  def js_cmp; to_f; end
  js_expose_method :substring
  js_def :indexOf do |needle|
    index(needle) || -1
  end
  js_def :match do |needle|
    Capuchin::RegExp === needle ? needle.exec(self) : index(needle) ? needle : nil
  end
  js_def :replace do |needle, replacement|
    case needle
    when Capuchin::RegExp
      needle.replace(self, replacement)
    else
      sub(needle, replacement)
    end
  end

  def js_get(k)
    case k
    when :length; size
    else; super
    end
  end
  def js_key?(k)
    case k
    when :length; true
    else; super
    end
  end

  def js_key; intern; end
  def js_truthy?; size > 0; end
  def js_typeof; 'string'; end
  def self.js_call(this, v)
    v.to_s
  end
end
class TrueClass
  include JSComparable
  def js_cmp; 1; end
  def js_typeof; 'boolean'; end
end
class FalseClass
  include JSComparable
  def js_cmp; 0; end
  def js_typeof; 'boolean'; end
end
class NilClass
  include JSComparable
  def js_cmp; 0; end
  def js_div(n); 0.js_div(n); end
end
class Method
  include JSOpen
  def js_prototype
    @proto || (
      @proto = Capuchin::Proto.new
      _js_set(:prototype, @proto)
    )
  end
  def js_typeof; 'function'; end
  def js_call(target, *args)
    if receiver.eql? target
      call(*args)
    else
      unbind.bind(target).call(*args)
    end
  end
  def js_apply(target, args)
    js_call(target, *args)
  end
  js_def :call do |this, *args|
    js_call(this, *args)
  end
  js_def :apply do |this, args|
    js_call(this, *args)
  end
  def js_new(*args)
    o = Capuchin::Obj.new(self, js_prototype)
    js_call(o, *args)
    o
  end
end
class UnboundMethod
  include JSOpen
  def js_prototype
    @proto || (
      @proto = Capuchin::Proto.new
      _js_set(:prototype, @proto)
    )
  end
  def js_typeof; 'function'; end
  def js_call(target, *args)
    bind(target).call(*args)
  end
  def js_apply(target, args)
    js_call(target, *args)
  end
  js_def :call do |this, *args|
    js_call(this, *args)
  end
  js_def :apply do |this, args|
    js_call(this, *args)
  end
  def js_new(*args)
    o = Capuchin::Obj.new(self, js_prototype)
    js_call(o, *args)
    o
  end
end

class Capuchin::Builtin
  include JSOpen
  def initialize(hash=nil)
    @js_hash = Rubinius::LookupTable.new
    if hash
      hash.each do |k,v|
        _js_set(k, v)
      end
    end
  end
end
class Capuchin::Obj
  include JSOpen
  def initialize(constructor, proto)
    _js_set(:constructor, constructor)
    @__proto__ = proto
  end
  def js_get(name)
    super || @__proto__.js_get(name)
  end
  def js_in(k)
    super || @__proto__.js_in(k)
  end
  def to_f
    js_value.to_f
  end
  def to_i
    js_value.to_i
  end
  def to_s
    js_value.to_s
  end
  def to_str
    js_value.to_s
  end
  def self.js_new
    @empty_proto ||= Capuchin::Proto.new
    new(nil, @empty_proto)
  end
end
class Capuchin::Function
  def call(*args)
    js_call(nil, *args)
  end
  js_def :call do |this, *args|
    js_call(this, *args)
  end
  js_def :apply do |this, args|
    js_call(this, *args)
  end
  def js_typeof; 'function'; end
  def js_call(target, *args)
    target.instance_exec(*args, &@block)
  end
  def js_apply(target, args)
    js_call(target, *args)
  end
  def js_new(*args)
    o = Capuchin::Obj.new(self, @proto)
    js_call(o, *args)
    o.extend(@module) if @module
    o
  end
  def to_proc
    @block
  end
end
class Capuchin::RegExp
  def initialize(pattern, flag_str=nil)
    @pattern = pattern

    flags = (flag_str ||= '').split('')

    @i = flags.include?('i')
    @g = flags.include?('g')
    @m = flags.include?('m')

    @regexp = build_regexp

    @last = 0
  end
  def build_regexp
    # There are probably translations that need to be done here
    pattern = @pattern

    flags = 0
    flags |= Regexp::IGNORECASE if @i
    flags |= Regexp::MULTILINE if @m

    Regexp.new(pattern, flags)
  end
  def js_get(k)
    case k
    when :source; @pattern
    when :ignoreCase; @i
    when :global; @g
    when :multiline; @m
    when :lastIndex; @last
    else; super
    end
  end
  def js_key?(k)
    case k
    when :source; true
    when :ignoreCase; true
    when :global; true
    when :multiline; true
    when :lastIndex; true
    else; super
    end
  end
  js_def :test do |str|
    @regexp.match(str) ? true : false
  end
  def replace(haystack, replacement)
    if @g
      haystack.gsub(@regexp, replacement)
    else
      haystack.sub(@regexp, replacement)
    end
  end
  def exec(str)
    if m = @regexp.match(str)
      @last = m.offset(0).last
      m.to_a
    else
      @last = 0
      nil
    end
  end
  js_expose_method :exec
  def js_call(str)
    exec(str)
  end
end

module Capuchin::DateMethods
  attr :t
  def -(other)
    (t - other.t) * 1000
  end
end

Capuchin::Globals = Rubinius::LookupTable.new
Capuchin::Globals[:xulRunner] = {}
Capuchin::Globals[:Array] = Array
Capuchin::Globals[:String] = String
Capuchin::Globals[:Object] = Capuchin::Obj
Capuchin::Globals[:Function] = Capuchin::Function
Capuchin::Globals[:RegExp] = Capuchin::RegExp
Capuchin::Globals[:Date] = Capuchin::Function.new('Date', nil, Capuchin::DateMethods) {|| @t = Time.new }
Capuchin::Globals[:print] = Capuchin::Function.new {|x| puts x }
Capuchin::Globals[:p] = Capuchin::Function.new {|x| p [x, x.methods.grep(/^js:/)] }
Capuchin::Globals[:gc] = Capuchin::Function.new {|x| GC.start }
Capuchin::Globals[:Math] = Capuchin::Builtin.new({
  :log => Capuchin::Function.new {|n| Math.log(n.js_value) },
  :pow => Capuchin::Function.new {|a,b| a.js_value ** b.js_value },
  :sqrt => Capuchin::Function.new {|n| Math.sqrt(n.js_value) },
  :sin => Capuchin::Function.new {|n| Math.sin(n.js_value) },
  :cos => Capuchin::Function.new {|n| Math.cos(n.js_value) },
  :E => Math::E,
  :PI => Math::PI,
})
Capuchin::Globals[:run] = Capuchin::Globals[:load] = Capuchin::Function.new do |filename|
  cx = Capuchin::Context.new
  start = Time.now
  cx.load(filename)
  done = Time.now
  (done - start) * 1000
end

# This isn't a real solution; eval needs to be a compiler construct, so
# it gets the containing scope's variables, etc.
Capuchin::Globals[:eval] = Capuchin::Function.new do |src|
  Capuchin::Context.new.eval(src)
end

Capuchin::Globals[:version] = Capuchin::Function.new {|x| }

