// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <sstream>

std::string
create_keys(unsigned long offset, unsigned long numKeys) {
    std::stringstream os;
    os << '"' << offset << "\":" << 1;
    for (unsigned long i(1); i < numKeys; i++) {
      os << ",\"" << (offset + i) << "\":" << 1;
    }
    return os.str();
}

template<typename T>
std::string
create_values(unsigned long numValues) {
    std::stringstream os;
    os << long(T(random()));
    for (unsigned long i(1); i < numValues; i++) {
      os << ',' << long(T(random()));
    }
    return os.str();
}

void
doc(unsigned long num, unsigned long numKeys, unsigned long numBytes) {
    std::string keys = create_keys(num * numKeys, numKeys);
    std::string bytes = create_values<int8_t>(numBytes);
    std::string longs = create_values<int64_t>((numBytes + (sizeof(long) - 1))/sizeof(long));

    printf("{\"id\":\"id:test:test::%d\", \"fields\":{"
           "    \"id\":%lu,"
           "    \"f1\":{%s},"
           "    \"s1\":{%s},"
           "    \"payload_array_byte\":[%s],"
           "    \"payload_array_long\":[%s]"
           " } }",
           num, num, keys.c_str(), keys.c_str(), bytes.c_str(), longs.c_str());
}

int
main(int argc, char **argv) {
    int i;
    int numDocs = atoi(argv[1]);
    int numKeys = atoi(argv[2]);
    int numBytes = atoi(argv[3]);
    printf("[\n");
    for (i = 0; i < (numDocs-1); i++) {
        doc(i, numKeys, numBytes);
        printf(",\n");
    }
    doc(i, numKeys, numBytes);
    printf("\n]\n");
    return 0;
}
