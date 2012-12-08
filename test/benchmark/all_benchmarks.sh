#!/bin/bash
BENCHMARK_DIR="`dirname \"$0\"`"
echo ""
$BENCHMARK_DIR/array_math_benchmark.rb
echo ""
$BENCHMARK_DIR/receiver_parser_benchmark.rb
