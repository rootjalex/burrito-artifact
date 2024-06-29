import scipy.sparse as sparse
import numpy as np
import math
import random


import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

# TODO: other matrix types.
# https://docs.scipy.org/doc/scipy/reference/sparse.html#sparse-array-classes

UINT32MAX = 0xFFFFFFFF

def to_burrito_array(a):
    assert(a.format in ["csr", "csc", "coo"])
    if a.format == "csr":
        if (a.shape[0] > UINT32MAX or a.shape[1] > UINT32MAX):
            raise Exception(f"Shape too large for CSR with uint32_t: {a.shape}")
        return burrito.CSR(a.indptr, a.indices, a.data, np.array(a.shape))
    # elif a.format == "csc":
    #     return burrito.CSC(a.indptr, a.indices, a.data, np.array(a.shape))
    elif a.format == "coo":
        if (a.shape[0] > UINT32MAX or a.shape[1] > UINT32MAX):
            print(a.row.dtype, a.col.dtype)
            return burrito.COO64(a.row, a.col, a.data, np.array(a.shape))
        else:
            return burrito.COO(a.row, a.col, a.data, np.array(a.shape))
    else:
        assert(False)

def csr_to_cvector(a):
    assert(a.format == "csr")
    assert(a.shape[0] == 1)
    if a.shape[1] > UINT32MAX:
        return burrito.CVector64(a.indices, a.data, a.shape[1])
    else:
        return burrito.CVector(a.indices, a.data, a.shape[1])

def cvector_to_csr(b):
    assert(isinstance(b, burrito.CVector) or isinstance(b, burrito.CVector64))
    indptr = np.array([0, b.data.shape[0]])
    return sparse.csr_array((b.data, b.indices, indptr), shape=(1, b.size))

def cvector_to_coo(b):
    assert(isinstance(b, burrito.CVector) or isinstance(b, burrito.CVector64))
    rows = np.zeros(b.data.shape[0])
    # print((1, b.shape[0]))
    return sparse.coo_array((b.data, (rows, b.indices)), shape=(1, b.size))

def from_burrito_array(b):
    # print(type(b), flush=True)
    if isinstance(b, burrito.CSR) or isinstance(b, burrito.CSR64):
        # print(b)
        # print(b.__dir__())
        # print(b.__getattribute__("data"))
        # print(b.ref().data)
        # print(b.data.shape, b.indices.shape, b.indptr.shape, b.shape, flush=True)
        return sparse.csr_array((b.data, b.indices, b.indptr), shape=tuple(b.shape))
    # elif isinstance(b, burrito.CSC):
    #     return sparse.csc_array((b.data, b.indices, b.indptr), shape=tuple(b.shape))
    elif isinstance(b, burrito.COO) or isinstance(b, burrito.COO64):
        return sparse.coo_array((b.data, (b.row, b.col)), shape=tuple(b.shape))
    else:
        print(type(b))
        assert(False)
