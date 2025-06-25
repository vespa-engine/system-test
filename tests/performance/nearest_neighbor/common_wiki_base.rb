# Copyright Vespa.ai. All rights reserved.

require 'performance/fbench'
require 'performance/nearest_neighbor/common_ann_base'

class CommonWikiBase < CommonAnnBaseTest

  FBENCH_TIME = 30

  def initialize(*args)
    super(*args)

    # The data set used is Wikipedia simple english from December 2022:
    # https://huggingface.co/datasets/Cohere/wikipedia-22-12-simple-embeddings
    # This consists of 485851 paragraphs across 187340 wikipedia documents.
    # Two feed files are prepared:
    #   - wiki_docs: 187340 documens with multiple vector embeddings (paragraphs) per document.
    #   - paragraph_docs: 485851 documents with one vector embedding (paragraph) per document.
    #
    # The feed files are manually created by:
    #   1) Feed the documents with text data to Vespa using the embed indexing operation to generate embeddings.
    #   2) Visit the entire corpus to extract the documents with embeddings.
    #
    # Details:
    # To create text feed files without embeddings:
    #   1) Download the 4 parquet files from https://huggingface.co/datasets/Cohere/wikipedia-22-12-simple-embeddings/tree/main/data
    #      and place them in wiki/
    #   2) python3 create_docs.py wiki > wiki_docs.text.json
    #   3) python3 create_docs.py paragraph > paragraph_docs.text.json
    #
    # To create feed files with embeddings:
    #   1) Edit the wiki.sd and paragraph.sd files to include the 'embedding' field outside the document block and remove the field inside.
    #   2) Run the performance tests (one at a time) with '--nostop' and wiki_docs.text.json and paragraph_docs.text.json as feed files.
    #   3) Visit the entire corpus:
    #       vespa-visit --shorttensors -v -m 16 --fieldset "[all]" > wiki_docs.visit.json
    #       vespa-visit --shorttensors -v -m 16 --fieldset "[all]" > paragraph_docs.visit.json
    #   4) Sort the feed files to avoid bucket id order:
    #       cat wiki_docs.visit.json | python3 sort_docs.py > wiki_docs.all.json
    #       cat paragraph_docs.visit.json | python3 sort_docs.py > paragraph_docs.all.json
    #
    #
    # The queries are from a Natural Questions dataset fra Google (3452 questions), provided by bergum.
    # To create the query file (queries.txt):
    #   1) Run one of the performance tests with '--nostop'.
    #   2) Feed the questions documents:
    #       cat wiki/question_docs.text.json | vespa-feed-perf
    #   3) Visit the entire corpus:
    #       vespa-visit --shorttensors -v -m 16 --fieldset "[all]" > question_docs.visit.json
    #   4) cat question_docs.visit.json | python3 create_queries.py > queries.txt
    #

    @data_path = "wiki-data/"
    @wiki_docs = @data_path + "wiki_docs.all.json"
    @paragraph_docs = @data_path + "paragraph_docs.all.json"
    @queries = @data_path + "queries.txt"
  end

  def run_wiki_test(feed_file, doc_type)
    deploy(selfdir + "wiki/app/")
    start
    @container = vespa.container.values.first

    feed_and_benchmark(feed_file, "docs", doc_type, "embedding")
    query_and_benchmark(doc_type)
  end

  def query_and_benchmark(doc_type)
    algorithm = "hnsw"
    target_hits = 100
    explore_hits = 0
    label = "#{algorithm}-th#{target_hits}-eh#{explore_hits}"
    query_file = fetch_query_file_to_container()
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, "query"),
               parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(TARGET_HITS, target_hits),
               parameter_filler(EXPLORE_HITS, explore_hits)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => 1,
                 :append_str => "&restrict=#{doc_type}",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -10 #{result_file}")
  end

  def fetch_query_file_to_container()
    proxy_file = nn_download_file(@queries, @container)
    puts "Got on container: #{proxy_file}"
    return proxy_file
  end

end
