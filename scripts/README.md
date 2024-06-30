# Burrito benchmarking scripts

This directory stores the Python benchmarking infrastructure. Each `test_*` file has the following structure:
```python
# Return Burrito data structures produced from the test matrix
def process_burr(matrix): ...
# Run the Burrito-generated code for the benchmark
def f_burrito(m0, m1): ...

# Return scipy data structures produced from the test matrix
def process_scipy(matrix): ...
# Run the scipy code for the benchmark
def f_scipy(m0, m1): ...

# Return pydata data structures produced from the test matrix
def process_pydata(matrix): ...
# Run the pydata code for the benchmark
def f_pydata(m0, m1): ...

# return whether the burrito, scipy, and pydata results are equivalent.
def f_equals(b, s, p):
```

The fusion benchmarks replace `process_pydata` and `f_pydata` with `process_burrito_unfused` and `f_burrito_unfused`, respectively.


## Individual tests
Each test can be run by itself, e.g.
```bash
python3 test_coo_hstack_coo_coo.py
```
This will test all of the Suitesparse dataset on an individual test.


## Full test suite
To run the group of benchmarks, we provide `partition_testing.py`. See the [root README.md](../README.md) for details on how to run this test.

We found that the testing bottleneck is almost always parsing the Suitesparse matrix file. As a result, we execute tests in the following (pseudocode) structure:
```python
for matrix in matrices:
    m = load(matrix)
    for test in tests:
        run_test(m, test)
```
This way, a matrix is only loaded once.

We also built a custom matrix reader, [io_coo](../io_coo) that reads `.mtx` files into 2D coordinate lists with `uint32_t` indices and `float` values.

Unfortunately, parsing is still slow for very large matrices, so the full testing suite is quite slow.
