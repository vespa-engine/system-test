// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <iostream>
#include <random>
#include <string>
#include <unistd.h>
#include <vector>

using IntVec = std::vector<int>;

size_t calc_total_docs(const IntVec& spec) {
    size_t res = 0;
    for (size_t i = 0; i < spec.size(); i += 2) {
        res += spec[i] * spec[i + 1];
    }
    return res;
}

void populate_ids_for_batch(IntVec& ids, int num_users, int docs_per_user, int start_id) {
    for (size_t i = 0; i < num_users; ++i) {
        for (size_t j = 0; j < docs_per_user; ++j) {
            ids.push_back(start_id + i);
        }
    }
}

IntVec populate_user_ids(const IntVec& spec, size_t total_docs, int parts, int part_id) {
    IntVec ids;
    size_t docs_per_part = total_docs / parts;
    ids.reserve(docs_per_part);
    int user_id_range = 10000000;
    int batch = 1;
    for (size_t i = 0; i < spec.size(); i += 2) {
        int docs_per_user = spec[i];
        int num_users = spec[i + 1];
        int users_per_part = num_users / parts;
        int start_user_id = (user_id_range * batch) + (users_per_part * part_id);
        populate_ids_for_batch(ids, users_per_part, docs_per_user, start_user_id);
        ++batch;
    }
    return ids;
}

void gen_vector(size_t dimension) {
    for (size_t i = 0; i < dimension; i++) {
        float v = (rand() % 100000) / 100000.0;
        if (i > 0) {
            printf(",%f", v);
        } else {
            printf("%f", v);
        }
    }
}

void gen_put(int user_id, size_t doc_id, int dimension) {
    printf("{\"put\":\"id:test:test:n=%u:%zu\",\"fields\":{\"id\":%u,\"embedding\":[", user_id, doc_id, doc_id);
    gen_vector(dimension);
    printf("]}}");
}

void gen_puts(const IntVec& user_ids, size_t start_doc_id, int dimension) {
    printf("[\n");
    for (size_t i = 0; i < user_ids.size(); i++) {
        int user_id = user_ids[i];
        size_t doc_id = start_doc_id + i;
        if (i > 0) {
            printf(",\n");
        }
        gen_put(user_id, doc_id, dimension);
    }
    printf("\n]\n");
}

int main(int argc, char *argv[]) {
    int dimension = 1;
    int parts = 1;
    int part_id = 0;
    int seed = 1234;
    bool shuffle = true;

    int option;
    while ((option = getopt(argc, argv, "d:p:i:ho")) != -1) {
        switch (option) {
            case 'd':
                dimension = std::stoi(optarg);
                break;
            case 'p':
                parts = std::stoi(optarg);
                break;
            case 'i':
                part_id = std::stoi(optarg);
                break;
            case 'o':
                shuffle = false;
                break;
            case 'h':
                std::cerr << argv[0] << " -o (ordered by user id) -h (help) -d <dimension> -p <parts> -i <part_id> <user batch spec>" << std::endl;
                std::cerr << "The user batch spec is a list of {docs_per_user, num_users} pairs." << std::endl;
                std::cerr << "Example: -d 128 -p 2 -i 0 10 2000 100 50" << std::endl;
                std::cerr << "    Where 2000 users have 10 documents each, and 50 users have 100 documents each." << std::endl;
                std::cerr << "    In total 25000 documents, where this invocation generates part 0 (of 2 in total)." << std::endl;
                return 1;
            default:
                return 1;
        }
    }
    if ((argc - optind) % 2 != 0) {
        std::cerr << "The user batch spec is malformed" << std::endl;
        return 1;
    }
    IntVec spec;
    for (int i = optind; i < argc; ++i) {
        spec.push_back(std::stoi(argv[i]));
    }
    for (size_t i = 0; i < spec.size(); i += 2) {
        int docs_per_user = spec[i];
        int num_users = spec[i + 1];
        if (num_users % parts != 0) {
            std::cerr << "Number of users in {" << docs_per_user << "," << num_users << "} cannot be evenly split into parts (" << parts << ")" << std::endl;
            return 1;
        }
    }

    size_t total_docs = calc_total_docs(spec);
    auto user_ids = populate_user_ids(spec, total_docs, parts, part_id);
    if (shuffle) {
        std::default_random_engine engine(seed);
        std::shuffle(std::begin(user_ids), std::end(user_ids), engine);
    }
    srand(seed);
    size_t start_doc_id = (total_docs / parts) * part_id;
    gen_puts(user_ids, start_doc_id, dimension);
    return 0;
}

