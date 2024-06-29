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

; (let* ([A (Array "A" (make-format (list (cons i Compressed))))]
;        [B (Array "B" (make-format (list (cons j Compressed))))]
;        [A_i (Read A)]
;        [B_j (Read B)]
;        [s (arith:Constant 0)]
;        [e (arith:Variable "J")]
;        [r (arith:Constant 2)]
;        [expr (Slice B_j j i s e r)]
;        [kernel (Kernel A expr)])
    
;     (displayln "CIN:")
;     (define cin (cin:codegen kernel))
;     (displayln (cin:print cin))

;     (displayln "CFIR:")
;     (define cfir (cfir:codegen cin))
;     (displayln (cfir:print cfir))

;     (displayln "CPP:")
;     (define ccode (cpp:codegen cfir))
;     (displayln (cpp:print-stmt ccode))

;     (displayln "\n")
; )

; (let* ([A (Array "A" (make-format (list (cons i Dense) (cons k Dense))))]
;        [B (Array "B" (make-format (list (cons k Dense) (cons j Dense))))]
;        [C (Array "C" (make-format (list (cons i Dense) (cons j Dense))))]
;        [A_ik (Broadcast j (Read A))]
;        [B_kj (Broadcast i (Read B))]
;        [kernel (Kernel C (Sum k (Mul A_ik B_kj)))])

;     (define cin (cin:codegen kernel))
;     (displayln (cin:print cin))

;     (displayln "CFIR:")
;     (define cfir (cfir:codegen cin))
;     (displayln (cfir:print cfir))

;     (displayln "CPP:")
;     (define ccode (cpp:codegen cfir))
;     (displayln (cpp:print-stmt ccode))

; )


; (let* ([A (Array "A" (make-format (list (cons i Dense) (cons k Compressed))))]
;        [B (Array "B" (make-format (list (cons j Dense) (cons k Compressed))))]
;        [C (Array "C" (make-format (list (cons i Dense) (cons j Dense))))]
;        [A_ik (Broadcast j (Read A))]
;        [B_kj (Broadcast i (Read B))]
;        [kernel (Kernel C (Sum k (Mul A_ik B_kj)))])

;     (define cin (cin:codegen kernel))
;     (displayln (cin:print cin))
;     (displayln "\n")

;     (define cfir (cfir:codegen cin))
;     (displayln (cfir:print cfir))
;     (displayln "\n")

;     (define cpp (cpp:codegen cfir))
;     (displayln (cpp:print-stmt cpp))
;     (displayln "\n")
; )

(let* ([A (Array "A" (make-format (list (cons i Dense))))]
       [B (Array "B" (make-format (list (cons i Dense))))]
       [C (Array "C" (make-format (list (cons i Dense))))]
       [D (Array "D" (make-format (list (cons i Dense))))]
       [B_i (Read B)]
       [C_i (Read C)]
       [D_i (Read D)]
       [expr (Add (Mul B_i C_i) D_i)] ; <-- B * C + D
       [kernel (Kernel A expr)])

    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (displayln "\n")

    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))
    (displayln "\n")

    (define cpp (cpp:codegen cfir))
    (displayln (cpp:print-stmt cpp))
    (displayln "\n")
)

(let* ([A (Array "A" (make-format (list (cons i Dense))))]
       [B (Array "B" (make-format (list (cons i Dense))))]
       [C (Array "C" (make-format (list (cons i Dense))))]
       [D (Array "D" (make-format (list (cons i Dense))))]
       [B_i (Read B)]
       [C_i (Read C)]
       [D_i (Read D)]
       [expr (Add B_i (Mul C_i D_i))] ; <-- B + C * D
       [kernel (Kernel A expr)])

    (define cin (cin:codegen kernel))
    (displayln (cin:print cin))
    (displayln "\n")

    (define cfir (cfir:codegen cin))
    (displayln (cfir:print cfir))
    (displayln "\n")

    (define cpp (cpp:codegen cfir))
    (displayln (cpp:print-stmt cpp))
    (displayln "\n")
)
