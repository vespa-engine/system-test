// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <sstream>

void
query(const char * field, unsigned int keys_per_query, unsigned long upper_limit) {
    std::ostringstream keys;
    keys << "%22" << (rand()%upper_limit) << "%22%3A1";
    for (unsigned int i(1); i < keys_per_query; i++) {
        keys << ",%22" << (rand()%upper_limit) << "%22%3A1";
    }
    const char * queryPrefix = "/search/?summary=minimal&ranking=unranked&hits=1&yql=select%20*%20from%20sources%20*%20where%20weightedSet";
    printf("%s(%s,%7B%s%7D)%3B\n", queryPrefix, field, keys.str().c_str());
}

int
main(int argc, char **argv) {
    long numQueries = atoi(argv[1]);
    long keys_per_query = atoi(argv[2]);
    long upper_limit = atoi(argv[3]);
    const char * field = argv[4];
    srand(1);
    for (long i = 0; i < numQueries; i++) {
        query(field, keys_per_query, upper_limit);
    }
    return 0;
}
