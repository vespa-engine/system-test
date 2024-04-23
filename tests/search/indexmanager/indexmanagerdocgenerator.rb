# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'

class IndexManagerDocGenerator
  
  def get_put_word(wordid)
    return "a#{wordid}"
  end

  def get_update_word(wordid)
    return "b#{wordid}"
  end

  def handle_put_doc(wordid, docid)
    word = get_put_word(wordid)
    inc_word(word, docid)
    @doc_count += 1
    return word
  end

  def handle_update_doc(wordid, docid)
    word = get_update_word(wordid)
    inc_word(word, docid)
    dec_word(get_put_word(wordid), docid)
    return word
  end

  def handle_remove_doc(wordid, docid)
    word = get_put_word(wordid)
    dec_word(word, docid)
    @doc_count -= 1
    return word
  end

  def inc_word(word, docid)
    @words[word].push(get_docid(docid))
  end

  def dec_word(word, docid)
    @words[word].delete(get_docid(docid))
  end

  def get_docid(docid)
    return "id:test:test::" + "%05d" % docid
  end

  def put_words
    puts "words:"
    @words.each do |word,docids|
      puts "#{word}: #{docids.join(',')}"
    end 
  end

  attr_reader :words
  attr_reader :doc_count

  def initialize(mod = 5)
    @mod = mod
    @doc_count = 0
    @words = {}
    for i in 0...@mod
      j = i % @mod
      # unique set of words for puts
      @words[get_put_word(j)] = []
      # unique set of words for updates
      @words[get_update_word(j)] = []
    end
  end

  def gen_doc_set(docid_begin, num_docs, handle_doc_func)
    ds = DocumentSet.new()
    for i in docid_begin...docid_begin + num_docs do
      doc = Document.new("test", get_docid(i))
      word = send(handle_doc_func, i % @mod, i)
      doc.add_field("features", word => i+1)
      doc.add_field("staticscore", i+1)
      ds.add(doc)
    end
    return ds
  end

  def gen_puts(docid_begin, num_docs)
    gen_doc_set(docid_begin, num_docs, :handle_put_doc)
  end

  def gen_updates(docid_begin, num_docs)
    gen_doc_set(docid_begin, num_docs, :handle_update_doc)
  end

  def gen_removes(docid_begin, num_docs)
    gen_doc_set(docid_begin, num_docs, :handle_remove_doc)
  end

end

