// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

using FloatVector = std::vector<float>;
using IntVector = std::vector<int32_t>;

/**
 * Reads all vectors with the given dimension from an .fvecs file.
 */
std::vector<FloatVector>
read_all_fvecs(const std::string& file, size_t dim_size)
{
    std::ifstream is(file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << file << "'" << std::endl;
        exit(1);
    }
    std::vector<FloatVector> result;
    int32_t read_dim_size = 0;
    while (is.read(reinterpret_cast<char*>(&read_dim_size), 4)) {
        if (static_cast<size_t>(read_dim_size) != dim_size) {
            std::cerr << "Expected dimension " << dim_size << " in '" << file << "', got " << read_dim_size << std::endl;
            exit(1);
        }
        FloatVector vector(dim_size);
        if (!is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * dim_size)) {
            std::cerr << "Truncated vector in '" << file << "'" << std::endl;
            exit(1);
        }
        result.push_back(std::move(vector));
    }
    return result;
}

/**
 * To compile:
 *   g++ -O3 -std=c++20 make_query_clusters.cpp -o make_query_clusters
 *
 * To run:
 *   ./make_query_clusters <query-vector-file> <centroid-file> <doc-cluster-file> <num-dimensions> <num-queries> <num-docs> <target-fraction> <closest|farthest> > query_clusters.ivecs
 *
 * Selects the closest (positive correlation) or farthest (negative correlation) clusters for each of the
 * first <num-queries> query vectors until the selected clusters contain at least <target-fraction> of the
 * first <num-docs> documents. This is the same as
 *   parquetvectors/utils/assign_query_clusters.py --target-fraction <target-fraction> --doc-clusters <doc-cluster-file> [--farthest]
 * but only takes the first <num-docs> documents into account, such that the selectivity is correct
 * when only a prefix of the documents is fed.
 *
 * <centroid-file> is an .fvecs file with the (spherical k-means) centroids, and <doc-cluster-file> an .ivecs file
 * with one cluster per document, as written by parquetvectors/utils/assign_clusters.py --spherical --centroids.
 *
 * The output (written to stdout) is an .ivecs file with one record (int32 number of clusters n, n int32 clusters)
 * per query vector, which can be given to make_clustered_queries. Statistics are written to stderr.
 */
int
main(int argc, char **argv)
{
    if (argc != 9) {
        std::cerr << "Usage: " << argv[0] << " <query-vector-file> <centroid-file> <doc-cluster-file> <num-dimensions> <num-queries> <num-docs> <target-fraction> <closest|farthest>" << std::endl;
        return 1;
    }
    std::string query_file(argv[1]);
    std::string centroid_file(argv[2]);
    std::string doc_cluster_file(argv[3]);
    size_t dim_size = std::stoll(argv[4]);
    size_t num_queries = std::stoll(argv[5]);
    size_t num_docs = std::stoll(argv[6]);
    double target_fraction = std::stod(argv[7]);
    std::string mode(argv[8]);
    if (mode != "closest" && mode != "farthest") {
        std::cerr << "Mode must be 'closest' or 'farthest', got '" << mode << "'" << std::endl;
        return 1;
    }
    bool farthest = (mode == "farthest");
    if (!(target_fraction > 0.0 && target_fraction <= 1.0)) {
        std::cerr << "Target fraction must be in (0, 1]" << std::endl;
        return 1;
    }

    auto centroids = read_all_fvecs(centroid_file, dim_size);
    size_t num_centroids = centroids.size();
    std::vector<double> centroid_norms(num_centroids);
    for (size_t c = 0; c < num_centroids; ++c) {
        centroid_norms[c] = std::inner_product(centroids[c].begin(), centroids[c].end(), centroids[c].begin(), 0.0);
    }

    // Cluster sizes over the first num_docs documents
    std::vector<size_t> sizes(num_centroids, 0);
    {
        std::ifstream is(doc_cluster_file, std::ifstream::binary);
        if (!is.good()) {
            std::cerr << "Could not open '" << doc_cluster_file << "'" << std::endl;
            return 1;
        }
        int32_t record[2];
        for (size_t doc = 0; doc < num_docs; ++doc) {
            if (!is.read(reinterpret_cast<char*>(record), sizeof(record)) || record[0] != 1) {
                std::cerr << "Could not read cluster for document " << doc << " from '" << doc_cluster_file << "'" << std::endl;
                return 1;
            }
            if (record[1] < 0 || static_cast<size_t>(record[1]) >= num_centroids) {
                std::cerr << "Cluster " << record[1] << " of document " << doc << " is not in '" << centroid_file << "'" << std::endl;
                return 1;
            }
            ++sizes[record[1]];
        }
    }
    double target_docs = target_fraction * num_docs - 1e-9;

    std::ifstream is(query_file, std::ifstream::binary);
    if (!is.good()) {
        std::cerr << "Could not open '" << query_file << "'" << std::endl;
        return 1;
    }
    FloatVector query(dim_size);
    std::vector<double> distances(num_centroids);
    IntVector ranked(num_centroids);
    size_t min_selected = num_centroids, max_selected = 0, sum_selected = 0;
    double min_fraction = 1.0, max_fraction = 0.0, sum_fraction = 0.0;
    for (size_t q = 0; q < num_queries; ++q) {
        int32_t read_dim_size = 0;
        is.read(reinterpret_cast<char*>(&read_dim_size), 4);
        is.read(reinterpret_cast<char*>(query.data()), sizeof(float) * dim_size);
        if (!is.good() || static_cast<size_t>(read_dim_size) != dim_size) {
            std::cerr << "Could not read query vector " << q << " from '" << query_file << "'" << std::endl;
            return 1;
        }
        // Squared euclidean distance without the (constant) query norm, as in parquetvectors/kmeans.py
        for (size_t c = 0; c < num_centroids; ++c) {
            double dot = std::inner_product(query.begin(), query.end(), centroids[c].begin(), 0.0);
            double distance = centroid_norms[c] - 2.0 * dot;
            distances[c] = farthest ? -distance : distance;
        }
        std::iota(ranked.begin(), ranked.end(), 0);
        std::stable_sort(ranked.begin(), ranked.end(), [&](int32_t a, int32_t b) { return distances[a] < distances[b]; });

        size_t count = 0;
        size_t covered = 0;
        while (count < num_centroids && (count == 0 || covered < target_docs)) {
            covered += sizes[ranked[count]];
            ++count;
        }
        int32_t n = count;
        std::cout.write(reinterpret_cast<const char*>(&n), 4);
        std::cout.write(reinterpret_cast<const char*>(ranked.data()), sizeof(int32_t) * count);

        double fraction = static_cast<double>(covered) / num_docs;
        min_selected = std::min(min_selected, count);
        max_selected = std::max(max_selected, count);
        sum_selected += count;
        min_fraction = std::min(min_fraction, fraction);
        max_fraction = std::max(max_fraction, fraction);
        sum_fraction += fraction;
    }
    std::cout.flush();
    std::fprintf(stderr, "Selected the %s clusters (target fraction %g of %zu documents) for %zu queries from %zu centroids\n",
                 mode.c_str(), target_fraction, num_docs, num_queries, num_centroids);
    std::fprintf(stderr, "Clusters per query: min %zu, max %zu, mean %.1f\n",
                 min_selected, max_selected, static_cast<double>(sum_selected) / num_queries);
    std::fprintf(stderr, "Fraction of documents in selected clusters: min %.4f, max %.4f, mean %.4f\n",
                 min_fraction, max_fraction, sum_fraction / num_queries);
    return 0;
}
