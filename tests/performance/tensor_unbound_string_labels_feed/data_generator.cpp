// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>
#include <random>
#include <ctime>

// To compile on rhel6
// g++ -Wl,-rpath,$vespa_home/lib64/ -Wall -g -O3 -o data_generator data_generator.cpp

std::ostream &
generate_tensor(std::ostream &os, int doc_id, int tensor_size)
{
    os << "\"cells\":{";
    for (int i = 0; i < tensor_size; ++i) {
        if (i != 0) {
            os << ",";
        }

        const int value = std::rand();
        // Adding random part to avoid cache hits
        os << "\"" << "doc_" << doc_id << "_label_" << i << "_value_" << value << "\":" << value;
    }
    return os << "}";
}

void
generate_put(std::ostream &os, int doc_id, int tensor_size)
{
    os << "{" << "\"put\":\"id:test:test::" << doc_id << "\",\"fields\":{" << std::endl;
    os << "\"tensor\"" << ":{"; generate_tensor(os, doc_id, tensor_size) << "}";
    os << "}}";
}

std::vector<int>
generate_doc_ids(int num_docs, bool shuffle)
{
    std::vector<int> result(num_docs);
    std::iota(result.begin(), result.end(), 0);

    if (shuffle) {
        std::mt19937 rng(static_cast<unsigned>(std::time(nullptr)));
        std::shuffle(result.begin(), result.end(), rng);
    }

    return result;
}

void
generate_puts(std::ostream &os, int num_docs, int tensor_size)
{
    auto doc_ids = generate_doc_ids(num_docs, true);

    os << "[" << std::endl;
    bool first = true;

    for (int doc_id : doc_ids) {
        if (!first) {
            os << "," << std::endl;
        }
        generate_put(os, doc_id, tensor_size);
        first = false;
    }

    os << std::endl << "]" << std::endl;
}

void
usage(char *argv[])
{
    std::cerr << argv[0] << " <num-docs> <tensor-size>" << std::endl;
}

bool
verify_usage(int argc, char *argv[])
{
    if (argc != 3) {
        usage(argv);
        return false;
    }
    return true;
}

int
main(int argc, char *argv[])
{
    if (!verify_usage(argc, argv)) {
        return 1;
    }

    int num_docs = std::stoi(argv[1]);
    int tensor_size = std::stoi(argv[2]);

    generate_puts(std::cout, num_docs, tensor_size);

    return 0;
}

