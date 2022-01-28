# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'
require 'environment'

class VisitUnknownDocTypeTest < MultiProviderStorageTest

  def self.testparameters
    { "DUMMY" => { :provider => "DUMMY" } }
  end

  def setup
    @progressFile = "#{Environment.instance.vespa_home}/tmp/progress_unknowndoctype"
    set_owner("vekterli")

    deploy_app(default_app.distribution_bits(8)) # To get 256 super buckets

    set_expected_logged(/Document type '?music'? not found/)
    start
  end

  def visit_failure(selection, skipbucketsonfatalerrors=false, progress=false, bucketsvisitedcount=-1, removeprogressfile=false)
    args = ""

    if (selection != nil && selection != "")
      args += " --selection \"" + selection + "\" "
    end
    if (skipbucketsonfatalerrors == true)
      args += " --skipbucketsonfatalerrors"
    end
    if (progress == true)
      args += " --progress #{@progressFile}"
    end

    assert_raise(ExecuteError) do
      vespa.adminserver.execute("vespa-visit --xmloutput" + args)
    end

    if (progress == true && bucketsvisitedcount != -1)
      progress_file = vespa.storage["storage"].storage["0"].execute("cat #{@progressFile}")
      visited_buckets = progress_file.split(/\n/)[3].to_i # Finished buckets
      assert_equal(bucketsvisitedcount, visited_buckets)
    end
    if (progress == true && removeprogressfile == true)
      vespa.storage["storage"].storage["0"].execute("rm -f #{@progressFile}*")
    end
  end

  def test_unknown_doc_type
    vespa.adminserver.logctl("searchnode:proton.server.protonconfigurer", "debug=on")
    vespa.document_api_v1.put(Document.new("music", "id:storage_test:music:n=1234:1"))
    vespa.document_api_v1.put(Document.new("music", "id:storage_test:music:n=1234:2"))

    deploy_app(default_app("movie").validation_override("content-type-removal")
                                   .distribution_bits(8)) # To get 256 super buckets

    # Deploy app does not wait for config to be active. Waiting a while in hopes
    # for it to become active. See bug 6466243 for better solution
    sleep(10)

    # Visiting fails on bucket with data, can't accept music documents.
    visit_failure("")

    # Visiting fails on bucket with data, can't use music in docselection
    visit_failure("music")

    # Visiting skips bucket with data, can't accept music documents.
    visit_failure("", true, true, 255)

    # Visiting should fail again when using the same progress file
    visit_failure("", true, true, 255, true)

    # Visiting skips bucket with data, can't use music in docselection
    visit_failure("music", true, true, 255)

    # Visiting should fail again when using the same progress file
    visit_failure("music", true, true, 255, true)
  end

  def teardown
    begin
      vespa.storage["storage"].storage["0"].execute("rm -f #{@progressFile}*")
    ensure
      stop
    end
  end

end
