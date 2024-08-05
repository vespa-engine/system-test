// Copyright Vespa.ai. All rights reserved.

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <sstream>

void
query(unsigned int keys_per_query, unsigned long upper_limit) {
    std::ostringstream keys;
    keys << (rand()%upper_limit) << "%3A1";
    for (unsigned int i(1); i < keys_per_query; i++) {
        keys << "," << (rand()%upper_limit) << "%3A1";
    }
    printf("/search/?wand.tokens=%7B%s%7D\n", keys.str().c_str());
}

int
main(int argc, char **argv) {
    long numQueries = atoi(argv[1]);
    long keys_per_query = atoi(argv[2]);
    long upper_limit = atoi(argv[3]);
    srand(1);
    for (long i = 0; i < numQueries; i++) {
        query(keys_per_query, upper_limit);
    }
    return 0;
}
