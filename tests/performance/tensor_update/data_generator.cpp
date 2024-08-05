// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

// To compile on rhel6
// g++ -Wl,-rpath,$vespa_home/lib64/ -Wall -g -O3 -o data_generator data_generator.cpp

inline char
rand_char()
{
    return 'a' + (std::rand()%('z'-'a'+1));
}

inline int
rand_int(int max)
{
    return std::rand()%max;
}

inline std::ostream &
generate_tensor_cell(std::ostream &os, int cell, int value)
{
    os << "{\"address\":{\"x\":\"" << cell << "\"},\"value\":" << value << "}";
    return os;
}

std::ostream &
generate_tensor(std::ostream &os, int size)
{
    os << "\"cells\":[";
    for (int i = 0; i < size; ++i) {
        if (i != 0) {
            os << ",";
        }
        generate_tensor_cell(os, i, rand_int(10000));
    }
    return os << "]";
}

std::ostream &
generate_rand_data(std::ostream &os, int bytes)
{
    os << "\"";
    for (int i = 0; i < bytes; ++i) {
        os << rand_char();
    }
    return os << "\"";
}

std::string
tensor_field(int size)
{
    return "\"tensor_" + std::to_string(size) + "\"";
}

constexpr int data_field_size = 4000;
std::vector<int> tensor_sizes = {10, 100, 1000};

void
generate_put(std::ostream &os, int doc_id)
{
    os << "{" << "\"put\":\"id:test:test::" << doc_id << "\",\"fields\":{" << std::endl;
    bool first = true;
    for (auto tensor_size : tensor_sizes) {
        if (!first) {
            os << "," << std::endl;
        }
        os << tensor_field(tensor_size) << ":{"; generate_tensor(os, tensor_size) << "}";
        first = false;
    }
    os << "," << std::endl << "\"data\":"; generate_rand_data(os, data_field_size) << std::endl;
    os << "}}";
}

void
generate_assign_update(std::ostream &os, int doc_id, int tensor_size)
{
    os << "{" << "\"update\":\"id:test:test::" << doc_id << "\",\"fields\":{" << std::endl;
    os << tensor_field(tensor_size) << ":{\"assign\":{"; generate_tensor(os, tensor_size) << "}";
    os << "}}}";
}

void
generate_modify_update(std::ostream &os, int doc_id, int tensor_size)
{
    os << "{" << "\"update\":\"id:test:test::" << doc_id << "\",\"fields\":{" << std::endl;
    os << tensor_field(tensor_size) << ":{\"modify\":{\"operation\":\"replace\",";
    os << "\"cells\":[";
    generate_tensor_cell(os, rand_int(tensor_size), rand_int(10000)) << "]}}}}";
}

std::vector<int>
generate_doc_ids(int num_docs, bool shuffle)
{
    std::vector<int> result(num_docs);
    std::iota(result.begin(), result.end(), 0);
    if (shuffle) {
        std::random_shuffle(result.begin(), result.end(), rand_int);
    }
    return result;
}

template <typename Func>
void
generate_ops(std::ostream &os, const std::vector<int> &doc_ids, int num_runs, Func &op_func)
{
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

void
generate_puts(std::ostream &os, int num_docs)
{
    generate_ops(os, generate_doc_ids(num_docs, false), 1, generate_put);
}

void
generate_assign_updates(std::ostream &os, const std::vector<int> &doc_ids, int num_runs, int tensor_size)
{
    auto op_func = [=](std::ostream &os, int doc_id) { generate_assign_update(os, doc_id, tensor_size); };
    generate_ops(os, doc_ids, num_runs, op_func);
}

void
generate_modify_updates(std::ostream &os, const std::vector<int> &doc_ids, int num_runs, int tensor_size)
{
    auto op_func = [=](std::ostream &os, int doc_id) { generate_modify_update(os, doc_id, tensor_size); };
    generate_ops(os, doc_ids, num_runs, op_func);
}

void
usage(char *argv[])
{
    std::cerr << argv[0] << " put <num-docs>" << std::endl;
    std::cerr << argv[0] << " assign <num-docs> <num-runs> <tensor-size>" << std::endl;
    std::cerr << argv[0] << " modify <num-docs> <num-runs> <tensor-size>" << std::endl;
}

bool
verify_usage(int argc, char *argv[])
{
    if (argc != 3 && argc != 5) {
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
    std::srand(123);
    std::string operation = argv[1];
    int num_docs = std::stoi(argv[2]);
    if (operation == "put") {
        generate_puts(std::cout, num_docs);
    } else if (operation == "assign") {
        int num_runs = std::stoi(argv[3]);
        int tensor_size = std::stoi(argv[4]);
        generate_assign_updates(std::cout, generate_doc_ids(num_docs, true), num_runs, tensor_size);
    } else if (operation == "modify") {
        int num_runs = std::stoi(argv[3]);
        int tensor_size = std::stoi(argv[4]);
        generate_modify_updates(std::cout, generate_doc_ids(num_docs, true), num_runs, tensor_size);
    } else {
        usage(argv);
        return 1;
    }
    return 0;
}

