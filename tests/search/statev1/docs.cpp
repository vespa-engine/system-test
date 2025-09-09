// Copyright Vespa.ai. All rights reserved.

#include <cstdlib>
#include <cstdio>
#include <cassert>
#include <sstream>

/**
 * Generate puts to use in initialization test
 **/

 static constexpr float HI = 100.0f;
 static constexpr float LO = -100.0f;

std::string random_vector(size_t num_dimensions) {
    std::stringstream ss;

    ss << '[';
    bool first = true;
    for (size_t j(0); j < num_dimensions; j++) {
        ss << (first ? "" : ", ") << LO + static_cast <float> (rand()) /( static_cast <float> (RAND_MAX/(HI-LO)));
        first = false;
    }
    ss << ']';

    return ss.str();
}

int main (int argc, char *argv[]) {
    assert(argc == 3);
    const size_t num_documents = strtoul(argv[1], nullptr, 0);
    const size_t num_dimensions = strtoul(argv[2], nullptr, 0);
    std::srand(42);

    printf("[\n");
    bool first = true;
    for (size_t i(0); i < num_documents; i++) {
        printf("%s{\"id\":\"id:reprocessing:reprocessing::%d\", \"fields\":{\"int_field\": %d, \"string_field\": \"title%d\", \"tensor_field\": {\"values\": %s}}}", first ? "" : ",\n", i, i, i, random_vector(num_dimensions).c_str());
        first = false;
    }
    printf("\n]\n");
    return 0;
}
