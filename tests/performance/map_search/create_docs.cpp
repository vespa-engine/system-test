// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <random>
#include <string>
#include <unistd.h>
#include <vector>

using IntVector = std::vector<int>;

// One entry per map field. 'name' must match the field names in test.sd and the
// "kv_#{map_size}" names built in map_search.rb. 'exp_mean' is the mean of the
// exponential distribution used to draw the number of entries in the field.
struct MapField {
    const char* name;
    double exp_mean;
};
const std::vector<MapField> map_fields = {
    {"kv_5", 5.0},
    {"kv_25", 25.0},
    {"kv_125", 125.0},
};

// Must match @hits_ratios in map_search.rb. Used for the independent 'filter' field.
const IntVector hits_ratios = {1, 2, 4, 5, 6, 8, 10, 20, 40, 50, 60, 80, 100, 150, 200};

/*
 * Generates a 'bucket' value for each document such that querying for value 'R'
 * (one of the hits_ratios) matches num_docs * R / 1000 documents.
 *
 * Documents that are not assigned to any bucket get the value 0 (never queried).
 */
IntVector make_buckets(int num_docs) {
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

// Prints one map field. The number of entries is (1 + int(r)) where r is drawn from an
// exponential distribution with mean 'exp_mean'. Keys are "k0".."k{n-1}" and each value
// is drawn from a normal distribution (mean 1000, stddev 100).
void print_map(const char* name, double exp_mean, std::mt19937& engine) {
    std::exponential_distribution<double> size_dist(1.0 / exp_mean);
    std::normal_distribution<double> value_dist(1000.0, 100.0);
    int num_elems = 1 + (int)size_dist(engine);
    printf("\"%s\":{", name);
    for (int j = 0; j < num_elems; ++j) {
        printf("%s\"k%d\":%d", (j == 0 ? "" : ","), j, (int)std::lround(value_dist(engine)));
    }
    printf("}");
}

void print_docs(int num_docs, const IntVector& filter, std::mt19937& engine) {
    printf("[\n");
    for (int doc_id = 0; doc_id < num_docs; ++doc_id) {
        if (doc_id > 0) {
            printf(",\n");
        }
        printf("{\"put\":\"id:test:test::%d\",\"fields\":{", doc_id);
        for (const auto& map_field : map_fields) {
            print_map(map_field.name, map_field.exp_mean, engine);
            printf(",");
        }
        printf("\"filter\":%d", filter[doc_id]);
        printf("}}");
    }
    printf("\n]\n");
}

/**
 * This program generates documents used for performance testing of map search.
 *
 * Each document has three map<string,int> fields (kv_5, kv_25, kv_125). For each field the
 * number of entries is (1 + int(r)) where r is drawn from an exponential distribution with
 * mean 5, 25 and 125 respectively (matching the field name). Keys are "k0".."k{n-1}" and
 * each value is drawn from a normal distribution (mean 1000, stddev 100).
 *
 * The independent 'filter' field is populated so that 'filter = R' matches
 * num_docs * R / 1000 documents, for each R in @hits_ratios, and can be AND-combined with
 * map key queries.
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
    auto filter = make_buckets(num_docs);
    shuffle(filter, 5678);
    std::mt19937 engine(9999);
    print_docs(num_docs, filter, engine);
    return 0;
}
