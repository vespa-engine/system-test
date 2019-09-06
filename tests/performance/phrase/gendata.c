#include <stdlib.h>
#include <stdio.h>

void header(int num) {
	printf("<document type='foobar' id='id:test:foobar::%d'>\n", num);
	printf("<title>doc %d here</title>\n", num);
}

int pct() {
	return random() % 100;
}

void phrases() {
	printf("<phrases>case");
	if (pct() < 10) printf(" ten");
	if (pct() < 20) printf(" twenty");
	if (pct() < 30) printf(" thirty");
	if (pct() < 40) printf(" forty");
	if (pct() < 50) printf(" fifty");
	if (pct() < 60) printf(" sixty");
	if (pct() < 70) printf(" seventy");
	if (pct() < 80) printf(" eighty");
	if (pct() < 90) printf(" ninety");
	printf(" worst</phrases>\n");
}

void whitelist() {
	int i;
	printf("<whitelist>\n");
	for (i = 0; i < 100; i += 10) {
		if (pct() < i) {
			printf("<item>%d</item>\n", i);
		}
	}
	printf("</whitelist>\n");
}

void footer(int num) {
	printf("<order>%d</order>\n", num);
	printf("</document>\n");
}

int main(int argc, char **argv) {
	int i;
	srandom(42);
	printf("<vespafeed>\n");
	for (i = 0; i < 123456; i++) {
		header(i);
		phrases();
		whitelist();
		footer(i);
	}
	printf("</vespafeed>\n");
	return 0;
}
