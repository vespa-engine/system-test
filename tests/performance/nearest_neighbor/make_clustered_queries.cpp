// Copyright Vespa.ai. All rights reserved.

#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "shared.h"

using FloatVector = std::vector<float>;
using IntVector = std::vector<int>;
std::string l_brace = "%7B";
std::string r_brace = "%7D";
std::string l_par = "(";
std::string r_par = ")";
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

void
print_query(std::ostream& os, bool approximate, int target_hits, int explore_hits, int filter_percent, float radius, const Interval &latitude, const Interval &longitude, const std::string& doc_tensor, const FloatVector& vector, const std::string& cluster_field, const IntVector& clusters)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, approximate, target_hits, explore_hits, doc_tensor);
    if (filter_percent > 0) {
        os << "%20and%20filter" << eq << filter_percent;
    }
    os << "%20and%20" << cluster_field << "%20in%20" << l_par;
    for (size_t i = 0; i < clusters.size(); ++i) {
        os << (i > 0 ? "," : "") << clusters[i];
    }
    os << r_par;
    if (radius > 0.0f && latitude.non_empty() && longitude.non_empty()) {
        os << "%20and%20geoLocation" << l_par << "latlng," << latitude.random() << "," << longitude.random() << "," << quot << radius << "+km" << quot << r_par;
    }
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector);
    os << std::endl;
}

/**
 * To compile:
 *   g++ make_clustered_queries.cpp -o make_clustered_queries
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
 *   ./make_clustered_queries <vector-file> <cluster-file> <cluster-field> <num-dimensions> <num-queries> <doc-tensor> <approximate> <target-hits> <explore-hits> <filter-percent> <radius> <latitude-interval> <longitude-interval>
 *
 * Works like make_queries, but additionally restricts each query to the clusters given for its query vector,
 * by adding "<cluster-field> in (c_1,...,c_n)" to the YQL. The <cluster-file> is an .ivecs file with one record
 * (int32 number of clusters n, n int32 clusters) per query vector, e.g., as written by parquetvectors/utils/assign_query_clusters.py.
 */ 
int
main(int argc, char **argv)
{
    srand(42);

    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << " <vector-file> <cluster-file> <cluster-field> <num-dimensions> <num-queries> <doc-tensor> ..." << std::endl;
        return 1;
    }
    std::string cluster_file(argv[2]);
    std::string cluster_field(argv[3]);

    // Remove cluster file and cluster field such that the remaining arguments are the same as for make_queries
    std::vector<char*> remaining_args(argv, argv + argc);
    remaining_args.erase(remaining_args.begin() + 2, remaining_args.begin() + 4);
    argc = static_cast<int>(remaining_args.size());
    argv = remaining_args.data();

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
        vector_file = std::string(argv[1]);
    }
    if (argc > 2) {
        dim_size = std::stoll(argv[2]);
    }
    if (argc > 3) {
        num_queries = std::stoll(argv[3]);
    }
    if (argc > 4) {
        doc_tensor = std::string(argv[4]);
        only_vectors = false;
    }
    if (argc > 5) {
        approximate = (std::string(argv[5]) == "true");
    }
    if (argc > 6) {
        target_hits = std::stoi(argv[6]);
    }
    if (argc > 7) {
        explore_hits = std::stoi(argv[7]);
    }
    if (argc > 8) {
        filter_percent = std::stoi(argv[8]);
    }
    if (argc > 9) {
        radius = std::stof(argv[9]);
    }
    if (argc > 10) {
        latitude = parse_interval(argv[10]);
    }
    if (argc > 11) {
        longitude = parse_interval(argv[11]);
    }
    std::ifstream is(vector_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << vector_file << "'" << std::endl;
        return 1;
    }
    std::ifstream cluster_is(cluster_file, std::ifstream::binary);
    if (!cluster_is.good()) {
        std::cerr << "Could not open '" << cluster_file << "'" << std::endl;
        return 1;
    }
    int read_dim_size = 0;
    int num_clusters = 0;
    IntVector clusters;
    FloatVector vector(dim_size, 0);
    for (size_t docid = 0; docid < num_queries; ++docid) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size);
        assert(is.good());
        cluster_is.read(reinterpret_cast<char*>(&num_clusters), 4);
        if (cluster_is.good() && num_clusters > 0) {
            clusters.resize(num_clusters);
            cluster_is.read(reinterpret_cast<char*>(clusters.data()), sizeof(int) * num_clusters);
        }
        if (!cluster_is.good() || num_clusters <= 0) {
            std::cerr << "Could not read clusters for query " << docid << " from '" << cluster_file << "'" << std::endl;
            return 1;
        }
        if (only_vectors) {
            print_vector(std::cout, vector);
            std::cout << std::endl;
        } else {
            print_query(std::cout, approximate, target_hits, explore_hits, filter_percent, radius, latitude, longitude, doc_tensor, vector, cluster_field, clusters);
        }
    }
    is.close();
}

