// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <iostream>
#include <random>
#include <string>
#include <vector>

bool verify_usage(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << argv[0] << " <batches> <dimension>" << std::endl;
        return false;
    }
    return true;
}

using IntVec = std::vector<uint32_t>;

void populate_ids(IntVec& ids, uint32_t num_users, uint32_t docs_per_user, uint32_t start_id) {
    for (size_t i = 0; i < num_users; ++i) {
        for (size_t j = 0; j < docs_per_user; ++j) {
            ids.push_back(start_id + i);
        }
    }
}

IntVec populate_ids(uint32_t batches) {
    IntVec ids;
    ids.reserve(500000 * batches);
    uint32_t id_range = 10000000;
    // One batch contains 500k documents, with 100k documents in each of the five categories:
    // 10, 100, 1000, 10000, and 100000 docs per user.
    populate_ids(ids, 10000 * batches, 10,     id_range);
    populate_ids(ids, 1000 * batches,  100,    id_range * 2);
    populate_ids(ids, 100 * batches,   1000,   id_range * 3);
    populate_ids(ids, 10 * batches,    10000,  id_range * 4);
    populate_ids(ids, 1 * batches,     100000, id_range * 5);
    return ids;
}

void gen_vector(size_t dimension) {
    for (size_t i = 0; i < dimension; i++) {
        float v = (rand() % 10000) / 10000.0;
        if (i > 0) {
            printf(",%f", v);
        } else {
            printf("%f", v);
        }
    }
}

void gen_put(uint32_t user_id, uint32_t doc_id, uint32_t dimension) {
    printf("{\"put\":\"id:test:test:n=%u:%u\",\"fields\":{\"id\":%u,\"embedding\":[", user_id, doc_id, doc_id);
    gen_vector(dimension);
    printf("]}}");
}

void gen_puts(const IntVec& ids, uint32_t dimension) {
    printf("[\n");
    for (size_t i = 0; i < ids.size(); i++) {
        uint32_t user_id = ids[i];
        if (i > 0) {
            printf(",\n");
        }
        gen_put(user_id, i, dimension);
    }
    printf("\n]\n");
}

int main(int argc, char *argv[]) {
    if (!verify_usage(argc, argv) ) {
        return 1;
    }
    uint32_t batches = strtoul(argv[1], nullptr, 0);
    uint32_t dimension = strtoul(argv[2], nullptr, 0);
    auto ids = populate_ids(batches);
    std::default_random_engine engine(1234);
    std::shuffle(std::begin(ids), std::end(ids), engine);
    srand(1234);
    gen_puts(ids, dimension);
    return 0;
}

