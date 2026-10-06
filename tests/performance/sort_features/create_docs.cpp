// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <random>
#include <string>
#include <unistd.h>
#include <vector>

constexpr int num_buckets = 100;
constexpr int num_categories = 20;

/*
 * Generates a 'bucket' value in [0, 100) for each document such that each value is used
 * by (almost) exactly 1% of the documents, in random order. 'bucket < P' then matches
 * num_docs * P / 100 documents (exact when num_docs is divisible by 100).
 */
std::vector<int> make_buckets(int num_docs, int seed) {
    std::vector<int> result(num_docs);
    for (int i = 0; i < num_docs; ++i) {
        result[i] = i % num_buckets;
    }
    std::default_random_engine engine(seed);
    std::shuffle(result.begin(), result.end(), engine);
    return result;
}

void print_docs(int num_docs, const std::vector<int>& buckets, std::mt19937& engine) {
    std::uniform_int_distribution<int> year_dist(1950, 2025);
    std::lognormal_distribution<double> price_dist(4.0, 1.0);
    std::uniform_int_distribution<int> discount_dist(0, 10);
    std::exponential_distribution<double> popularity_dist(1.0 / 10000.0);
    std::uniform_int_distribution<int> rating_dist(10, 50);
    std::uniform_int_distribution<int> category_dist(0, num_categories - 1);
    printf("[\n");
    for (int doc_id = 0; doc_id < num_docs; ++doc_id) {
        if (doc_id > 0) {
            printf(",\n");
        }
        double price = std::max(0.01, std::round(price_dist(engine) * 100.0) / 100.0);
        printf("{\"put\":\"id:test:test::%d\",\"fields\":{", doc_id);
        printf("\"bucket\":%d,", buckets[doc_id]);
        printf("\"year\":%d,", year_dist(engine));
        printf("\"price\":%.2f,", price);
        printf("\"discount\":%.2f,", discount_dist(engine) * 0.05);
        printf("\"popularity\":%d,", (int)popularity_dist(engine));
        printf("\"rating\":%.1f,", rating_dist(engine) * 0.1);
        printf("\"category\":\"c%d\"", category_dist(engine));
        printf("}}");
    }
    printf("\n]\n");
}

/**
 * Generates small documents used for performance testing of sorting on rank features
 * (sort-features in the rank profile, sortspec=feature(name) in the query).
 *
 * Each document has:
 *   bucket:     uniform in [0, 100), used to select a percentage of the corpus
 *   year:       uniform in [1950, 2025]
 *   price:      log-normal (median ~55), two decimals
 *   discount:   one of 0.00, 0.05, ..., 0.50
 *   popularity: exponential with mean 10000
 *   rating:     one of 1.0, 1.1, ..., 5.0
 *   category:   one of "c0" .. "c19"
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
    auto buckets = make_buckets(num_docs, 1234);
    std::mt19937 engine(4321);
    print_docs(num_docs, buckets, engine);
    return 0;
}
