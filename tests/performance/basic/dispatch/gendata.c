#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

void header(int num)
{
	printf("{ \"put\": \"id:test:foobar::%d\",\n", num);
        printf("  \"fields\": { \"title\": \"doc %d here\",\n", num);
}

void footer(int num)
{
	printf("    \"order\": %d }\n}\n", num);
}

void matches(int num)
{
	int i;
        bool firstElement = true;
	printf("    \"foo\": [");
	for (i = 0; i < num; i++) {
                if ((random() % 100) < 9) {
                        if (firstElement) {
                                firstElement = false;
                        } else {
                                printf(",");
                        }
                        printf("%d", i);

                }
	}
	printf("],\n");
}

int main(int argc, char **argv)
{
	int i;
	srandom(42);
	printf("[\n");
	for (i = 0; i < 12345; i++) {
		header(i);
		matches(10000);
		footer(i);
                if (i < 12344) {
                        printf(",");
                }
	}
	printf("]\n");
	return 0;
}
