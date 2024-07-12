# Burrito

## Installation

Burrito was developed and tested on a Mac M1, but is not machine-specific. We provide detailed instructions for installation on MacOS, but see below for a brief list of instructions for Ubuntu installation (tldr; replace `brew install` with `apt-get`).


### MacOS Installation

#### Install Python
For testing, we used Python 3.12.3, but theoretically, any Python version past 3.11 should work. To use 3.12.3 specifically (on MacOS), execute via [brew](https://brew.sh):
```bash
brew install python@3.12.3
```
Make sure to replace all uses of `python3` below with `python3.12` if you prefer to test specifically with the same version we tested with.

#### Set up virtual environment
Make a Python virtual environment for building and testing:
```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install -r requirements.txt
```

#### Install Racket
You will need to install [Racket](https://racket-lang.org) to run the Burrito compiler. Install via [brew](https://brew.sh):
```bash
brew install --cask racket
```
Alternatively, you can [download Racket](https://racket-lang.org/download/), but you will likely need to edit your PATH to point to the install location's bin. We recommend using brew.

Afterwards, please run the racket package manager to install [Rosette](https://docs.racket-lang.org/rosette-guide/):
```bash
raco pkg install rosette
```
If this command reports that z3 is not installed, please run `brew install z3` to install the [z3 Theorem Prover](https://github.com/Z3Prover/z3), a dependency of Rosette.
Note: we do not use Rosette's synthesis features, just its pattern-matching functionality.

#### Install CMake
You will also need to install CMake. On MacOS, install via [brew](https://brew.sh):
```bash
brew install cmake
```
Note: We built and tested with version 3.29.2, but any CMake version above 3.27 should work for building the Python bindings.


### Ubuntu Installation

```bash
# Install Python
apt-get install python3 python3-venv
# Activate a virtual environment
python3 -m venv venv
source venv/bin/activate
python3 -m pip install -r requirements.txt
# Install Racket and Rosette (which depends on z3)
apt-get install racket z3
raco pkg install rosette
# Install CMake and a C++ compiler.
apt-get install cmake g++
```

If `raco pkg install rosette` fails with an `ssl-make-client-context` error, run `apt-get install openssl libssl-dev` and then re-try.


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

#### Download Suitesparse (>2 hours on MacBook Pro M1)
Download the real-valued Suitesparse matrices:
```bash
cd ../suitesparse
chmod +x download_suitesparse_reals.sh
./download_suitesparse_reals.sh
chmod +x unzip_suitesparse.sh
./unzip_suitesparse.sh
```

Now, make a results directory.
```bash
cd ..
mkdir results
```

#### Sequential testing (>24 hours on MacBook Pro M1)
If you're on a machine with Slurm, skip to the `Parallel Testing` section below. Otherwise, run the following commands:
```bash
cd scripts
python3 partition_testing.py 0 1 &> ../results/out.txt
```
NOTE: if the testing scripts fail to import burrito (and/or io_coo), then please rebuild both packages with the following commands:
```bash
cd <pyburrito | io_coo>
rm -rf build
cmake -S . -B build -DPython_EXECUTABLE=<path to python executable>
cmake --build build
```
And try the testing script again.

#### Parallel Testing
On a machine with many nodes, and slurm, the following testing scripts will attempt to balance test matrices across machines. Replace `<N>` with the number of parallel jobs to launch (e.g. 16).
```bash
cd scripts
chmod +x run_gen_partition.sh
chmod +x run_partition.sh
./run_gen_partition.sh ../results <N>
```
Afterwards, please concatenate all result files into a single output file (the file that the plotting script looks for):
```bash
cat ../results/*.txt > ../results/out.txt
```

#### Generating Plots
To generate the plots from the paper (e.g. Fig 24, Fig 25, Fig 26), run the following commands:
```bash
cd .. # now in root project directory
mkdir imgs
python3 graph/scatter_plot.py
```
The generated images will be in the `imgs` directory.
