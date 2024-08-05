// Copyright Vespa.ai. All rights reserved.
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

        printf("{ \"put\": \"id:test:sad::%d\",\n", num);
        printf("  \"fields\": { \"title\": \"the ");
	if ((random() % 100) <= 42) {
            printf("bar ");
        }
        printf("fox says ");
	if ((random() % 100) <= 24) {
            printf("foo ");
        }
        printf("hihi\",\n");
}

void footer(int num)
{
	printf("\"order\": %d }", num);
}

void impressions(int num)
{
	int i;
	int entries = random() % 128;
	histogram[entries]++;
	printf("\"pos%dimpr\": [", num);
	for (i = 0; i < entries; i++) {
		printf("%.6f", nextDouble(i, entries));
                if (i < entries - 1) {
                        printf(",");
                }
	}
	printf("],\n", num);
}

int main(int argc, char **argv)
{
	int i;
	srandom(42);
	printf("[\n");
	for (i = 0; i < 123456; i++) {
		header(i);
		impressions(1);
		impressions(2);
		footer(i);
                printf("}");
                if (i < 123455) {
                  printf(",\n");
                }
	}
	printf("\n]");
	return 0;
}
