// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <sstream>

constexpr size_t STEP_LENGTH = 11;
void
doc(unsigned long num, unsigned long numValues) {
    unsigned long offset=num * numValues;
    std::stringstream os;
    os << '"' << offset << "\":" << 1;
    for (unsigned long i(1); i < numValues; i++) {
      os << ",\"" << ((offset + i) * STEP_LENGTH) << "\":" << 1;
    }
    std::string values = os.str();
 
    printf("{\"id\":\"id:test:test::%d\", \"fields\":{ \"id\":%lu, \"f1\":{%s}, \"s1\":{%s} } }", num, num, values.c_str(), values.c_str());
}

int
main(int argc, char **argv) {
    int i;
    int numDocs = atoi(argv[1]);
    int numValues = atoi(argv[2]);
    printf("[\n");
    for (i = 0; i < (numDocs-1); i++) {
        doc(i, numValues);
        printf(",\n");
    }
    doc(i, numValues);
    printf("\n]\n");
    return 0;
}
