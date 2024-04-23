# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'

class WandDocGenerator

  def handle_put_doc(wordid, docid)
    word = "a#{wordid}"
    @words[word].push([get_docid(docid),docid])
    return word
  end

  def get_docid(docid)
    return "id:test:test::" + "%05d" % docid
  end

  attr_reader :words

  def initialize(mod)
    @mod = mod
    @words = {}
    for i in 0...@mod
      j = i % @mod
      # unique set of words for puts
      @words["a#{j}"] = []
    end
  end

  def gen_doc_set(docid_begin, num_docs, gen_func)
    ds = DocumentSet.new()
    for i in docid_begin...docid_begin + num_docs do
      doc = Document.new("test", get_docid(i))
      send(gen_func, doc, i)
      ds.add(doc)
    end
    return ds
  end

  def ranking_gen_func(doc, docid)
      word = handle_put_doc(docid % @mod, docid)
      doc.add_field("features", [[word, docid]])
  end

  def gen_ranking_docs(docid_begin, num_docs)
    return gen_doc_set(docid_begin, num_docs, :ranking_gen_func)
  end
     
  def filter_gen_func(doc, docid)
      word = handle_put_doc(docid % @mod, docid)
      doc.add_field("features", [["all", docid]])
      doc.add_field("filter", word)
  end

  def gen_filter_docs(docid_begin, num_docs)
    return gen_doc_set(docid_begin, num_docs, :filter_gen_func)
  end

  def wand_no_hit(doc)
    doc.add_field("features", [["nohit", 1]])
    doc.add_field("filter", "hit")
  end

  def wand_good_hit(doc)
    doc.add_field("features", [["hit", 100]])
    doc.add_field("filter", "nohit")
  end

  def wand_bad_hit(doc)
    doc.add_field("features", [["hit", 1]])
    doc.add_field("filter", "hit")
  end

  def wand_filter_test_gen_func(doc, docid)
    if docid <= 40
      if docid % 2 == 1
        wand_no_hit(doc)
      else
        wand_good_hit(doc)
      end
    else
      wand_bad_hit(doc)
    end
  end

  def gen_wand_filter_test_docs(docid_begin, num_docs)
    return gen_doc_set(docid_begin, num_docs, :wand_filter_test_gen_func)
  end

end

