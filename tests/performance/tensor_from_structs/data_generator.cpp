// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <iostream>
#include <numeric>
#include <random>
#include <string>
#include <vector>

// Compile: g++ -Wl,-rpath,$vespa_home/lib64/ -Wall -g -O3 -o data_generator data_generator.cpp

inline int rand_int(int max) {
    return std::rand() % max;
}

inline int rand_iw() {
    return rand_int(20) - 5;
}

inline float rand_float() {
    return static_cast<float>(rand_int(10000)) / 1000.0f - 2.0f;
}

// smap: map<string,float> — keys "0".."size-1" match imap and skv for tensorFromStructs
std::ostream& generate_smap(std::ostream& os, int size) {
    os << "{";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "\"" << i << "\":" << rand_float();
    }
    return os << "}";
}

// imap: map<int,int> — int keys 0..size-1 become string labels matching smap
std::ostream& generate_imap(std::ostream& os, int size) {
    os << "{";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "\"" << i << "\":" << rand_iw();
    }
    return os << "}";
}

// skv: array<kvs> = {k: string, v: float} — k values "0".."size-1" match smap/imap
std::ostream& generate_skv(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k\":\"" << i << "\",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

static const std::vector<std::string> k2_labels = {"a", "b", "c", "d", "e"};

// sk2v: array<k2vs> = {k1: string, k2: string, v: float} — k1 values match skv.k
std::ostream& generate_sk2v(std::ostream& os, int size) {
    os << "[";
    bool first = true;
    for (int i = 0; i < size; ++i) {
        for (const auto& k2 : k2_labels) {
            if (!first)
                os << ",";
            os << "{\"k1\":\"" << i << "\",\"k2\":\"" << k2 << "\",\"v\":" << rand_float() << "}";
            first = false;
        }
    }
    return os << "]";
}

// ik2v: array<k2vi> = {k1: int, k2: int, v: float}
std::ostream& generate_ik2v(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":" << i << ",\"k2\":" << rand_int(size) << ",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

// sk3v: array<k3vs> = {k1, k2, k4: string, v: float}
std::ostream& generate_sk3v(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":\"" << i << "\",\"k2\":\"" << k2_labels[rand_int(k2_labels.size())] << "\",\"k4\":\""
           << k2_labels[rand_int(k2_labels.size())] << "\",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

// sk4v: array<k4vs> = {k1,k2,k3,k4: string, v: float}
std::ostream& generate_sk4v(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":\"" << i << "\",\"k2\":\"" << k2_labels[rand_int(k2_labels.size())] << "\",\"k3\":\""
           << k2_labels[rand_int(k2_labels.size())] << "\",\"k4\":\"" << k2_labels[rand_int(k2_labels.size())]
           << "\",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

// sk5v: array<k5vs> = {k1-k5: string, v: float}
std::ostream& generate_sk5v(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":\"" << i << "\",\"k2\":\"" << k2_labels[rand_int(k2_labels.size())] << "\",\"k3\":\""
           << k2_labels[rand_int(k2_labels.size())] << "\",\"k4\":\"" << k2_labels[rand_int(k2_labels.size())]
           << "\",\"k5\":\"" << k2_labels[rand_int(k2_labels.size())] << "\",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

// ik5v: array<k5vi> = {k1-k5: int, v: float}
std::ostream& generate_ik5v(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":\"" << i << "\",\"k2\":\"" << rand_int(1000) << "\",\"k3\":\""
           << rand_int(1000) << "\",\"k4\":\"" << rand_int(1000)
           << "\",\"k5\":\"" << rand_int(1000) << "\",\"v\":" << rand_float() << "}";
    }
    return os << "]";
}

// mix5: array<k5vmix> = {k1: string, k2: int, k3: string, k4: int, k5: string, v: int}
std::ostream& generate_mix5(std::ostream& os, int size) {
    os << "[";
    for (int i = 0; i < size; ++i) {
        if (i != 0)
            os << ",";
        os << "{\"k1\":\"" << i << "\",\"k2\":" << rand_int(size) << ",\"k3\":\""
           << k2_labels[rand_int(k2_labels.size())] << "\",\"k4\":" << rand_int(size) << ",\"k5\":\""
           << k2_labels[rand_int(k2_labels.size())] << "\",\"v\":" << rand_iw() << "}";
    }
    return os << "]";
}

void generate_put(std::ostream& os, int doc_id, int size) {
    os << "{\"put\":\"id:test:test::" << doc_id << "\",\"fields\":{" << std::endl;
    os << "\"title\":\"doc " << doc_id << "\"," << std::endl;
    os << "\"smap\":";
    generate_smap(os, size);
    os << "," << std::endl;
    os << "\"imap\":";
    generate_imap(os, size);
    os << "," << std::endl;
    os << "\"skv\":";
    generate_skv(os, size);
    os << "," << std::endl;
    os << "\"sk2v\":";
    generate_sk2v(os, size);
    os << "," << std::endl;
    os << "\"ik2v\":";
    generate_ik2v(os, size);
    os << "," << std::endl;
    os << "\"sk3v\":";
    generate_sk3v(os, size);
    os << "," << std::endl;
    os << "\"sk4v\":";
    generate_sk4v(os, size);
    os << "," << std::endl;
    os << "\"sk5v\":";
    generate_sk5v(os, size);
    os << "," << std::endl;
    os << "\"ik5v\":";
    generate_ik5v(os, size);
    os << "," << std::endl;
    os << "\"mix5\":";
    generate_mix5(os, size) << std::endl;
    os << "}}";
}

std::vector<int> generate_doc_ids(int num_docs, bool shuffle) {
    std::vector<int> result(num_docs);
    std::iota(result.begin(), result.end(), 0);
    if (shuffle) {
        std::mt19937 rng(std::rand());
        std::shuffle(result.begin(), result.end(), rng);
    }
    return result;
}

template <typename Func>
void generate_ops(std::ostream& os, const std::vector<int>& doc_ids, int num_runs, Func& op_func) {
    os << "[" << std::endl;
    bool first = true;
    for (int i = 0; i < num_runs; ++i) {
        for (int doc_id : doc_ids) {
            if (!first) {
                os << "," << std::endl;
            }
            op_func(os, doc_id);
            first = false;
        }
    }
    os << std::endl << "]" << std::endl;
}

void generate_puts(std::ostream& os, int num_docs, int size) {
    auto op_func = [=](std::ostream& os, int doc_id) { generate_put(os, doc_id, size); };
    generate_ops(os, generate_doc_ids(num_docs, false), 1, op_func);
}

void usage(char* argv[]) {
    std::cerr << argv[0] << " put <num-docs> [<size>]" << std::endl;
}

bool verify_usage(int argc, char* argv[]) {
    if (argc != 3 && argc != 4 && argc != 5) {
        usage(argv);
        return false;
    }
    return true;
}

int main(int argc, char* argv[]) {
    if (!verify_usage(argc, argv)) {
        return 1;
    }
    std::srand(123);
    std::string operation = argv[1];
    int         num_docs = std::stoi(argv[2]);
    if (operation == "put") {
        int size = (argc >= 4) ? std::stoi(argv[3]) : 100;
        generate_puts(std::cout, num_docs, size);
    } else {
        usage(argv);
        return 1;
    }
    return 0;
}
