# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'environment'

# install gbdt
class GbdtConverter < IndexedSearchTest

  PATH = "/tmp/gbdtconverter#{}"

  def setup
    set_owner("yngve")
    set_description("Ensure that vespa-gbdt-converter works as intended.")
  end

  def test_gbdt_converter
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start

    vespa.adminserver.execute("cp -r #{Environment.instance.vespa_home}/share/gbdt #{PATH}")
    vespa.adminserver.execute("cd #{PATH} && #{Environment.instance.vespa_home}/bin64/gbdt gbdt.cfg")
    vespa.adminserver.execute("cd #{PATH}/result && vespa-gbdt-converter gbdt.xml")
  end

  def teardown
    stop
  end
end

