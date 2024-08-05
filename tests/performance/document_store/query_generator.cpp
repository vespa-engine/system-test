// Copyright Vespa.ai. All rights reserved.

#include <cstdio>
#include <cstdlib>

int main(int, char **argv) {
    const unsigned int numDocs{static_cast<unsigned int>(atoi(argv[1]))};
    const unsigned int queryType{static_cast<unsigned int>(atoi(argv[2]))};

    if (queryType == 0) {
        for (unsigned int i = 1; i <= numDocs; i++) {
            printf("/document/v1/doc/doc/docid/%u\n", i);
        }
    } else if (queryType == 1) {
        for (unsigned int i = 1; i <= numDocs; i++) {
            printf("/search/?query=doc_id:%u\n", i);
        }
    }

    return 0;
}
