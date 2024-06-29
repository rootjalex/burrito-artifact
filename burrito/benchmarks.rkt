#lang racket

(require
  (only-in racket/struct make-constructor-style-printer)
  rosette/lib/destruct
  "arith.rkt"
  "array.rkt"
  "expr.rkt"
  "format.rkt"
  "index.rkt"
  "kernel.rkt"
  "compile.rkt"
)

(define I (arith:Variable "I"))
(define J (arith:Variable "J"))
(define K (arith:Variable "K"))
(define L (arith:Variable "L"))
(define P (arith:Variable "P"))

(define i (Index "i" I))
(define j (Index "j" J))
(define k (Index "k" K))
(define l (Index "l" L))
(define p (Index "p" P))

; C = collapse(COO)
(let* ([A (Array "A" (make-format (list (cons i Coordinate) (cons j Coordinate))))]
       [k (Index "k" (arith:Mul I J))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [A_ij (Read A)]
       [expr (Collapse A_ij i j k)]
       [kernel (Kernel B expr)])
    (compile kernel "cv_collapse_coo" "pyburrito/cv_collapse_coo.h"))

; COO = hstack(COO, COO)
(let* ([A (Array "A" (make-format (list (cons i Coordinate) (cons j Coordinate))))]
       [B (Array "B" (make-format (list (cons i Coordinate) (cons k Coordinate))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons i Coordinate) (cons l Coordinate))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "coo_hstack_coo_coo" "pyburrito/coo_hstack_coo_coo.h"))

; COO = vstack(COO, COO)
(let* ([A (Array "A" (make-format (list (cons j Coordinate) (cons i Coordinate))))]
       [B (Array "B" (make-format (list (cons k Coordinate) (cons i Coordinate))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons l Coordinate) (cons i Coordinate))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "coo_vstack_coo_coo" "pyburrito/coo_vstack_coo_coo.h"))


; CSR = hstack(CSR, CSR)
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [B (Array "B" (make-format (list (cons i Dense) (cons k Compressed))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons i Dense) (cons l Compressed))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "csr_hstack_csr_csr" "pyburrito/csr_hstack_csr_csr.h"))

; CSR = vstack(CSR, CSR)
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [B (Array "B" (make-format (list (cons k Dense) (cons i Compressed))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons l Dense) (cons i Compressed))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "csr_vstack_csr_csr" "pyburrito/csr_vstack_csr_csr.h"))

; CSR = slice(CSR)
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [s0 (arith:Variable "s0")]
       [e0 (arith:Variable "e0")]
       [r0 (arith:Variable "r0")]
       [K (arith:Div (arith:Add (arith:Sub e0 s0) (arith:Sub r0 (arith:Constant 1))) r0)]
       [k (Index "k" K)]
       [B (Array "B" (make-format (list (cons k Dense) (cons i Compressed))))]
       [A_ji (Read A)]
       [expr (Slice A_ji j k s0 e0 r0)]
       [kernel (Kernel B expr)])
    (compile kernel "csr_slice_1d_csr" "pyburrito/csr_slice_1d_csr.h"))

; COO = split(C)
(let* ([A (Array "A" (make-format (list (cons i Coordinate) (cons j Coordinate))))]
       [k (Index "k" (arith:Mul I J))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [B_k (Read B)]
       [expr (Split B_k k i j)]
       [kernel (Kernel A expr)])
    (compile kernel "coo_split_cv" "pyburrito/coo_split_cv.h"))

; CSR = split(C)
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [k (Index "k" (arith:Mul I J))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [B_k (Read B)]
       [expr (Split B_k k i j)]
       [kernel (Kernel A expr)])
    (compile kernel "csr_split_cv" "pyburrito/csr_split_cv.h"))

; CSR = hstack(COO, COO)
(let* ([A (Array "A" (make-format (list (cons i Coordinate) (cons j Coordinate))))]
       [B (Array "B" (make-format (list (cons i Coordinate) (cons k Coordinate))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons i Dense) (cons l Compressed))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "csr_hstack_coo_coo" "pyburrito/csr_hstack_coo_coo.h"))

; COO = vstack(CSR, CSR)
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [B (Array "B" (make-format (list (cons k Dense) (cons i Compressed))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons l Coordinate) (cons i Coordinate))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "coo_vstack_csr_csr" "pyburrito/coo_vstack_csr_csr.h"))

; COO = hstack(CSR, CSR)
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [B (Array "B" (make-format (list (cons i Dense) (cons k Compressed))))]
       [l (Index "l" (arith:Add J K))]
       [C (Array "C" (make-format (list (cons i Coordinate) (cons l Coordinate))))]
       [A_ij (Read A)]
       [B_ik (Read B)]
       [expr (Concat A_ij B_ik j k l)]
       [kernel (Kernel C expr)])
    (compile kernel "coo_hstack_csr_csr" "pyburrito/coo_hstack_csr_csr.h"))

; COO = slice(CSR)
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [s0 (arith:Variable "s0")]
       [e0 (arith:Variable "e0")]
       [r0 (arith:Variable "r0")]
       [K (arith:Div (arith:Add (arith:Sub e0 s0) (arith:Sub r0 (arith:Constant 1))) r0)]
       [k (Index "k" K)]
       [B (Array "B" (make-format (list (cons k Coordinate) (cons i Coordinate))))]
       [A_ji (Read A)]
       [expr (Slice A_ji j k s0 e0 r0)]
       [kernel (Kernel B expr)])
    (compile kernel "coo_slice_1d_csr" "pyburrito/coo_slice_1d_csr.h"))

; C = collapse(CSR) * C
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [k (Index "k" (arith:Mul I J))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [C (Array "C" (make-format (list (cons k Compressed))))]
       [A_ij (Read A)]
       [B_k (Read B)]
       [expr (Mul (Collapse A_ij i j k) B_k)]
       [kernel (Kernel C expr)])
    (compile kernel "cv_collapse_csr_mul_cv" "pyburrito/cv_collapse_csr_mul_cv.h"))
; The unfused pieces of above
; TODO: could use CSR workspace?
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [k (Index "k" (arith:Mul I J))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [A_ij (Read A)]
       [expr (Collapse A_ij i j k)]
       [kernel (Kernel B expr)])
    (compile kernel "cv_collapse_csr" "pyburrito/cv_collapse_csr.h"))
(let* ([A (Array "A" (make-format (list (cons k Compressed))))]
       [B (Array "B" (make-format (list (cons k Compressed))))]
       [C (Array "C" (make-format (list (cons k Compressed))))]
       [A_k (Read A)]
       [B_k (Read B)]
       [expr (Mul A_k B_k)]
       [kernel (Kernel C expr)])
    (compile kernel "cv_mul_cv_cv" "pyburrito/cv_mul_cv_cv.h"))

; D = sum(vstack(CSR, CSR) * D)
; dv_sum_vstack_csr_csr_mul_dv
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [B (Array "B" (make-format (list (cons k Dense) (cons i Compressed))))]
       [C (Array "C" (make-format (list (cons i Dense))))]
       [l (Index "l" (arith:Add J K))]
       [D (Array "D" (make-format (list (cons l Dense))))]
       [A_ji (Read A)]
       [B_ki (Read B)]
       [C_i (Read C)]
       [expr (Sum i (Mul (Concat A_ji B_ki j k l) (Broadcast l C_i)))]
       [kernel (Kernel D expr)])
    (compile kernel "dv_sum_vstack_csr_csr_mul_dv" "pyburrito/dv_sum_vstack_csr_csr_mul_dv.h"))
; The unfused SpMV of above (vstack(CSR, CSR) is already done above)
; TODO: could use CSR workspace?
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [B (Array "B" (make-format (list (cons j Dense))))]
       [C (Array "C" (make-format (list (cons i Dense))))]
       [A_ij (Read A)]
       [B_j (Read B)]
       [expr (Sum j (Mul A_ij (Broadcast i B_j)))]
       [kernel (Kernel C expr)])
    (compile kernel "dv_sum_csr_mul_dv" "pyburrito/dv_sum_csr_mul_dv.h"))

; CSR = slice(CSR) * CSR
(let* ([A (Array "A" (make-format (list (cons j Dense) (cons i Compressed))))]
       [s0 (arith:Variable "s0")]
       [e0 (arith:Variable "e0")]
       [r0 (arith:Variable "r0")]
       [K (arith:Div (arith:Add (arith:Sub e0 s0) (arith:Sub r0 (arith:Constant 1))) r0)]
       [k (Index "k" K)]
       [B (Array "B" (make-format (list (cons k Dense) (cons i Compressed))))]
       [C (Array "C" (make-format (list (cons k Dense) (cons i Compressed))))]
       [A_ji (Read A)]
       [B_ki (Read B)]
       [expr (Mul (Slice A_ji j k s0 e0 r0) B_ki)]
       [kernel (Kernel C expr)])
    (compile kernel "csr_slice_1d_csr_mul_csr" "pyburrito/csr_slice_1d_csr_mul_csr.h"))
; The unfused CSR * CSR of above (slice(CSR) is already done above)
; TODO: could use CSR workspace?
(let* ([A (Array "A" (make-format (list (cons i Dense) (cons j Compressed))))]
       [B (Array "B" (make-format (list (cons i Dense) (cons j Compressed))))]
       [C (Array "C" (make-format (list (cons i Dense) (cons j Compressed))))]
       [A_ij (Read A)]
       [B_ij (Read B)]
       [expr (Mul A_ij B_ij)]
       [kernel (Kernel C expr)])
    (compile kernel "csr_mul_csr_csr" "pyburrito/csr_mul_csr_csr.h"))
