// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdio>
#include <cstdlib>

int main(int, char **argv) {
    const unsigned int numDocs{static_cast<unsigned int>(atoi(argv[1]))};

    for (unsigned int i = 1; i <= numDocs; i++) {
        printf("/document/v1/doc/doc/docid/%u\n", i);
    }

    return 0;
}
