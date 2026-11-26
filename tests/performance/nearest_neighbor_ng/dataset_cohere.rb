# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/dataset_base'

# Data set module (see DatasetBase) for tests over the Cohere embeddings (1024 dimensions, normalized) of Wikipedia passages
# (https://huggingface.co/datasets/Cohere/wikipedia-2023-11-embed-multilingual-v3), for AnnFiltered (with correlated
# filters) and AnnGeo.
#
# The data is downloaded from cohere-data/ in the S3 folder (a local copy in cohere-data/ is used if present).
# The schemas are in schemas/cohere_<name>/test.sd.
module DatasetCohere
  include DatasetBase

  # The data files, derived from the Cohere data set and downloaded as <file>.gz (see AnnBase.find_or_download_compressed_file).
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

  def max_num_documents
    NUM_DOCUMENTS
  end

  def doc_vector_files(node)
    num_files = (@num_documents.to_f / DOCS_PER_FILE).ceil
    (0...num_files).map { |i| find_data_file(format(DOCS_FILE_FORMAT, i), node) }
  end

  def query_vector_file(node)
    find_data_file(QUERIES_FILE, node)
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

  # Feeds the documents with the field 'filter' for the hit ratios and the fields cluster_<level> (see AnnFiltered).
  def feed_filtered_documents(hit_ratios)
    cluster_files = CLUSTERS_FILES.values.map { |name| find_data_file(name, vespa.adminserver) }
    cluster_fields = CLUSTERS_FILES.keys.map { |level| "cluster_#{level}" }
    feed_documents("make_filtered_docs",
                   "--hit-ratios #{hit_ratios.join(',')} " +
                   "--cluster-files #{cluster_files.join(',')} --cluster-fields #{cluster_fields.join(',')}")
  end

  # ---- Query generation ----

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

end
