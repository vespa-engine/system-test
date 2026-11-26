// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

#include <iostream>
#include <optional>

const std::string USAGE =
    "Usage: make_geo_docs --vectors <files> --tensor-field <name> [options] > docs.json\n"
    "\n"
    "Prints a feed (JSON array of puts) of documents with a vector and a random location in the position field 'latlng',\n"
    "by default in the contiguous United States (uniformly distributed in latitude and longitude in its bounding box,\n"
    "uncorrelated with the vectors, the same for every run). Each document has the int field 'id' (its number).\n"
    "\n"
    "Options:\n"
    "  --vectors <files>          .fvecs file, or a comma-separated list of .fvecs files read in order as one sequence\n"
    "                             (e.g., docs_0000.fvecs,docs_0001.fvecs), the i-th vector is used for document i\n"
    "  --num-docs <n>             Number of documents (default: all vectors)\n"
    "  --tensor-field <name>      Name of the tensor field\n"
    + LOCATION_OPTIONS_USAGE +
    "\n"
    "Example:\n"
    "  make_geo_docs --vectors docs_0000.fvecs,docs_0001.fvecs --tensor-field embedding > docs.json\n";

void
print_put(std::ostream& os, size_t docid, float lat, float lng, const std::string& tensor_field, const FloatVector& vector)
{
    os << "{\n";
    os << "  \"put\": \"id:test:test::" << docid << "\",\n";
    os << "  \"fields\": {\n";
    os << "    \"id\": " << docid << ",\n";
    os << "    \"latlng\": { \"lat\": " << lat << ", \"lng\": " << lng << "},\n";
    os << "    \"" << tensor_field << "\": { \"values\": ";
    print_vector(os, vector) << " }\n";
    os << "  }\n";
    os << "}";
}

int
main(int argc, char** argv)
{
    try {
        std::string vector_files;
        std::optional<size_t> num_docs;
        std::string tensor_field;
        Interval latitude = US_LATITUDE;
        Interval longitude = US_LONGITUDE;
        if (argc % 2 == 0) { // --help, or an option without a value
            std::cerr << USAGE;
            return 1;
        }
        for (int i = 1; i < argc; i += 2) {
            std::string option = argv[i];
            std::string value = argv[i + 1];
            if (option == "--vectors") {
                vector_files = value;
            } else if (option == "--num-docs") {
                num_docs = parse_number<size_t>(value);
            } else if (option == "--tensor-field") {
                tensor_field = value;
            } else if (option == "--latitude") {
                latitude = parse_interval(value);
            } else if (option == "--longitude") {
                longitude = parse_interval(value);
            } else {
                throw std::runtime_error("Unknown option " + option);
            }
        }
        if (vector_files.empty() || tensor_field.empty()) {
            std::cerr << USAGE;
            return 1;
        }

        VectorFileReader<float> vectors(vector_files);
        size_t num = num_docs.value_or(vectors.num_vectors());
        vectors.require(num);

        srand(DOC_LOCATION_SEED);
        FloatVector vector;
        std::cout << "[\n";
        for (size_t docid = 0; docid < num; ++docid) {
            vectors.read(vector);
            float lat = latitude.random();
            float lng = longitude.random();
            std::cout << (docid == 0 ? "" : ",\n");
            print_put(std::cout, docid, lat, lng, tensor_field, vector);
        }
        std::cout << "\n]" << std::endl;
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
