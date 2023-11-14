// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#include <stdlib.h>
#include <stdio.h>

void header(int num)
{
	printf("<document type='simple' id='id:test:simple::%d'>\n", num);
        printf(" <title>foobar %d foobar</title> ", num);
}

void descriptions(int cnt)
{
	int i;
	printf("<description>");
	for (i = 0; i < cnt; i++) {
		printf("foobar %d ", 1234567 - i);
	}
	printf("</description>\n");
}

void footer(int num)
{
	printf("</document>\n");
}


int main(int argc, char **argv)
{
	int i;
	printf("<vespafeed>\n");
	for (i = 0; i < 400; i++) {
		header(i);
		descriptions(678);
		footer(i);
	}
	printf("</vespafeed>\n");
	return 0;
}
