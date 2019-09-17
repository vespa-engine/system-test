#include <stdlib.h>
#include <stdio.h>

void header(int num) {
	printf("{\"id\":\"id:test:foobar::%d\", \"fields\":{", num);
	printf("\"title\":\"doc %d here\", ", num);
}

int pct() {
	return random() % 100;
}

void phrases() {
	printf("\"phrases\":\"case case case");
	if (pct() < 10) printf(" ten ten ten ten ten ten");
	if (pct() < 20) printf(" twenty twenty twenty twenty twenty");
	if (pct() < 30) printf(" thirty thirty thirty thirty thirty thirty thirty thirty thirty thirty");
	if (pct() < 40) printf(" forty forty forty forty forty forty forty forty forty forty");
	if (pct() < 50) printf(" fifty fifty fifty fifty fifty");
	if (pct() < 60) printf(" sixty sixty sixty sixty sixty sixty sixty sixty sixty sixty");
	if (pct() < 70) printf(" seventy seventy seventy seventy seventy");
	if (pct() < 80) printf(" eighty eighty eighty eighty eighty");
	if (pct() < 90) printf(" ninety ninety ninety ninety ninety");
	printf(" worst worst worst\", ");
}

void whitelist() {
	int i;
	printf("\"whitelist\":[");
	for (i = 0; i < 100; i += 10) {
		if (pct() < i) {
			printf("%d,", i);
		}
	}
	printf("100], ");
}

void footer(int num) {
	printf("\"order\":%d", num);
	printf("}},\n");
}

int main(int argc, char **argv) {
	int i;
	srandom(42);
	printf("[\n");
	for (i = 0; i < 123456; i++) {
		header(i);
		phrases();
		whitelist();
		footer(i);
	}
        printf("{\"id\":\"id:test:foobar::0\",\"fields\":{\"title\":\"0\", \"order\":0}}");
	printf("]\n");
	return 0;
}
