# Copyright Vespa.ai. All rights reserved.

# Data set module (see AnnCommon) for tests over the Cohere embeddings (1024 dimensions, normalized) of Wikipedia passages
# (https://huggingface.co/datasets/Cohere/wikipedia-2023-11-embed-multilingual-v3), for AnnFiltered (with correlated
# filters) and AnnGeo.
#
# The data is downloaded from cohere-data/ in the S3 folder (a local copy in cohere-data/ is used if present).
# The schemas are in schemas/cohere_<name>/test.sd.
#
# The documents have the tensor field 'embedding', and the queries search it with nearestNeighbor and the query tensor q_vec.
module DatasetCohere

  # The data files, derived from the Cohere data set and downloaded as <file>.gz (see AnnCommon.find_or_download_compressed_file).
  # Each file is a sequence of little-endian records [int32 number of entries, entries].
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
  NUM_DOCUMENTS = 2_000_000
  # The documents are clustered with spherical k-means. The ranked clusters are ordered from closest to farthest.

  # Cluster level => the files of the level
  CLUSTERS_FILES = {"fine" => CLUSTERS_FINE_FILE, "medium" => CLUSTERS_MEDIUM_FILE, "coarse" => CLUSTERS_COARSE_FILE}
  RANKED_CLUSTERS_FILES = {"fine" => RANKED_FINE_FILE, "medium" => RANKED_MEDIUM_FILE, "coarse" => RANKED_COARSE_FILE}

  # ---- Helpers ----

  def find_data_file(name, node)
    find_or_download_compressed_file("cohere-data/" + name, node)
  end

  # Returns the cluster level (the field cluster_<level>) used for the correlated filters with the hit ratio.
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

  # ---- Document generation ----

  # Feeds the documents printed by the document generator generators/<generator>.cpp with the given options.
  def feed_documents(generator, options)
    assert(@num_documents <= NUM_DOCUMENTS, "The data set has only #{NUM_DOCUMENTS} documents")
    node = vespa.adminserver
    num_files = (@num_documents.to_f / DOCS_PER_FILE).ceil
    doc_vectors = (0...num_files).map do |i|
      find_data_file(format(DOCS_FILE_FORMAT, i), node)
    end
    feed_from_command("#{compile_generator(generator, node)} --vectors #{doc_vectors.join(',')} " +
                      "--num-docs #{@num_documents} --tensor-field embedding #{options}",
                      [parameter_filler("label", "#{@num_documents}-docs")])
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding")
  end

  # Feeds the documents with the field 'filter' for the hit ratios and the fields cluster_<level> (see AnnFiltered).
  def feed_filtered_documents(hit_ratios)
    cluster_files = CLUSTERS_FILES.values.map { |name| find_data_file(name, vespa.adminserver) }
    cluster_fields = CLUSTERS_FILES.keys.map { |level| "cluster_#{level}" }
    feed_documents("make_filtered_docs",
                   "--hit-ratios #{hit_ratios.join(',')} " +
                   "--cluster-files #{cluster_files.join(',')} --cluster-fields #{cluster_fields.join(',')}")
  end

  def feed_geo_documents
    feed_documents("make_geo_docs", "")
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

  # Writes the queries with a filter on the clusters (of the level of the hit ratio) closest to the query vector for
  # AnnFiltered::POSITIVE or farthest from it for AnnFiltered::NEGATIVE, which contain the hit ratio of the fed documents.
  def write_correlated_queries(filter_type, hit_ratio, values)
    level = cluster_level(hit_ratio)
    selection = (filter_type == AnnFiltered::POSITIVE) ? "closest" : "farthest"
    write_queries("make_correlated_filtered_queries",
                  "--ranked-clusters #{find_data_file(RANKED_CLUSTERS_FILES[level], container)} " +
                  "--doc-clusters #{find_data_file(CLUSTERS_FILES[level], container)} --cluster-field cluster_#{level} " +
                  "--num-docs #{@num_documents} --selection #{selection} --target-fraction #{hit_ratio}",
                  values)
  end

  def write_geo_queries(radius, values)
    write_queries("make_geo_queries", "--radius #{radius}", values)
  end

end
