// Copyright Vespa.ai. All rights reserved.

#include <cstdlib>
#include <iostream>

std::ostream& print_array_field(std::ostream& os, size_t array_size, double true_probability) {
    os << "\"bool_array\": [";

    bool first = true;
    for (size_t i = 0; i < array_size; ++i) {
        if (!first) {
            os << ",";
        }
        first = false;

        os << (((static_cast<double>(rand()) / (static_cast<double>(RAND_MAX) + 1.0)) < true_probability) ? "true" : "false");
    }

    os << "]";

    return os;
}

void print_put(std::ostream& os, size_t docid, size_t array_size, double true_probability) {
    os << "{" << std::endl;
    os << "  \"put\": \"id:test:test::" << docid << "\"," << std::endl;
    os << "  \"fields\": {" << std::endl;
    os << "    \"id\": " << docid << "," << std::endl;
    os << "    "; print_array_field(os, array_size, true_probability) << std::endl;
    os << "  }" << std::endl;
    os << "}";
}

/**
 * Generate documents with random boolean arrays.
 *
 * To compile:
 *   g++ make_docs.cpp -o make_docs
 *
 * To run:
 *   ./make_docs <num-documents> <array-size> <true-probability>
 */
int main(int argc, char **argv) {
    srand(42);
    size_t num_documents = 10'000;
    size_t array_size = 1'000;
    double true_probability = 0.5;
    if (argc > 1) {
        num_documents = std::stoll(argv[1]);
    }
    if (argc > 2) {
        array_size = std::stoll(argv[2]);
    }
    if (argc > 3) {
        true_probability = std::stod(argv[3]);
    }

    std::cout << "[" << std::endl;
    bool first = true;
    for (size_t docid = 0; docid < num_documents; ++docid) {
        if (!first) {
            std::cout << "," << std::endl;
        }
        first = false;

        print_put(std::cout, docid, array_size, true_probability);
    }
    std::cout << std::endl << "]" << std::endl;
}

