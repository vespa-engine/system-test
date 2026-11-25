// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

#include <iostream>
#include <optional>

const std::string USAGE =
    "Usage: make_filtered_queries --vectors <file> --tensor-field <name> [options] > queries.txt\n"
    "\n"
    "Prints one nearestNeighbor query (URL) per query vector for the documents of make_filtered_docs,\n"
    "with a filter with a given hit ratio, uncorrelated with the query vectors.\n"
    "\n"
    "Options:\n"
    "  --vectors <file>           .fvecs file with the query vectors\n"
    "  --num-queries <n>          Number of queries (default: all vectors)\n"
    "  --tensor-field <name>      Name of the document tensor field searched by nearestNeighbor\n"
    "  --approximate <bool>       Whether to use approximate search (HNSW), true or false (default: true)\n"
    "  --target-hits <n>          targetNumHits of nearestNeighbor (default: 100)\n"
    "  --explore-hits <n>         hnsw.exploreAdditionalHits of nearestNeighbor (default: 0)\n"
    "  --hit-ratio <r>            Adds 'filter=<r * 1000>' to each query, e.g., 'filter=10' for 0.01, see --hit-ratios of\n"
    "                             make_filtered_docs (default: no filter)\n"
    "\n"
    "Example:\n"
    "  make_filtered_queries --vectors queries.fvecs --tensor-field embedding --hit-ratio 0.1 > queries_uncorrelated.txt\n";

/**
 * Prints the query. The filter 'filter=<value>' is added if the filter value is given.
 */
void
print_query(std::ostream& os, const std::string& tensor_field, bool approximate, int target_hits, int explore_hits,
            std::optional<int> filter, const FloatVector& vector)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, tensor_field, approximate, target_hits, explore_hits);
    if (filter) {
        os << "%20and%20filter" << EQ << *filter;
    }
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
        std::optional<int> filter;
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
            } else if (option == "--hit-ratio") {
                filter = filter_value(parse_number<double>(value));
            } else {
                throw std::runtime_error("Unknown option " + option);
            }
        }
        if (vector_file.empty() || tensor_field.empty()) {
            std::cerr << USAGE;
            return 1;
        }

        VectorFileReader<float> vectors(vector_file);
        size_t num = num_queries.value_or(vectors.num_vectors());
        vectors.require(num);

        FloatVector vector;
        for (size_t i = 0; i < num; ++i) {
            vectors.read(vector);
            print_query(std::cout, tensor_field, approximate, target_hits, explore_hits, filter, vector);
        }
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
