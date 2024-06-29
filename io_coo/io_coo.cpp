#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>

#include <iostream>

#include "parse.h"
#include "types.h"


NB_MODULE(io_coo, m) {
    nb::class_<io_coo::COO2D<uint32_t, float>>(m, "COO2D")
        .def_ro("row", &io_coo::COO2D<uint32_t, float>::row, nb::rv_policy::reference)
        .def_ro("col", &io_coo::COO2D<uint32_t, float>::col, nb::rv_policy::reference)
        .def_ro("data", &io_coo::COO2D<uint32_t, float>::data, nb::rv_policy::reference)
        .def_ro("N", &io_coo::COO2D<uint32_t, float>::N, nb::rv_policy::reference)
        .def_ro("M", &io_coo::COO2D<uint32_t, float>::M, nb::rv_policy::reference);

    m.def("parse2D", &io_coo::parse2D<uint32_t, float>);
}
