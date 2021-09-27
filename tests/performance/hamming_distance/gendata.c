// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <stdlib.h>
#include <stdio.h>

#define NUMDOCS 10000
#define NUMBYTES 16
#define NUMVECS 7

int pct() {
	return random() % 100;
}

void header(int num) {
	printf("{\"id\":\"id:test:hamming::%d\", \"fields\":{", num);
	printf("\"title\":\"doc %d ", num);
	if (pct() < 10) printf(" ten");
	if (pct() < 50) printf(" fifty");
	if (pct() < 90) printf(" ninety");
	printf(" here\", ");
}

void vector() {
	int i, j;
	printf("\"docvector\": { \"blocks\": { ");
	for (j = 0; j < NUMVECS; ++j) {
		if (j != 0) printf(", ");
		printf("\"v%d\": [ ", j);
		for (i = 0; i < NUMBYTES; ++i) {
			char dv = (random() & 0xff);
			if (i != 0) printf(", ");
			printf("%d", dv);
		}
		printf(" ]");
	}
	printf(" } }, ");
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
	printf("{\"id\":\"id:test:hamming::0\",\"fields\":{\"title\":\"0\", \"order\":0}}\n");
	printf("]\n");
	return 0;
}
