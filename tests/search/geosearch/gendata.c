// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

const double inv = 1.0 / RAND_MAX;

static double nextDouble(double max)
{
	long rv1 = random();
	double d = rv1;
	d *= inv;
        d *= max;
	return d;
}

void header(int num)
{
	printf("<document type='point' id='id:test:point::%d'>\n", num);
        printf("<title>the ");
	if ((random() % 100) <= 42) {
            printf("bar ");
        }
        printf("fox says ");
	if ((random() % 100) <= 84) {
            printf("foo ");
        }
        printf("hihi</title>");
}

void footer(int num)
{
	printf("<order>%d</order>\n", num);
	printf("</document>\n");
}

void geo()
{
	printf("<latlong>");
	if ((random() % 100) <= 42) {
	    printf("N");
        } else {
	    printf("S");
        }
        printf("%.6f", nextDouble(71.2));
	printf(";");
	if ((random() % 100) <= 42) {
	    printf("E");
        } else {
	    printf("W");
        }
        printf("%.6f", nextDouble(179.9));
	printf("</latlong>\n");
}

void genUrls(double distmax)
{
	int i;
	srandom(42);
	for (i = 0; i < 123456; i++) {
		double ns = nextDouble(71.2);
		double ew = nextDouble(179.9);
                int dd = nextDouble(distmax);
                int r = nextDouble(65536);
		printf("/search/?query=title:foo&pos.ll=%s%.6f%s%s%.6f&pos.radius=%d%s&ranking=withdrop\n",
			((r & 1) ? "N" : "S"), ns, "%3B",
			((r & 2) ? "E" : "W"), ew, dd,
			((r & 4) ? "km" : "mi"));
        }
}

int main(int argc, char **argv)
{
	int i;
	srandom(42);
	close(1);
	creat("feed-2.xml", 0644);

	printf("<vespafeed>\n");
	for (i = 0; i < 1234567; i++) {
		header(i);
		geo();
		footer(i);
	}
	printf("</vespafeed>\n");
	fflush(stdout);
	close(1);
	creat("urls-2.txt", 0644);
	genUrls(1000);
	fflush(stdout);
	close(1);
	creat("urls-3.txt", 0644);
	genUrls(50);
	fflush(stdout);
	return 0;
}
