// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#include <stdlib.h>
#include <stdio.h>

const double inv = 123456789.0 / RAND_MAX;

void header(int num)
{
    printf("<document type='covtest' id='id:test:covtest::%d'>\n", num);
    printf("<title>the coverage %d test</title>\n", num);
}

void footer(int num)
{
    // TODO Avoid randomness to make matchphase limiting more predictable.
    double score = random() * inv;
    printf("<sortlimnum>%d</sortlimnum>\n", (int)score);
    score = random() * inv * 0.001;
    printf("<weight>%f</weight>\n", score);
    printf("</document>\n");
}

int main(int argc, char **argv)
{
    int i;
    int documents = 100000;
    if (argc > 1) { documents = atoi(argv[1]); }
    srandom(42);
    printf("<vespafeed>\n");
    for (i = 0; i < documents; i++) {
        header(i);
        footer(i);
    }
    printf("</vespafeed>\n");
    return 0;
}
