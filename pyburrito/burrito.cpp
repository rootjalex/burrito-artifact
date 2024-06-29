#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>

#include <iostream>

#include "runtime.h"
// Comparison to handwritten kernels
#include "cv_collapse_coo.h"
#include "coo_hstack_coo_coo.h"
#include "coo_vstack_coo_coo.h"
#include "csr_hstack_csr_csr.h"
#include "csr_vstack_csr_csr.h"
#include "csr_slice_1d_csr.h"
// Portability kernels
#include "coo_split_cv.h"
#include "csr_split_cv.h"
#include "csr_hstack_coo_coo.h"
#include "coo_vstack_csr_csr.h"
#include "coo_hstack_csr_csr.h"
#include "coo_slice_1d_csr.h"
// Fusion benchmarks
#include "cv_collapse_csr_mul_cv.h"
#include "dv_sum_vstack_csr_csr_mul_dv.h"
#include "csr_slice_1d_csr_mul_csr.h"
#include "unfused.h"

NB_MODULE(burrito, m) {
    nb::class_<CSR<uint32_t, float>>(m, "CSR")
        .def(nb::init<const UInt32Vector &, const UInt32Vector &, const Float32Vector &, const UInt32Tuple &>())
        .def_ro("indptr", &CSR<uint32_t, float>::indptr, nb::rv_policy::reference)
        .def_ro("indices", &CSR<uint32_t, float>::indices, nb::rv_policy::reference)
        .def_ro("data", &CSR<uint32_t, float>::data, nb::rv_policy::reference)
        .def_ro("shape", &CSR<uint32_t, float>::shape, nb::rv_policy::reference);

    nb::class_<COO<uint32_t, float>>(m, "COO")
        .def(nb::init<const UInt32Vector &, const UInt32Vector &, const Float32Vector &, const UInt32Tuple &>())
        .def_ro("row", &COO<uint32_t, float>::row, nb::rv_policy::reference)
        .def_ro("col", &COO<uint32_t, float>::col, nb::rv_policy::reference)
        .def_ro("data", &COO<uint32_t, float>::data, nb::rv_policy::reference)
        .def_ro("shape", &COO<uint32_t, float>::shape, nb::rv_policy::reference);

    nb::class_<CVector<uint32_t, float>>(m, "CVector")
        .def(nb::init<const UInt32Vector &, const Float32Vector &, const uint32_t &>())
        .def_ro("indices", &CVector<uint32_t, float>::indices, nb::rv_policy::reference)
        .def_ro("data", &CVector<uint32_t, float>::data, nb::rv_policy::reference)
        .def_ro("size", &CVector<uint32_t, float>::size, nb::rv_policy::reference);

    nb::class_<COO<uint64_t, float>>(m, "COO64")
        .def(nb::init<const UInt64Vector &, const UInt64Vector &, const Float32Vector &, const UInt64Tuple &>())
        .def_ro("row", &COO<uint64_t, float>::row, nb::rv_policy::reference)
        .def_ro("col", &COO<uint64_t, float>::col, nb::rv_policy::reference)
        .def_ro("data", &COO<uint64_t, float>::data, nb::rv_policy::reference)
        .def_ro("shape", &COO<uint64_t, float>::shape, nb::rv_policy::reference);

     nb::class_<CSR<uint64_t, float>>(m, "CSR64")
        .def(nb::init<const UInt64Vector &, const UInt64Vector &, const Float32Vector &, const UInt64Tuple &>())
        .def_ro("indptr", &CSR<uint64_t, float>::indptr, nb::rv_policy::reference)
        .def_ro("indices", &CSR<uint64_t, float>::indices, nb::rv_policy::reference)
        .def_ro("data", &CSR<uint64_t, float>::data, nb::rv_policy::reference)
        .def_ro("shape", &CSR<uint64_t, float>::shape, nb::rv_policy::reference);

    nb::class_<CVector<uint64_t, float>>(m, "CVector64")
        .def(nb::init<const UInt64Vector &, const Float32Vector &, const uint64_t &>())
        .def_ro("indices", &CVector<uint64_t, float>::indices, nb::rv_policy::reference)
        .def_ro("data", &CVector<uint64_t, float>::data, nb::rv_policy::reference)
        .def_ro("size", &CVector<uint64_t, float>::size, nb::rv_policy::reference);

    // handwritten
    m.def("cv_collapse_coo", &cv_collapse_coo<uint32_t, uint32_t, float>);
    m.def("cv_collapse_coo32to64", &cv_collapse_coo<uint32_t, uint64_t, float>);
    m.def("coo_hstack_coo_coo", &coo_hstack_coo_coo<uint32_t, float>);
    m.def("coo_vstack_coo_coo", &coo_vstack_coo_coo<uint32_t, float>);
    m.def("csr_hstack_csr_csr", &csr_hstack_csr_csr<uint32_t, float>);
    m.def("csr_vstack_csr_csr", &csr_vstack_csr_csr<uint32_t, float>);
    m.def("csr_slice_1d_csr", &csr_slice_1d_csr<uint32_t, float>);
    // portable
    m.def("coo_split_cv", &coo_split_cv<uint32_t, uint32_t, float>);
    m.def("coo_split_cv64to32", &coo_split_cv<uint64_t, uint32_t, float>);
    m.def("csr_split_cv", &csr_split_cv<uint32_t, uint32_t, float>);
    m.def("csr_split_cv64to32", &csr_split_cv<uint64_t, uint32_t, float>);
    m.def("csr_hstack_coo_coo", &csr_hstack_coo_coo<uint32_t, float>);
    m.def("coo_vstack_csr_csr", &coo_vstack_csr_csr<uint32_t, float>);
    m.def("coo_hstack_csr_csr", &coo_hstack_csr_csr<uint32_t, float>);
    m.def("coo_slice_1d_csr", &coo_slice_1d_csr<uint32_t, float>);
    // fusion
    m.def("cv_collapse_csr_mul_cv", &cv_collapse_csr_mul_cv<uint32_t, uint32_t, float>);
    m.def("cv_collapse_csr_mul_cv32to64", &cv_collapse_csr_mul_cv<uint32_t, uint64_t, float>);
    m.def("cv_collapse_csr_mul_cv_unfused", &cv_collapse_csr_mul_cv_unfused<uint32_t, uint32_t, float>);
    m.def("cv_collapse_csr_mul_cv32to64_unfused", &cv_collapse_csr_mul_cv_unfused<uint32_t, uint64_t, float>);

    m.def("dv_sum_vstack_csr_csr_mul_dv", &dv_sum_vstack_csr_csr_mul_dv<uint32_t, float>);
    m.def("dv_sum_vstack_csr_csr_mul_dv_unfused", &dv_sum_vstack_csr_csr_mul_dv_unfused<uint32_t, float>);

    m.def("csr_slice_1d_csr_mul_csr", &csr_slice_1d_csr_mul_csr<uint32_t, float>);
    m.def("csr_slice_1d_csr_mul_csr_unfused", &csr_slice_1d_csr_mul_csr_unfused<uint32_t, float>);
}
