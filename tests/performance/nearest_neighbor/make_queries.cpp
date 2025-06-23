// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using FloatVector = std::vector<float>;
std::string l_brace = "%7B";
std::string r_brace = "%7D";
std::string quot = "%22";
std::string eq = "%3D";

void
print_vector(std::ostream& os, const FloatVector& vector)
{
    os << "[";
    bool first = true;
    for (auto val : vector) {
        if (!first) {
            os << ",";
        }
        first = false;
        os << val;
    }
    os << "]";
}

std::ostream&
print_int_param(std::ostream& os, const std::string& key, int value)
{
    os << quot << key << quot << ":" << value;
    return os;
}

std::ostream&
print_bool_param(std::ostream& os, const std::string& key, bool value)
{
    os << quot << key << quot << ":" << (value ? "true" : "false");
    return os;
}

std::ostream&
print_str_param(std::ostream& os, const std::string& key, const std::string& value)
{
    os << quot << key << quot << ":" << quot << value << quot;
    return os;
}

void
print_nns(std::ostream& os, bool approximate, int target_hits, int explore_hits, const std::string& doc_tensor)
{
    os << "[" << l_brace;
    print_int_param(os, "targetNumHits", target_hits) << ",";
    print_int_param(os, "hnsw.exploreAdditionalHits", explore_hits) << ",";
    print_bool_param(os, "approximate", approximate) << ",";
    print_str_param(os, "label", "nns");
    os << r_brace << "]" << "nearestNeighbor(" << doc_tensor << ",q_vec)";
}

void
print_query(std::ostream& os, bool approximate, int target_hits, int explore_hits, int filter_percent, const std::string& doc_tensor, const FloatVector& vector)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, approximate, target_hits, explore_hits, doc_tensor);
    if (filter_percent > 0) {
        os << "%20and%20filter" << eq << filter_percent;
    }
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector);
    os << std::endl;
}

/**
 * To compile:
 *   g++ make_queries.cpp -o make_queries
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
 *   ./make_queries <data-set> <num-queries> <doc-tensor> <approximate> <target-hits> <explore-hits> <filter-percent>
 */ 
int
main(int argc, char **argv)
{
    std::string data_set = "sift";
    int dim_size = 128;
    size_t num_queries = 10000;
    std::string doc_tensor = "";
    bool approximate = true;
    int target_hits = 100;
    int explore_hits = 0;
    int filter_percent = 0;
    bool only_vectors = true;
    if (argc > 1) {
        data_set = std::string(argv[1]);
        if (data_set != "sift" && data_set != "gist") {
            std::cerr << "Unknown data set '" << data_set << "'" << std::endl;
            return 1;
        }
        if (data_set == "gist") {
            dim_size = 960;
            num_queries = 1000;
        }
    }
    if (argc > 2) {
        num_queries = std::stoll(argv[2]);
    }
    if (argc > 3) {
        doc_tensor = std::string(argv[3]);
        only_vectors = false;
    }
    if (argc > 4) {
        approximate = (std::string(argv[4]) == "true");
    }
    if (argc > 5) {
        target_hits = std::stoi(argv[5]);
    }
    if (argc > 6) {
        explore_hits = std::stoi(argv[6]);
    }
    if (argc > 7) {
        filter_percent = std::stoi(argv[7]);
    }
    std::string file_name = data_set + "/" + data_set + "_query.fvecs";
    std::ifstream is(file_name, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << file_name << "'" << std::endl;
        return 1;
    }
    int read_dim_size = 0;
    FloatVector vector(dim_size, 0);
    for (size_t docid = 0; docid < num_queries; ++docid) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size);
        assert(is.good());
        if (only_vectors) {
            print_vector(std::cout, vector);
            std::cout << std::endl;
        } else {
            print_query(std::cout, approximate, target_hits, explore_hits, filter_percent, doc_tensor, vector);
        }
    }
    is.close();
}

