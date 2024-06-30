# Burrito

## Installation

#### Install Python
For testing, we used Python 3.12.3, but theoretically, any Python version past 3.11 should work. To use 3.12.3 specifically (on MacOS), execute via [brew](https://brew.sh):
```bash
brew install python@3.12.3
```
Make sure to replace all uses of `python3` below with `python3.12` if you prefer to test specifically with the same version we tested with.

#### Set up virtual environment
First, make a Python virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### Install Racket
You will need to [install racket](https://racket-lang.org/download/) to run the Burrito compiler.

#### Install CMake
You will also need to install CMake. On MacOS, install via [brew](https://brew.sh):
```bash
brew install cmake
```
Note: We built and tested with version 3.29.2, but any CMake version above 3.27 should work for building the Python bindings.


## Build

#### Run compiler on benchmark expressions
Next, run the Burrito compiler to generate C++ code (generated kernels will appear in `pyburrito`)
```bash
racket burrito/benchmarks.rkt
```

#### Build Python extensions
Next, build the [nanobind](https://nanobind.readthedocs.io/en/latest/)-enabled Python package.
```bash
cd pyburrito
cmake -S . -B build
cmake --build build
```
Note: if the above CMake commands cause issues, see [these build tips](https://nanobind.readthedocs.io/en/latest/basics.html#building-using-cmake).

Also build the custom matrix reader package in io_coo:
```bash
cd ../io_coo
cmake -S . -B build
cmake --build build
```

## Test

#### Download Suitesparse
Download the real-valued Suitesparse matrices (NOTE: this will take a long time, and a lot of bandwidth!):
```bash
cd ../suitesparse
chmod +x download_suitesparse_reals.sh
./download_suitesparse_reals.sh
chmod +x unzip_suitesparse_reals.sh
./unzip_suitesparse.sh
```

Before running the testing script, you need to edit the first line of `scripts/paths.py` to point to this repository on your machine.

Now, make a results directory.
```bash
cd ..
mkdir results
```

#### Sequential testing
If you're on a machine with Slurm, skip to the `Parallel Testing` section below. Otherwise, run the following commands (NOTE: this will take a very long time):
```bash
cd scripts
python3 partition_testing.py 0 1 &> ../results/out.txt
```

#### Parallel Testing
On a machine with many nodes, and slurm, the following testing scripts will attempt to balance test matrices across machines. Replace `<N>` with the number of parallel jobs to launch (e.g. 16).
```bash
cd scripts
chmod +x run_gen_partition.sh
chmod +x run_partition.sh
./run_gen_partition.sh ../results <N>
```

#### Generating Plots
To generate the plots from the paper (e.g. Fig 24, Fig 25, Fig 26), run the following commands:
```bash
cd .. # now in root project directory
mkdir imgs
python3 graph/scatter_plot.py
```
The generated images will be in the `imgs` directory.
