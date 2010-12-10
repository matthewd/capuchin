
if (!"!") {
   print('yes');
} else {
   print('no');
}

print(!!print);

for (var x = 0; x < 5; x++) {
   print("x = " + x);
   switch(x) {
      case 1:
         print('1');
      case 2:
         print('2');
         continue;
      case 3:
         print('3');
         break;
      default:
         print('dflt');
   }
   print(".");
}

