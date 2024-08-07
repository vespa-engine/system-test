// Copyright Vespa.ai. All rights reserved.

/**
 * Utility program to generate json documents for testing ranking performance.
 *
 * Compile program:
 * g++ -std=c++0x doc_generator.cpp -o doc_generator
 *
 * Run program:
 * ./doc_generator 1000
 *
 **/

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace std;

string
gen_field_content()
{
    vector<int> terms = {64, 32, 16, 8, 4, 2, 1};
    ostringstream oss;
    for (int i = 1; !terms.empty(); ++i) {
        for (int j = 0; j < terms.size(); ++j) {
            oss << terms[j] << " ";
        }
        if (i >= terms.back()) {
            terms.pop_back();
        }
    }
    return oss.str();
}

string
gen_selection_content(int id)
{
    vector<int> percents = {100, 50, 20, 10, 5, 2, 1};
    ostringstream oss;
    for (int percent : percents) {
        int freq = 100 / percent;
        if (id % freq == 0) {
            oss << percent << " ";
        }
    }
    return oss.str();
}

double
gen_random_score()
{
    return static_cast<double>(rand()) / static_cast<double>(RAND_MAX);
}

void
write_document(int id, const string &field_content, const string &selection_content, double score_1, double score_2)
{
    cout << "  {" << endl;
    cout << "    \"put\": \"id:test:test::" << id << "\"," << endl;
    cout << "    \"fields\": {" << endl;
    cout << "      \"title\": \"" << field_content << "\"," << endl;
    cout << "      \"body\": \"" << field_content << "\"," << endl;
    cout << "      \"selection\": \"" << selection_content << "\"," << endl;
    cout << "      \"score_1\": " << score_1 << "," << endl;
    cout << "      \"score_2\": " << score_2 << endl;
    cout << "    }" << endl;
    cout << "  }";
}

void
write_documents(int num_docs)
{
    string field_content = gen_field_content();
    cout << "[" << endl;
    for (int i = 0; i < num_docs; ++i) {
        if (i > 0) {
            cout << "," << endl;
        }
        write_document(i, field_content, gen_selection_content(i), gen_random_score(), gen_random_score());
    }
    cout << endl << "]" << endl;
}

int
main(int argc, char **argv)
{
    if (argc != 2) {
        cout << "Usage: doc_generator num_docs" << endl;
        exit(1);
    }
    int num_docs = atoi(argv[1]);
    srand(123456789);
    write_documents(num_docs);
}
