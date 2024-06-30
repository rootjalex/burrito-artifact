import time
import scipy
import sparse
import numpy as np
import sys

import paths
import suitesparse_benchmarks
sys.path.append(paths.IO_COO_PATH)
import io_coo

import signal
from contextlib import contextmanager

import gc

class TimeoutException(Exception): pass

@contextmanager
def time_limit(seconds):
    def signal_handler(signum, frame):
        raise TimeoutException("Timed out!")
    signal.signal(signal.SIGALRM, signal_handler)
    signal.alarm(seconds)
    try:
        yield
    finally:
        signal.alarm(0)

# from dataclasses import dataclass
# from collections.abc import Callable

INT32MAX = 2147483647

TIMEOUT_SECONDS = 50
TIMEOUT_TIME = 5

def construct_matrix(filename, format):
    A = scipy.io.mmread(filename).astype(np.single)
    if (A.shape[0] > INT32MAX or A.shape[1] > INT32MAX):
        raise Exception("matrix too big")
    if format == "coo":
        return A.tocoo()
    elif format == "csr":
        return A.tocsr()
    elif format == "csc":
        return A.tocsc()
    else:
        raise NotImplementedError(f"Unrecognized format: {format}")

def convert_matrix(A, format):
    if format == "coo":
        return A.tocoo()
    elif format == "csr":
        return A.tocsr()
    elif format == "csc":
        return A.tocsc()
    else:
        raise NotImplementedError(f"Unrecognized format: {format}")

def is_iterable(item):
    try:
        a = iter(item)
        return True
    except TypeError:
        return False

def flat_map(f, xs):
    out = list()
    for x in xs:
        o = f(x)
        if isinstance(o, tuple):
            out.extend(o)
        else:
            out.append(o)
    return out

class Tester:
    def __init__(self, name, input_format, process_burr, f_burrito, process_scipy, f_scipy, process_pydata, f_pydata, f_equals, is_unfused=False):
        self.name = name
        self.input_format = input_format
        self.process_burr = process_burr
        self.f_burrito = f_burrito
        self.process_scipy = process_scipy
        self.f_scipy = f_scipy
        self.process_pydata = process_pydata
        self.f_pydata = f_pydata
        self.f_equals = f_equals
        self.is_unfused = is_unfused

    def run_test(self, matrix_name, A, iters):
        print(f"{matrix_name},{self.name},", end="", flush=True)
        B = convert_matrix(A, self.input_format)

        burr_matrices = tuple(self.process_burr(B))
        pydata_matrices = tuple(self.process_pydata(B))
        scipy_matrices = tuple(self.process_scipy(B))

        gc.collect()

        # print("testing burrito...", flush=True)
        burr_t = float('inf')
        burr_out = self.f_burrito(*burr_matrices)
        try:
            with time_limit(TIMEOUT_SECONDS):
                burr_out = self.f_burrito(*burr_matrices)
                for _ in range(iters):
                    # print("Deallocating...", flush=True)
                    # t0 = time.time()
                    t0 = time.perf_counter()
                    burr_out = self.f_burrito(*burr_matrices)
                    # t1 = time.time()
                    t1 = time.perf_counter()
                    burr_t = min(burr_t, t1 - t0)
        except Exception as e:
            burr_t = TIMEOUT_TIME
            # print("caught burrito timeout", e)
        # print(burr_t, flush=True)

        gc.collect()

        # print("testing scipy...", flush=True)
        scipy_t = float('inf')
        scipy_out = self.f_scipy(*scipy_matrices)
        try:
            with time_limit(TIMEOUT_SECONDS):
                for _ in range(iters):
                    # t0 = time.time()
                    t0 = time.perf_counter()
                    scipy_out = self.f_scipy(*scipy_matrices)
                    # t1 = time.time()
                    t1 = time.perf_counter()
                    scipy_t = min(scipy_t, t1 - t0)
        except Exception as e:
            scipy_t = TIMEOUT_TIME
            # print("caught scipy timeout")

        # print(scipy_t, flush=True)
        gc.collect()

        # print("testing pydata...", flush=True)
        pydata_t = float('inf')
        if (not self.is_unfused) and ("slice_1d" in self.name and A.nnz >= 7031999):
            # these larger matrices just absolutely breaks pydata,
            # and the timeout code doesn't work on it, due to some
            # weird numba.jit code.
            pydata_t = TIMEOUT_TIME + 1
        else:
            try:
                # pydata just breaks on a bunch of things...
                with time_limit(TIMEOUT_TIME * 2):
                    pydata_out = self.f_pydata(*pydata_matrices)
                try:
                    with time_limit(TIMEOUT_SECONDS):
                        for _ in range(iters):
                            # t0 = time.time()
                            t0 = time.perf_counter()
                            pydata_out = self.f_pydata(*pydata_matrices)
                            # t1 = time.time()
                            t1 = time.perf_counter()
                            pydata_t = min(pydata_t, t1 - t0)
                except Exception as e:
                    pydata_t = TIMEOUT_TIME
                    # print("caught pydata timeout")
                    # print(f" Exception: {e}")
            except Exception as e:
                # pydata is a little buggy, not sure what to do here...
                pydata_t = TIMEOUT_TIME + 1
                # print(f"Exception: {e}")
    
        # print(pydata_t, flush=True)

        # TODO: still want to check equality if only one timed out?
        # print(self.f_equals(burr_out, scipy_out, pydata_out))
        # print("checking equality...", flush=True)
        assert(TIMEOUT_TIME in (burr_t, scipy_t, pydata_t) or (pydata_t == TIMEOUT_TIME + 1) or self.f_equals(burr_out, scipy_out, pydata_out))
        # print("equality checked!")
        # assert(burr_b.format == scipy_b.format)
        # assert((burr_b != scipy_b).nnz == 0)
        # assert(pydata_b.format == scipy_b.format)
        # assert((pydata_b != scipy_b).nnz == 0)
        print(f"{scipy_t / burr_t},{pydata_t / burr_t},{burr_t},{scipy_t},{pydata_t}", flush=True)

    # def run_idx_test(self, matrix_name, A, iters, idx):
    #     if idx == 0:
    #         process = self.process_burr
    #         f = self.f_burrito
    #         tname = "burrito"
    #     elif idx == 1:
    #         process = self.process_scipy
    #         f = self.f_scipy
    #         tname = "scipy"
    #     else:
    #         assert(idx == 2)
    #         process = self.process_pydata
    #         f = self.f_pydata
    #         tname = "burrito_unfused"

    #     B = convert_matrix(A, self.input_format)
    #     matrices = tuple(process(B))

    #     t = float('inf')
    #     try:
    #         with time_limit(TIMEOUT_SECONDS):
    #             out = f(*matrices)
    #             for _ in range(iters):
    #                 t0 = time.time()
    #                 out = f(*matrices)
    #                 t1 = time.time()
    #                 t = min(t, t1 - t0)
    #     except Exception as e:
    #         t = TIMEOUT_TIME
    #         # print(e)

    #     mname = matrix_name.split(".")[0]
    #     outfile = f"{paths.FUSION_WRITE_PATH}/{self.name}_{mname}.txt"
    #     text = f"{matrix_name},{self.name},{tname},{t}\n"
    #     file = open(outfile, "a")
    #     file.write(text)
    #     file.close()
    #     if idx != 1:
    #         matrices = tuple(self.process_scipy(B))
    #         assert(self.f_equals(out, self.f_scipy(*matrices), out))

def run_partition(count, k, m, tests):
    # assert(k < m and k >= 0)
    # n = len(suitesparse_benchmarks.real_matrices)
    # Take every mth value starting at index k.
    matrices = suitesparse_benchmarks.real_matrices_sorted[k::m]

    path = paths.SUITESPARSE_PATH
    assert(path)
    if path[-1] == "/":
        path = path[:-1]

    for matrix_name in matrices:
        filename = f"{path}/{matrix_name}"
        # A = scipy.io.mmread(filename).astype(np.single)
        # print(f"reading: {filename}", flush=True)
        # t0 = time.time()
        A = io_coo.parse2D(filename)
        # t1 = time.time()
        # print(f"read: {filename} in time {t1 - t0}", flush=True)
        # t0 = time.time()
        A = scipy.sparse.coo_matrix((A.data, (A.row, A.col)), shape=(A.N, A.M))
        # t1 = time.time()
        # print(f"converted: {filename} in time {t1 - t0}", flush=True)

        for test in tests:
            test.run_test(matrix_name, A, count)

def run_matrix_test(count, matrix_name, tests):
    path = paths.SUITESPARSE_PATH
    assert(path)
    if path[-1] == "/":
        path = path[:-1]

    filename = f"{path}/{matrix_name}"
    # A = scipy.io.mmread(filename).astype(np.single)
    # print(f"reading: {filename}", flush=True)
    # t0 = time.time()
    A = io_coo.parse2D(filename)
    # t1 = time.time()
    # print(f"read: {filename} in time {t1 - t0}", flush=True)
    # t0 = time.time()
    A = scipy.sparse.coo_matrix((A.data, (A.row, A.col)), shape=(A.N, A.M))
    # t1 = time.time()
    # print(f"converted: {filename} in time {t1 - t0}", flush=True)

    for test in tests:
        test.run_test(matrix_name, A, count)
