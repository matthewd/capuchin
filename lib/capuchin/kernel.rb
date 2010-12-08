
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
    if respond_to?(:_js_get)
      if respond_to?(:_js_key?)
        if _js_key?(name)
          return true
        end
      elsif _js_get(name)
        return true
      end
    end

    respond_to?(:"js:#{k}")
  end
  def js_get(name)
    getter = :"js:get:#{name}"
    if respond_to?(getter)
      return send(getter)
    end

    if respond_to?(:_js_get)
      if respond_to?(:_js_key?)
        if _js_key?(name)
          return _js_get(name)
        end
      elsif v = _js_get(name)
        return v
      end
    end

    accessor = :"js:#{name}"
    if respond_to?(accessor)
      meth = js_method(accessor)
    end
  end
  def js_set(name, value)
    setter = :"js:set:#{name}"
    if respond_to?(setter)
      return send(setter, value)
    end

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
def test_js_respond_to(name, *args)
  respond_to?(:"js:#{name}")
end
def invoke_js_respond_to(name, *args)
  send(:"js:#{name}", *args)
end
def invoke_js_get(name, *args)
  js_get(name).js_call(self, *args)
end
def Rubinius.bind_call(recv, meth, *args)
  # meth == :js_invoke
  case meth
  when :js_invoke
    Rubinius::CallUnit.test(
      Rubinius::CallUnit.for_method(method(:test_js_respond_to)),
      Rubinius::CallUnit.for_method(method(:invoke_js_respond_to)),
      Rubinius::CallUnit.for_method(method(:invoke_js_get))
    )
  else
    raise ArgumentError, "bind_call for unknown '#{meth}'"
  end
end
class Capuchin::Proto
  include JSOpen
end
class Capuchin::Function
  include JSOpen
  def initialize(name=nil, object={}, mod=nil, &block)
    @name = name
    @block = block || lambda {}
    @proto = Capuchin::Proto.new
    @module = mod
    _js_set(:prototype, @proto)
    object.each do |k,v|
      _js_set(k, v)
    end
  end
end
class Class
  def js_new(*args); new(*args); end
  def js_instance_of(v); self === v; end
  def js_expose_method(*names)
    names.each do |name|
      alias_method :"js:#{name}", name
    end
  end
  def js_expose_attr(*names)
    names.each do |name|
      alias_method :"js:get:#{name}", name
      if method_defined?(:"#{name}=")
        alias_method :"js:set:#{name}", :"#{name}="
      end
    end
  end
  def js_def(name, &block)
    _js_define_method(:"js:#{name}", &block)
  end
  def js_attr(name, &block)
    name = name.to_s.dup
    if name.sub!(/=$/, '')
      _js_define_method(:"js:set:#{name}", &block)
    else
      _js_define_method(:"js:get:#{name}", &block)
    end
  end
  def _js_define_method(name, &block)
    (@js_methods ||= Rubinius::LookupTable.new)[name] = Capuchin::Function.new(&block)
    define_method(name, &block)
  end
end

class Array
  js_attr :length do
    size
  end
  js_attr :length= do |n|
    if n > size
      slice!(n, size)
    elsif n < size
      fill(0, size, n)
    end
  end
  js_expose_method :push

  def js_hash; @js_hash ||= Rubinius::LookupTable.new; end
  def _js_key?(k); Fixnum === k ? k <= size : js_hash.key?(k); end
  def _js_get(k); Fixnum === k ? self[k] : js_hash[k]; end
  def _js_set(k,v); Fixnum === k ? self[k] = v : js_hash[k] = v; end

  def self.js_new(*args)
    new(*args)
  end
end
class Integer
  def js_div(n); n == 0 ? self.to_f / n : self / n; end
  js_def :valueOf do
    self
  end
end
class Fixnum
  def js_key; self; end
  def js_truthy?; 0 != self; end
  def js_typeof; 'number'; end
end
class Float
  def js_typeof; 'number'; end
  js_def :toFixed do |x|
    self.to_i
  end
  js_def :valueOf do
    self
  end
  js_def :toPrecision do |digits|
    "%.#{digits}f" % self
  end
end
class Symbol
  def js_key; self; end
end
class String
  js_attr :length do
    size
  end
  js_expose_method :substring
  js_def :indexOf do |needle|
    index(needle) || -1
  end
  def js_key; intern; end
  def js_truthy?; size > 0; end
  def js_typeof; 'string'; end
end
class TrueClass
  def js_typeof; 'boolean'; end
end
class FalseClass
  def js_typeof; 'boolean'; end
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

module Capuchin::DateMethods
  attr :t
  def -(other)
    (t - other.t) * 1000
  end
end

Capuchin::Globals = Rubinius::LookupTable.new
Capuchin::Globals[:Array] = Array
Capuchin::Globals[:Object] = Capuchin::Obj
Capuchin::Globals[:Date] = Capuchin::Function.new('Date', {}, Capuchin::DateMethods) {|| @t = Time.new }
Capuchin::Globals[:print] = Capuchin::Function.new {|x| puts x }
Capuchin::Globals[:p] = Capuchin::Function.new {|x| p [x, x.methods.grep(/^js:/)] }
Capuchin::Globals[:Math] = {
  :log => Capuchin::Function.new {|n| Math.log(n.js_value) },
  :pow => Capuchin::Function.new {|a,b| a.js_value ** b.js_value },
  :sqrt => Capuchin::Function.new {|n| Math.sqrt(n.js_value) },
  :E => Math::E,
}
Capuchin::Globals[:run] = Capuchin::Globals[:load] = Capuchin::Function.new do |filename|
  cx = Capuchin::Context.new
  start = Time.now
  cx.load(filename)
  done = Time.now
  (done - start) * 1000
end

