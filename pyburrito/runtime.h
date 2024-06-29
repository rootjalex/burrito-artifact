#pragma once

#include <cstdint>
#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>

namespace nb = nanobind;

template<typename value_t>
using nVector = nb::ndarray<nb::numpy, value_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;

using UInt32Vector = nb::ndarray<nb::numpy, uint32_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
using UInt64Vector = nb::ndarray<nb::numpy, uint64_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
using Float32Vector = nb::ndarray<nb::numpy, float, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
using UInt32Tuple = nb::ndarray<nb::numpy, uint32_t, nb::shape<2>, nb::c_contig, nb::device::cpu>;
using UInt64Tuple = nb::ndarray<nb::numpy, uint64_t, nb::shape<2>, nb::c_contig, nb::device::cpu>;

template<typename index_t, typename value_t>
struct CSR {
    using IntVector = nb::ndarray<nb::numpy, index_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    using FloatVector = nb::ndarray<nb::numpy, value_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    using ShapeTuple2D = nb::ndarray<nb::numpy, index_t, nb::shape<2>, nb::c_contig, nb::device::cpu>;
    IntVector indptr;
    IntVector indices;
    FloatVector data;
    ShapeTuple2D shape;

    CSR(const IntVector &_indptr, const IntVector &_indices,
        const FloatVector &_data, const ShapeTuple2D &_shape)
        : indptr(_indptr), indices(_indices), data(_data), shape(_shape) {}

    CSR(const index_t N, const index_t M, const uint64_t nnz) {
        index_t *_indptr = new index_t[N + 1];
        index_t *_indices = new index_t[nnz];
        value_t *_data = new value_t[nnz];
        index_t *_shape = new index_t[2];
        _shape[0] = N;
        _shape[1] = M;

        // These *have* to be size_t
        size_t shape_dense[1] = { (size_t)N + 1 };
        size_t shape_nnz[1] = { (size_t)nnz };
        size_t shape_scalar[1] = { (size_t)2 };

        indptr = IntVector(_indptr, /* ndim = */ 1, shape_dense);
        indices = IntVector(_indices, /* ndim = */ 1, shape_nnz);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz);
        shape = ShapeTuple2D(_shape, /* ndim = */ 1, shape_scalar);
    }

    CSR(index_t *_indptr, index_t *_indices, value_t *_data,
        const index_t N, const index_t M, const uint64_t nnz) {
        index_t *_shape = new index_t[2];
        _shape[0] = N;
        _shape[1] = M;

        // These *have* to be size_t
        size_t shape_dense[1] = { (size_t)N + 1 };
        size_t shape_nnz[1] = { (size_t)nnz };
        size_t shape_scalar[1] = { (size_t)2 };

        nb::capsule owner_indptr(_indptr, [](void *p) noexcept {
            delete[] (index_t *)p;
        });
        nb::capsule owner_indices(_indices, [](void *p) noexcept {
            delete[] (index_t *)p;
        });
        nb::capsule owner_data(_data, [](void *p) noexcept {
            delete[] (value_t *)p;
        });
        nb::capsule owner_shape(_shape, [](void *p) noexcept {
            delete[] (size_t *)p;
        });

        indptr = IntVector(_indptr, /* ndim = */ 1, shape_dense, owner_indptr);
        indices = IntVector(_indices, /* ndim = */ 1, shape_nnz, owner_indices);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz, owner_data);
        shape = ShapeTuple2D(_shape, /* ndim = */ 1, shape_scalar, owner_shape);
    }
};

template<typename index_t, typename value_t>
struct COO {
    using IntVector = nb::ndarray<nb::numpy, index_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    using FloatVector = nb::ndarray<nb::numpy, value_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    using ShapeTuple2D = nb::ndarray<nb::numpy, index_t, nb::shape<2>, nb::c_contig, nb::device::cpu>;
    IntVector row;
    IntVector col;
    FloatVector data;
    ShapeTuple2D shape;

    COO(const IntVector &_row, const IntVector &_col,
        const FloatVector &_data, const ShapeTuple2D &_shape)
        : row(_row), col(_col), data(_data), shape(_shape) {}

    COO(const index_t N, const index_t M, const uint64_t nnz) {
        index_t *_row = new index_t[nnz];
        index_t *_col = new index_t[nnz];
        value_t *_data = new value_t[nnz];
        index_t *_shape = new index_t[2];
        _shape[0] = N;
        _shape[1] = M;

        // These *have* to be size_t
        size_t shape_nnz[1] = { (size_t)nnz };
        size_t shape_scalar[1] = { (size_t)2 };

        row = IntVector(_row, /* ndim = */ 1, shape_nnz);
        col = IntVector(_col, /* ndim = */ 1, shape_nnz);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz);
        shape = ShapeTuple2D(_shape, /* ndim = */ 1, shape_scalar);
    }

    COO(index_t *_row, index_t *_col, value_t *_data,
        const index_t N, const index_t M, const uint64_t nnz) {
        index_t *_shape = new index_t[2];
        _shape[0] = N;
        _shape[1] = M;

        // These *have* to be size_t
        size_t shape_nnz[1] = { (size_t)nnz };
        size_t shape_scalar[1] = { (size_t)2 };

        nb::capsule owner_row(_row, [](void *p) noexcept {
            delete[] (index_t *)p;
        });
        nb::capsule owner_col(_col, [](void *p) noexcept {
            delete[] (index_t *)p;
        });
        nb::capsule owner_data(_data, [](void *p) noexcept {
            delete[] (value_t *)p;
        });
        nb::capsule owner_shape(_shape, [](void *p) noexcept {
            delete[] (size_t *)p;
        });

        row = IntVector(_row, /* ndim = */ 1, shape_nnz, owner_row);
        col = IntVector(_col, /* ndim = */ 1, shape_nnz, owner_col);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz, owner_data);
        shape = ShapeTuple2D(_shape, /* ndim = */ 1, shape_scalar, owner_shape);
    }
};

template<typename index_t, typename value_t>
struct CVector {
    using IntVector = nb::ndarray<nb::numpy, index_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    using FloatVector = nb::ndarray<nb::numpy, value_t, nb::shape<-1>, nb::c_contig, nb::device::cpu>;
    IntVector indices;
    FloatVector data;
    struct _Shape {
        _Shape(const index_t _size) : size(_size) {}
        const index_t size;
        const index_t operator()(const index_t c) const {
            return size;
        }
    };
    index_t size = 0;
    const _Shape shape;

    CVector(const IntVector &_indices, const FloatVector &_data, const index_t &_size)
        : indices(_indices), data(_data), size(_size), shape(_size) {}

    CVector(const index_t N, const uint64_t nnz): shape(N) {
        index_t *_indices = new index_t[nnz];
        value_t *_data = new value_t[nnz];

        // These *have* to be size_t
        size_t shape_nnz[1] = { (size_t)nnz };

        indices = IntVector(_indices, /* ndim = */ 1, shape_nnz);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz);
        size = N;
    }

    CVector(index_t *_indices, value_t *_data, const index_t N, const uint64_t nnz) : shape(N) {
        // These *have* to be size_t
        size_t shape_nnz[1] = { (size_t)nnz };

        nb::capsule owner_indices(_indices, [](void *p) noexcept {
            // std::cerr << "deleting indices!" << std::endl;
            delete[] (index_t *)p;
        });
        nb::capsule owner_data(_data, [](void *p) noexcept {
            // std::cerr << "deleting data!" << std::endl;
            delete[] (value_t *)p;
        });

        indices = IntVector(_indices, /* ndim = */ 1, shape_nnz, owner_indices);
        data = FloatVector(_data, /* ndim = */ 1, shape_nnz, owner_data);
        size = N;
    }
};

// std::min does weird stuff sometimes, use this instead.
template<typename T, typename S>
uint64_t min(const T &t, const S &s) {
    return std::min((uint64_t)t, (uint64_t)s);
}

// for locate.
template<typename index_t, typename value_t>
index_t binary_search(const value_t &value, index_t low, index_t high, const value_t *array) {
    while (low < high) {
        const index_t mid = (uint64_t)low + ((uint64_t)high - (uint64_t)low) / 2;
        if (array[mid] == value) {
            return mid;
        } else if (array[mid] < value) {
            low = mid + 1;
        } else {
            // array[mid] > value
            high = mid;
        }
    }
    return low;
}
