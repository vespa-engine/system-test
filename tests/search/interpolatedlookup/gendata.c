// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#include <stdlib.h>
#include <stdio.h>

const double inv = 1.0 / RAND_MAX;

static int histogram[256];

static double nextDouble(double iter, double entries)
{
	long rv1 = random();
	double d = rv1;
	d *= inv;
	d /= (2*entries+1);
	d += iter / entries;
	return d;
}

void header(int num)
{
	printf("<document type='sad' id='id:test:sad::%d'>\n", num);
        printf("<title>the ");
	if ((random() % 100) <= 42) {
            printf("bar ");
        }
        printf("fox says ");
	if ((random() % 100) <= 24) {
            printf("foo ");
        }
        printf("hihi</title>");
}

void footer(int num)
{
	printf("<order>%d</order>\n", num);
	printf("</document>\n");
}

void impressions(int num)
{
	int i;
	int entries = random() % 128;
	histogram[entries]++;
	printf("<pos%dimpr>\n", num);
	for (i = 0; i < entries; i++) {
		printf("<item>");
		printf("%.6f", nextDouble(i, entries));
		printf("</item>\n");
	}
	printf("</pos%dimpr>\n", num);
}

int main(int argc, char **argv)
{
	int i;
	srandom(42);
	printf("<vespafeed>\n");
	for (i = 0; i < 123456; i++) {
		header(i);
		impressions(1);
		impressions(2);
		footer(i);
	}
	printf("</vespafeed>\n");
/*
	for (i = 0; i < 129; i++) {
		fprintf(stderr, "hist %d: %d\n", i, histogram[i]);
	}
*/
	return 0;
}
