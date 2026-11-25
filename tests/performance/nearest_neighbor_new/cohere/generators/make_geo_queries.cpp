// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

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
    "Usage: {program} --vectors <file> --tensor-field <name> --radius <km> [options] > queries.txt\n"
    "       {program} --locations-only --num-queries <n> [options] > locations.txt\n"
    "\n"
    "Prints one nearestNeighbor query (URL) per query vector for the documents of make_geo_docs, restricted with geoLocation\n"
    "to the documents within the radius around a random location, by default in the contiguous United States (uniformly distributed\n"
    "in latitude and longitude in its bounding box). The locations are the same for every run, --locations-only prints them as\n"
    "'latitude,longitude', one per line, e.g., for computing the recall.\n"
    "\n"
    "Options:\n" + QUERY_OPTIONS_USAGE +
    "  --radius <km>              Radius around the location of the query in kilometers, e.g., 15 for a city or 200 for a state\n"
    "                             (see the comment in make_geo_queries.cpp for the radii used and what they correspond to)\n"
    + LOCATION_OPTIONS_USAGE +
    "  --locations-only           Print only the locations of the queries\n"
    "\n"
    "Example:\n"
    "  {program} --vectors queries.fvecs --tensor-field embedding --radius 15 > queries_15km.txt\n";

int
main(int argc, char** argv)
{
    srand(QUERY_LOCATION_SEED);
    Args args(argc, argv, USAGE, QUERY_OPTIONS + LOCATION_OPTIONS + std::set<std::string>{"radius"},
              QUERY_FLAGS + std::set<std::string>{"locations-only"});
    Interval latitude = get_interval(args, "latitude", US_LATITUDE);
    Interval longitude = get_interval(args, "longitude", US_LONGITUDE);
    if (args.flag("locations-only")) {
        if (args.flag("vectors-only")) {
            args.fail("--locations-only and --vectors-only cannot be combined");
        }
        size_t num_queries = args.get_number<size_t>("num-queries");
        for (size_t i = 0; i < num_queries; ++i) {
            float lat = latitude.random();
            float lng = longitude.random();
            std::cout << lat << "," << lng << "\n";
        }
        return 0;
    }
    try {
        VectorFileReader vectors(args.get("vectors"));
        size_t num_queries = vectors.check_num(args, "num-queries");
        if (args.flag("vectors-only")) {
            print_vectors(std::cout, vectors, num_queries);
            return 0;
        }
        NearestNeighbor nns = get_nearest_neighbor(args);
        float radius = args.get_number<float>("radius");
        if (!(radius > 0.0f)) {
            args.fail("--radius must be positive");
        }
        FloatVector vector;
        for (size_t i = 0; i < num_queries; ++i) {
            vectors.read(vector);
            float lat = latitude.random();
            float lng = longitude.random();
            print_query_begin(std::cout, nns);
            std::cout << SPACE << "and" << SPACE << "geoLocation(latlng," << lat << "," << lng << "," << QUOT << radius << "+km" << QUOT << ")";
            print_query_end(std::cout, vector);
        }
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
