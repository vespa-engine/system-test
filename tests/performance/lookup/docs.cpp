#include <cstdlib>
#include <cstdio>
#include <cstdint>

void
doc(int num, unsigned long v) {
    printf("{\"id\":\"id:test:test::%d\", \"fields\":{ \"f1\":%lu, \"f1_hash\":%lu } }", num, v, v);
}

int
main(int argc, char **argv) {
    int i;
    int numDocs = atoi(argv[1]);
    printf("[\n");
    for (i = 0; i < (numDocs-1); i++) {
        doc(i, i);
        printf(",\n");
    }
    doc(i, i);
    printf("\n]\n");
    return 0;
}
