// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <iostream>
#include <numeric>
#include <random>
#include <unistd.h>
#include <vector>

constexpr int per_thousand = 1000;

/**
 * Class used to generate a set of values to be inserted into a subset of documents.
 *
 * When searching for range(my_field, LOWER, UPPER) this will match 'values_in_range'
 * unique values (or posting lists) and return the given number of 'hits'.
 *
 * LOWER = hits_ratio * 100000 + values_in_range
 * UPPER = LOWER + values_in_range
 */
class ValueGenerator {
private:
    int _hits_per_value;
    int _curr_value;
    int _i;
    int _doc_mod;
    int _doc_mod_bias;

public:
    ValueGenerator(int hits, int hits_ratio, int values_in_range, int doc_mod_bias)
        : _hits_per_value(hits / values_in_range),
          _curr_value(hits_ratio * 100000 + values_in_range),
          _i(0),
          _doc_mod(per_thousand / hits_ratio),
          _doc_mod_bias(doc_mod_bias % _doc_mod)
    {
    }
    bool use_doc(int doc_id) const {
        return (doc_id % _doc_mod) == _doc_mod_bias;
    }
    int next() {
        int result = _curr_value;
        if (++_i % _hits_per_value == 0) {
            ++_curr_value;
        }
        return result;
    }
};

using IntVector = std::vector<int>;
using ValueGeneratorVector = std::vector<ValueGenerator>;

ValueGeneratorVector make_generators(int num_docs, bool verbose) {
    ValueGeneratorVector result;
    // Specifies the amount of the corpus that will hit (per thousand) for a range query term.
    for (int ratio : {1, 10, 50, 100, 200, 500}) {
        int hits = ((size_t)num_docs * (size_t)ratio) / per_thousand;
        for (int values_in_range : {1, 10, 100, 1000, 10000}) {
            if (hits >= values_in_range) {
                result.emplace_back(hits, ratio, values_in_range, rand());
                if (verbose) {
                    printf("ValueGenerator(%d,%d,%d)\n", hits, ratio, values_in_range);
                }
            }
        }
    }
    return result;
}

void make_range_values(int doc_id, ValueGeneratorVector& gens) {
    bool first = true;
    for (auto& gen : gens) {
        if (gen.use_doc(doc_id)) {
            if (!first) {
                printf(",");
            }
            printf("%d", gen.next());
            first = false;
        }
    }
}

void make_filter(int doc_id) {
    bool first = true;
    // Specifies the amount of the corpus that will hit (per thousand) for a filter query term.
    for (int filter : {1, 10, 50, 100, 200, 500}) {
        if ((doc_id % per_thousand) < filter) {
            if (!first) {
                printf(",");
            }
            printf("%d", filter);
            first = false;
        }
    }
}

void make_docs(int num_docs, const IntVector& values_ids, const IntVector& filter_ids, ValueGeneratorVector& gens) {
    printf("[\n");
    for (int doc_id = 0; doc_id < num_docs; ++doc_id) {
        if (doc_id > 0) {
            printf(",\n");
        }
        printf("{\"put\":\"id:test:test::%d\",\"fields\":{\"id\":%d,\"values\":[", doc_id, doc_id);
        make_range_values(values_ids[doc_id], gens);
        printf("],\"filter\":[");
        make_filter(filter_ids[doc_id]);
        printf("]}}");
    }
    printf("\n]\n");
}

IntVector shuffled_ids(int num_docs, int seed) {
    IntVector result(num_docs);
    std::iota(result.begin(), result.end(), 0);
    std::default_random_engine engine(seed);
    std::shuffle(std::begin(result), std::end(result), engine);
    return result;
}

/**
 * This program generates documents used for performance testing of range search.
 *
 * The 'values' field is populated such that 30 different range queries can be used:
 *   - 6 catagories of queries return a subset of the corpus: 0.1%, 1%, 5%, 10%, 20%, 50%.
 *   - Each category supports 5 different amount of values in the range: 1, 10, 100, 1000, 10000.
 *     The documents are spread evenly across the unique values in such range.
 *
 * Examples:
 *   - range(values, 20000100, 20000200) returns 20% of the corpus, and has 100 values in the range.
 *   - range(values,  5001000,  5002000) returns 5% of the corpus, and has 1000 values in the range.
 * See ValueGenerator for more details.
 * Note: 10M documents are needed in order to support all combinations.
 *
 * The 'filter' field is populated such that a query filter term returns a subset of the corpus: 0.1%, 1%, 5%, 10%, 20%, 50%.
 */
int main(int argc, char *argv[]) {
    int num_docs = 10000;
    bool verbose = false;

    int option;
    while ((option = getopt(argc, argv, "d:v")) != -1) {
        switch (option) {
            case 'd':
                num_docs = std::stoi(optarg);
                break;
            case 'v':
                verbose = true;
                break;
            default:
                return 1;
        }
    }
    srand(1234);
    auto gens = make_generators(num_docs, verbose);
    make_docs(num_docs, shuffled_ids(num_docs, 1234), shuffled_ids(num_docs, 5678), gens);
    return 0;
}

