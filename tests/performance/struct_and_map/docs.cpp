#include <cstdlib>
#include <cstdio>

void elem(int elem) {
    printf("\"%d\": {", elem);
    printf("\"weight\": %d,", elem);
    printf("\"name\": \"name-%d\",", elem);
    printf("\"description\": \"Longer description, but still folded into one dictionary entry to avoid blowing memory.\"");
    printf("}");
}

void map(const char *name, int numElem) {
    printf("\"%s\" : {", name);
    int i(0);
    for (; (i+1) < numElem; i++) {
        elem(i);
        printf(",");
    }
    elem(i);
    printf("}");
}

void doc(int num, int numElem) {
    printf("{\"id\":\"id:test:test::%d\", \"fields\":{ ", num);
    printf("\"identity\":\"d-%03d\",", num);
    map("elem_map_attr", numElem);
    printf(",");
    map("elem_map_mix", numElem);
    printf(" } }");
}

int main(int argc, char **argv) {
    int i(0);
    int numDocs = atoi(argv[1]);
    int numElem = atoi(argv[2]);
    printf("[\n");
    for (; (i+1) < numDocs; i++) {
        doc(i, numElem);
        printf(",\n");
    }
    doc(i, numElem);
    printf("\n]\n");
    return 0;
}
