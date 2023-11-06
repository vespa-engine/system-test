// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <cassert>
#include <iostream>
#include <numeric>
#include <random>
#include <unistd.h>
#include <vector>

using IntVector = std::vector<int>;

const IntVector hits_ratios = {1, 2, 4, 5, 6, 8, 10, 20, 40, 50, 60, 80, 100, 150, 200};

/*
 * Generates the set of values to be inserted into a field.
 *
 * When searching for range(my_field, LOWER, UPPER) this will match 'values_in_range'
 * unique values (or posting lists) and return a number of hits given by the 'hits_ratio'.
 *
 * LOWER = hits_ratio * 100000 + values_in_range
 * UPPER = LOWER + values_in_range
 */
IntVector make_range_values(int num_docs, int values_in_range) {
    IntVector result(num_docs, 0);
    int i = 0;
    for (int hits_ratio : hits_ratios) {
        int hits = ((size_t)num_docs * (size_t)hits_ratio) / 1000;
        if (hits >= values_in_range) {
            int hits_per_value = hits / values_in_range;
            int value = hits_ratio * 100000 + values_in_range;
            for (int j = 0; j < hits; ++j) {
                result[i++] = value;
                if ((j + 1) % hits_per_value == 0) {
                    ++value;
                }
            }
        }
    }
    assert(i <= num_docs);
    return result;
}

IntVector make_filter(int num_docs) {
    IntVector result(num_docs, 0);
    int i = 0;
    for (int hits_ratio : hits_ratios) {
        int hits = ((size_t)num_docs * (size_t)hits_ratio) / 1000;
        for (int j = 0; j < hits; ++j) {
            result[i++] = hits_ratio;
        }
    }
    assert(i <= num_docs);
    return result;
}

void shuffle(IntVector& vector, int seed) {
    std::default_random_engine engine(seed);
    std::shuffle(vector.begin(), vector.end(), engine);
}

using RangeValuesData = std::vector<std::pair<int, IntVector>>;

RangeValuesData make_range_values_data(int num_docs) {
    RangeValuesData result;
    for (int values_in_range : {1, 10, 100, 1000, 10000}) {
        auto values = make_range_values(num_docs, values_in_range);
        shuffle(values, 1234);
        result.emplace_back(values_in_range, std::move(values));
    }
    return result;
}

void print_docs(int num_docs, const RangeValuesData& values, const IntVector& filter) {
    printf("[\n");
    for (int doc_id = 0; doc_id < num_docs; ++doc_id) {
        if (doc_id > 0) {
            printf(",\n");
        }
        printf("{\"put\":\"id:test:test::%d\",\"fields\":{", doc_id);
        for (const auto& elem : values) {
            printf("\"v_%d\":%d,", elem.first, elem.second[doc_id]);
        }
        printf("\"filter\":%d", filter[doc_id]);
        printf("}}");
    }
    printf("\n]\n");
}

/**
 * This program generates documents used for performance testing of range search.
 *
 * The 'v_%d' and 'v_%d_fs' fields (10 in total) are populated such that 30 different range queries can be used:
 *   - Each field uses a given number of unique values in a range: 1, 10, 100, 1000, 10000.
 *   - Each field supports 6 catagories of queries that each return a subset of the corpus: 0.1%, 1%, 5%, 10%, 20%, 50%.
 *
 * Examples:
 *   - range(v_100,  20000100, 20000200) returns 20% of the corpus, and has 100 values in the range.
 *   - range(v_1000,  5001000,  5002000) returns 5% of the corpus, and has 1000 values in the range.
 *
 * See make_range_values() for more details.
 * Note: 10M documents are needed in order to support all combinations.
 *
 * The 'filter' field is populated such that a query filter term returns a subset of the corpus: 0.1%, 1%, 5%, 10%, 20%, 50%.
 */
int main(int argc, char *argv[]) {
    int num_docs = 10000;

    int option;
    while ((option = getopt(argc, argv, "d:")) != -1) {
        switch (option) {
            case 'd':
                num_docs = std::stoi(optarg);
                break;
            default:
                return 1;
        }
    }
    auto values = make_range_values_data(num_docs);
    auto filter = make_filter(num_docs);
    shuffle(filter, 5678);
    print_docs(num_docs, values, filter);
    return 0;
}

