// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

bool verify_usage(int argc, char *argv[]) {
    if (argc != 2) {
        std::cerr << argv[0] << " <num docs>" << std::endl;
        return false;
    }
    return true;
}

std::ostream & produce_puts(std::ostream & os, size_t numDocs);

/**
 * Generate puts/removes to use in lidspace compaction test
 **/

using V = std::vector<uint32_t>;

int main (int argc, char *argv[]) {
    if ( ! verify_usage(argc, argv) ) { return 1; }
    const size_t numDocs = strtoul(argv[1], nullptr, 0);
    srand(123456789);
    produce_puts(std::cout, numDocs);
    return 0;
}

std::ostream & gen_wset(std::ostream & os, const V & values) {
    os << "\"0\":" << values[0];
    for (size_t i(1); i < values.size(); i++) {
        os << ",\"" << i << "\":" << values[i];
    }
    return os;
}

std::ostream & gen_array(std::ostream & os, const V & values) {
    os << values[0];
    for (size_t i(1); i < values.size(); i++) {
        os << "," << values[i];
    }
    return os;
}

std::ostream & gen_tensor(std::ostream & os, const V & values) {
    os << "\"cells\":[";
    os << "{\"address\":{\"x\":\"0\"},\"value\":" << values[0] << ".0}";
    for (size_t i(1); i < values.size(); i++) {
        os << ",{\"address\":{\"x\":\"" << i << "\"},\"value\":" << values[i] << ".0}";
    }
    return os << "]";
}

std::ostream& gen_2d_tensor(std::ostream& os, const V& values) {
    os << "\"cells\":[";
    os << "{\"address\":{\"x\":\"0\", \"y\":\"0\"},\"value\":" << values[0] << ".0}";
    for (size_t x = 0; x < values.size(); ++x) {
        for (size_t y = 1; y < values.size(); ++y) {
            os << ",{\"address\":{\"x\":\"" << x << "\", \"y\":\"" << y << "\"},\"value\":" << values[y] << ".0}";
        }
    }
    return os << "]";
}

std::ostream & put(std::ostream & os, uint32_t doc, const V & values) {
    os << "{ \"put\":\"id:test:test::" << doc << "\",\"fields\": {\n";
    os << "\"wset\":{"; gen_wset(os, values) << "},\n";
    os << "\"array\":["; gen_array(os, values) << "],\n";
    os << "\"wset_entries\":" << values.size() << ",\n";
    os << "\"sparse_vector\":{"; gen_tensor(os, values) << "},\n";
    if (values.size() <= 50) {
        os << "\"sparse_xy\":{"; gen_2d_tensor(os, values) << "},\n";
    }
    os << "\"dense_vector_" << values.size() << "\":{"; gen_tensor(os, values) << "},\n";
    os << "\"dense_float_vector_" << values.size() << "\":{"; gen_tensor(os, values) << "}\n";
    os << "}}";
    return os;
}

V gen_values(size_t entries) {
    std::vector<uint32_t> values;
    values.reserve(entries);
    for (size_t i(0); i < entries; i++) {
        values.push_back(rand()%100);
    }
    return values;
}

std::ostream & produce_puts(std::ostream & os, size_t num) {
    os << "[\n";
    for (size_t i(0), docId(0); i < num; i++) {
        for (uint32_t entries : {5, 10, 25, 50, 100, 250}) {
            if (docId > 0) { os << ",\n"; }
            V values = gen_values(entries);
            put(os, docId++, values);
        }
    }
    return os << "]" << std::endl;
}
