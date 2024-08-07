// Copyright Vespa.ai. All rights reserved.

#include <cstdint>
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

struct V {
    std::vector<uint32_t> key;
    std::vector<uint32_t> val;
    size_t size() const { return key.size(); }
    void add(uint32_t k, uint32_t v) {
        key.push_back(k);
        val.push_back(k);
    }
    void reserve(size_t n) {
        key.reserve(n);
        val.reserve(n);
    }
};

int main (int argc, char *argv[]) {
    if ( ! verify_usage(argc, argv) ) { return 1; }
    const size_t numDocs = strtoul(argv[1], nullptr, 0);
    srand(123456789);
    produce_puts(std::cout, numDocs);
    return 0;
}

std::ostream & gen_wset(std::ostream & os, const V & wset) {
    for (size_t i = 0; i < wset.size(); ++i) {
        if (i > 0) { os << ','; }
        os << '"' << wset.key[i] << '"';
        os << ":" << wset.val[i];
    }
    return os;
}

std::ostream & gen_tensor(std::ostream & os, const V & wset) {
    os << "\"cells\":{";
    for (size_t i = 0; i < wset.size(); ++i) {
        if (i > 0) { os << ','; }
        os << '"' << wset.key[i] << '"';
        os << ":" << wset.val[i];
    }
    return os << "}";
}

std::ostream & put(std::ostream & os, uint32_t doc, const V & values) {
    os << "{ \"put\":\"id:sparsedot:sparsedot::" << doc << "\",\"fields\": {\n";
    os << "\"wset\":{"; gen_wset(os, values) << "},\n";
    os << "\"stringwset\":{"; gen_wset(os, values) << "},\n";
    os << "\"sparse_vector_x\":{"; gen_tensor(os, values) << "},";
    os << "\"wset_entries\":" << values.size();
    os << "}}\n";
    return os;
}

V gen_values(size_t entries) {
    V result;
    result.reserve(entries);
    for (size_t i(0); i < entries; i++) {
        result.add(i, rand()%100);
    }
    return result;
}

std::ostream & produce_puts(std::ostream & os, size_t num) {
    os << "[\n";
    for (size_t i(0), docId(0); i < num; i++) {
        for (uint32_t entries : {10, 50, 250}) {
            if (docId > 0) { os << ",\n"; }
            V values = gen_values(entries);
            put(os, docId++, values);
        }
    }
    return os << "]" << std::endl;
}
