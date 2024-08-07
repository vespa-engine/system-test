// Copyright Vespa.ai. All rights reserved.
#include <stdlib.h>
#include <stdio.h>

const double inv = 123456789.0 / RAND_MAX;

void header(int num)
{
    printf("{ \"put\": \"id:test:covtest::%d\",\n", num);
    printf("  \"fields\": { \"title\": \"the coverage %d test\",", num);
}

void footer(int num)
{
    // TODO Avoid randomness to make matchphase limiting more predictable.
    double score = random() * inv;
    printf("\"sortlimnum\": %d, ", (int)score);
    score = random() * inv * 0.001;
    printf("\"weight\": %f }\n}", score);
}

int main(int argc, char **argv)
{
    int i;
    int documents = 100000;
    if (argc > 1) { documents = atoi(argv[1]); }
    srandom(42);
    printf("[\n");
    for (i = 0; i < documents; i++) {
        if (i > 0) {
          printf(",\n");
        }
        header(i);
        footer(i);
    }
    printf("]");
    return 0;
}
