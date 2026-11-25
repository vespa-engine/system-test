// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

#include <iostream>
#include <optional>

/**
 * Radii (--radius, in km) used for the queries, and what the searched circle around the location of a query roughly corresponds to.
 * The fraction of the documents in the circle is the mean over the queries for the default locations of the documents and queries
 * (uniformly distributed in latitude and longitude in the bounding box of the contiguous United States, 14.1 million km^2),
 * measured with 1M documents and 1000 queries. A circle around a location near the border of the box extends beyond it
 * and contains fewer documents than a circle around a location in the middle, which matters for the larger radii.
 *
 * - 2 km (13 km^2): part of a city, e.g., about a quarter of Manhattan (59 km^2).
 *   0.0001% of the documents: about 1 of 1M documents (many queries have no document in the circle), 9 of 10M documents.
 * - 15 km (700 km^2): a city such as Chicago (600 km^2) or Los Angeles (1,300 km^2).
 *   0.005% of the documents: about 50 of 1M documents.
 * - 75 km (17,700 km^2): multiple cities, e.g., the San Francisco Bay Area (18,000 km^2).
 *   0.12% of the documents: about 1,200 of 1M documents.
 * - 200 km (126,000 km^2): a state such as Pennsylvania (119,000 km^2) or Ohio (116,000 km^2).
 *   0.9% of the documents.
 * - 500 km (785,000 km^2): multiple states, e.g., the Pacific Northwest (Washington, Oregon, and Idaho, 660,000 km^2),
 *   a circle around Portland reaching Seattle and almost Boise.
 *   5% of the documents.
 * - 1100 km: a large region, e.g., a circle around Kansas City reaching Denver, Chicago, and Dallas (the Great Plains and the Midwest).
 *   20% of the documents.
 * - 2000 km: half of the country, e.g., a circle around Kansas City reaching the East Coast and the Rocky Mountains
 *   (everything but the West Coast).
 *   51% of the documents.
 */

const std::string USAGE =
    "Usage: make_geo_queries --vectors <file> --tensor-field <name> --radius <km> [options] > queries.txt\n"
    "\n"
    "Prints one nearestNeighbor query (URL) per query vector for the documents of make_geo_docs, restricted with geoLocation\n"
    "to the documents within the radius around a random location, by default in the contiguous United States (uniformly distributed\n"
    "in latitude and longitude in its bounding box). The locations are the same for every run.\n"
    "\n"
    "Options:\n"
    "  --vectors <file>           .fvecs file with the query vectors\n"
    "  --num-queries <n>          Number of queries (default: all vectors)\n"
    "  --tensor-field <name>      Name of the document tensor field searched by nearestNeighbor\n"
    "  --approximate <bool>       Whether to use approximate search (HNSW), true or false (default: true)\n"
    "  --target-hits <n>          targetNumHits of nearestNeighbor (default: 100)\n"
    "  --explore-hits <n>         hnsw.exploreAdditionalHits of nearestNeighbor (default: 0)\n"
    "  --radius <km>              Radius around the location of the query in kilometers, e.g., 15 for a city or 200 for a state\n"
    "                             (see the comment in make_geo_queries.cpp for the radii used and what they correspond to)\n"
    + LOCATION_OPTIONS_USAGE +
    "\n"
    "Example:\n"
    "  make_geo_queries --vectors queries.fvecs --tensor-field embedding --radius 15 > queries_15km.txt\n";

void
print_query(std::ostream& os, const std::string& tensor_field, bool approximate, int target_hits, int explore_hits,
            float lat, float lng, float radius, const FloatVector& vector)
{
    os << "/search/?yql=select%20*%20from%20sources%20*%20where%20";
    print_nns(os, tensor_field, approximate, target_hits, explore_hits);
    os << "%20and%20geoLocation(latlng," << lat << "," << lng << "," << QUOT << radius << "+km" << QUOT << ")";
    os << ";&ranking.features.query(q_vec)=";
    print_vector(os, vector) << "\n";
}

int
main(int argc, char** argv)
{
    try {
        std::string vector_file;
        std::optional<size_t> num_queries;
        std::string tensor_field;
        bool approximate = true;
        int target_hits = 100;
        int explore_hits = 0;
        float radius = 0.0f;
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
                vector_file = value;
            } else if (option == "--num-queries") {
                num_queries = parse_number<size_t>(value);
            } else if (option == "--tensor-field") {
                tensor_field = value;
            } else if (option == "--approximate") {
                approximate = parse_bool(value);
            } else if (option == "--target-hits") {
                target_hits = parse_number<int>(value);
            } else if (option == "--explore-hits") {
                explore_hits = parse_number<int>(value);
            } else if (option == "--radius") {
                radius = parse_number<float>(value);
            } else if (option == "--latitude") {
                latitude = parse_interval(value);
            } else if (option == "--longitude") {
                longitude = parse_interval(value);
            } else {
                throw std::runtime_error("Unknown option " + option);
            }
        }
        if (vector_file.empty() || tensor_field.empty()) {
            std::cerr << USAGE;
            return 1;
        }
        if (!(radius > 0.0f)) {
            throw std::runtime_error("--radius must be given and positive");
        }

        VectorFileReader<float> vectors(vector_file);
        size_t num = num_queries.value_or(vectors.num_vectors());
        vectors.require(num);

        srand(QUERY_LOCATION_SEED);
        FloatVector vector;
        for (size_t i = 0; i < num; ++i) {
            vectors.read(vector);
            float lat = latitude.random();
            float lng = longitude.random();
            print_query(std::cout, tensor_field, approximate, target_hits, explore_hits, lat, lng, radius, vector);
        }
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
