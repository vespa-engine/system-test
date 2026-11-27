# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/dataset_base'

# Data set module (see DatasetBase) for tests over the SIFT data set (http://corpus-texmex.irisa.fr/, 1M document vectors and 10k query vectors
# with 128 dimensions, euclidean distance), for AnnFiltered (without correlated filters).
#
# The data is downloaded from sift-data/ in the S3 folder (a local copy in sift-data/ is used if present).
# The schemas are in schemas/sift_<name>/test.sd.
module DatasetSift
  include DatasetBase

  # The data files in the .fvecs format (little-endian records [int32 128, 128 float32], see AnnBase.find_or_download_file).
  DOCS_FILE = "sift_base.fvecs" # 1M document vectors
  QUERIES_FILE = "sift_query.fvecs" # 10k query vectors (not among the documents)
  NUM_DOCUMENTS = 1_000_000

  def find_data_file(name, node)
    find_or_download_file("sift-data/" + name, node)
  end

  def max_num_documents
    NUM_DOCUMENTS
  end

  def doc_vector_files(node)
    [find_data_file(DOCS_FILE, node)]
  end

  def query_vector_file(node)
    find_data_file(QUERIES_FILE, node)
  end

end
