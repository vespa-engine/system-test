// Copyright Vespa.ai. All rights reserved.

#include <stdlib.h>
#include <stdio.h>

#define NUMDOCS 100000
#define NUMDIMS 512

int pct() {
	return random() % 100;
}

void header(int num) {
	printf("{\"id\":\"id:test:foobar::%d\", \"fields\":{", num);
	printf("\"title\":\"doc %d ", num);
	if (pct() < 10) printf(" ten");
	if (pct() < 50) printf(" fifty");
	if (pct() < 90) printf(" ninety");
	printf(" here\", ");
}

void vector() {
	int i;
	printf("\"dvector\": { \"values\": [ ");
	for (i = 0; i < NUMDIMS; ++i) {
		double dv = (random() % 1000000) * 0.0001;
		if (i != 0) printf(", ");
		printf("%.3f", dv);
	}
	printf("] }, ");
	printf("\"bvector\": { \"values\": [ ");
	for (i = 0; i < NUMDIMS/8; ++i) {
		char dv = (random() & 0xff);
		if (i != 0) printf(", ");
		printf("%d", dv);
	}
	printf("] }, ");
}

void footer(int num) {
	printf("\"order\":%d", num);
	printf("}},\n");
}

int main(int argc, char **argv) {
	int i;
	srandom(42);
	printf("[\n");
	for (i = 0; i < NUMDOCS; i++) {
		header(i);
		vector();
		footer(i);
	}
	printf("{\"id\":\"id:test:foobar::0\",\"fields\":{\"title\":\"0\", \"order\":0}}\n");
	printf("]\n");
	return 0;
}
