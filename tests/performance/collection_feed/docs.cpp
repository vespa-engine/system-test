#include <cstdlib>
#include <cstdio>

void elem() {
    printf("\"%d\": %d", rand(), rand());
}

void wset(const char *name, int numElem) {
    printf("\"%s\" : {", name);
    int i(0);
    for (; (i+1) < numElem; i++) {
        elem();
        printf(",");
    }
    elem();
    printf("}");
}

void doc(const char * fieldName, int num, int numElem) {
    printf("{\"id\":\"id:user:footype::%d\", \"fields\":{ ", num);
    printf("\"id\" : %d,", num);
    wset(fieldName, numElem);
    printf(" } }");
}

int main(int argc, char **argv) {
    int i(0);
    int numDocs = atoi(argv[1]);
    int numElem = atoi(argv[2]);
    const char * fieldName = argv[3];
    srand(7);
    printf("[\n");
    for (; (i+1) < numDocs; i++) {
        doc(fieldName, i, numElem);
        printf(",\n");
    }
    doc(fieldName, i, numElem);
    printf("\n]\n");
    return 0;
}
