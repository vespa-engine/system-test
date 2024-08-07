// Copyright Vespa.ai. All rights reserved.

#include <cstdlib>
#include <cstdio>
#include <cstdint>

void
words(const char * name, uint32_t numElem, uint32_t numUniq) {
    printf("\"%s\":\"", name);
    for (uint32_t i(0); i < numElem; i++) {
        printf("word%u ", random() % numUniq);
    }
    printf("\",");
}

void
doc(const char * batch, uint32_t num, uint32_t numElem, uint32_t numUniq) {
    printf("{\"id\":\"id:ns:genfeed::%s%u\", \"fields\":{ ", batch, num);
    words("title", 5, numUniq);
    words("body", numElem, numUniq);
    printf("\"tag\":\"%s\",", batch);
    printf("\"seqno\":\"%u\",", num);
    printf("\"id\":\"%s%u\"", batch, num);
    printf(" } }");
}

int
main(int argc, char **argv) {
    uint32_t i(0);
    const char * batch = argv[1];
    uint32_t numDocs = atoi(argv[2]);
    uint32_t numElem = atoi(argv[3]);
    uint32_t numUniq = atoi(argv[4]);
    printf("[\n");
    for (; (i+1) < numDocs; i++) {
        doc(batch, i, numElem, numUniq);
        printf(",\n");
    }
    doc(batch, i, numElem, numUniq);
    printf("\n]\n");
    return 0;
}
