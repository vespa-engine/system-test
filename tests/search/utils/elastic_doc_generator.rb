# Copyright Vespa.ai. All rights reserved.
require 'document'
require 'documentupdate'
require 'document_set'

class ElasticDocGenerator
  def self.generate_docs(doc_begin, num_docs, content=nil)
    doc_ids = []
    for i in doc_begin...(doc_begin + num_docs) do
      doc_ids.push("id:test:test::#{i}")
    end
    return generate_docs_base(doc_ids, content)
  end

  def self.generate_random_docs(doc_begin, doc_end, num_docs, content=nil)
    doc_ids = []
    for i in doc_begin...doc_end do
      doc_ids.push("id:test:test::#{i}")
    end
    return generate_docs_base(doc_ids.shuffle.take(num_docs), content)
  end

  def self.generate_docs_base(doc_ids, content=nil)
    if content.nil?
      content = { :field1 => 'word', :field2 => '2000' }
    end
    ds = DocumentSet.new()
    doc_ids.each do | doc_id |
      doc = Document.new("test", doc_id)
      doc.add_field("f1", content[:field1])
      doc.add_field("f2", content[:field2])
      ds.add(doc)
    end
    return ds
  end

  def self.generate_updates(doc_begin, num_docs, assign_value = 2012)
    ds = DocumentSet.new()
    for i in doc_begin...(doc_begin + num_docs) do
      upd = DocumentUpdate.new("test", "id:test:test::#{i}")
      upd.addOperation("assign", "f2", assign_value)
      ds.add(upd)
    end
    return ds
  end

  def self.write_docs(doc_begin, num_docs, file_name, content=nil)
    generate_docs(doc_begin, num_docs, content).write_json(file_name)
  end

  def self.write_removes(doc_begin, num_docs, file_name)
    generate_docs(doc_begin, num_docs).write_removes_json(file_name)
  end

  def self.write_random_removes(doc_begin, doc_end, num_removes, file_name)
    generate_random_docs(doc_begin, doc_end, num_removes).write_removes_json(file_name)
  end

  def self.write_updates(doc_begin, num_docs, file_name, assign_value = 2012)
    generate_updates(doc_begin, num_docs, assign_value).write_updates_json(file_name)
  end

end

