// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

#include <iostream>
#include <optional>

const std::string USAGE =
    "Usage: make_filtered_docs --vectors <files> --tensor-field <name> [options] > docs.json\n"
    "\n"
    "Prints a feed (JSON array of puts) of documents with a vector, a filter field uncorrelated with the vectors,\n"
    "and the clusters of the documents (e.g., for filters correlated with the query vectors, see make_correlated_filtered_queries).\n"
    "Each document has the int field 'id' (its number).\n"
    "\n"
    "Options:\n"
    "  --vectors <files>          .fvecs file, or a comma-separated list of .fvecs files read in order as one sequence\n"
    "                             (e.g., docs_0000.fvecs,docs_0001.fvecs), the i-th vector is used for document i\n"
    "  --num-docs <n>             Number of documents (default: all vectors)\n"
    "  --tensor-field <name>      Name of the tensor field\n"
    "  --hit-ratios <ratios>      Comma-separated hit ratios for the array<int> field 'filter' (default: no field 'filter').\n"
    "                             For each hit ratio r, document i contains r * 1000 if (i % 1000) < r * 1000, e.g., 10 for 0.01,\n"
    "                             such that the filter 'filter=10' has hit ratio 0.01, uncorrelated with the vectors\n"
    "  --cluster-files <files>    Comma-separated .ivecs files with the cluster of each document (int32 1, int32 cluster),\n"
    "                             as written by assign_clusters.py, e.g., clusters_fine.ivecs,clusters_coarse.ivecs\n"
    "  --cluster-fields <names>   Comma-separated names of the int fields for the clusters, one per cluster file\n"
    "\n"
    "Example:\n"
    "  make_filtered_docs --vectors docs_0000.fvecs,docs_0001.fvecs --tensor-field embedding --hit-ratios 0.01,0.1,0.5,0.9,0.99 \\\n"
    "    --cluster-files clusters_fine.ivecs,clusters_coarse.ivecs --cluster-fields cluster_fine,cluster_coarse > docs.json\n";

/**
 * Returns the filter values of document docid: value v if (docid % 1000) < v.
 */
IntVector
doc_filter_values(size_t docid, const IntVector& filter_values)
{
    IntVector result;
    for (int value : filter_values) {
        if (docid % 1000 < static_cast<size_t>(value)) {
            result.push_back(value);
        }
    }
    return result;
}

void
print_put(std::ostream& os, size_t docid, const IntVector& filter_values, const StringVector& cluster_fields, const IntVector& clusters,
          const std::string& tensor_field, const FloatVector& vector)
{
    os << "{\n";
    os << "  \"put\": \"id:test:test::" << docid << "\",\n";
    os << "  \"fields\": {\n";
    os << "    \"id\": " << docid << ",\n";
    if (!filter_values.empty()) {
        os << "    \"filter\": ";
        print_vector(os, doc_filter_values(docid, filter_values)) << ",\n";
    }
    for (size_t i = 0; i < cluster_fields.size(); ++i) {
        os << "    \"" << cluster_fields[i] << "\": " << clusters[i] << ",\n";
    }
    os << "    \"" << tensor_field << "\": { \"values\": ";
    print_vector(os, vector) << " }\n";
    os << "  }\n";
    os << "}";
}

int
main(int argc, char** argv)
{
    try {
        std::string vector_files;
        std::optional<size_t> num_docs;
        std::string tensor_field;
        std::vector<double> hit_ratios;
        StringVector cluster_files;
        StringVector cluster_fields;
        if (argc % 2 == 0) { // --help, or an option without a value
            std::cerr << USAGE;
            return 1;
        }
        for (int i = 1; i < argc; i += 2) {
            std::string option = argv[i];
            std::string value = argv[i + 1];
            if (option == "--vectors") {
                vector_files = value;
            } else if (option == "--num-docs") {
                num_docs = parse_number<size_t>(value);
            } else if (option == "--tensor-field") {
                tensor_field = value;
            } else if (option == "--hit-ratios") {
                hit_ratios = parse_numbers<double>(value);
            } else if (option == "--cluster-files") {
                cluster_files = split(value, ',');
            } else if (option == "--cluster-fields") {
                cluster_fields = split(value, ',');
            } else {
                throw std::runtime_error("Unknown option " + option);
            }
        }
        if (vector_files.empty() || tensor_field.empty()) {
            std::cerr << USAGE;
            return 1;
        }
        if (cluster_files.size() != cluster_fields.size()) {
            throw std::runtime_error("The number of cluster files and cluster fields must be the same");
        }

        VectorFileReader<float> vectors(vector_files);
        size_t num = num_docs.value_or(vectors.num_vectors());
        vectors.require(num);
        IntVector filter_values;
        for (double hit_ratio : hit_ratios) {
            filter_values.push_back(filter_value(hit_ratio));
        }
        std::vector<VectorFileReader<int32_t>> cluster_readers;
        for (const auto& file : cluster_files) {
            cluster_readers.emplace_back(file);
            cluster_readers.back().require_dim(1);
            cluster_readers.back().require(num);
        }

        FloatVector vector;
        IntVector cluster;
        IntVector clusters(cluster_readers.size());
        std::cout << "[\n";
        for (size_t docid = 0; docid < num; ++docid) {
            vectors.read(vector);
            for (size_t i = 0; i < cluster_readers.size(); ++i) {
                cluster_readers[i].read(cluster);
                clusters[i] = cluster[0];
            }
            std::cout << (docid == 0 ? "" : ",\n");
            print_put(std::cout, docid, filter_values, cluster_fields, clusters, tensor_field, vector);
        }
        std::cout << "\n]" << std::endl;
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
