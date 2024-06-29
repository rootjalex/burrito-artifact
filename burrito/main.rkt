#lang racket

(require
  (only-in racket/struct make-constructor-style-printer)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "cfir.rkt"
  "cin.rkt"
  "cpp-codegen.rkt"
  "cpp-lang.rkt"
  "expr.rkt"
  "format.rkt"
  "index.rkt"
  "infer.rkt"
  "kernel.rkt"
  "seq.rkt"

  "compile.rkt"
)

(define i (Index "i" (arith:Variable "I")))
(define j (Index "j" (arith:Variable "J")))
(define k (Index "k" (arith:Variable "K")))
(define l (Index "l" (arith:Variable "L")))
(define p (Index "p" (arith:Variable "P")))

; Figure 8.
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [b (Array "b" (make-format (list (cons k Compressed))))]
       [c (Array "c" (make-format (list (cons k Dense))))]
       [A_ij (Read A)]
       [b_k (Read b)]
       [expr (Add (Collapse A_ij i j k) b_k)]
       [kernel (Kernel c expr)])
    (compile kernel "fig8" "fig8.cpp")

    (displayln "\n")
)
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [b (Array "b" (make-format (list (cons k Compressed))))]
       [c (Array "c" (make-format (list (cons k Compressed))))]
       [A_ij (Read A)]
       [b_k (Read b)]
       [expr (Add (Collapse A_ij i j k) b_k)]
       [kernel (Kernel c expr)])
    (compile kernel "fig8c" "fig8c.cpp")

    (displayln "\n")
)
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [b (Array "b" (make-format (list (cons k Compressed))))]
       [c (make-scalar-array "c")]
       [A_ij (Read A)]
       [b_k (Read b)]
       [expr (Sum k (Add (Collapse A_ij i j k) b_k))]
       [kernel (Kernel c expr)])
    (compile kernel "fig8csum" "fig8csum.cpp")


    (displayln "\n")
)

(error "stop")

; Figure 9.
(let* ([a (Array "a" (make-format (list (cons k Compressed))))]
       [B (Array "B" (make-format (list (cons i Dense) (cons j Compressed))))]
       [C (Array "C" (make-format (list (cons i Dense) (cons j Dense))))]
       [a_k (Read a)]
       [B_ij (Read B)]
       [expr (Mul (Split a_k k i j) B_ij)]
       [kernel (Kernel C expr)])
    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))

    (displayln "\n")
)

; Figure 12.
(let* ([a (Array "a" (make-format (list (cons k Compressed))))]
       [B (Array "B" (make-format (list (cons i Dense) (cons j Compressed))))]
       [C (Array "C" (make-format (list (cons i Dense) (cons j Dense))))]
       [a_k (Read a)]
       [B_ij (Read B)]
       [expr (Add (Split a_k k i j) B_ij)]
       [kernel (Kernel C expr)])
    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))

    (displayln "\n")
)

; Figure 13.
(let* ([A (Array "A" (make-format (list (cons i Compressed) (cons k Compressed))))]
       [B (Array "B" (make-format (list (cons i Compressed) (cons l Compressed))))]
       [C (Array "C" (make-format (list (cons i Dense) (cons j Dense))))]
       [A_ik (Read A)]
       [B_il (Read B)]
       [s (arith:Constant 0)]
       [e (arith:Div (arith:Variable "L") (arith:Constant 2))]
       [r (arith:Constant 1)]
       [expr (Concat A_ik (Slice B_il l p s e r) k p j)]
       [kernel (Kernel C expr)])
    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))

    (displayln "\n")
)


(let* ([A (Array "A" (make-format (list (cons i Compressed) )))]
       [B (Array "B" (make-format (list (cons i Compressed) )))]
       [C (Array "C" (make-format (list (cons i Dense) )))]
       [A_ij (Read A)]
       [B_ij (Read B)]
       [expr (Add A_ij B_ij)]
       [kernel (Kernel C expr)])
    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))

    (displayln "\n")
)
