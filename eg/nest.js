
function a(n) {
  n = n + 4;
  function b(n) {
     n = n + 5;
     return n * 2;
  }
  return n + b(7);
}

print(a(3));

