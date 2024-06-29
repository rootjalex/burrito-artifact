#pragma once

#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>

namespace nb = nanobind;

namespace io_coo {

template<typename T>
using Array = nb::ndarray<nb::numpy, T, nb::shape<-1>, nb::c_contig, nb::device::cpu>;

template<typename index_t, typename value_t>
struct COO2D {
    Array<index_t> row, col;
    Array<value_t> data;
    index_t N, M;
};

}  // namespace io_coo
