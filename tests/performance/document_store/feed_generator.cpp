// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <cstdio>
#include <cstdlib>
#include <cstring>

void randomString(unsigned int stringSize) {
    const char alnum[] =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    printf("\"");
    for (unsigned int i = 0; i < stringSize; i++) {
        printf("%c", alnum[rand() % 62]);
    }
    printf("\"");
}

void content(unsigned int contentLength) {
    printf("\"content\": ");
    randomString(contentLength);
}

void doc(unsigned int id, unsigned int contentLength) {
    printf("{\"put\": \"id:doc:doc::%u\", \"fields\": { ", id);
    printf("\"doc_id\": %u, ", id);
    content(contentLength);
    printf(" } }");
}

int main(int, char **argv) {
    const unsigned int numDocs{static_cast<unsigned int>(atoi(argv[1]))};
    const unsigned int contentLengths{static_cast<unsigned int>(atoi(argv[2]))};

    srand(7);
    printf("[\n");
    for (unsigned int i = 1; i < numDocs; i++) {
        doc(i, contentLengths);
        printf(",\n");
    }
    doc(numDocs, contentLengths);
    printf("\n]\n");
    return 0;
}
