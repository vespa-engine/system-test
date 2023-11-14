// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdlib>
#include <cstdio>
#include <cassert>

/**
 * Generate puts/removes to use in lidspace compaction test
 **/

int main (int argc, char *argv[]) {
    assert(argc == 3);
    const size_t num_users = strtoul(argv[1], nullptr, 0);
    const size_t num_docs_per_user = strtoul(argv[2], nullptr, 0);
    printf("[\n");
    bool first = true;
    for (size_t i(0); i < num_users; i++) {
        for (size_t j(0); j < num_docs_per_user; j++) {
            printf("%s{\"id\":\"id:storage_test:music:n=%d:%d\", \"fields\":{\"title\": \"title%d\"}}\n", first ? "" : ",\n", i, j, i);
            first = false;
        }
    }
    printf("\n]\n");
    return 0;
}
