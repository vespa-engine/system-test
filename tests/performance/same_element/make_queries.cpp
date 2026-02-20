// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <fstream>
#include <iostream>

void print_query(std::ostream& os, size_t array_size, size_t num_indices) {
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20"
       << "bool_array%20contains%20(%7BelementFilter:[";

    bool first = true;
    for (size_t i = 0; i < num_indices; ++i) {
        if (first) {
            first = false;
        } else {
            os << ",";
        }
        os << rand() % array_size;
    }

    os << "]%7DsameElement(%22true%22))" << std::endl;
}

/**
 * Generate queries checking boolean array at random indices.
 *
 * To compile:
 *   g++ make_queries.cpp -o make_queries
 *
 * To run:
 *   ./make_queries <num-queries> <array-size> <num-indices>
 */
int main(int argc, char **argv) {
    srand(42);
    size_t num_queries = 1'000;
    size_t array_size = 1'000;
    size_t num_indices = 3;
    if (argc > 1) {
        num_queries = std::stoll(argv[1]);
    }
    if (argc > 2) {
        array_size = std::stoll(argv[2]);
    }
    if (argc > 3) {
        num_indices = std::stoll(argv[3]);
    }

    if (array_size > RAND_MAX) {
        std::cerr << "array-size too large" << std::endl;
        return 1;
    }

    if (num_indices == 0) {
        std::cerr << "num-indices has to be at least 1" << std::endl;
        return 1;
    }

    for (size_t query = 0; query < num_queries; ++query) {
        print_query(std::cout, array_size, num_indices);
    }
}

