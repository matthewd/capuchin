# Capuchin

A JavaScript implementation, running on the Rubinius VM.


## Usage

Given `eg/nest.js`:

    function a(n) {
      n = n + 4;
      function b(n) {
         n = n + 5;
         return n * 2;
      }
      return n + b(7);
    }
    
    print(a(3));

Run:

    bin/capuchin eg/nest.js

And you'll see:

    (Loads of debug information that I haven't turned off yet, and...)
    31

(Which isn't very exciting, but is correct, and demonstrates that the
inner `n` parameter correctly shadows the outer.)

Alternatively, run something more interesting, and then fix whatever
breaks.

