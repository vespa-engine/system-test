// Copyright Vespa.ai. All rights reserved.

#include <algorithm>
#include <cassert>
#include <iostream>
#include <numeric>
#include <random>
#include <string>
#include <unistd.h>
#include <vector>

using StringVector = std::vector<std::string>;
using IntVector = std::vector<int>;

class RandomStrings {
private:
    StringVector _strings;
    std::default_random_engine _rnd;

    StringVector gen_strings(size_t count, size_t offset, bool number_string) {
        StringVector result;
        for (size_t i = offset; i < (count + offset); ++i) {
            char str[7];
            if (number_string) {
                snprintf(str, 7, "%d", 10000 + i);
            } else {
                snprintf(str, 7, "A%05d", i);
            }
            result.push_back(std::string(str));
        }
        return result;
    }

public:
    RandomStrings(size_t count, size_t offset, bool number_string)
        : _strings(gen_strings(count, offset, number_string)),
          _rnd(12345)
    {
    }

    const StringVector& get() const { return _strings; }

    StringVector get_rnd(size_t count) {
        assert(count <= _strings.size());
        StringVector result(count);
        std::shuffle(_strings.begin(), _strings.end(), _rnd);
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

std::ostream& print_models_tensor(std::ostream& os, const StringVector& models, const StringVector& cats, size_t vec_size) {
    os << "\"blocks\":[";
    for (size_t i = 0; i < models.size(); ++i) {
        if (i != 0) os << ",\n";
        const auto& model = models[i];
        for (size_t j = 0; j < cats.size(); ++j) {
            if (j != 0) os << ",\n";
            const auto& cat = cats[j];
            os << "{ \"address\": {\"model\":\"" << model << "\",\"cat\":\"" << cat << "\"}, \"values\":";
            print_vector(os, make_rnd_vector(vec_size));
            os << "}";
        }
    }
    return os << "]";
}

std::ostream& print_addresses(std::ostream& os, const std::string& dim_name, const StringVector& values) {
    os << "\"addresses\":[";
    for (size_t i = 0; i < values.size(); ++i) {
        if (i != 0) os << ",\n";
        os << "{\"" << dim_name << "\":\"" << values[i] << "\"}";
    }
    return os << "]";
}

void print_puts(std::ostream& os, const StringVector& models, RandomStrings& strings,
                size_t num_docs, size_t num_cats_per_doc, size_t vec_size, const std::string& field) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        auto cats = strings.get_rnd(num_cats_per_doc);
        os << "{\"put\":\"id:test:test::" << i << "\",\"fields\":{\n";
        os << "\"id\":" << i << ",";
        if (field == "all") {
            os << "\"model\":{"; print_model_tensor(os, cats, vec_size) << "},";
            os << "\"models\":{"; print_models_tensor(os, models, cats, vec_size) << "}";
        } else if (field == "model") {
            os << "\"model\":{"; print_model_tensor(os, cats, vec_size) << "}";
        } else if (field == "models") {
            os << "\"models\":{"; print_models_tensor(os, models, cats, vec_size) << "}";
        }
        os << "}}";
    }
    os << "]\n";
}

void print_updates(std::ostream& os, const std::string& type, const StringVector& models, RandomStrings& strings,
                   size_t num_docs, size_t num_cats_per_doc, size_t vec_size, const std::string& field) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        auto cats = strings.get_rnd(num_cats_per_doc);
        os << "{\"update\":\"id:test:test::" << i << "\",\"fields\":{\n";
        if (field == "model") {
            os << "\"model\":{\"" << type << "\":{"; print_model_tensor(os, cats, vec_size) << "}}";
        } else if (field == "models") {
            os << "\"models\":{\"" << type << "\":{"; print_models_tensor(os, models, cats, vec_size) << "}}";
        }
        os << "}}";
    }
    os << "]\n";
}

void print_remove_updates(std::ostream& os, const std::string& field, const std::string& dim_name,
                          RandomStrings& strings, size_t num_docs) {
    os << "[\n";
    for (size_t i = 0; i < num_docs; ++i) {
        if (i != 0) os << ",\n";
        auto values = strings.get_rnd(1);
        os << "{\"update\":\"id:test:test::" << i << "\",\"fields\":{\n";
        os << "\"" << field << "\":{\"remove\":{"; print_addresses(os, dim_name, values) << "}}";
        os << "}}";
    }
    os << "]\n";
}


const std::string LB = "%7B";
const std::string RB = "%7D";

void print_query_tensor(std::ostream& os, const std::string& dim_name, const StringVector& values, bool rnd_value) {
    os << LB;
    for (size_t i = 0; i < values.size(); ++i) {
        if (i != 0) os << ",";
        os << LB << dim_name << ":" << values[i] << RB << ":" << (rnd_value ? (std::rand()%100) : 1) << ".0";
    }
    os << RB;
}

void print_query_cat_tensor(std::ostream& os, const StringVector& cats, bool rnd_value) {
    print_query_tensor(os, "cat", cats, rnd_value);
}

void print_query_model_tensor(std::ostream& os, const StringVector& model) {
    assert(model.size() == 1);
    print_query_tensor(os, "model", model, false);
}

void print_query(std::ostream& os, RandomStrings& models, RandomStrings& categories,
                 size_t num_cats_per_query, size_t vec_size, bool single_model) {
    auto cats = categories.get_rnd(num_cats_per_query);
    os << "/search/?query=sddocname:test";
    os << "&ranking.features.query(q_cat_keys)="; print_query_cat_tensor(os, cats, false);
    os << "&ranking.features.query(q_cat_scores)="; print_query_cat_tensor(os, cats, true);
    if (!single_model) {
        os << "&ranking.features.query(q_model)="; print_query_model_tensor(os, models.get_rnd(1));
    }
    os << "&ranking.features.query(q_user_vec)="; print_vector(os, make_rnd_vector(vec_size));
}

void print_queries(std::ostream& os, RandomStrings& models, RandomStrings& categories,
                   size_t num_queries, size_t num_cats_per_query, size_t vec_size, bool single_model) {
    for (size_t i = 0; i < num_queries; ++i) {
        print_query(os, models, categories, num_cats_per_query, vec_size, single_model);
        os << std::endl;
    }
}

void print_usage(char* argv[]) {
    std::cerr << argv[0] << " [-o num_ops] [-f field_name]" << std::endl;
    std::cerr << "    puts | updates <type> | queries <type> " << std::endl;
}

int main (int argc, char* argv[]) {
    std::srand(12345);
    size_t num_cats = 50;
    size_t num_cats_per_doc = 3;
    size_t num_cats_per_query = 10;
    size_t num_models = 10;
    size_t vec_size = 256;

    size_t num_ops = 2;
    std::string field = "all";
    bool label_as_number_string = false;

    char c;
    while ((c = getopt(argc, argv, "shc:d:f:o:v:")) != static_cast<char>(-1)) {
        switch (c) {
        case 'c':
            num_cats = strtoul(optarg, nullptr, 0);
            break;
        case 'd':
            num_cats_per_doc = strtoul(optarg, nullptr, 0);
            break;
        case 'f':
            field = std::string(optarg);
            break;
        case 'o':
            num_ops = strtoul(optarg, nullptr, 0);
            break;
        case 'v':
            vec_size = strtoul(optarg, nullptr, 0);
            break;
        case 'h':
        default:
            print_usage(argv);
            return 1;
        }
    }

    RandomStrings strings(num_cats, 0, label_as_number_string);
    RandomStrings models(num_models, 0, label_as_number_string);
    RandomStrings strings_2(num_cats, num_cats, label_as_number_string);
    RandomStrings models_2(1, num_models, label_as_number_string);

    if (optind >= argc) {
        print_usage(argv);
        return 1;
    }

    std::string mode(argv[optind]);
    if (mode == "puts") {
        print_puts(std::cout, models.get(), strings, num_ops, num_cats_per_doc, vec_size, field);
    } else if (mode == "updates") {
        std::string type(argv[optind + 1]);
        bool single_model = (field == "model");
        if (type == "assign") {
            print_updates(std::cout, "assign", models.get(), strings, num_ops, num_cats_per_doc, vec_size, field);
        } else if (type == "add") {
            // Single model tensor: we add a single category.
            // Multi-model tensor: we add an entire new model.
            print_updates(std::cout, "add", models_2.get(), strings_2, num_ops,
                          single_model ? 1 : num_cats_per_doc, vec_size, field);
        } else if (type == "remove") {
            // Single model tensor: we remove a single category (same that was added).
            // Multi-model tensor: we remove an an entire model (same that was added).
            std::string dim_name = single_model ? "cat" : "model";
            auto& values = single_model ? strings_2 : models_2;
            print_remove_updates(std::cout, field, dim_name, values, num_ops);
        } else {
            print_usage(argv);
            return 1;
        }
    } else if (mode == "queries") {
        std::string type(argv[optind + 1]);
        if (type == "single") {
            print_queries(std::cout, models, strings, num_ops, num_cats_per_query, vec_size, true);
        } else if (type == "multi") {
            print_queries(std::cout, models, strings, num_ops, num_cats_per_query, vec_size, false);
        } else {
            print_usage(argv);
            return 1;
        }
    } else {
        print_usage(argv);
        return 1;
    }
    return 0;
}


