// Copyright Vespa.ai. All rights reserved.

// Functionality shared by the document and query generators.

#pragma once

#include <charconv>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <format>
#include <fstream>
#include <ostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using StringVector = std::vector<std::string>;
using FloatVector = std::vector<float>;
using IntVector = std::vector<int>;

// ---------------------------------------------------------------------------------------------------------------------
// Parsing options

StringVector
split(const std::string& str, char separator)
{
    StringVector result;
    std::stringstream ss(str);
    std::string part;
    while (std::getline(ss, part, separator)) {
        result.push_back(part);
    }
    return result;
}

std::string
join(const StringVector& parts)
{
    std::string result;
    for (const auto& part : parts) {
        result += (result.empty() ? "" : ",") + part;
    }
    return result;
}

template <typename T>
T
parse_number(const std::string& str)
{
    T value{};
    auto [end, ec] = std::from_chars(str.data(), str.data() + str.size(), value);
    if (ec != std::errc() || end != str.data() + str.size()) {
        throw std::runtime_error("Invalid number '" + str + "'");
    }
    return value;
}

/**
 * Parses a comma-separated list of numbers, e.g., "1,10,50".
 */
template <typename T>
std::vector<T>
parse_numbers(const std::string& str)
{
    std::vector<T> result;
    for (const auto& part : split(str, ',')) {
        result.push_back(parse_number<T>(part));
    }
    return result;
}

bool
parse_bool(const std::string& str)
{
    if (str != "true" && str != "false") {
        throw std::runtime_error("Invalid boolean '" + str + "', expected 'true' or 'false'");
    }
    return str == "true";
}

// ---------------------------------------------------------------------------------------------------------------------
// Reading vector and cluster files

/**
 * Reads the vectors of one or several files in order as one sequence, e.g., a large file split into chunks of 1M vectors.
 * Each vector is its int32 dimension followed by its entries of type T: float for .fvecs files (e.g., the document vectors),
 * int32_t for .ivecs files (e.g., the cluster of each document with dimension 1, or all clusters ranked for each query vector).
 * The dimension is taken from the first vector, all vectors must have the same dimension.
 */
template <typename T>
class VectorFileReader {
    static_assert(sizeof(T) == 4);

    StringVector _files;
    size_t _dim = 0;
    size_t _num_vectors = 0;
    size_t _file_index = 0; // File currently read from
    size_t _vector_num = 0; // Number of the next vector in the whole sequence
    std::ifstream _is;

    size_t record_size() const { return 4 + sizeof(T) * _dim; }

    void open_file(size_t file_index) {
        _file_index = file_index;
        _is.close();
        _is.clear();
        if (_file_index < _files.size()) {
            _is.open(_files[_file_index], std::ifstream::binary);
            if (!_is.good()) {
                throw std::runtime_error("Could not open '" + _files[_file_index] + "'");
            }
        }
    }

public:
    /**
     * Opens a comma-separated list of files.
     */
    explicit VectorFileReader(const std::string& files)
        : _files(split(files, ','))
    {
        if (_files.empty()) {
            throw std::runtime_error("No vector file given");
        }
        std::vector<uintmax_t> sizes;
        for (const auto& file : _files) {
            std::error_code ec;
            sizes.push_back(std::filesystem::file_size(file, ec));
            if (ec) {
                throw std::runtime_error("Could not open '" + file + "': " + ec.message());
            }
            if (_dim == 0 && sizes.back() >= 4) {
                int dim = 0;
                std::ifstream(file, std::ifstream::binary).read(reinterpret_cast<char*>(&dim), 4);
                if (dim <= 0) {
                    throw std::runtime_error("Invalid dimension " + std::to_string(dim) + " in '" + file + "'");
                }
                _dim = dim;
            }
        }
        for (size_t i = 0; i < _files.size(); ++i) {
            if (sizes[i] > 0 && (_dim == 0 || sizes[i] % record_size() != 0)) {
                throw std::runtime_error("The size of '" + _files[i] + "' (" + std::to_string(sizes[i]) + " bytes) is not a multiple of the size of a vector with "
                                         + std::to_string(_dim) + " dimensions (" + std::to_string(record_size()) + " bytes)");
            }
            _num_vectors += (_dim == 0) ? 0 : sizes[i] / record_size();
        }
        open_file(0);
    }

    size_t dim() const { return _dim; }

    /**
     * Fails unless the vectors have the given dimension, e.g., 1 for the cluster of each document.
     */
    void require_dim(size_t dim) const {
        if (_dim != dim) {
            throw std::runtime_error("The vectors in '" + join(_files) + "' have dimension " + std::to_string(_dim) + ", expected " + std::to_string(dim));
        }
    }
    size_t num_vectors() const { return _num_vectors; }

    /**
     * Reads the next vector, resizing the given vector to the dimension.
     */
    void read(std::vector<T>& vector) {
        while (_file_index < _files.size() && _is.peek() == std::ifstream::traits_type::eof()) {
            open_file(_file_index + 1);
        }
        if (_file_index >= _files.size()) {
            throw std::runtime_error("Could not read vector " + std::to_string(_vector_num) + ", there are only "
                                     + std::to_string(_num_vectors) + " vectors in '" + join(_files) + "'");
        }
        int read_dim = 0;
        vector.resize(_dim);
        _is.read(reinterpret_cast<char*>(&read_dim), 4);
        _is.read(reinterpret_cast<char*>(vector.data()), sizeof(T) * _dim);
        if (!_is.good() || read_dim != static_cast<int>(_dim)) {
            throw std::runtime_error("Could not read vector " + std::to_string(_vector_num) + " with " + std::to_string(_dim) + " dimensions from '"
                                     + _files[_file_index] + "' (dimension in file: " + std::to_string(read_dim) + ")");
        }
        ++_vector_num;
    }

    /**
     * Fails unless there are at least num vectors.
     */
    void require(size_t num) const {
        if (num > _num_vectors) {
            throw std::runtime_error("Requested " + std::to_string(num) + " vectors, but there are only " + std::to_string(_num_vectors) + " in '" + join(_files) + "'");
        }
    }
};

// ---------------------------------------------------------------------------------------------------------------------
// Printing vectors

template <typename T>
std::ostream&
print_vector(std::ostream& os, const std::vector<T>& vector)
{
    os << "[";
    for (size_t i = 0; i < vector.size(); ++i) {
        os << (i == 0 ? "" : ",") << std::format("{}", vector[i]);
    }
    return os << "]";
}

// ---------------------------------------------------------------------------------------------------------------------
// Printing queries

// URL-encoded characters used in queries
const std::string L_BRACE = "%7B";
const std::string R_BRACE = "%7D";
const std::string QUOT = "%22";
const std::string EQ = "%3D";

void
print_nns(std::ostream& os, const std::string& tensor_field, bool approximate, int target_hits, int explore_hits)
{
    os << "[" << L_BRACE
       << QUOT << "targetNumHits" << QUOT << ":" << target_hits << ","
       << QUOT << "hnsw.exploreAdditionalHits" << QUOT << ":" << explore_hits << ","
       << QUOT << "approximate" << QUOT << ":" << (approximate ? "true" : "false") << ","
       << QUOT << "label" << QUOT << ":" << QUOT << "nns" << QUOT
       << R_BRACE << "]" << "nearestNeighbor(" << tensor_field << ",q_vec)";
}

// ---------------------------------------------------------------------------------------------------------------------
// Filters with a given hit ratio, uncorrelated with the vectors (make_filtered_docs and make_filtered_queries)
//
// For each hit ratio r, document i contains the filter value r * 1000 in the array<int> field 'filter' if (i % 1000) < r * 1000,
// such that the filter 'filter=<r * 1000>' of the queries has hit ratio r.

/**
 * Returns the filter value of a hit ratio, which is the hit ratio per 1000, e.g., 10 for 0.01.
 */
int
filter_value(double hit_ratio)
{
    if (!(hit_ratio >= 0.001 && hit_ratio <= 1.0)) {
        throw std::runtime_error("Invalid hit ratio " + std::to_string(hit_ratio) + ", must be in [0.001, 1]");
    }
    return std::lround(hit_ratio * 1000);
}

// ---------------------------------------------------------------------------------------------------------------------
// Random locations (make_geo_docs and make_geo_queries)

struct Interval {
    float lower = 0.0f;
    float upper = 0.0f;

    float random() const {
        if (lower == upper) {
            return lower;
        }
        return lower + static_cast<float>(rand()) / (static_cast<float>(RAND_MAX / (upper - lower)));
    }
};

// Bounding box of the contiguous United States (the lower 48 states) in degrees, the default area of the locations.
// The box has about 14.1 million km^2, of which the contiguous United States are about 8.1 million km^2 (57%),
// the rest are parts of Canada, Mexico, and the oceans. As the locations are uniformly distributed in latitude and longitude,
// there are about 40% more locations per km^2 in the north than in the south (cos(24.5 degrees) / cos(49.4 degrees)).
const Interval US_LATITUDE{24.5f, 49.4f};
const Interval US_LONGITUDE{-124.8f, -66.9f};

// Seeds of the random locations, such that they are the same for every run. They must differ, as the locations of the queries would
// otherwise be the locations of the first documents (each query would be centered on a document).
const unsigned int DOC_LOCATION_SEED = 42;
const unsigned int QUERY_LOCATION_SEED = 43;

const std::string LOCATION_OPTIONS_USAGE =
    "  --latitude <lower,upper>   Interval of the latitudes in degrees (default: 24.5,49.4, the contiguous United States)\n"
    "  --longitude <lower,upper>  Interval of the longitudes in degrees (default: -124.8,-66.9, the contiguous United States)\n";

/**
 * Parses an interval "lower,upper".
 */
Interval
parse_interval(const std::string& str)
{
    std::vector<float> values = parse_numbers<float>(str);
    if (values.size() != 2 || values[0] > values[1]) {
        throw std::runtime_error("Invalid interval '" + str + "', expected 'lower,upper' with lower <= upper");
    }
    return Interval{values[0], values[1]};
}
