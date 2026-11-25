# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/common/common_ann_base'

# Base class for tests over the Cohere embeddings (1024 dimensions, normalized) of Wikipedia passages
# (https://huggingface.co/datasets/Cohere/wikipedia-2023-11-embed-multilingual-v3), independent of the kind of test
# (see the subclasses CohereFilteredBase and CohereGeoBase).
#
# cohere/ contains everything specific to the data set: the base classes, the document and query generators in generators/
# (from parquet-vectors), the data in cohere-data/, and the schemas in schemas/<name>/test.sd.
#
# The documents have the tensor field 'embedding', and the queries search it with nearestNeighbor and the query tensor q_vec.
class CohereBase < CommonAnnBase

  COHERE_DIR = File.expand_path(File.dirname(__FILE__)) + "/"

  # The data files, generated with make_test_data.py from parquet-vectors (see the readme there).
  # Each file is a sequence of little-endian records [int32 number of entries, entries]. A file missing in LOCAL_DIR is
  # decompressed from <file>.gz, which is downloaded from S3_DIR in the nearest-neighbor S3 folder if not present in
  # LOCAL_DIR (see CommonAnnBase.find_or_download_compressed_file).
  LOCAL_DIR = COHERE_DIR + "cohere-data/"
  S3_DIR = "cohere-data/" # https://data.vespa-cloud.com/tests/performance/nearest-neighbor/cohere-data/
  #                                                 Contents                                      Record
  DOCS_FILE_FORMAT     = "docs_%04d.fvecs"        # document vectors, DOCS_PER_FILE per file      [int32 1024, 1024 float32]
  QUERIES_FILE         = "queries.fvecs"          # 10k query vectors (not among the documents)   [int32 1024, 1024 float32]
  CLUSTERS_FINE_FILE   = "clusters_fine.ivecs"    # cluster of each document, 1000 clusters       [int32 1, int32 cluster]
  CLUSTERS_MEDIUM_FILE = "clusters_medium.ivecs"  # cluster of each document, 200 clusters         [int32 1, int32 cluster]
  CLUSTERS_COARSE_FILE = "clusters_coarse.ivecs"  # cluster of each document, 50 clusters          [int32 1, int32 cluster]
  RANKED_FINE_FILE     = "ranked_fine.ivecs"      # the 1000 fine clusters for each query vector   [int32 1000, 1000 int32 clusters]
  RANKED_MEDIUM_FILE   = "ranked_medium.ivecs"    # the 200 medium clusters for each query vector  [int32 200, 200 int32 clusters]
  RANKED_COARSE_FILE   = "ranked_coarse.ivecs"    # the 50 coarse clusters for each query vector   [int32 50, 50 int32 clusters]
  DOCS_PER_FILE = 1_000_000
  # The documents are clustered with spherical k-means. The ranked clusters are ordered from closest to farthest.

  # Cluster level => the files of the level
  CLUSTERS_FILES = {"fine" => CLUSTERS_FINE_FILE, "medium" => CLUSTERS_MEDIUM_FILE, "coarse" => CLUSTERS_COARSE_FILE}
  RANKED_CLUSTERS_FILES = {"fine" => RANKED_FINE_FILE, "medium" => RANKED_MEDIUM_FILE, "coarse" => RANKED_COARSE_FILE}

  # Returns the cluster level (the field cluster_<level>) used for the positive and negative filters with the hit ratio.
  # The level is chosen such that the queries contain about 5 to 25 clusters (hit ratio * number of clusters of the level),
  # which keeps the queries small while the selected clusters contain close to the target fraction of the documents.
  # For hit ratios below 0.005, there are only a few clusters per query, so the selected clusters can contain several
  # times the target fraction (e.g., about 1 to 4 clusters for 0.001).
  def cluster_level(hit_ratio)
    if hit_ratio >= 0.2
      "coarse" # 50 clusters
    elsif hit_ratio >= 0.05
      "medium" # 200 clusters
    else
      "fine" # 1000 clusters
    end
  end

  # Deploys the schema cohere/schemas/<schema>/test.sd and starts Vespa.
  def setup_cohere_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:)
    assert(num_queries_for_recall <= num_queries_for_benchmark)
    @num_documents = num_documents
    @num_queries_for_benchmark = num_queries_for_benchmark
    deploy_app(create_app(COHERE_DIR + "schemas/#{schema}/test.sd"))
    start
    print_hardware_details
  end

  # Feeds the documents printed by the document generator cohere/generators/<generator>.cpp with the given options.
  def feed_documents(generator, options)
    node = vespa.adminserver
    num_files = (@num_documents.to_f / DOCS_PER_FILE).ceil
    doc_vectors = (0...num_files).map do |i|
      find_or_download_compressed_file(format(DOCS_FILE_FORMAT, i), node, local_dir: LOCAL_DIR, s3_dir: S3_DIR)
    end
    feed_from_command("#{compile_cpp(COHERE_DIR + "generators/#{generator}.cpp", node)} --vectors #{doc_vectors.join(',')} " +
                      "--num-docs #{@num_documents} --tensor-field embedding #{options}",
                      [parameter_filler("label", "#{@num_documents}-docs")])
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding")
  end

  # Downloads the file with the cluster of each document at each level (see CLUSTERS_FILES) to the node (if needed)
  # and returns their paths on the node: [fine, medium, coarse].
  def download_cluster_files(node)
    CLUSTERS_FILES.values.map { |name| find_or_download_compressed_file(name, node, local_dir: LOCAL_DIR, s3_dir: S3_DIR) }
  end

  # Writes the queries printed by the query generator cohere/generators/<generator>.cpp with the given options for the
  # query case to a file (on the container), and returns the file. The values of the query case set the nearestNeighbor
  # operator: :approximate (true for approximate search with HNSW, false for exact search), :target_hits, and :explore_hits.
  def write_queries(generator, options, values)
    node = container
    query_file = dirs.tmpdir + "queries.#{label(values)}.txt"
    node.execute("#{compile_cpp(COHERE_DIR + "generators/#{generator}.cpp", node)} " +
                 "--vectors #{find_or_download_compressed_file(QUERIES_FILE, node, local_dir: LOCAL_DIR, s3_dir: S3_DIR)} " +
                 "--num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                 "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                 "--explore-hits #{values.fetch(:explore_hits)} #{options} > #{query_file}")
    query_file
  end

end
