// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#include <algorithm>
#include <cassert>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

using StringVector = std::vector<std::string>;
using IntVector = std::vector<int>;

class RandomStrings {
private:
    StringVector _strings;

    StringVector gen_strings(size_t count) {
        StringVector result;
        for (size_t i = 0; i < count; ++i) {
            char str[7];
            snprintf(str, 7, "%06d", i);
            result.push_back(std::string(str));
        }
        return result;
    }

public:
    RandomStrings(size_t count)
        : _strings(gen_strings(count))
    {
    }

    StringVector get_rnd(size_t count) {
        assert(count <= _strings.size());
        StringVector result(count);
        std::random_shuffle(_strings.begin(), _strings.end());
        std::copy_n(_strings.begin(), count, result.begin());
        return result;
    }
};

IntVector make_rnd_vector(size_t count) {
    IntVector result;
    result.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        result.push_back(std::rand()%100);
    }
    return result;
}

std::ostream& print_vector(std::ostream& os, const IntVector& vec) {
    os << "[";
    for (size_t i = 0; i < vec.size(); ++i) {
        if (i != 0) os << ",";
        os << vec[i] << ".0";
    }
    return os << "]";
}

std::ostream& print_model_tensor(std::ostream& os, const StringVector& cats, size_t vec_size) {
    os << "\"blocks\":{";
    for (size_t i = 0; i < cats.size(); ++i) {
        if (i != 0) os << ",\n";
        os << "\"" << cats[i] << "\":";
        print_vector(os, make_rnd_vector(vec_size));
    }
    return os << "}";
}

void print_puts(std::ostream& os, RandomStrings& strings,
                size_t num_docs, size_t num_cats_per_doc, size_t vec_size) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        os << "{\"put\":\"id:test:test::" << i << "\",\"fields\":{\n";
        os << "\"id\":" << i << ",";
        os << "\"model\":{"; print_model_tensor(os, strings.get_rnd(num_cats_per_doc), vec_size) << "}";
        os << "}}";
    }
    os << "]\n";
}

const std::string LB = "%7B";
const std::string RB = "%7D";

void print_cat_tensor(std::ostream& os, const StringVector& cats, bool rnd_value) {
    os << LB;
    for (size_t i = 0; i < cats.size(); ++i) {
        if (i != 0) os << ",";
        os << LB << "cat:" << cats[i] << RB << ":" << (rnd_value ? (std::rand()%100) : 1) << ".0";
    }
    os << RB;
}

void print_query(std::ostream& os, RandomStrings& strings,
                 size_t num_cats_per_query, size_t vec_size) {
    auto cats = strings.get_rnd(num_cats_per_query);
    os << "/search/?query=sddocname:test";
    os << "&ranking.features.query(q_cat_keys)="; print_cat_tensor(os, cats, false);
    os << "&ranking.features.query(q_cat_scores)="; print_cat_tensor(os, cats, true);
    os << "&ranking.features.query(q_user_vec)="; print_vector(os, make_rnd_vector(vec_size));
}

void print_queries(std::ostream& os, RandomStrings& strings,
                   size_t num_queries, size_t num_cats_per_query, size_t vec_size) {
    for (size_t i = 0; i < num_queries; ++i) {
        print_query(os, strings, num_cats_per_query, vec_size);
        os << std::endl;
    }
}

void print_usage(char* argv[]) {
    std::cerr << argv[0] << " puts <num docs> | queries <num queries>" << std::endl;
}

int main (int argc, char* argv[]) {
    if (argc != 3) {
        print_usage(argv);
        return 1;
    }
    std::srand(12345);
    std::string mode(argv[1]);
    size_t num_cats = 50;
    size_t num_cats_per_doc = 3;
    size_t num_cats_per_query = 10;
    size_t vec_size = 256;
    RandomStrings strings(num_cats);
    if (mode == "puts") {
        size_t num_docs = strtoul(argv[2], nullptr, 0);
        print_puts(std::cout, strings, num_docs, num_cats_per_doc, vec_size);
    } else if (mode == "queries") {
        size_t num_queries = strtoul(argv[2], nullptr, 0);
        print_queries(std::cout, strings, num_queries, num_cats_per_query, vec_size);
    } else {
        print_usage(argv);
        return 1;
    }
    return 0;
}


