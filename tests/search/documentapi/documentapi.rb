# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DocumentApiTest < IndexedSearchTest

  def setup
    set_owner("valerijf")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_documentapi_java
    tmp = "#{dirs.tmpdir}/#{File.basename(selfdir)}"
    vespa.adminserver.copy("#{selfdir}/project", tmp)
    install_maven_parent_pom(vespa.adminserver)
    vespa.adminserver.execute("cd #{tmp}; #{maven_command} -Dtest.hide=false test")
  end

  def teardown
    stop
  end

end
