// Copyright Vespa.ai. All rights reserved.

#include "shared.h"

const std::string USAGE =
    "Usage: {program} --vectors <files> --tensor-field <name> [options] > docs.json\n"
    "\n"
    "Prints a feed (JSON array of puts) of documents with a vector and a random location in the position field 'latlng',\n"
    "by default in the contiguous United States (uniformly distributed in latitude and longitude in its bounding box,\n"
    "uncorrelated with the vectors, the same for every run). Each document has the int field 'id' (its number).\n"
    "\n"
    "Options:\n" + DOC_OPTIONS_USAGE + LOCATION_OPTIONS_USAGE +
    "\n"
    "Example:\n"
    "  {program} --vectors docs_0000.fvecs,docs_0001.fvecs --tensor-field embedding > docs.json\n";

int
main(int argc, char** argv)
{
    srand(DOC_LOCATION_SEED);
    Args args(argc, argv, USAGE, DOC_OPTIONS + LOCATION_OPTIONS);
    std::string tensor_field = args.get("tensor-field");
    Interval latitude = get_interval(args, "latitude", US_LATITUDE);
    Interval longitude = get_interval(args, "longitude", US_LONGITUDE);
    try {
        VectorFileReader vectors(args.get("vectors"));
        size_t num_docs = vectors.check_num(args, "num-docs");
        FeedPrinter printer(std::cout);
        FloatVector vector;
        for (size_t docid = 0; docid < num_docs; ++docid) {
            vectors.read(vector);
            printer.begin_put(docid);
            printer.field("id") << docid;
            float lat = latitude.random();
            float lng = longitude.random();
            printer.field("latlng") << "{ \"lat\": " << lat << ", \"lng\": " << lng << "}";
            printer.tensor_field(tensor_field, vector);
            printer.end_put();
        }
        printer.finish();
    } catch (const std::runtime_error& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }
    return 0;
}
