# Burrito Python bindings

The Burrito compiler generates C++ code that uses [nanobind](https://nanobind.readthedocs.io/en/latest/) numpy arrays for compressed/dense/coordinate arrays. This is purely for the ease of testing via Python scripts.

The Burrito extension file, [burrito.cpp](burrito.cpp) includes all the generated headers from [our benchmarks](../burrito/benchmarks.rkt). Note that this directory _will not compile_ if the benchmarks file has not been run from the root directory of this repository, as that file generates the headers included in [burrito.cpp](burrito.cpp).

[runtime.h](runtime.h) defines the data structures we use for testing (e.g. COO, CSR, compressed vectors). Note: for generated code that does not use the data structures we tested, this file needs to be updated with their definitions. [burrito.cpp](burrito.cpp) will also need to be updated to expose those data structures to Python, and the burrito compiler may need to be updated with their names (see the [compiler README](../burrito/README.md) for details on testing new sparse data structures).

[unfused.h](unfused.h) provides thin C++ wrappers around the individual functions used for comparing to Burrito's unfused code generation.

## Example: Adding a new function
Consider the example from the [compiler README](../burrito/README.md). In order to generate a Python binding for it, we would move the generated header file to this directory, include it in [burrito.cpp](burrito.cpp), and add the following line to the module generator:
```c++
m.def("cv_concat_cv_cv", &cv_concat_cv_cv<uint32_t, float>);
```
The template parameters specify the index and value type, respectively.

Rebuilding this repository:
```bash
cmake --build build
```

The following Python code can be used to test the function.
```python
import numpy as np

import sys
# Make sure Python knows where to find the pyburrito extension
sys.path.append("<PATH TO ROOT DIRECTORY>/pyburrito/build")
import burrito

# Logical array sizes
A_size = 100
B_size = 50

# Array densities
A_d = 0.2
B_d = 0.3

# Generate random compressed arrays
A_nnz = int(A_size * A_d)
A_idxs = np.sort(np.random.choice(A_size, A_nnz, replace=False)).astype(np.uint32)
A_values = np.random.random(A_nnz)
# Use burrito.CVector64 if uint64 indices are necessary.
A = burrito.CVector(A_idxs, A_values, A_size)

# Same for B
...
B = burrito.CVector(B_idxs, B_values, B_size)

# Perform computation
C = burrito.cv_concat_cv_cv(A, B)
# And print
print(C.indices, C.data)
```
