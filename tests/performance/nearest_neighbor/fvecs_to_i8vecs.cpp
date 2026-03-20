// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <cstdlib>
#include <format>
#include <fstream>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

using FloatVector = std::vector<float>;
using Int8Vector = std::vector<int8_t>;

/**
 * Convert file of float vectors to file of int8 vectors.
 *
 * To compile:
 *   g++ fvecs_to_i8vecs.cpp -o fvecs_to_i8vecs
 *
 * To run:
 *   ./fvecs_to_i8vecs <vector-in-file> <num-dimensions> <vector-out-file> <number-of-vectors>
 */
int main(int argc, char **argv) {
    if (argc < 4) {
        std::cerr << "Not enough arguments provided" << std::endl;
        return 1;
    }

    std::string vector_in_file = std::string(argv[1]);
    size_t dim_size = std::stoll(argv[2]);
    std::string vector_out_file = std::string(argv[3]);

    bool vector_limit = false;
    size_t number_of_vectors = 0;
    if (argc > 4) {
        number_of_vectors = std::stoll(argv[4]);
        vector_limit = true;
    }

    std::ifstream is(vector_in_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << vector_in_file << "'" << std::endl;
        return 1;
    }

    std::ofstream os(vector_out_file, std::ifstream::binary);
    if (!os.good()) {
        std::cerr << "Could not open '" << vector_out_file << "'" << std::endl;
        return 1;
    }

    int read_dim_size = 0;
    FloatVector float_vector(dim_size, 0);
    Int8Vector int8_vector(dim_size, 0);
    for (size_t vector_num = 0; !vector_limit || (vector_num < number_of_vectors); ++vector_num) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        if (is.eof()) {
            break;
        }

        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(float_vector.data()), sizeof(float) * dim_size);
        assert(is.good());

        for (size_t i = 0; i < dim_size; ++i) {
            int8_vector[i] = static_cast<int8_t>(float_vector[i]);
        }

        os.write(reinterpret_cast<char*>(&read_dim_size), 4);
        os.write(reinterpret_cast<char*>(int8_vector.data()), sizeof(int8_t) * dim_size);
        assert(os.good());

    }
    is.close();
    os.close();
}

