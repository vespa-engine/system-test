#include <stdlib.h>
#include <stdio.h>

void header(int num)
{
	printf("<document type='foobar' id='id:test:foobar::%d'>\n", num);
        printf("<title>doc %d here</title>\n", num);
}

void footer(int num)
{
	printf("<order>%d</order>\n", num);
	printf("</document>\n");
}

void matches(int num)
{
	int i;
	printf("<foo>\n");
	for (i = 0; i < num; i++) {
                if ((random() % 100) < 9) {
			printf("<item>%d</item>\n", i);
                }
	}
	printf("</foo>\n");
}

int main(int argc, char **argv)
{
	int i;
	srandom(42);
	printf("<vespafeed>\n");
	for (i = 0; i < 12345; i++) {
		header(i);
		matches(10000);
		footer(i);
	}
	printf("</vespafeed>\n");
	return 0;
}
