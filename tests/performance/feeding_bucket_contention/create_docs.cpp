// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <iostream>
#include <random>
#include <string>
#include <vector>
#include <utility>
#include <unistd.h>

void gen_put(uint32_t user_id, size_t doc_id) {
    printf("{\"put\":\"id:test:test:g=%u:%zu\",\"fields\":{\"id\":%zu}}", user_id, doc_id, doc_id);
}

int main(int argc, char* argv[]) {
    int seed = 1234;
    bool shuffle = false;
    uint32_t locations = 0;
    uint32_t docs_per_location = 0;

    int option;
    // Note: opt parsing has signed-ness mismatch, but we trust the input to be non-negative.
    while ((option = getopt(argc, argv, "n:d:sh")) != -1) {
        switch (option) {
        case 'n':
            locations = std::stoi(optarg);
            break;
        case 'd':
            docs_per_location = std::stoi(optarg);
            break;
        case 's':
            shuffle = true;
            break;
        case 'h':
            std::cerr << argv[0] << " -s (shuffle) -h (help) -n <location count> -d <docs per location>" << std::endl;
            return 1;
        default:
            return 1;
        }
    }
    if (locations == 0 || docs_per_location == 0) {
        std::cerr << "Must specify at least 1 location with 1 document" << std::endl;
        return 1;
    }
    using LocationAndDocId = std::pair<uint32_t, size_t>;
    std::vector<LocationAndDocId> docs;
    docs.reserve(locations * docs_per_location);
    for (uint32_t loc = 0; loc < locations; ++loc) {
        for (uint32_t doc = 0; doc < docs_per_location; ++doc) {
            // Let doc ID itself be distinct also _across_ locations
            docs.emplace_back(loc, (loc * docs_per_location) + doc);
        }
    }
    if (shuffle) {
        std::default_random_engine engine(seed);
        std::shuffle(std::begin(docs), std::end(docs), engine);
    }
    printf("[\n");
    for (size_t i = 0; i < docs.size(); ++i) {
        if (i > 0) {
            printf(",\n");
        }
        gen_put(docs[i].first, docs[i].second);
    }
    printf("\n]\n");
    return 0;
}

