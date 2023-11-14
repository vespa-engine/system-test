# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'document'
require 'document_set'

class SimpleDocGenerator
  attr_reader :doc_type

  def initialize(doc_type, id_prefix)
    @doc_type = doc_type
    @id_prefix = id_prefix
  end

  def generate(doc_begin, num_docs, mods = [2, 3, 5, 7, 11])
    ds = DocumentSet.new()
    for i in doc_begin..doc_begin + num_docs - 1 do
      doc = Document.new(@doc_type, @id_prefix + i.to_s)
      w = []
      mods.each do |mod|
        w.push("w#{mod}w#{i % mod}")
      end
      doc.add_field("i1", w.join(" "))
      doc.add_field("a1", i)
      ds.add(doc)
    end
    return ds
  end
end

class AddPartition < SearchTest

  def setup
    set_owner("toregge")
    set_description("Test growing cluster by adding partitions")
    @doc_type = "addpartition"
    @id_prefix = "id:test:#{@doc_type}::"
  end

  def enable_proton_debug_log(index)
    proton = vespa.search["search"].searchnode[index]
    proton.logctl2("proton.server.storeonlyfeedview", "all=on")
    proton.logctl2("proton.persistenceengine.persistenceengine", "all=on")
  end

  def test_addpartition
    deploy_app(SearchApp.new.sd(selfdir + "addpartition.sd"))
    dg = SimpleDocGenerator.new(@doc_type, @id_prefix)
    docs1 = dg.generate(0, 10)
    docs2 = dg.generate(10, 10)
    docs1.write_xml("add1")
    docs1.write_rm_xml("rm1")
    docs2.write_xml("add2")
    docs2.write_rm_xml("rm2")
    start
    enable_proton_debug_log(0)
    proton = vespa.search["search"].first
    proton.logctl("searchnode2:proton.server.storeonlyfeedview", "all=on")
    proton.logctl("searchnode2:proton.persistenceengine.persistenceengine",
	 "all=on")
    feed(:file => "add1", :timeout => 240)
    wait_for_hitcount("query=sddocname:addpartition", 10)
    @leave_loglevels = true
    vespa.stop
    @leave_loglevels = false
    deploy_app(SearchApp.new.sd(selfdir + "addpartition.sd").
	              search_type("ELASTIC").num_parts(2),
	              :no_init_logging => true)
    vespa.start
    enable_proton_debug_log(0)
    enable_proton_debug_log(1)
    wait_for_hitcount("query=sddocname:addpartition", 10)
    feed(:file => "add2", :timeout => 240)
    wait_for_hitcount("query=sddocname:addpartition", 20)
    feed(:file => "rm1", :timeout => 240)
    wait_for_hitcount("query=sddocname:addpartition", 10)
    feed(:file => "rm2", :timeout => 240)
    wait_for_hitcount("query=sddocname:addpartition", 0)
  end

  def teardown
    stop
  end
end

