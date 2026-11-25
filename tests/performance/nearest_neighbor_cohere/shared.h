// Copyright Vespa.ai. All rights reserved.

#include <cstdlib>
#include <sstream>

struct Interval {
    float lower;
    float upper;

    Interval()
    : lower(0.0f), upper(-1.0f) {
    }

    bool
    non_empty() const {
        return (upper - lower) >= 0.0f;
    }

    bool
    point() const {
        return lower == upper;
    }

    float
    random() const {
        if (point()) {
            return lower;
        }

        return lower + static_cast<float>(rand()) / (static_cast<float>(RAND_MAX/(upper - lower)));
    }
};

Interval
parse_interval(const std::string &str) {
    Interval interval;

    std::stringstream ss(str);

    if (ss.peek() == '[') {
        ss.ignore();
    }

    if (!(ss >> interval.lower)) {
        return Interval();
    }

    if (ss.peek() == ',') {
        ss.ignore();
    }

    if (!(ss >> interval.upper)) {
        return Interval();
    }

    return interval;
}

