// Copyright Vespa.ai. All rights reserved.

#include <stdlib.h>
#include <stdio.h>

const double inv = 1.0 / RAND_MAX;

static int *histogram;

void header(int num)
{
        printf("{ \"put\": \"id:test:mpd::%d\",\n", num);
        printf("  \"fields\": { \"title\": \"the ");
	if ((random() % 100) <= 42) {
            printf("bar ");
        }
        printf("fox says ");
	if ((random() % 100) <= 24) {
            printf("foo ");
        }
        printf("hihi\",");
}

void footer(int num)
{
	double score = random() * .0009765625;
        score += num * .00000095367431640625;
        printf("\"order\": %.30g, ", score);
	printf("\"seq\": %d, ", num);
        printf("\"cat\": %d }\n}", (num / 1000));
}

void body(int docid, int numdocs, int numvals)
{
	int i;
	printf("\"body\": \"");
	for (i = 0; i <= numvals; i++) {
		int wantHits = (i * numdocs) / numvals;
		int gotHits = histogram[i];
		double needHits = wantHits - gotHits;
		double docsLeft = numdocs - docid;
		double r = random() * inv;
		if ((r * docsLeft) < needHits) {
                        histogram[i]++;
			printf(" %d", i);
		}
	}
        printf("\",");
}

int main(int argc, char **argv)
{
	int i;
	int documents = 100000;
	int values = 1000;
	if (argc > 1) { documents = atoi(argv[1]); }
	if (argc > 2) { values = atoi(argv[2]); }
	histogram = (int *)malloc((values+1) * sizeof(int));
	for (i = 0; i <= values; i++) {
		histogram[i] = 0;
	}
	srandom(42);
	printf("[\n");
	for (i = 0; i < documents; i++) {
		header(i);
		body(i, documents, values);
		footer(i);
                if (i < documents - 1) {
                  printf(",");
                }
	}
	printf("\n]");
/*      for (i = 0; i <= values; i++) { fprintf(stderr, "hist %d : %d\n", i, histogram[i]); }    */
	return 0;
}
