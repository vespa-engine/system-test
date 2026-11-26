# Copyright Vespa.ai. All rights reserved.

# Data set module (see AnnCommon) for tests over the SIFT data set (http://corpus-texmex.irisa.fr/, 1M document vectors and 10k query vectors
# with 128 dimensions, euclidean distance), for AnnFiltered (without correlated filters).
#
# The data is downloaded from sift-data/ in the S3 folder (a local copy in sift-data/ is used if present).
# The schemas are in schemas/sift_<name>/test.sd.
#
# The documents have the tensor field 'embedding', and the queries search it with nearestNeighbor and the query tensor q_vec.
module DatasetSift

  # The data files in the .fvecs format (little-endian records [int32 128, 128 float32], see AnnCommon.find_or_download_file).
  DOCS_FILE = "sift_base.fvecs"     # 1M document vectors
  QUERIES_FILE = "sift_query.fvecs" # 10k query vectors (not among the documents)
  NUM_DOCUMENTS = 1_000_000

  # ---- Helpers ----

  def find_data_file(name, node)
    find_or_download_file("sift-data/" + name, node)
  end

  # ---- Document generation ----

  # Feeds the documents printed by the document generator generators/<generator>.cpp with the given options.
  def feed_documents(generator, options)
    assert(@num_documents <= NUM_DOCUMENTS, "The data set has only #{NUM_DOCUMENTS} documents")
    node = vespa.adminserver
    doc_vectors = find_data_file(DOCS_FILE, node)
    feed_from_command("#{compile_generator(generator, node)} --vectors #{doc_vectors} " +
                      "--num-docs #{@num_documents} --tensor-field embedding #{options}",
                      [parameter_filler("label", "#{@num_documents}-docs")])
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding")
  end

  def feed_filtered_documents(hit_ratios)
    feed_documents("make_filtered_docs", "--hit-ratios #{hit_ratios.join(',')}")
  end

  # ---- Query generation ----

  # Writes the queries printed by the query generator generators/<generator>.cpp with the given options for the
  # benchmark to a file (on the container), and returns the file. The values of the benchmark set the nearestNeighbor
  # operator: :approximate (true for approximate search with HNSW, false for exact search), :target_hits, and :explore_hits.
  def write_queries(generator, options, values)
    node = container
    query_file = dirs.tmpdir + "queries.#{label(values)}.txt"
    node.execute("#{compile_generator(generator, node)} " +
                 "--vectors #{find_data_file(QUERIES_FILE, node)} " +
                 "--num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                 "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                 "--explore-hits #{values.fetch(:explore_hits)} #{options} > #{query_file}")
    query_file
  end

  def write_unfiltered_queries(values)
    write_queries("make_filtered_queries", "", values)
  end

  def write_uncorrelated_queries(hit_ratio, values)
    write_queries("make_filtered_queries", "--hit-ratio #{hit_ratio}", values)
  end

end
