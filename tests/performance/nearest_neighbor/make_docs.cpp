// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using FloatVector = std::vector<float>;
using IntVector = std::vector<int>;

IntVector
parse_filters(const std::string &str) {
    IntVector filters;

    std::stringstream ss(str);

    int i;
    while (ss >> i) {
        filters.push_back(i);
        if (ss.peek() == ','
	    || ss.peek() == '{'
	    || ss.peek() == '}'
	    || ss.peek() == '['
	    || ss.peek() == ']')
            ss.ignore();
    }

    return filters;
}

IntVector
gen_filter_values(size_t docid, const IntVector &filters)
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
print_put(std::ostream& os, size_t docid, const IntVector &filters, const StringVector& tensor_fields, const FloatVector& vector, bool mixed_tensor)
{
    os << "{" << std::endl;
    os << "  \"put\": \"id:test:test::" << docid << "\"," << std::endl;
    os << "  \"fields\": {" << std::endl;
    os << "    \"id\": " << docid << "," << std::endl;
    if (!filters.empty()) {
        os << "    \"filter\": "; print_vector(os, gen_filter_values(docid, filters)); os << "," << std::endl;
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
 *   ./make_docs <data-set> <feed-op> <begin-doc> <start-vector> <end-vector> <filter-values> <mixed-tensor> <tensor-field-0> ... <tensor-field-n>
 */ 
int
main(int argc, char **argv)
{
    std::string vector_file;
    std::string feed_op = "put";
    size_t begin_doc = 0;
    size_t start_vector = 0; // inclusive
    size_t end_vector = 1000000; // exclusive
    size_t dim_size = 128;
    IntVector filters;
    bool mixed_tensor = false;
    std::vector<std::string> tensor_fields;
    if (argc > 1) {
        vector_file = std::string(argv[1]);
    }
    if (argc > 2) {
        dim_size = std::stoll(argv[2]);
    }
    if (argc > 3) {
        feed_op = std::string(argv[3]);
    }
    if (argc > 4) {
        begin_doc = std::stoll(argv[4]);
    }
    if (argc > 5) {
        start_vector = std::stoll(argv[5]);
    }
    if (argc > 6) {
        end_vector = std::stoll(argv[6]);
    }
    if (argc > 7) {
	filters = parse_filters(argv[7]);
    }
    if (argc > 8) {
        mixed_tensor = (argv[8] == std::string("true"));
    }
    for (int i = 9; i < argc; ++i) {
        tensor_fields.push_back(std::string(argv[i]));
    }
    std::ifstream is(vector_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << vector_file << "'" << std::endl;
        return 1;
    }
    int read_dim_size = 0;
    FloatVector vector(dim_size, 0);
    std::cout << "[" << std::endl;
    bool make_puts = (feed_op == "put");
    bool first = true;

    is.ignore(start_vector * (4 + sizeof(float) * dim_size)); // skip vectors as specified by start_vector
    for (size_t vector_num = start_vector; vector_num < end_vector; ++vector_num) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size);
        assert(is.good());

        if (!first) {
            std::cout << "," << std::endl;
        }
        first = false;
        if (make_puts) {
            print_put(std::cout, begin_doc + vector_num - start_vector, filters, tensor_fields, vector, mixed_tensor);
        } else {
            print_update(std::cout, begin_doc + vector_num - start_vector, tensor_fields, vector, mixed_tensor);
        }
    }
    std::cout << std::endl << "]" << std::endl;
    is.close();
}

