# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/dataset_base'

# Data set module (see DatasetBase) for tests over the GIST data set (http://corpus-texmex.irisa.fr/, 1M document vectors and 1k query vectors
# with 960 dimensions, euclidean distance), for AnnFiltered (without correlated filters).
#
# The data is downloaded from gist-data/ in the S3 folder (a local copy in gist-data/ is used if present).
# The schemas are in schemas/gist_<name>/test.sd.
module DatasetGist
  include DatasetBase

  # The data files in the .fvecs format (little-endian records [int32 960, 960 float32], see AnnBase.find_or_download_file).
  DOCS_FILE = "gist_base_300k.fvecs" # The first 300k of the 1M document vectors
  QUERIES_FILE = "gist_query.fvecs" # 1k query vectors (not among the documents)
  NUM_DOCUMENTS = 300_000

  def find_data_file(name, node)
    find_or_download_file("gist-data/" + name, node)
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
