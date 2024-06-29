# Burrito Compiler

The Burrito compiler is embedded in the [Racket](https://racket-lang.org) programming language. Like [Taco](https://github.com/tensor-compiler/taco), it separates an algorithm of tensor operations from the data structures that the algorithm must operate on. It extends the algorithm language to include a set of _shape operators_, specifically, dimension collapsing, concatenation, splitting, and slicing. Like Taco, it also supports element-wise addition and multiplication, dimension summations, and broadcasting (also a shape operator).

## Example
For example, consider a shape operator that concatenates two compressed arrays. We must first define our tensor operands with symbolic sizes. We can define a compressed array of (logical) size "I" like so:
```racket
(define I (arith:Variable "I"))
(define i (Index "i" I))
(define A (Array "A" (make-format (list (cons i Compressed)))))
```
And the second operand, of a possibly different (logical) size "J":
```racket
(define J (arith:Variable "J"))
(define j (Index "j" J))
(define B (Array "B" (make-format (list (cons j Compressed)))))
```
Our output array will have a logical size that is the sum of the two input sizes, so we can define the output vector like so:
```racket
(define k (Index "k" (arith:Add I J)))
(define C (Array "C" (make-format (list (cons k Compressed)))))
```

Now, to define the kernel we wish to compute, we can construct an expression representing the concatenation:
```
(define expr (Concat (Read A) (Read B) i j k))
```
To define a compute kernel, and compile it into C++, we run the `compile` function:
```
(compile (Kernel C expr) "cv_concat_cv_cv" "cv_concat_cv_cv.h")
```
This will generate a header file with a templated (over tensor value type and index type) version of this function in `cv_concat_cv_cv.h`. Runtime types (e.g. for a compressed vector) are defined in [pyburrito/runtime.h](../pyburrito/runtime.h).

The complete code for this example is in [example.rkt](example.rkt). Benchmark kernels for the paper are in [benchmarks.rkt](benchmarks.rkt).
