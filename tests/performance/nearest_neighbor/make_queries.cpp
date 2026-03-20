// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <format>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "shared.h"

using FloatVector = std::vector<float>;
using Int8Vector = std::vector<int8_t>;
std::string l_brace = "%7B";
std::string r_brace = "%7D";
std::string l_par = "(";
std::string r_par = ")";
std::string quot = "%22";
std::string eq = "%3D";

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
        first = false;
        os << std::format("{}", val);
    }
    os << "]";
}

void
print_random_location(std::ostream& os, const Interval &latitude, const Interval &longitude)
{
    os << latitude.random() << "," << longitude.random();
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

template <typename T>
void
print_query(std::ostream& os, bool approximate, int target_hits, int explore_hits, int filter_percent, float radius, const Interval &latitude, const Interval &longitude, const std::string& doc_tensor, const std::vector<T>& vector)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, approximate, target_hits, explore_hits, doc_tensor);
    if (filter_percent > 0) {
        os << "%20and%20filter" << eq << filter_percent;
    }
    if (radius > 0.0f && latitude.non_empty() && longitude.non_empty()) {
        os << "%20and%20geoLocation" << l_par << "latlng," << latitude.random() << "," << longitude.random() << "," << quot << radius << "+km" << quot << r_par;
    }
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector);
    os << std::endl;
}

int
print_only_locations(int argc, char **argv) {
    Interval latitude;
    Interval longitude;
    size_t num_queries = 10000;

    if (argc > 2) {
        latitude = parse_interval(argv[2]);
    }
    if (argc > 3) {
        longitude = parse_interval(argv[3]);
    }
    if (argc > 4) {
        num_queries = std::stoll(argv[4]);
    }

    for (size_t docid = 0; docid < num_queries; ++docid) {
        print_random_location(std::cout, latitude, longitude);
        std::cout << std::endl;
    }

    return 0;
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
 *   ./make_queries <data-type> <vector-file> <num-dimensions> <num-queries> <doc-tensor> <approximate> <target-hits> <explore-hits> <filter-percent> <radius> <latitude-interval> <longitude-interval>
 */ 
int
main(int argc, char **argv)
{
    srand(42);
    bool use_int8 = false;
    std::string vector_file;
    size_t dim_size = 128;
    size_t num_queries = 10000;
    std::string doc_tensor = "";
    bool approximate = true;
    int target_hits = 100;
    int explore_hits = 0;
    int filter_percent = 0;
    float radius = 0;
    Interval latitude;
    Interval longitude;
    bool only_vectors = true;
    if (argc > 1) {
        use_int8 = (std::string(argv[1]) == "int8");
    }
    if (argc > 2) {
        vector_file = std::string(argv[2]);

        if (vector_file == "--only-locations") {
            return print_only_locations(argc, argv);
        }
    }
    if (argc > 3) {
        dim_size = std::stoll(argv[3]);
    }
    if (argc > 4) {
        num_queries = std::stoll(argv[4]);
    }
    if (argc > 5) {
        doc_tensor = std::string(argv[5]);
        only_vectors = false;
    }
    if (argc > 6) {
        approximate = (std::string(argv[6]) == "true");
    }
    if (argc > 7) {
        target_hits = std::stoi(argv[7]);
    }
    if (argc > 8) {
        explore_hits = std::stoi(argv[8]);
    }
    if (argc > 9) {
        filter_percent = std::stoi(argv[9]);
    }
    if (argc > 10) {
        radius = std::stof(argv[10]);
    }
    if (argc > 11) {
        latitude = parse_interval(argv[11]);
    }
    if (argc > 12) {
        longitude = parse_interval(argv[12]);
    }
    std::ifstream is(vector_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << vector_file << "'" << std::endl;
        return 1;
    }
    int read_dim_size = 0;
    size_t data_type_size = (use_int8 ? sizeof(int8_t) : sizeof(float));
    FloatVector float_vector(dim_size, 0);
    Int8Vector int8_vector(dim_size, 0);
    for (size_t docid = 0; docid < num_queries; ++docid) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);

        char* data_target = use_int8 ? reinterpret_cast<char*>(int8_vector.data()) : reinterpret_cast<char*>(float_vector.data());
        is.read(data_target, data_type_size * dim_size);
        assert(is.good());

        if (only_vectors) {
            if (use_int8) {
                print_vector(std::cout, int8_vector);
            } else {
                print_vector(std::cout, float_vector);
            }
            std::cout << std::endl;
        } else {
            if (use_int8) {
                print_query(std::cout, approximate, target_hits, explore_hits, filter_percent, radius, latitude, longitude, doc_tensor, int8_vector);
            } else {
                print_query(std::cout, approximate, target_hits, explore_hits, filter_percent, radius, latitude, longitude, doc_tensor, float_vector);
            }
        }
    }
    is.close();
}

