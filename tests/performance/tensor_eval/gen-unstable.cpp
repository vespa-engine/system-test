// Copyright Vespa.ai. All rights reserved.

#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

bool verify_usage(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << argv[0] << " <num docs> <queries dir>" << std::endl;
        return false;
    }
    return true;
}

using V = std::vector<int>;
constexpr size_t N = 128;

V gen_rnd_values(size_t entries) {
    V values;
    values.reserve(entries);
    for (size_t i(0); i < entries; i++) {
        values.push_back(int8_t(rand()));
    }
    return values;
}

std::ostream & gen_tensor(std::ostream & os, const V & values) {
    os << "[" << values[0] << ".0";
    for (size_t i(1); i < values.size(); i++) {
        os << "," << values[i] << ".0";
    }
    return os << "]";
}

std::ostream & put(std::ostream & os, uint32_t doc, const V & values) {
    os << "{ \"put\":\"id:unstable:unstable::" << doc << "\",\"fields\": {\n";
    os << "\"id\":" << doc << ",\n";
    os << "\"doc8\":  { \"values\":"; gen_tensor(os, values) << "},\n";
    os << "\"doc16\": { \"values\":"; gen_tensor(os, values) << "},\n";
    os << "\"doc32\": { \"values\":"; gen_tensor(os, values) << "},\n";
    os << "\"doc64\": { \"values\":"; gen_tensor(os, values) << "},\n";
    os << "\"title\": \"unstable " << doc << "\"\n";
    os << "}}";
    return os;
}

std::ostream & produce_puts(std::ostream & os, size_t num) {
    os << "[\n";
    for (size_t i(0), docId(0); i < num; i++) {
        if (docId > 0) { os << ",\n"; }
        V values = gen_rnd_values(N);
        put(os, docId++, values);
    }
    return os << "]" << std::endl;
}

struct QueryOutput {
    const char * _cell_type;
    std::ofstream _target;
    QueryOutput(const char *cell_type, const char *filename)
      : _cell_type(cell_type),
        _target(filename)
    {}
    void put(const V& values) {
        _target << "/search/?query=unstable&ranking.features.query(qry" << _cell_type << ")=";
        gen_tensor(_target, values) << "\n";
    }
};

void produce_queries(const char *dir, size_t numDocs) {
    std::vector<QueryOutput> outputs;
    for (const char * cell_size : { "8", "16", "32", "64" }) {
        std::string fn = dir;
        fn += "/qf.qry";
        fn += cell_size;
        outputs.emplace_back(cell_size, fn.c_str());
        fprintf(stderr, "writing '%s'\n", fn.c_str());
    }
    for (size_t i = 0; i < numDocs; ++i) {
        V values = gen_rnd_values(N);
        for (QueryOutput & out : outputs) {
            out.put(values);
        }
    }
    std::string fn = dir;
    fn += "/qf.default";
    fprintf(stderr, "writing '%s'\n", fn.c_str());
    std::ofstream out(fn.c_str());
    out << "/search/?query=unstable\n";
}

int main (int argc, char *argv[]) {
    if ( ! verify_usage(argc, argv) ) { return 1; }
    const size_t numDocs = strtoul(argv[1], nullptr, 0);
    srand(123456789);
    produce_queries(argv[2], numDocs/10);
    produce_puts(std::cout, numDocs);
    return 0;
}
