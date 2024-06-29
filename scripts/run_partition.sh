#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "Usage: $0 <outfile> <int> <int>"
    exit 1
fi

source venv/bin/activate

echo "Testing on partition=$2 / $3 with output file $1..."

python3 partition_testing.py $2 $3 &> $1

echo "Testing on partition=$2 / $3 with output file $1 complete."
