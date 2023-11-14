// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <stdlib.h>
#include <stdio.h>

const double inv = 1.0 / RAND_MAX;

static int *histogram;

void header(int num)
{
	printf("<document type='mpd' id='id:test:mpd::%d'>\n", num);
        printf("<title>the ");
	if ((random() % 100) <= 42) {
            printf("bar ");
        }
        printf("fox says ");
	if ((random() % 100) <= 24) {
            printf("foo ");
        }
        printf("hihi</title>\n");
}

void footer(int num)
{
	double score = random() * .0009765625;
        score += num * .00000095367431640625;
	printf("<order>%.30g</order>\n", score);
	printf("<seq>%d</seq>\n", num);
	printf("<cat>%d</cat>\n", (num / 1000));
	printf("</document>\n");
}

void body(int docid, int numdocs, int numvals)
{
	int i;
	printf("<body>\n");
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
	printf(" </body>\n");
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
	printf("<vespafeed>\n");
	for (i = 0; i < documents; i++) {
		header(i);
		body(i, documents, values);
		footer(i);
	}
	printf("</vespafeed>\n");
/*      for (i = 0; i <= values; i++) { fprintf(stderr, "hist %d : %d\n", i, histogram[i]); }    */
	return 0;
}
