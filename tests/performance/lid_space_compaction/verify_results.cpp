// Copyright Vespa.ai. All rights reserved.

#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <string.h>
#include <assert.h>
#include <stdlib.h>

bool verify_usage(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << argv[0] << "<expected fbench resultfile> <actual fbench result file>" << std::endl;
        std::cerr << "This program will verify that summaries produced are identical to the expected ones." << std::endl;
        std::cerr << "The order of the expected is identical to the 'key' in the actual." << std::endl;
        return false;
    }
    return true;
}

constexpr const char *KEY = "\"key\":";
size_t KEYLEN = strlen(KEY);

int main (int argc, char *argv[]) {
    if ( !verify_usage(argc, argv) ) { return 2; }
    std::ifstream expected(argv[1]);
    size_t sum(0);
    std::unordered_map<size_t, std::string> lines;
    while (expected && !expected.eof()) {
        std::string line;
        std::getline(expected, line);
        if ( ! line.empty() && (line.find("root") != std::string::npos)) {
            size_t key_pos = line.find(KEY);
            if (key_pos != std::string::npos) {
                const char * start = strstr(line.c_str(), KEY) + KEYLEN;
                char * e;
                size_t key = strtoul(start, &e, 0);
                assert(e[0] == '}');
                lines[key] = line;
                sum += line.size();
            }
        }
    }
    std::cout << lines.size() << " " << sum << std::endl;
    std::ifstream results(argv[2]);
    size_t numFailures(0);
    while (results && !results.eof()) {
        std::string line;
        std::getline(results, line);
        if ( ! line.empty() && (line.find("root") != std::string::npos)) {
            size_t key_pos = line.find(KEY);
            if (key_pos != std::string::npos) {
                const char * start = strstr(line.c_str(), KEY) + KEYLEN;
                char * e;
                size_t key = strtoul(start, &e, 0);
                assert(e[0] == '}');
                if (line != lines[key]) {
                    std::cout << "Failed key " << key << std::endl;
                    numFailures++;
                }
            } else {
               std::cerr << "Found no key in line : " << line << std::endl;
               numFailures++;
            }
        }
    }
    std::cout << "Verification produced " << numFailures << " failures in file " << argv[2] << " compared to expected file " << argv[1] << std::endl;
    return numFailures == 0 ? 0 : 1;
}
