// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

const std::set<std::string> FILTER_QUERY_OPTIONS = {"filter-value", "ranked-clusters", "doc-clusters", "num-docs", "cluster-field", "selection", "target-fraction"};

const std::string FILTER_QUERY_OPTIONS_USAGE =
    "Filter uncorrelated with the query vectors (see --filter-values of the document generator):\n"
    "  --filter-value <v>         Adds 'filter=v' to each query\n"
    "\n"
    "Filter correlated with the query vectors, restricting each query to the closest (positive correlation) or farthest (negative correlation)\n"
    "clusters of its query vector with '<cluster-field> in (c_1,...,c_n)'. Clusters are selected until they contain at least\n"
    "the target fraction of the documents, such that all queries have about the same selectivity:\n"
    "  --ranked-clusters <file>   .ivecs file with all clusters of each query vector, closest first (int32 n, n int32 clusters),\n"
    "                             as written by rank_query_clusters.py\n"
    "  --doc-clusters <file>      .ivecs file with the cluster of each document (int32 1, int32 cluster), for the cluster sizes\n"
    "  --num-docs <n>             Number of documents fed, only the clusters of the first n documents are counted (default: all)\n"
    "  --cluster-field <name>     Name of the int field with the cluster of each document\n"
    "  --selection <selection>    closest or farthest\n"
    "  --target-fraction <f>      Fraction of the documents in the selected clusters, in (0, 1]\n";

const std::string USAGE =
    "Usage: {program} --vectors <file> --tensor-field <name> [options] > queries.txt\n"
    "\n"
    "Prints one nearestNeighbor query (URL) per query vector for the documents of make_filtered_docs, with a filter uncorrelated\n"
    "with the query vectors and/or a filter restricting each query to the closest or farthest clusters of its query vector.\n"
    "\n"
    "Options:\n" + QUERY_OPTIONS_USAGE +
    "\n" + FILTER_QUERY_OPTIONS_USAGE +
    "\n"
    "Examples:\n"
    "  {program} --vectors queries.fvecs --tensor-field embedding --filter-value 90 > queries_uncorrelated.txt\n"
    "  {program} --vectors queries.fvecs --tensor-field embedding --ranked-clusters ranked_fine.ivecs --doc-clusters clusters_fine.ivecs \\\n"
    "    --cluster-field cluster_fine --selection closest --target-fraction 0.01 > queries_positive.txt\n";

/**
 * Selects the closest or farthest clusters of each query vector until they contain at least the target fraction of the documents.
 */
class ClusterSelection {
    std::string _field;
    bool _farthest;
    std::vector<size_t> _sizes; // Number of documents per cluster
    size_t _num_docs = 0;
    double _target_docs;
    IntRecordReader _ranked;
    std::string _selection;
    size_t _num_queries = 0;
    size_t _min_clusters = SIZE_MAX, _max_clusters = 0, _sum_clusters = 0;
    double _min_fraction = 1.0, _max_fraction = 0.0, _sum_fraction = 0.0;

public:
    explicit ClusterSelection(const Args& args)
        : _field(args.get("cluster-field")),
          _farthest(args.get("selection") == "farthest"),
          _sizes(),
          _target_docs(0.0),
          _ranked(args.get("ranked-clusters")),
          _selection(args.get("selection"))
    {
        if (_selection != "closest" && _selection != "farthest") {
            args.fail("--selection must be 'closest' or 'farthest', not '" + _selection + "'");
        }
        double target_fraction = args.get_number<double>("target-fraction");
        if (!(target_fraction > 0.0 && target_fraction <= 1.0)) {
            args.fail("--target-fraction must be in (0, 1]");
        }
        size_t num_docs_limit = args.get_number<size_t>("num-docs", SIZE_MAX);
        std::string doc_clusters = args.get("doc-clusters");
        IntRecordReader reader(doc_clusters);
        IntVector record;
        while (_num_docs < num_docs_limit && reader.read(record)) {
            if (record.size() != 1 || record[0] < 0) {
                throw std::runtime_error("Invalid record " + std::to_string(_num_docs) + " in '" + doc_clusters + "'");
            }
            if (static_cast<size_t>(record[0]) >= _sizes.size()) {
                _sizes.resize(record[0] + 1, 0);
            }
            ++_sizes[record[0]];
            ++_num_docs;
        }
        if (num_docs_limit != SIZE_MAX && _num_docs < num_docs_limit) {
            throw std::runtime_error("'" + doc_clusters + "' contains only " + std::to_string(_num_docs) + " documents, not " + std::to_string(num_docs_limit));
        }
        if (_num_docs == 0) {
            throw std::runtime_error("'" + doc_clusters + "' contains no documents");
        }
        _target_docs = target_fraction * _num_docs;
    }

    /**
     * Selects the clusters for the next query and prints the condition. Empty clusters are skipped.
     */
    void print(std::ostream& os) {
        IntVector ranking;
        if (!_ranked.read(ranking)) {
            throw std::runtime_error("Could not read the clusters of query " + std::to_string(_num_queries) + ", the file with the ranked clusters is too short");
        }
        IntVector selected;
        size_t selected_docs = 0;
        for (size_t i = 0; i < ranking.size() && selected_docs < _target_docs; ++i) {
            int cluster = ranking[_farthest ? ranking.size() - 1 - i : i];
            size_t size = (cluster >= 0 && static_cast<size_t>(cluster) < _sizes.size()) ? _sizes[cluster] : 0;
            if (size > 0) {
                selected.push_back(cluster);
                selected_docs += size;
            }
        }
        os << SPACE << "and" << SPACE << _field << SPACE << "in" << SPACE << "(";
        for (size_t i = 0; i < selected.size(); ++i) {
            os << (i > 0 ? "," : "") << selected[i];
        }
        os << ")";

        double fraction = static_cast<double>(selected_docs) / _num_docs;
        ++_num_queries;
        _min_clusters = std::min(_min_clusters, selected.size());
        _max_clusters = std::max(_max_clusters, selected.size());
        _sum_clusters += selected.size();
        _min_fraction = std::min(_min_fraction, fraction);
        _max_fraction = std::max(_max_fraction, fraction);
        _sum_fraction += fraction;
    }

    void print_stats(std::ostream& os) const {
        if (_num_queries == 0) {
            return;
        }
        os << "Selected the " << _selection << " clusters for " << _num_queries << " queries: "
           << "clusters per query min " << _min_clusters << ", max " << _max_clusters << ", mean " << static_cast<double>(_sum_clusters) / _num_queries << "; "
           << "fraction of documents min " << _min_fraction << ", max " << _max_fraction << ", mean " << _sum_fraction / _num_queries << std::endl;
    }
};

int
main(int argc, char** argv)
{
    Args args(argc, argv, USAGE, QUERY_OPTIONS + FILTER_QUERY_OPTIONS, QUERY_FLAGS);
    try {
        VectorFileReader vectors(args.get("vectors"));
        size_t num_queries = vectors.check_num(args, "num-queries");
        if (args.flag("vectors-only")) {
            print_vectors(std::cout, vectors, num_queries);
            return 0;
        }

        NearestNeighbor nns = get_nearest_neighbor(args);
        args.require_all_or_none({"ranked-clusters", "doc-clusters", "cluster-field", "selection", "target-fraction"});
        if (args.has("num-docs") && !args.has("doc-clusters")) {
            args.fail("--num-docs can only be used with the options for correlated filters");
        }
        std::optional<int> filter_value;
        if (args.has("filter-value")) {
            filter_value = args.get_number<int>("filter-value");
        }
        std::optional<ClusterSelection> clusters;
        if (args.has("ranked-clusters")) {
            clusters.emplace(args);
        }
        FloatVector vector;
        for (size_t i = 0; i < num_queries; ++i) {
            vectors.read(vector);
            print_query_begin(std::cout, nns);
            if (filter_value) {
                std::cout << SPACE << "and" << SPACE << "filter" << EQ << *filter_value;
            }
            if (clusters) {
                clusters->print(std::cout);
            }
            print_query_end(std::cout, vector);
        }
        if (clusters) {
            clusters->print_stats(std::cerr);
        }
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
