
var o = { a: 1, b: 2, c: 3, x: function() { p(this); print('xx'); } };
print(o.a);
o.d = 4;
print(o.d);
print(o['d'+'']);

p(o);

o.x();

var z = o.x;

z();

z.call('foo');

