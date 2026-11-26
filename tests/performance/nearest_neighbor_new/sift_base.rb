# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/common_ann_base'

# Base class for tests over the SIFT data set (http://corpus-texmex.irisa.fr/, 1M document vectors and 10k query vectors
# with 128 dimensions, euclidean distance), independent of the kind of test (see sift_filtered.rb).
#
# The data is in sift-data/ and the schemas in schemas/sift_<name>/test.sd.
#
# The documents have the tensor field 'embedding', and the queries search it with nearestNeighbor and the query tensor q_vec.
class SiftBase < CommonAnnBase

  # The data files in the .fvecs format (little-endian records [int32 128, 128 float32]). A file missing in LOCAL_DIR is
  # downloaded from S3_DIR in the nearest-neighbor S3 folder (see CommonAnnBase.find_or_download_file).
  LOCAL_DIR = ANN_DIR + "sift-data/"
  S3_DIR = "sift-data/" # https://data.vespa-cloud.com/tests/performance/nearest-neighbor/sift-data/
  DOCS_FILE = "sift_base.fvecs"     # 1M document vectors
  QUERIES_FILE = "sift_query.fvecs" # 10k query vectors (not among the documents)

  # Deploys the schema schemas/<schema>/test.sd and starts Vespa. The test sets @num_documents (the first vectors of
  # the data set are fed), @num_queries_for_benchmark (the queries in each query file), and @num_queries_for_recall (the first
  # queries of each query file used to calculate the recall).
  def setup_sift_test(schema)
    assert(@num_queries_for_recall <= @num_queries_for_benchmark)
    deploy_app(create_app(SCHEMAS_DIR + "#{schema}/test.sd"))
    start
    print_hardware_details
  end

  # Feeds the documents printed by the document generator generators/<generator>.cpp with the given options.
  def feed_documents(generator, options)
    node = vespa.adminserver
    doc_vectors = find_or_download_file(DOCS_FILE, node, local_dir: LOCAL_DIR, s3_dir: S3_DIR)
    feed_from_command("#{compile_generator(generator, node)} --vectors #{doc_vectors} " +
                      "--num-docs #{@num_documents} --tensor-field embedding #{options}",
                      [parameter_filler("label", "#{@num_documents}-docs")])
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding")
  end

  # Writes the queries printed by the query generator generators/<generator>.cpp with the given options for the
  # benchmark to a file (on the container), and returns the file. The values of the benchmark set the nearestNeighbor
  # operator: :approximate (true for approximate search with HNSW, false for exact search), :target_hits, and :explore_hits.
  def write_queries(generator, options, values)
    node = container
    query_file = dirs.tmpdir + "queries.#{label(values)}.txt"
    node.execute("#{compile_generator(generator, node)} " +
                 "--vectors #{find_or_download_file(QUERIES_FILE, node, local_dir: LOCAL_DIR, s3_dir: S3_DIR)} " +
                 "--num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                 "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                 "--explore-hits #{values.fetch(:explore_hits)} #{options} > #{query_file}")
    query_file
  end

end
