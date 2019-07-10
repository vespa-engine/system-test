# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'docproc_test'
require 'simpledocument'

class DocprocHttpHandler < DocprocTest

  def setup
    set_owner("havardpe")
    set_description("Tests that it is possible to feed to a handler running in docproc container.")
    add_bundle(DOCPROC + "v3docprocs/WorstMusicDocProc.java")
    add_bundle(selfdir + "/HttpDocprocHandler.java")
    deploy(selfdir + "/app");
    start
  end

  def test_docproc_http_handler
    container = vespa.container.values.first
    wait_until_httphandler_ready(container)

    response = https_client.post(container.name, container.http_port,'/HttpDocproc', \
                         '<document id="id:this:music::is:a:music:document" type="music"><title>Best of Wenche Myhre</title></document>',
                         headers: {'Content-Type' => 'text/xml'})

    assert_equal(response.message, "OK")
    assert_equal(response.code, "200")

    doc = REXML::Document.new(response.body)
    sd = SimpleDocument.new(doc.elements[1].attributes["documenttype"],
      doc.elements[1].attributes["documentid"],
      response.body)
    doc.elements[1].elements.each { |elem|
      sd.add_field(elem.name, elem.text)
    }

    assert_equal(sd.documenttype, "music")
    assert_equal(sd.documentid, "id:this:music::is:a:music:document")
    assert_equal(sd.attributes.size, 1.to_i)
    assert_equal(sd.attributes["title"], "Worst music ever")
  end

  def wait_until_httphandler_ready(container, timeout = 60)
    port = container.http_port
    output("Wait until docproc HTTP handler ready at port " + port.to_s + " ...")
    endtime = Time.now.to_i + timeout.to_i
    while Time.now.to_i < endtime
       begin
         status = https_client.get(container.name, container.http_port, '/HttpDocproc')
       rescue StandardError => e
         sleep 0.1
         if Time.now.to_i < endtime
           retry
         else
           raise e
         end
       end
       if status.body =~ /Premature end of file/
         output("Docproc HTTP handler ready.")
         return true
       end
       sleep 0.1
    end
    raise "Timeout while waiting for docproc HTTP handler to become ready."
  end

  def teardown
    stop
  end

end
