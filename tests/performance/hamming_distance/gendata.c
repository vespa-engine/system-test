// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

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

void gen_queries() {
	int i, j, v;
	for (i = 0; i < NUMDOCS; i++) {
		printf("/search/?query=title:doc&ranking.features.query(qvector)=%s", "%7B");
		for (j = 0; j < 4; ++j) {
			for (v = 0; v < 16; ++v) {
				if (j + v > 0) printf(",");
				char dv = random() & 0xff;
				printf("%s", "%7B");
				printf("question:n%d,x:%d", j, v);
				printf("%s:%d", "%7D", dv);
			}
		}
		printf("%s", "%7D");
		printf("\n");
	}
}

void gen_docs() {
	int i;
	printf("[\n");
	for (i = 0; i < NUMDOCS; i++) {
		header(i);
		vector();
		footer(i);
	}
	printf("{\"id\":\"id:test:hamming::0\",\"fields\":{\"title\":\"0\", \"order\":0}}\n");
	printf("]\n");
}

int main(int argc, char **argv) {
	srandom(42);
	if (argc == 2) {
		if (strcmp(argv[1], "queries") == 0) {
			gen_queries();
			return 0;
		} else if (strcmp(argv[1], "docs") == 0) {
			gen_docs();
			return 0;
		}
	}
	fprintf(stderr, "Usage: %s queries|docs\n", argv[0]);
	return 1;
}
