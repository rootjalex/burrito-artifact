#lang racket

(require
  rosette/lib/destruct
  racket/hash
  "arith.rkt"
  "array.rkt"
  "cfir.rkt"
  "cin.rkt"
  "cpp-codegen.rkt"
  "cpp-lang.rkt"
  "cpp-utils.rkt"
  "expr.rkt"
  "format.rkt"
  "index.rkt"
  "kernel.rkt"
)

(provide compile)

(define (compile kernel fname filename)

  (define expr (Kernel-expr kernel))
  (define array (Kernel-array kernel))

  (when (expr:contains-reshape? expr)
    (cpp:set-index_t! "uint64_t"))
  (define small_index_t (if (expr:contains-reshape? expr) "small_index_t" "index_t"))
  (define large_index_t (if (expr:contains-reshape? expr) "large_index_t" "index_t"))

  (define cin (cin:codegen kernel))
  ; (displayln (cin:print cin))
  (define cfir (cfir:codegen cin))
  ; (displayln (cfir:print cfir))
  (define initset (mutable-set))
  (define ccode (cpp:codegen cfir initset array))
  ; (displayln (cpp:print-stmt ccode))

  (define array-args (expr:gather-arrays expr))
  (define scalar-args (get-sorted-args expr))

  (define outfile (open-output-file filename #:exists 'replace))
  (displayln "#pragma once" outfile)
  (displayln "#include \"runtime.h\"" outfile)
  ; Detect reshapes, use small_index_t and large_index_t if necessary.
  (if (expr:contains-reshape? expr)
    (displayln "\ntemplate<typename small_index_t, typename large_index_t, typename value_t>" outfile)
    (displayln "\ntemplate<typename index_t, typename value_t>" outfile))
  (displayln (format "~a ~a(~a) {" (make-runtime-type array small_index_t large_index_t) fname (make-arg-string array-args scalar-args array small_index_t large_index_t)) outfile)
  ; Extract sizes from each tensor argument.
  ; TODO: don't do this for dense arrays.
  (for-each (lambda (a) (displayln (extract-params a) outfile)) (filter (lambda (array) (not (array-is-dense? array))) array-args))
  (displayln "" outfile)
  (for-each (lambda (a) (displayln (extract-compressed-arrays a small_index_t large_index_t) outfile)) array-args)
  ; Define each size as a computation.
  (displayln (codegen-array-sizes expr) outfile)
  (displayln "" outfile)
  (displayln (codegen-compute-nnz expr cfir) outfile)
  (displayln "" outfile)
  ; allocate output array.
  (displayln (codegen-allocate-output array "ret_nnz" small_index_t large_index_t) outfile)
  ; set up output iterators
  (displayln (codegen-output-iterators array large_index_t) outfile)
  (displayln "" outfile)
  ; Print the actual code.
  (displayln (cpp:_print-stmt ccode "  ") outfile)
  ; Print the return statement.
  (displayln (codegen-return-output array small_index_t large_index_t) outfile)
  (displayln "}" outfile)
  (close-output-port outfile))

(define (extract-params structure)
  (define name (Array-name structure))
  (define f (Array-format structure))
  (define modes (Format-modes f))
  (define levels (Format-levels f))
  (string-join
    (append
      (map (lambda (idx count) (format "  const uint64_t ~a~a = ~a.shape(~a);" (string-upcase (idx-name idx)) name name count)) modes (range (length modes)))
      (list (format "  const uint64_t ~a_nnz = ~a.data.shape(0);" name name)))
    "\n"))

(define (extract-compressed-arrays array small_index_t large_index_t)
  (define name (Array-name array))
  (define f (Array-format array))
  (define small_idx_type (format "const ~a *__restrict" small_index_t))
  (define large_idx_type (format "const ~a *__restrict" large_index_t))
  (define data_type "const value_t *__restrict")
  (cond
    [(is-csr? f)
      (format "  ~a ~a = ~a.indptr.data();\n  ~a ~a = ~a.indices.data();\n  ~a ~a_data = ~a.data.data();\n" small_idx_type (get-level-name array (array-idx array 0)) name small_idx_type (get-level-name array (array-idx array 1)) name data_type name name)]
    [(is-coo? f)
      (format "  ~a ~a = ~a.row.data();\n  ~a ~a = ~a.col.data();\n  ~a ~a_data = ~a.data.data();\n" small_idx_type (get-level-name array (array-idx array 0)) name small_idx_type (get-level-name array (array-idx array 1)) name data_type name name)]
    [(is-cvector? f)
      (format "  const uint64_t ~A_pos[2] = {0, ~a_nnz};\n  ~a ~a = ~a.indices.data();\n  ~a ~a_data = ~a.data.data();\n" name name large_idx_type (get-level-name array (array-idx array 0)) name data_type name name)]
    [(is-dvector? f)
      (format "  ~a ~a_data = ~a.data();\n" data_type name name)]
    ; TODO: handle general case (need general runtime type, or to codegen runtime type).
    [else (error (format "unrecognized runtime format in C++ codegen: ~a with format ~a" name f))]))

; sometimes need split/slice args.
(define (gather-args expr)
  (destruct expr
    [(Read array) (list)]
    [(Add a b) (append (gather-args a) (gather-args b))]
    [(Mul a b) (append (gather-args a) (gather-args b))]
    [(Sum idx a) (gather-args a)]

    [(Broadcast idx a) (gather-args a)]
    [(Collapse a i j k) (gather-args a)]
    [(Concat a b i j k) (append (gather-args a) (gather-args b))]
    [(Split a i j k) (append (gather-args a) (list (idx-size j) (idx-size k)))]
    [(Slice a i j s e r) (append (gather-args a) (list s e r))]
    
    [_ (error (format "Unrecognized expr in gather-args: ~a" expr))]))

(define (get-sorted-args expr)
  ; TODO: what about duplicates?
  (filter-map (lambda (elem) (and (arith:Variable? elem) (arith:Variable-name elem))) (gather-args expr)))

(define (make-runtime-type array small_index_t large_index_t)
  (cond
    [(is-scalar-array? array) (format "value_t")]
    [(is-csr? (Array-format array)) (format "CSR<~a, value_t>" small_index_t)]
    [(is-coo? (Array-format array)) (format "COO<~a, value_t>" small_index_t)]
    [(is-cvector? (Array-format array)) (format "CVector<~a, value_t>" large_index_t)]
    [(is-dvector? (Array-format array)) "nVector<value_t>"]
    ; TODO: handle general case.
    [else (error (format "unrecognized runtime format in C++ codegen: ~a" array))]))

(define (make-arg-string array-args scalar-args out-array small_index_t large_index_t)
  (define (make-array-str array)
    (format "~a &~a" (make-runtime-type array small_index_t large_index_t) (Array-name array)))
  (define (make-scalar-str name)
    (format "const ~a ~a" small_index_t name))
  (string-join
    (append
      (map (lambda (array) (string-append "const " (make-array-str array))) array-args)
      (map make-scalar-str scalar-args))
    ", "))

(define (gather-array-sizes expr)
  (define dropper (lambda (a b) a))
  (destruct expr
    [(Read array) (make-immutable-hash (map (lambda (idx) (cons idx array)) (array-idxs array)))]
    [(Add a b) (hash-union (gather-array-sizes a) (gather-array-sizes b) #:combine dropper)]
    [(Mul a b) (hash-union (gather-array-sizes a) (gather-array-sizes b) #:combine dropper)]
    [(Sum idx a) (gather-array-sizes a)]

    [(Broadcast idx a) (gather-array-sizes a)]
    [(Collapse a i j k) (gather-array-sizes a)]
    [(Concat a b i j k) (hash-union (gather-array-sizes a) (gather-array-sizes b) #:combine dropper)]
    [(Split a i j k) (gather-array-sizes a)]
    [(Slice a i j s e r) (gather-array-sizes a)]
    
    [_ (error (format "Unrecognized expr in gather-args: ~a" expr))]))

(define (codegen-array-sizes expr)
  (define array-sizes (hash->list (gather-array-sizes expr)))

  (string-join
    (map
      (lambda (p) (format "  const uint64_t ~a = ~a~a;" (string-upcase (idx-name (car p))) (string-upcase (idx-name (car p))) (Array-name (cdr p))))
      array-sizes)
    "\n"))

(define (compute-nnz-statically? expr)
  (destruct expr
    [(Read array) #t]
    [(Add a b) #f]
    [(Mul a b) #f]
    [(Sum idx a) (compute-nnz-statically? a)]

    [(Broadcast idx a) (compute-nnz-statically? a)]
    [(Collapse a i j k) (compute-nnz-statically? a)]
    [(Concat a b i j k) (and (compute-nnz-statically? a) (compute-nnz-statically? b))]
    [(Split a i j k) (compute-nnz-statically? a)]
    [(Slice a i j s e r) #f]

    [_ (error (format "Unrecognized expr in compute-nnz-statically?: ~a" expr))]))

(define (compute-nnz expr)
  (destruct expr
    [(Read array) (format "~a_nnz" (Array-name array))]
    [(Sum idx a) (compute-nnz a)]

    [(Broadcast idx a) (compute-nnz a)]
    [(Collapse a i j k) (compute-nnz a)]
    [(Concat a b i j k) (format "~a + ~a" (compute-nnz a) (compute-nnz b))]
    [(Split a i j k) (compute-nnz a)]

    [_ (error (format "Unrecognized expr in compute-nnz: ~a" expr))]))

(define (codegen-compute-nnz expr cfir)
  (if (compute-nnz-statically? expr)
    (format "  const uint64_t ret_nnz = ~a;" (compute-nnz expr))
    (format "  uint64_t ret_nnz = 0; {\n~a\n}\n" (cpp:_print-stmt (cpp:codegen (cfir:repl-assign-with-incr cfir "ret_nnz") (mutable-set) #f) "  "))))

(define (codegen-allocate-output array nnz small_index_t large_index_t)
  (define name (Array-name array))
  (define f (Array-format array))
  (define index_t (if (is-cvector? (Array-format array)) large_index_t small_index_t))
  (define idx_type (format "~a *__restrict" index_t))
  (define data_type "value_t *__restrict")
  (define (helper idx i)
    (if (and (is-dense-level? array idx) (or (equal? (+ i 1) (length (Format-modes f))) (not (is-cmp-level? array (array-idx-child array idx)))))
      "" ; do nothing, this is a dense level feeding nothing.
      (format "  ~a ~a = new ~a[~a];~a" idx_type (get-level-name array idx) index_t
                                        (if (equal? Dense (array-idx-format array idx))
                                          (cpp:_print-expr (cpp:Add (cpp:from-arith (idx-size idx)) (cpp:Constant 1)))
                                          nnz)
                                        (if (equal? Dense (array-idx-format array idx))
                                          (format "\n  ~a[0] = 0;" (get-level-name array idx))
                                          ""))))
  (string-join
    (append
      (map helper (Format-modes f) (range (length (Format-modes f))))
      (list (format "  ~a ~a_data = new value_t[~a];\n" data_type name nnz)))
    "\n"))

(define (codegen-output-iterators array index_t)
  (string-join
    (map
      (lambda (idx) (format "  ~a ~a = 0;" index_t (cpp:_print-expr (cpp:array-index array idx))))
      (array-idxs array))
    "\n"))

(define (codegen-return-output array small_index_t large_index_t)
  (let ([modes (Format-modes (Array-format array))])
    (if (array-is-dense? array)
      ; Fully dense arrays just use nanobind's numpy interface
      (string-append
        (format
          "  nb::capsule owner_data(~a_data, [](void *p) noexcept { delete[] (value_t *)p; });\n"
          (Array-name array))
        (format
          "  size_t shape_dense[~a] = { ~a };\n"
          (length (array-idxs array))
          (string-join
            (map (lambda (idx) (string-append "(size_t)" (cpp:_print-expr (cpp:from-arith (idx-size idx))))) modes)
            ", "))
        (format
          "  return nb::ndarray<nb::numpy, value_t, nb::shape<~a>, nb::c_contig, nb::device::cpu>(~a_data, /* ndim = */ ~a, shape_dense, owner_data);\n"
          (string-join
            (map (lambda (idx) "-1") modes)
            ", ")
          (Array-name array)
          (length (array-idxs array))))
      ; Sparse arrays must use our runtime types.
      (string-append
        "  return "
        (make-runtime-type array small_index_t large_index_t)
        "("
        (string-join
          (map (lambda (idx) (get-level-name array idx)) modes)
        ", ")
        (format ", ~a_data, " (Array-name array))
        (string-join
          (map (lambda (idx) (cpp:_print-expr (cpp:from-arith (idx-size idx)))) modes)
          ", ")
        ", ret_nnz);"
      ))))
