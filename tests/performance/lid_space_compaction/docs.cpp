// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <string.h>
#include <assert.h>
#include <stdlib.h>

bool verify_usage(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << argv[0] << "<put|remove> <num docs>" << std::endl;
        return false;
    }
    return true;
}

void produce_puts(size_t numDocs);
void produce_removes(size_t numDocs, size_t cap);

/**
 * Generate puts/removes to use in lidspace compaction test
 **/

int main (int argc, char *argv[]) {
    if ( ! verify_usage(argc, argv) ) { return 1; }
    const size_t numDocs = strtoul(argv[2], nullptr, 0);
    if (std::string(argv[1]) == "remove") {
        produce_removes(numDocs, 2*numDocs);
    } else {
        produce_puts(numDocs);
    }
    return 0;
}

void produce_puts(size_t numDocs) {
    constexpr size_t num_unique = 100;
    constexpr size_t hits_per_query = 1000;
    constexpr size_t average_body_length = 500;
    const size_t num_unique_keys = numDocs/hits_per_query;

    std::vector<std::string> data;
    for (size_t i(0); i < num_unique; i++) {
        std::string s;
        for (size_t j(0); j < (average_body_length-50) + i; j++) {
            s += 'a' + (rand()%26);
        }
        data.push_back(s);
    }

    std::cout << "[" << std::endl;
    for (size_t i(0); i < numDocs; i++) {
        size_t key = i % num_unique_keys;
        char id[128];
        sprintf(id, "{ \"put\": \"id:test:test::%05ld\",\n \"fields\": {", i);
        std::cout << id;
        std::cout << " \"body\": \"" << data[rand()%num_unique] << "\",";
        std::cout << " \"id\": "  << i << ",";
        std::cout << " \"key\": " << key << ",";
        std::cout << " \"slowkey\": " << key;
        std::cout << " }" << std::endl;
        std::cout << "}";
        if (i < numDocs - 1) {
          std::cout << "," << std::endl;
        }
    }
    std::cout << std::endl << "]" << std::endl;
}

void produce_removes(size_t numDocs, size_t cap) {
    std::vector<size_t> ids;
    ids.reserve(cap);
    for (size_t i(0); i < cap; i++) {
        ids.push_back(i);
    }
    for (size_t i(0); i < numDocs; i++) {
        size_t index = rand() % ids.size();
        ids[index] = ids.back();
        ids.resize(ids.size() - 1);
    }
    std::cout << "[" << std::endl;
    for (size_t i : ids) {
        char id[128];
        sprintf(id, "{ \"remove\": \"id:test:test::%05ld\" }", i);
        std::cout << id;
        if (i < numDocs - 1) {
          std::cout << "," << std::endl;
        }
    }
    std::cout << std::endl << "]" << std::endl;
}

