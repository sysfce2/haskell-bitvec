bitvec
======

Another bit-array library for Haskell.  This one defines a Bit type (which is an instance of all the "expected" classes, including numeric ones) and makes that type an instance of Data.Vector.Unboxed.Unbox, so we get a lot of nice APIs for free.  Bool is already an unboxable type, but the current implementation packs each bit as a byte.  This one packs 8 bits per byte, as expected.

In addition to the Vector interface, there are several high-level operations and some low-level ones suitable for building new bulk operations by viewing the bit-vector as a word vector.