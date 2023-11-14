# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'

class SimpleHTTPFeeder
  def initialize(testcase, qrserver, document_api_v1,
                 doc_type, id_prefix, field)
    @testcase = testcase
    @qrserver = qrserver
    @document_api_v1 = document_api_v1
    @doc_type = doc_type
    @id_prefix = id_prefix
    @field = field
  end

  def puts(str)
    @testcase.puts(str)
  end

  def docquery(i)
    timeout = @testcase.valgrind ? 60 : 5
    "/search/?query=w#{i.to_s}&nocache&hits=0&ranking=unranked&format=xml&timeout=#{timeout}"
  end

  def gen_docid(i)
    @id_prefix + i.to_s
  end
 
  def get_doccount(i)
    dq = docquery(i)
    @qrserver.search(dq).hitcount
  end

  def assert_doccount(i, expected)
    @testcase.assert_equal(expected, get_doccount(i),
                           "Query returned unexpected number of hits.")
  end

  def wait_doccount(i, expected)
    start = Time.now.to_i
    while Time.now.to_i < start + 60
      count = get_doccount(i)
      if count == expected
        return true
      end
      sleep 0.01
    end
    fail("Timeout after 60s: Expected #{i} docs, got #{count}")
  end

  def gen_doc_docid(i, docid)
    Document.new(@doc_type, docid).add_field(@field, "w#{i.to_s}")
  end

  def gen_doc(i)
    gen_doc_docid(i, gen_docid(i))
  end

  def gen_and_put_doc(i, verbose = false)
    doc = gen_doc(i)
    @document_api_v1.put(doc, :brief => !verbose)
  end
end
