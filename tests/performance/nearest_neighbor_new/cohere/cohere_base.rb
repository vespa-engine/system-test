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

  # Where the data files are found or downloaded from: a file missing in cohere-data/ is decompressed from <file>.gz,
  # which is downloaded from the nearest-neighbor S3 folder if not present in cohere-data/, i.e., from
  # https://data.vespa-cloud.com/tests/performance/nearest-neighbor/cohere-data/<file>.gz
  # (see CommonAnnBase.find_or_download_compressed_file).
  DATA_DIRS = {local_dir: COHERE_DIR + "cohere-data/", s3_dir: "cohere-data/"}

  # The data files, generated with make_test_data.py from parquet-vectors (see the readme there). All values are little-endian.

  # Document vectors, DOCS_PER_FILE per file: docs_0000.fvecs, docs_0001.fvecs, ...
  # [per vector: int32 1024, 1024 float32]
  DOCS_FILE_FORMAT = "docs_%04d.fvecs"
  DOCS_PER_FILE = 1_000_000

  # 10k query vectors (not among the document vectors)
  # [per vector: int32 1024, 1024 float32]
  QUERIES_FILE = "queries.fvecs"

  # The documents are clustered (spherical k-means) at the levels fine (1000 clusters), medium (200), and coarse (50).

  # Cluster level => the cluster of each document at the level
  # [per document: int32 1, int32 cluster]
  CLUSTERS_FILES = {"fine" => "clusters_fine.ivecs", "medium" => "clusters_medium.ivecs", "coarse" => "clusters_coarse.ivecs"}

  # Cluster level => all clusters of the level for each query vector, ordered from closest to farthest
  # [per query: int32 n, n int32 clusters]
  RANKED_CLUSTERS_FILES = {"fine" => "ranked_fine.ivecs", "medium" => "ranked_medium.ivecs", "coarse" => "ranked_coarse.ivecs"}

  # Deploys the schema cohere/schemas/<schema>/test.sd and starts Vespa.
  # extra_values: values of the test that are added to the parameters of the feed and nni reports, e.g.,
  #   {:quantization_bits => 4}
  def setup_cohere_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:, extra_values:)
    assert(num_queries_for_recall <= num_queries_for_benchmark)
    @extra_values = extra_values
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
    doc_vectors = (0...num_files).map { |i| find_or_download_compressed_file(format(DOCS_FILE_FORMAT, i), node, **DATA_DIRS) }
    feed_from_command("#{compile_cpp(COHERE_DIR + "generators/#{generator}.cpp", node)} --vectors #{doc_vectors.join(',')} " +
                      "--num-docs #{@num_documents} --tensor-field embedding #{options}",
                      [parameter_filler("label", "#{@num_documents}-docs")] + extra_fillers)
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding", extra_fillers)
  end

  def extra_fillers
    @extra_values.map { |key, value| parameter_filler(key.to_s, value) }
  end

  # Downloads the file with the cluster of each document at each level (see CLUSTERS_FILES) to the node (if needed)
  # and returns their paths on the node: [fine, medium, coarse].
  def download_cluster_files(node)
    CLUSTERS_FILES.values.map { |name| find_or_download_compressed_file(name, node, **DATA_DIRS) }
  end

  # Writes the queries printed by the query generator cohere/generators/<generator>.cpp with the given options to the
  # file (on the container), and returns the file.
  def write_queries(generator, target_hits, options, file_name)
    node = container
    query_file = dirs.tmpdir + file_name
    node.execute("#{compile_cpp(COHERE_DIR + "generators/#{generator}.cpp", node)} " +
                 "--vectors #{find_or_download_compressed_file(QUERIES_FILE, node, **DATA_DIRS)} " +
                 "--num-queries #{@num_queries_for_benchmark} --tensor-field embedding --target-hits #{target_hits} " +
                 "#{options} > #{query_file}")
    query_file
  end

end
