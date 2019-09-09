#include <stdlib.h>
#include <stdio.h>

void doc(int num) {
    printf("{\"id\":\"id:test:test::%d\", \"fields\":{ \"score\":%d } }", num, num);
}

int main(int argc, char **argv) {
    int i;
    int numDocs = atoi(argv[1]);
    printf("[\n");
    for (i = 0; i < (numDocs-1); i++) {
        doc(i);
        printf(",\n");
    }
    doc(i);
    printf("\n]\n");
    return 0;
}
