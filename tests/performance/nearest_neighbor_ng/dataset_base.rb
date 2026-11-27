# Copyright Vespa.ai. All rights reserved.

# The functionality shared by the data set modules (see AnnBase): feeding the documents and writing the queries with
# the generators, for AnnFiltered (without correlated filters) and AnnGeo.
#
# The documents have the tensor field 'embedding', and the queries search it with nearestNeighbor and the query tensor q_vec.
#
# The data set module includes this module and provides:
#   max_num_documents        the number of documents in the data set
#   doc_vector_files(node)   the .fvecs files with the document vectors on the node (see AnnBase.find_or_download_file)
#   query_vector_file(node)  the .fvecs file with the query vectors on the node
module DatasetBase

  # ---- Document generation ----

  # Feeds the documents printed by the command (a document generator, run on the admin server), which feeds the first
  # @num_documents vectors of the data set to the tensor field 'embedding'.
  def feed_documents(command)
    assert(@num_documents <= max_num_documents, "The data set has only #{max_num_documents} documents")
    feed_from_command(command, [parameter_filler("label", "#{@num_documents}-docs")])
    assert_hitcount("query=sddocname:test", @num_documents)
    report_nni_stats("test", "embedding")
  end

  # Feeds the documents with the field 'filter' for the hit ratios (see AnnFiltered).
  def feed_filtered_documents(hit_ratios)
    node = vespa.adminserver
    feed_documents("#{compile_generator("make_filtered_docs", node)} " +
                   "--vectors #{doc_vector_files(node).join(',')} --num-docs #{@num_documents} --tensor-field embedding " +
                   "--hit-ratios #{hit_ratios.join(',')}")
  end

  # Feeds the documents with the position field 'latlng' (see AnnGeo).
  def feed_geo_documents
    node = vespa.adminserver
    feed_documents("#{compile_generator("make_geo_docs", node)} " +
                   "--vectors #{doc_vector_files(node).join(',')} --num-docs #{@num_documents} --tensor-field embedding")
  end

  # ---- Query generation ----

  # Writes the queries printed by the command (a query generator, run on the container) for the benchmark to a file
  # (on the container), and returns the file. The values of the benchmark set the options of the nearestNeighbor
  # operator: :approximate (true for approximate search with HNSW, false for exact search), :target_hits, and :explore_hits.
  def write_queries(command, values)
    query_file = dirs.tmpdir + "queries.#{label(values)}.txt"
    container.execute("#{command} > #{query_file}")
    query_file
  end

  def write_unfiltered_queries(values)
    node = container
    write_queries("#{compile_generator("make_filtered_queries", node)} " +
                  "--vectors #{query_vector_file(node)} --num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                  "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                  "--explore-hits #{values.fetch(:explore_hits)}",
                  values)
  end

  def write_uncorrelated_queries(hit_ratio, values)
    node = container
    write_queries("#{compile_generator("make_filtered_queries", node)} " +
                  "--vectors #{query_vector_file(node)} --num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                  "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                  "--explore-hits #{values.fetch(:explore_hits)} " +
                  "--hit-ratio #{hit_ratio}",
                  values)
  end

  def write_geo_queries(radius, values)
    node = container
    write_queries("#{compile_generator("make_geo_queries", node)} " +
                  "--vectors #{query_vector_file(node)} --num-queries #{@num_queries_for_benchmark} --tensor-field embedding " +
                  "--approximate #{values.fetch(:approximate)} --target-hits #{values.fetch(:target_hits)} " +
                  "--explore-hits #{values.fetch(:explore_hits)} " +
                  "--radius #{radius}",
                  values)
  end

end
