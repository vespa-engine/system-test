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

    std::cout << "<?xml version=\"1.0\" encoding=\"utf-8\" ?>" << std::endl;
    std::cout << "<vespafeed>" << std::endl;
    for (size_t i(0); i < numDocs; i++) {
        size_t key = i % num_unique_keys;
        char id[128];
        sprintf(id, "id:test:test::%05ld", i);
        std::cout << "<document documenttype=\"test\" documentid=\"" << id << "\">\n"; 
        std::cout << "  <body>" << data[rand()%num_unique] << "</body>\n";
        std::cout << "  <id>" << i << "</id>\n";
        std::cout << "  <key>" << key << "</key>\n";
        std::cout << "  <slowkey>" << key << "</slowkey>\n";
        std::cout << "</document>\n";
    }
    std::cout << "</vespafeed>" << std::endl;
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
    std::cout << "<?xml version=\"1.0\" encoding=\"utf-8\" ?>" << std::endl;
    std::cout << "<vespafeed>" << std::endl;
    for (size_t i : ids) {
        char id[128];
        sprintf(id, "id:test:test::%05ld", i);
        std::cout << "<remove documentid=\"" << id << "\" />\n"; 
    }
    std::cout << "</vespafeed>" << std::endl;
}

