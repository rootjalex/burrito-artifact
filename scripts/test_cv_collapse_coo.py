import scipy
import sparse
import math
import numpy as np

import utils
import tester

import sys
import paths
sys.path.append(paths.BURRITO_PATH)
import burrito

UINT32MAX = 0xFFFFFFFF

def process(matrix):
    matrix.sum_duplicates() # put in canonical order
    assert(matrix.has_canonical_format)
    return matrix

def process_burr(matrix):
    # print(matrix.data[:10], matrix.row[:10], matrix.col[:10])
    # print(matrix[0, 0])
    return [utils.to_burrito_array(process(matrix))]

def f_burrito(matrix):
    if int(matrix.shape[0]) * int(matrix.shape[1]) > UINT32MAX:
        return burrito.cv_collapse_coo32to64(matrix)
    else:
        return burrito.cv_collapse_coo(matrix)

def process_scipy(matrix):
    return [process(matrix)]

def f_scipy(matrix):
    a = matrix.reshape(1, matrix.shape[0] * matrix.shape[1]).tocsr()
    return a

def process_pydata(matrix):
    return [sparse.COO.from_scipy_sparse(process(matrix))]

def f_pydata(matrix):
    return matrix.reshape((matrix.shape[0] * matrix.shape[1],))

# extreme OOM issues here
def f_equals(b, s, p):
    # return True
    # print(b.data[:10], s.data[:10], b.data[1] == s.data[1])
    # print(b.indices[:10], s.indices[:10], b.indices[1] == s.indices[1])
    # print(b.data == s.data)
    # print(b.indices == s.indices)
    # b = utils.cvector_to_csr(b)
    # print(b.data[1], s.data[1], b.data[1] == s.data[1])
    # print(b.indices[1], s.indices[1], b.indices[1] == s.indices[1])
    # raise Exception
    return np.array_equal(b.data, s.data) and np.array_equal(b.indices, s.indices)
    # import gc
    
    # print("here 0", flush=True)
    # gc.collect()
    # p = p.reshape((1, p.shape[0],))
    # print("here 1", flush=True)
    # gc.collect()
    # p = p.to_scipy_sparse()
    # print("here 2", flush=True)
    # gc.collect()
    # p = p.tocsr()
    # print("here 3", flush=True)
    # if (b.format == s.format) and (p.format == s.format):
    #     print("here 4", flush=True)
    #     if (b != s).nnz == 0:
    #         print("here 5", flush=True)
    #         gc.collect()
    #         if ((p != s).nnz == 0):
    #             print("here 6", flush=True)
    #             gc.collect()
    #             return True
    # return False
    # return (b.format == s.format) and (p.format == s.format) and \
        #    ((b != s).nnz == 0) and ((p != s).nnz == 0)

if __name__ == "__main__":
    tests = [
        tester.Tester("cv_collapse_coo", "coo", process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals),
    ]

    tester.run_partition(10, 0, 1, tests)
