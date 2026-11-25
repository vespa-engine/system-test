// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

const std::set<std::string> FILTER_DOC_OPTIONS = {"filter-values", "filter-denominator", "cluster-files", "cluster-fields"};

const std::string FILTER_DOC_OPTIONS_USAGE =
    "  --filter-values <values>   Comma-separated values v for the array<int> field 'filter' (default: no field 'filter').\n"
    "                             Document i gets value v if (i % denominator) >= v, i.e., the fraction 1 - v / denominator\n"
    "                             of the documents passes the filter 'filter=v', uncorrelated with the vectors.\n"
    "  --filter-denominator <n>   Denominator for the filter values (default: 100)\n"
    "  --cluster-files <files>    Comma-separated .ivecs files with the cluster of each document (int32 1, int32 cluster),\n"
    "                             as written by assign_clusters.py, e.g., clusters_fine.ivecs,clusters_coarse.ivecs\n"
    "  --cluster-fields <names>   Comma-separated names of the int fields for the clusters, one per cluster file\n";

const std::string USAGE =
    "Usage: {program} --vectors <files> --tensor-field <name> [options] > docs.json\n"
    "\n"
    "Prints a feed (JSON array of puts) of documents with a vector, a filter field uncorrelated with the vectors,\n"
    "and the clusters of the documents (e.g., for filters correlated with the query vectors, see make_filtered_queries).\n"
    "Each document has the int field 'id' (its number).\n"
    "\n"
    "Options:\n" + DOC_OPTIONS_USAGE + FILTER_DOC_OPTIONS_USAGE +
    "\n"
    "Example:\n"
    "  {program} --vectors docs_0000.fvecs,docs_0001.fvecs --tensor-field embedding --filter-values 1,10,50,90,99 \\\n"
    "    --cluster-files clusters_fine.ivecs,clusters_coarse.ivecs --cluster-fields cluster_fine,cluster_coarse > docs.json\n";

/**
 * Writes the field 'filter' with values uncorrelated with the vectors, and the cluster of each document from cluster files.
 */
class FilterClusterFields {
    IntVector _filter_values;
    size_t _filter_denominator;
    StringVector _cluster_fields;
    std::vector<IntRecordReader> _cluster_readers;

public:
    FilterClusterFields(const Args& args, size_t num_docs)
        : _filter_values(args.get_list<int>("filter-values")),
          _filter_denominator(args.get_number<size_t>("filter-denominator", 100)),
          _cluster_fields(split(args.get("cluster-fields", ""), ',')),
          _cluster_readers()
    {
        if (_filter_denominator == 0) {
            args.fail("--filter-denominator must be positive");
        }
        StringVector cluster_files = split(args.get("cluster-files", ""), ',');
        if (cluster_files.size() != _cluster_fields.size()) {
            args.fail("The number of cluster files (" + std::to_string(cluster_files.size()) + ") and cluster fields ("
                      + std::to_string(_cluster_fields.size()) + ") must be the same");
        }
        for (const auto& file : cluster_files) {
            std::error_code ec;
            auto size = std::filesystem::file_size(file, ec);
            if (!ec && size < 8 * num_docs) {
                throw std::runtime_error("'" + file + "' contains the clusters of at most " + std::to_string(size / 8) + " documents, not "
                                         + std::to_string(num_docs));
            }
            _cluster_readers.emplace_back(file);
        }
    }

    void print(FeedPrinter& printer, size_t docid) {
        if (!_filter_values.empty()) {
            IntVector values;
            for (int value : _filter_values) {
                if (static_cast<int64_t>(docid % _filter_denominator) >= value) {
                    values.push_back(value);
                }
            }
            print_vector(printer.field("filter"), values);
        }
        for (size_t i = 0; i < _cluster_fields.size(); ++i) {
            printer.field(_cluster_fields[i]) << _cluster_readers[i].read_single();
        }
    }
};

int
main(int argc, char** argv)
{
    Args args(argc, argv, USAGE, DOC_OPTIONS + FILTER_DOC_OPTIONS);
    std::string tensor_field = args.get("tensor-field");
    try {
        VectorFileReader vectors(args.get("vectors"));
        size_t num_docs = vectors.check_num(args, "num-docs");
        FilterClusterFields filter_cluster_fields(args, num_docs);
        FeedPrinter printer(std::cout);
        FloatVector vector;
        for (size_t docid = 0; docid < num_docs; ++docid) {
            vectors.read(vector);
            printer.begin_put(docid);
            printer.field("id") << docid;
            filter_cluster_fields.print(printer, docid);
            printer.tensor_field(tensor_field, vector);
            printer.end_put();
        }
        printer.finish();
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
