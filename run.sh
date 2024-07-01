# Install a specific Python version
brew install python@3.12.3

# Build a Python virtual environment and install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install Racket and Rosette
brew install --cask racket
raco pkg install rosette

# Install CMake
brew install cmake

# Run the compiler
racket burrito/benchmarks.rkt

# Build the Burrito nanobind module
cd pyburrito
cmake -S . -B build
cmake --build build

# Build the matrix reader nanobind module
cd ../io_coo
cmake -S . -B build
cmake --build build

# Download Suitesparse
cd ../suitesparse
chmod +x download_suitesparse_reals.sh
./download_suitesparse_reals.sh
chmod +x unzip_suitesparse_reals.sh
./unzip_suitesparse.sh

# Make a results directory
cd ..
mkdir results

# Run the benchmarks
cd scripts
python3 partition_testing.py 0 1 &> ../results/out.txt

# Graph the paper figures
cd ..
mkdir imgs
python3 graph/scatter_plot.py
