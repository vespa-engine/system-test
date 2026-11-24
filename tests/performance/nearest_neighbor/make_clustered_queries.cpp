// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
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
 * Reads a cluster file with one record (int32 dimension 1, int32 cluster) per document and returns the number of documents per cluster,
 * counting only the first num_docs documents (all documents if num_docs is 0).
 */
bool
read_cluster_sizes(const std::string& doc_cluster_file, size_t num_docs, std::vector<size_t>& sizes)
{
    std::ifstream is(doc_cluster_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << doc_cluster_file << "'" << std::endl;
        return false;
    }
    int record[2];
    size_t read_docs = 0;
    while ((num_docs == 0 || read_docs < num_docs) && is.read(reinterpret_cast<char*>(record), sizeof(record))) {
        if (record[0] != 1 || record[1] < 0) {
            std::cerr << "Invalid record in '" << doc_cluster_file << "'" << std::endl;
            return false;
        }
        if (static_cast<size_t>(record[1]) >= sizes.size()) {
            sizes.resize(record[1] + 1, 0);
        }
        ++sizes[record[1]];
        ++read_docs;
    }
    if (read_docs < num_docs) {
        std::cerr << "'" << doc_cluster_file << "' contains only " << read_docs << " documents, not " << num_docs << std::endl;
        return false;
    }
    return true;
}

/**
 * Selects clusters from the ranking (ordered from closest to farthest) until they contain at least target_docs documents,
 * starting with the closest clusters, or with the farthest clusters if farthest is true. Empty clusters are skipped.
 */
IntVector
select_clusters(const IntVector& ranking, const std::vector<size_t>& sizes, double target_docs, bool farthest, size_t& selected_docs)
{
    IntVector selected;
    selected_docs = 0;
    for (size_t i = 0; i < ranking.size() && selected_docs < target_docs; ++i) {
        int cluster = ranking[farthest ? ranking.size() - 1 - i : i];
        size_t size = (static_cast<size_t>(cluster) < sizes.size()) ? sizes[cluster] : 0;
        if (size == 0) {
            continue; // Empty clusters do not change the selectivity, no need to include them in the query
        }
        selected.push_back(cluster);
        selected_docs += size;
    }
    return selected;
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
 *   ./make_clustered_queries <vector-file> <query-cluster-file> <doc-cluster-file> <num-docs> <cluster-field> <closest|farthest> <target-fraction> <num-dimensions> <num-queries> <doc-tensor> <approximate> <target-hits> <explore-hits> <filter-percent> <radius> <latitude-interval> <longitude-interval>
 *
 * Works like make_queries, but additionally restricts each query to the closest (positive correlation) or farthest (negative correlation)
 * clusters of its query vector, by adding "<cluster-field> in (c_1,...,c_n)" to the YQL. Clusters are selected until they contain
 * at least <target-fraction> of the documents.
 *
 * The <query-cluster-file> is an .ivecs file with one record (int32 number of clusters n, n int32 clusters ordered from closest
 * to farthest) per query vector, as written by parquetvectors/utils/rank_query_clusters.py. The <doc-cluster-file> is an .ivecs file
 * with one record (int32 dimension 1, int32 cluster) per document, as written by parquetvectors/utils/assign_clusters.py,
 * and is used for the cluster sizes. Only the first <num-docs> documents are counted (all documents if <num-docs> is 0), e.g., to feed
 * only the first 1M of 10M clustered documents.
 */ 
int
main(int argc, char **argv)
{
    srand(42);

    if (argc < 8) {
        std::cerr << "Usage: " << argv[0] << " <vector-file> <query-cluster-file> <doc-cluster-file> <num-docs> <cluster-field> <closest|farthest> <target-fraction> <num-dimensions> <num-queries> <doc-tensor> ..." << std::endl;
        return 1;
    }
    std::string cluster_file(argv[2]);
    std::string doc_cluster_file(argv[3]);
    size_t num_docs_limit = std::stoull(argv[4]);
    std::string cluster_field(argv[5]);
    std::string selection(argv[6]);
    double target_fraction = std::stod(argv[7]);
    if (selection != "closest" && selection != "farthest") {
        std::cerr << "Selection must be 'closest' or 'farthest', not '" << selection << "'" << std::endl;
        return 1;
    }
    if (!(target_fraction > 0.0 && target_fraction <= 1.0)) {
        std::cerr << "Target fraction must be in (0, 1]" << std::endl;
        return 1;
    }
    bool farthest = (selection == "farthest");
    std::vector<size_t> sizes;
    if (!read_cluster_sizes(doc_cluster_file, num_docs_limit, sizes)) {
        return 1;
    }
    size_t num_docs = 0;
    for (auto size : sizes) {
        num_docs += size;
    }
    if (num_docs == 0) {
        std::cerr << "'" << doc_cluster_file << "' contains no documents" << std::endl;
        return 1;
    }
    double target_docs = target_fraction * num_docs;

    // Remove the cluster arguments such that the remaining arguments are the same as for make_queries
    std::vector<char*> remaining_args(argv, argv + argc);
    remaining_args.erase(remaining_args.begin() + 2, remaining_args.begin() + 8);
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
    IntVector ranking;
    IntVector clusters;
    size_t selected_docs = 0;
    double min_fraction = 1.0, max_fraction = 0.0, sum_fraction = 0.0;
    size_t min_clusters = sizes.size(), max_clusters = 0, sum_clusters = 0;
    FloatVector vector(dim_size, 0);
    for (size_t docid = 0; docid < num_queries; ++docid) {
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        assert(read_dim_size == dim_size);
        is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size);
        assert(is.good());
        cluster_is.read(reinterpret_cast<char*>(&num_clusters), 4);
        if (cluster_is.good() && num_clusters > 0) {
            ranking.resize(num_clusters);
            cluster_is.read(reinterpret_cast<char*>(ranking.data()), sizeof(int) * num_clusters);
        }
        if (!cluster_is.good() || num_clusters <= 0) {
            std::cerr << "Could not read clusters for query " << docid << " from '" << cluster_file << "'" << std::endl;
            return 1;
        }
        clusters = select_clusters(ranking, sizes, target_docs, farthest, selected_docs);
        double fraction = static_cast<double>(selected_docs) / num_docs;
        min_fraction = std::min(min_fraction, fraction);
        max_fraction = std::max(max_fraction, fraction);
        sum_fraction += fraction;
        min_clusters = std::min(min_clusters, clusters.size());
        max_clusters = std::max(max_clusters, clusters.size());
        sum_clusters += clusters.size();
        if (only_vectors) {
            print_vector(std::cout, vector);
            std::cout << std::endl;
        } else {
            print_query(std::cout, approximate, target_hits, explore_hits, filter_percent, radius, latitude, longitude, doc_tensor, vector, cluster_field, clusters);
        }
    }
    is.close();
    std::cerr << "Selected the " << selection << " clusters for " << num_queries << " queries: "
              << "clusters per query min " << min_clusters << ", max " << max_clusters << ", mean " << static_cast<double>(sum_clusters) / num_queries << "; "
              << "fraction of documents min " << min_fraction << ", max " << max_fraction << ", mean " << sum_fraction / num_queries << std::endl;
}

