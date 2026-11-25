// Copyright Vespa.ai. All rights reserved.

// Functionality shared by the document and query generators:
// command line options, reading vector and cluster files, and printing feed documents and queries.

#pragma once

#include <algorithm>
#include <charconv>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using FloatVector = std::vector<float>;
using IntVector = std::vector<int>;
using StringVector = std::vector<std::string>;

// ---------------------------------------------------------------------------------------------------------------------
// Parsing

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

template <typename T>
T
parse_number(const std::string& str, const std::string& what)
{
    T value{};
    auto [end, ec] = std::from_chars(str.data(), str.data() + str.size(), value);
    if (ec != std::errc() || end != str.data() + str.size()) {
        throw std::invalid_argument("Invalid " + what + " '" + str + "'");
    }
    return value;
}

/**
 * Parses a comma-separated list of numbers, optionally enclosed in brackets, e.g., "1,10,50" or "[1,10,50]".
 */
template <typename T>
std::vector<T>
parse_list(std::string str, const std::string& what)
{
    if (!str.empty() && (str.front() == '[' || str.front() == '{')) {
        str = str.substr(1);
    }
    if (!str.empty() && (str.back() == ']' || str.back() == '}')) {
        str.pop_back();
    }
    std::vector<T> result;
    for (const auto& part : split(str, ',')) {
        result.push_back(parse_number<T>(part, what));
    }
    return result;
}

// ---------------------------------------------------------------------------------------------------------------------
// Command line options

/**
 * Command line options of the form "--name value" and flags of the form "--name".
 * On invalid input, fail() prints the message and the usage and exits.
 */
class Args {
    // In the usage, "{program}" is replaced by the name of the program.
    std::string _usage;
    std::map<std::string, std::string> _values;
    std::set<std::string> _flags;

public:
    Args(int argc, char** argv, const std::string& usage, const std::set<std::string>& options, const std::set<std::string>& flags = {})
        : _usage(usage), _values(), _flags()
    {
        for (size_t pos; (pos = _usage.find("{program}")) != std::string::npos;) {
            _usage.replace(pos, 9, std::filesystem::path(argv[0]).filename().string());
        }
        for (int i = 1; i < argc; ++i) {
            std::string arg(argv[i]);
            if (arg == "--help" || arg == "-h") {
                std::cout << _usage;
                std::exit(0);
            }
            if (!arg.starts_with("--")) {
                fail("Unexpected argument '" + arg + "'");
            }
            std::string name = arg.substr(2);
            if (flags.contains(name)) {
                _flags.insert(name);
            } else if (options.contains(name)) {
                if (i + 1 >= argc) {
                    fail("Missing value for option " + arg);
                }
                _values[name] = argv[++i];
            } else {
                fail("Unknown option " + arg);
            }
        }
    }

    [[noreturn]] void fail(const std::string& message) const {
        std::cerr << message << std::endl << std::endl << _usage;
        std::exit(1);
    }

    bool has(const std::string& name) const { return _values.contains(name); }
    bool flag(const std::string& name) const { return _flags.contains(name); }

    std::string get(const std::string& name) const {
        auto it = _values.find(name);
        if (it == _values.end()) {
            fail("Missing option --" + name);
        }
        return it->second;
    }

    std::string get(const std::string& name, const std::string& fallback) const {
        return has(name) ? get(name) : fallback;
    }

    template <typename T>
    T get_number(const std::string& name) const {
        try {
            return parse_number<T>(get(name), "value for --" + name);
        } catch (const std::invalid_argument& e) {
            fail(e.what());
        }
    }

    template <typename T>
    T get_number(const std::string& name, T fallback) const {
        return has(name) ? get_number<T>(name) : fallback;
    }

    template <typename T>
    std::vector<T> get_list(const std::string& name) const {
        try {
            return has(name) ? parse_list<T>(get(name), "value for --" + name) : std::vector<T>();
        } catch (const std::invalid_argument& e) {
            fail(e.what());
        }
    }

    bool get_bool(const std::string& name, bool fallback) const {
        std::string value = get(name, fallback ? "true" : "false");
        if (value != "true" && value != "false") {
            fail("Value for --" + name + " must be 'true' or 'false', not '" + value + "'");
        }
        return value == "true";
    }

    /**
     * Fails unless either all or none of the options are given.
     */
    void require_all_or_none(const StringVector& names) const {
        size_t given = std::count_if(names.begin(), names.end(), [this](const auto& name) { return has(name); });
        if (given != 0 && given != names.size()) {
            std::string list;
            for (const auto& name : names) {
                list += (list.empty() ? "--" : ", --") + name;
            }
            fail("The options " + list + " must be given together");
        }
    }
};

std::set<std::string>
operator+(std::set<std::string> a, const std::set<std::string>& b)
{
    a.insert(b.begin(), b.end());
    return a;
}

// ---------------------------------------------------------------------------------------------------------------------
// Reading vector and cluster files

/**
 * Reads the vectors of one or several .fvecs files (int32 dimension followed by the float32 entries per vector)
 * in order as one sequence, e.g., a large file split into chunks of 1M vectors. The dimension is taken from the first vector.
 */
class VectorFileReader {
    StringVector _files;
    size_t _dim = 0;
    size_t _num_vectors = 0;
    size_t _file_index = 0; // File currently read from
    size_t _vector_num = 0; // Number of the next vector in the whole sequence
    std::ifstream _is;

    size_t record_size() const { return 4 + sizeof(float) * _dim; }

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
     * Opens a comma-separated list of .fvecs files.
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
    size_t num_vectors() const { return _num_vectors; }

    /**
     * Reads the next vector, resizing the given vector to the dimension.
     */
    void read(FloatVector& vector) {
        while (_file_index < _files.size() && _is.peek() == std::ifstream::traits_type::eof()) {
            open_file(_file_index + 1);
        }
        if (_file_index >= _files.size()) {
            throw std::runtime_error("Could not read vector " + std::to_string(_vector_num) + ", there are only "
                                     + std::to_string(_num_vectors) + " vectors in the vector files");
        }
        int read_dim = 0;
        vector.resize(_dim);
        _is.read(reinterpret_cast<char*>(&read_dim), 4);
        _is.read(reinterpret_cast<char*>(vector.data()), sizeof(float) * _dim);
        if (!_is.good() || read_dim != static_cast<int>(_dim)) {
            throw std::runtime_error("Could not read vector " + std::to_string(_vector_num) + " with " + std::to_string(_dim) + " dimensions from '"
                                     + _files[_file_index] + "' (dimension in file: " + std::to_string(read_dim) + ")");
        }
        ++_vector_num;
    }

    /**
     * Returns the number of vectors to use: num if given (failing if there are fewer vectors), otherwise all vectors.
     */
    size_t check_num(const Args& args, const std::string& option) const {
        size_t num = args.get_number<size_t>(option, _num_vectors);
        if (num > _num_vectors) {
            args.fail("--" + option + " is " + std::to_string(num) + ", but there are only " + std::to_string(_num_vectors) + " vectors");
        }
        return num;
    }
};

/**
 * Reads an .ivecs file with records of varying length (int32 number of entries n followed by n int32 entries).
 * Records of length 1 are, e.g., the cluster of each document (as written by assign_clusters.py),
 * longer records, e.g., all clusters ranked for each query vector (as written by rank_query_clusters.py).
 */
class IntRecordReader {
    std::string _file;
    std::ifstream _is;
    size_t _record_num = 0;

public:
    explicit IntRecordReader(const std::string& file)
        : _file(file), _is(file, std::ifstream::binary)
    {
        if (!_is.good()) {
            throw std::runtime_error("Could not open '" + file + "'");
        }
    }

    /**
     * Reads the next record into entries. Returns false at the end of the file.
     */
    bool read(IntVector& entries) {
        int size = 0;
        if (!_is.read(reinterpret_cast<char*>(&size), 4)) {
            return false;
        }
        if (size <= 0) {
            throw std::runtime_error("Invalid size " + std::to_string(size) + " of record " + std::to_string(_record_num) + " in '" + _file + "'");
        }
        entries.resize(size);
        if (!_is.read(reinterpret_cast<char*>(entries.data()), sizeof(int) * size)) {
            throw std::runtime_error("Truncated record " + std::to_string(_record_num) + " in '" + _file + "'");
        }
        ++_record_num;
        return true;
    }

    /**
     * Reads the next record, which must exist and have exactly one entry, and returns the entry.
     */
    int read_single() {
        IntVector entries;
        if (!read(entries)) {
            throw std::runtime_error("Could not read record " + std::to_string(_record_num) + " from '" + _file + "', the file is too short");
        }
        if (entries.size() != 1) {
            throw std::runtime_error("Record " + std::to_string(_record_num - 1) + " in '" + _file + "' has " + std::to_string(entries.size())
                                     + " entries, expected 1");
        }
        return entries[0];
    }
};

// ---------------------------------------------------------------------------------------------------------------------
// Random locations

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

const std::set<std::string> LOCATION_OPTIONS = {"latitude", "longitude"};

const std::string LOCATION_OPTIONS_USAGE =
    "  --latitude <lower,upper>   Interval of the latitudes in degrees (default: 24.5,49.4, the contiguous United States)\n"
    "  --longitude <lower,upper>  Interval of the longitudes in degrees (default: -124.8,-66.9, the contiguous United States)\n";

/**
 * Returns the interval given by the option "lower,upper", or the fallback if the option is not given.
 */
Interval
get_interval(const Args& args, const std::string& name, const Interval& fallback)
{
    if (!args.has(name)) {
        return fallback;
    }
    std::vector<float> values;
    try {
        values = parse_list<float>(args.get(name), "value for --" + name);
    } catch (const std::invalid_argument& e) {
        args.fail(e.what());
    }
    if (values.size() != 2 || values[0] > values[1]) {
        args.fail("--" + name + " must be an interval 'lower,upper' with lower <= upper, not '" + args.get(name) + "'");
    }
    return Interval{values[0], values[1]};
}

// ---------------------------------------------------------------------------------------------------------------------
// Printing

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

/**
 * Prints a JSON array of put operations with the document ids "id:test:test::<id>".
 */
class FeedPrinter {
    std::ostream& _os;
    bool _first_doc = true;
    bool _first_field = true;

public:
    explicit FeedPrinter(std::ostream& os) : _os(os) { _os << "[" << std::endl; }

    void begin_put(size_t id) {
        _os << (_first_doc ? "" : ",\n") << "{\n  \"put\": \"id:test:test::" << id << "\",\n  \"fields\": {\n";
        _first_doc = false;
        _first_field = true;
    }

    /**
     * Starts a field, the value is printed to the returned stream.
     */
    std::ostream& field(const std::string& name) {
        _os << (_first_field ? "" : ",\n") << "    \"" << name << "\": ";
        _first_field = false;
        return _os;
    }

    void tensor_field(const std::string& name, const FloatVector& vector) {
        print_vector(field(name) << "{ \"values\": ", vector) << " }";
    }

    void end_put() { _os << "\n  }\n}"; }

    void finish() { _os << "\n]" << std::endl; }
};

// URL-encoded characters used in queries
const std::string L_BRACE = "%7B";
const std::string R_BRACE = "%7D";
const std::string QUOT = "%22";
const std::string EQ = "%3D";
const std::string SPACE = "%20";

/**
 * Settings of the nearestNeighbor operator of the queries.
 */
struct NearestNeighbor {
    std::string doc_tensor;
    bool approximate = true;
    int target_hits = 100;
    int explore_hits = 0;
};

/**
 * Prints the beginning of a query up to and including the nearestNeighbor operator. Further conditions can be added
 * with SPACE + "and" + SPACE + ..., and print_query_end() completes the query with the query vector.
 */
void
print_query_begin(std::ostream& os, const NearestNeighbor& nns)
{
    os << "/search/?yql=select" << SPACE << "*" << SPACE << "from" << SPACE << "sources" << SPACE << "*" << SPACE << "where" << SPACE
       << "[" << L_BRACE
       << QUOT << "targetNumHits" << QUOT << ":" << nns.target_hits << ","
       << QUOT << "hnsw.exploreAdditionalHits" << QUOT << ":" << nns.explore_hits << ","
       << QUOT << "approximate" << QUOT << ":" << (nns.approximate ? "true" : "false") << ","
       << QUOT << "label" << QUOT << ":" << QUOT << "nns" << QUOT
       << R_BRACE << "]" << "nearestNeighbor(" << nns.doc_tensor << ",q_vec)";
}

void
print_query_end(std::ostream& os, const FloatVector& vector)
{
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector) << "\n";
}

// ---------------------------------------------------------------------------------------------------------------------
// Options shared by all document generators and all query generators

const std::set<std::string> DOC_OPTIONS = {"vectors", "num-docs", "tensor-field"};

const std::string DOC_OPTIONS_USAGE =
    "  --vectors <files>          .fvecs file, or a comma-separated list of .fvecs files read in order as one sequence\n"
    "                             (e.g., docs_0000.fvecs,docs_0001.fvecs), the i-th vector is used for document i\n"
    "  --num-docs <n>             Number of documents (default: all vectors)\n"
    "  --tensor-field <name>      Name of the tensor field\n";

const std::set<std::string> QUERY_OPTIONS = {"vectors", "num-queries", "tensor-field", "approximate", "target-hits", "explore-hits"};
const std::set<std::string> QUERY_FLAGS = {"vectors-only"};

const std::string QUERY_OPTIONS_USAGE =
    "  --vectors <file>           .fvecs file with the query vectors\n"
    "  --num-queries <n>          Number of queries (default: all vectors)\n"
    "  --tensor-field <name>      Name of the document tensor field searched by nearestNeighbor\n"
    "  --approximate <bool>       Whether to use approximate search (HNSW), true or false (default: true)\n"
    "  --target-hits <n>          targetNumHits of nearestNeighbor (default: 100)\n"
    "  --explore-hits <n>         hnsw.exploreAdditionalHits of nearestNeighbor (default: 0)\n"
    "  --vectors-only             Print only the query vectors, one per line, e.g., for computing the recall\n";

/**
 * Prints the vectors, one per line, e.g., for computing the recall (--vectors-only of the query generators).
 */
void
print_vectors(std::ostream& os, VectorFileReader& vectors, size_t num)
{
    FloatVector vector;
    for (size_t i = 0; i < num; ++i) {
        vectors.read(vector);
        print_vector(os, vector) << "\n";
    }
}

NearestNeighbor
get_nearest_neighbor(const Args& args)
{
    return NearestNeighbor{args.get("tensor-field"), args.get_bool("approximate", true),
                           args.get_number<int>("target-hits", 100), args.get_number<int>("explore-hits", 0)};
}
