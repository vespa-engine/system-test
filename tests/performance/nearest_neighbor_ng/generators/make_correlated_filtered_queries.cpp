// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <numeric>
#include <optional>

const std::string USAGE =
    "Usage: make_correlated_filtered_queries --vectors <file> --tensor-field <name> --ranked-clusters <file>\n"
    "                                        --doc-clusters <file> --cluster-field <name> --selection <selection>\n"
    "                                        --target-fraction <f> [options] > queries.txt\n"
    "\n"
    "Prints one nearestNeighbor query (URL) per query vector for the documents of make_filtered_docs, with a filter correlated\n"
    "with the query vectors: Each query is restricted to the closest (positive correlation) or farthest (negative correlation)\n"
    "clusters of its query vector with '<cluster-field> in (c_1,...,c_n)'. Clusters are selected until they contain at least\n"
    "the target fraction of the documents, such that all queries have about the same selectivity.\n"
    "\n"
    "Options:\n"
    "  --vectors <file>           .fvecs file with the query vectors\n"
    "  --num-queries <n>          Number of queries (default: all vectors)\n"
    "  --tensor-field <name>      Name of the document tensor field searched by nearestNeighbor\n"
    "  --approximate <bool>       Whether to use approximate search (HNSW), true or false (default: true)\n"
    "  --target-hits <n>          targetNumHits of nearestNeighbor (default: 100)\n"
    "  --explore-hits <n>         hnsw.exploreAdditionalHits of nearestNeighbor (default: 0)\n"
    "  --ranked-clusters <file>   .ivecs file with all clusters of each query vector, closest first (int32 n, n int32 clusters),\n"
    "                             as written by rank_query_clusters.py\n"
    "  --doc-clusters <file>      .ivecs file with the cluster of each document (int32 1, int32 cluster), for the cluster sizes\n"
    "  --num-docs <n>             Number of documents fed, only the clusters of the first n documents are counted (default: all)\n"
    "  --cluster-field <name>     Name of the int field with the cluster of each document\n"
    "  --selection <selection>    closest or farthest\n"
    "  --target-fraction <f>      Fraction of the documents in the selected clusters, in (0, 1]\n"
    "\n"
    "Example:\n"
    "  make_correlated_filtered_queries --vectors queries.fvecs --tensor-field embedding --ranked-clusters ranked_fine.ivecs --doc-clusters clusters_fine.ivecs \\\n"
    "    --cluster-field cluster_fine --selection closest --target-fraction 0.01 > queries_positive.txt\n";

/**
 * Returns the number of documents in each cluster, counting the first num_docs documents (all if not given).
 */
std::vector<size_t>
count_cluster_sizes(const std::string& doc_clusters, std::optional<size_t> num_docs)
{
    VectorFileReader<int32_t> reader(doc_clusters);
    reader.require_dim(1);
    size_t num = num_docs.value_or(reader.num_vectors());
    reader.require(num);
    std::vector<size_t> sizes;
    IntVector cluster;
    for (size_t docid = 0; docid < num; ++docid) {
        reader.read(cluster);
        if (cluster[0] < 0) {
            throw std::runtime_error("Invalid cluster " + std::to_string(cluster[0]) + " of document " + std::to_string(docid) + " in '" + doc_clusters + "'");
        }
        if (static_cast<size_t>(cluster[0]) >= sizes.size()) {
            sizes.resize(cluster[0] + 1, 0);
        }
        ++sizes[cluster[0]];
    }
    if (num == 0) {
        throw std::runtime_error("'" + doc_clusters + "' contains no documents");
    }
    return sizes;
}

/**
 * Selects clusters in the order of the ranking until they contain at least target_docs documents. Empty clusters are skipped.
 */
IntVector
select_clusters(const IntVector& ranking, const std::vector<size_t>& sizes, double target_docs)
{
    IntVector selected;
    size_t selected_docs = 0;
    for (size_t i = 0; i < ranking.size() && selected_docs < target_docs; ++i) {
        int cluster = ranking[i];
        size_t size = (cluster >= 0 && static_cast<size_t>(cluster) < sizes.size()) ? sizes[cluster] : 0;
        if (size > 0) {
            selected.push_back(cluster);
            selected_docs += size;
        }
    }
    return selected;
}

void
print_query(std::ostream& os, const std::string& tensor_field, bool approximate, int target_hits, int explore_hits,
            const std::string& cluster_field, const IntVector& clusters, const FloatVector& vector)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, tensor_field, approximate, target_hits, explore_hits);
    os << "%20and%20" << cluster_field << "%20in%20(";
    for (size_t i = 0; i < clusters.size(); ++i) {
        os << (i > 0 ? "," : "") << clusters[i];
    }
    os << ")";
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector) << "\n";
}

int
main(int argc, char** argv)
{
    try {
        std::string vector_file;
        std::optional<size_t> num_queries;
        std::string tensor_field;
        bool approximate = true;
        int target_hits = 100;
        int explore_hits = 0;
        std::string ranked_clusters;
        std::string doc_clusters;
        std::optional<size_t> num_docs;
        std::string cluster_field;
        std::string selection;
        double target_fraction = 0.0;
        if (argc % 2 == 0) { // --help, or an option without a value
            std::cerr << USAGE;
            return 1;
        }
        for (int i = 1; i < argc; i += 2) {
            std::string option = argv[i];
            std::string value = argv[i + 1];
            if (option == "--vectors") {
                vector_file = value;
            } else if (option == "--num-queries") {
                num_queries = parse_number<size_t>(value);
            } else if (option == "--tensor-field") {
                tensor_field = value;
            } else if (option == "--approximate") {
                approximate = parse_bool(value);
            } else if (option == "--target-hits") {
                target_hits = parse_number<int>(value);
            } else if (option == "--explore-hits") {
                explore_hits = parse_number<int>(value);
            } else if (option == "--ranked-clusters") {
                ranked_clusters = value;
            } else if (option == "--doc-clusters") {
                doc_clusters = value;
            } else if (option == "--num-docs") {
                num_docs = parse_number<size_t>(value);
            } else if (option == "--cluster-field") {
                cluster_field = value;
            } else if (option == "--selection") {
                selection = value;
            } else if (option == "--target-fraction") {
                target_fraction = parse_number<double>(value);
            } else {
                throw std::runtime_error("Unknown option " + option);
            }
        }
        if (vector_file.empty() || tensor_field.empty() || ranked_clusters.empty() || doc_clusters.empty() || cluster_field.empty()) {
            std::cerr << USAGE;
            return 1;
        }
        if (selection != "closest" && selection != "farthest") {
            throw std::runtime_error("--selection must be 'closest' or 'farthest'");
        }
        if (!(target_fraction > 0.0 && target_fraction <= 1.0)) {
            throw std::runtime_error("--target-fraction must be given and in (0, 1]");
        }

        std::vector<size_t> cluster_sizes = count_cluster_sizes(doc_clusters, num_docs);
        double target_docs = target_fraction * std::accumulate(cluster_sizes.begin(), cluster_sizes.end(), size_t(0));
        VectorFileReader<float> vectors(vector_file);
        size_t num = num_queries.value_or(vectors.num_vectors());
        vectors.require(num);
        VectorFileReader<int32_t> ranked_reader(ranked_clusters);
        ranked_reader.require(num);

        FloatVector vector;
        IntVector ranking;
        for (size_t i = 0; i < num; ++i) {
            vectors.read(vector);
            ranked_reader.read(ranking);
            if (selection == "farthest") {
                std::reverse(ranking.begin(), ranking.end());
            }
            IntVector clusters = select_clusters(ranking, cluster_sizes, target_docs);
            print_query(std::cout, tensor_field, approximate, target_hits, explore_hits, cluster_field, clusters, vector);
        }
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
