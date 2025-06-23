// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using FloatVector = std::vector<float>;
using IntVector = std::vector<int>;

// These values indicate how many percent of the corpus should be filtered away.
const IntVector filters = {1, 10, 50, 90, 95, 99};

IntVector
gen_filter_values(size_t docid)
{
    IntVector result;
    for (auto filter_percent : filters) {
        if ((docid % 100) >= filter_percent) {
            // This document is NOT filtered away for this filter percent.
            result.push_back(filter_percent);
        }
    }
    return result;
}

template <typename T>
void
print_vector(std::ostream& os, const std::vector<T>& vector)
{
    os << "[";
    bool first = true;
    for (auto val : vector) {
        if (!first) {
            os << ",";
        }
        os << val;
        first = false;
    }
    os << "]";
}

std::ostream&
print_vector_spec(std::ostream& os, bool mixed_tensor)
{
    if (mixed_tensor) {
        os << "\"blocks\": { \"a\": ";
    } else {
        os << "\"values\": ";
    }
    return os;
}

std::ostream&
print_vector_field(std::ostream& os, const std::string& field_name, const FloatVector& vector, bool mixed_tensor)
{
    os << "\"" << field_name << "\": { ";
    print_vector_spec(os, mixed_tensor);
    print_vector(os, vector);
    os << (mixed_tensor ? " }" : "") << " }";
    return os;
}

std::ostream&
print_assign_vector_field(std::ostream& os, const std::string& field_name, const FloatVector& vector, bool mixed_tensor)
{
    os << "\"" << field_name << "\": { \"assign\": { ";
    print_vector_spec(os, mixed_tensor);
    print_vector(os, vector);
    os << (mixed_tensor ? " }" : "") << " } }";
    return os;
}


using StringVector = std::vector<std::string>;

void
print_put(std::ostream& os, size_t docid, bool gen_filter, const StringVector& tensor_fields, const FloatVector& vector, bool mixed_tensor)
{
    os << "{" << std::endl;
    os << "  \"put\": \"id:test:test::" << docid << "\"," << std::endl;
    os << "  \"fields\": {" << std::endl;
    os << "    \"id\": " << docid << "," << std::endl;
    if (gen_filter) {
        os << "    \"filter\": "; print_vector(os, gen_filter_values(docid)); os << "," << std::endl;
    }
    for (size_t i = 0; i < tensor_fields.size(); ++i) {
        bool last = (i + 1) == tensor_fields.size();
        os << "    "; print_vector_field(os, tensor_fields[i], vector, mixed_tensor) << (last ? "" : ",") << std::endl;
    }
    os << "  }" << std::endl;
    os << "}";
}

void
print_update(std::ostream& os, size_t docid, const StringVector& tensor_fields, const FloatVector& vector, bool mixed_tensor)
{
    os << "{" << std::endl;
    os << "  \"update\": \"id:test:test::" << docid << "\"," << std::endl;
    os << "  \"fields\": {" << std::endl;
    for (size_t i = 0; i < tensor_fields.size(); ++i) {
        bool last = (i + 1) == tensor_fields.size();
        os << "    "; print_assign_vector_field(os, tensor_fields[i], vector, mixed_tensor) << (last ? "" : ",") << std::endl;
    }
    os << "  }" << std::endl;
    os << "}";
}


/**
 * To compile:
 *   g++ make_docs.cpp -o make_docs
 *
 * Download and extract the ANN_SIFT1M data set (1M docs, 10000 queries, 128 dims):
 *   wget ftp://ftp.irisa.fr/local/texmex/corpus/sift.tar.gz
 *   tar -xf sift.tar.gz
 *
 * Download and extract the ANN_GIST1M data set (1M docs, 1000 queries, 960 dims):
 *   wget ftp://ftp.irisa.fr/local/texmex/corpus/gist.tar.gz
 *   tar -xf gist.tar.gz
 *
 * To run:
 *   ./make_docs <data-set> <feed-op> <begin-doc> <num-docs> <gen-filter> <mixed-tensor> <tensor-field-0> ... <tensor-field-n>
 */ 
int
main(int argc, char **argv)
{
    std::string data_set = "sift";
    std::string feed_op = "put";
    size_t begin_doc = 0;
    size_t num_docs = 1000000;
    int dim_size = 128;
    bool gen_filter = false;
    bool mixed_tensor = false;
    std::vector<std::string> tensor_fields;
    if (argc > 1) {
        data_set = std::string(argv[1]);
        if (data_set != "sift" && data_set != "gist") {
            std::cerr << "Unknown data set '" << data_set << "'" << std::endl;
            return 1;
        }
        if (data_set == "gist") {
            dim_size = 960;
        }
    }
    if (argc > 2) {
        feed_op = std::string(argv[2]);
    }
    if (argc > 3) {
        begin_doc = std::stoll(argv[3]);
    }
    if (argc > 4) {
        num_docs = std::stoll(argv[4]);
    }
    if (argc > 5) {
        gen_filter = (argv[5] == std::string("true"));
    }
    if (argc > 6) {
        mixed_tensor = (argv[6] == std::string("true"));
    }
    for (int i = 7; i < argc; ++i) {
        tensor_fields.push_back(std::string(argv[i]));
    }
    std::string file_name = data_set + "/" + data_set + "_base.fvecs";
    std::ifstream is(file_name, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << file_name << "'" << std::endl;
        return 1;
    }
    int read_dim_size = 0;
    FloatVector vector(dim_size, 0);
    std::cout << "[" << std::endl;
    bool make_puts = (feed_op == "put");
    bool first = true;
    for (size_t docid = begin_doc; docid < (begin_doc + num_docs); ++docid) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size);
        assert(is.good());
        if (!first) {
            std::cout << "," << std::endl;
        }
        first = false;
        if (make_puts) {
            print_put(std::cout, docid, gen_filter, tensor_fields, vector, mixed_tensor);
        } else {
            print_update(std::cout, docid, tensor_fields, vector, mixed_tensor);
        }
    }
    std::cout << std::endl << "]" << std::endl;
    is.close();
}

