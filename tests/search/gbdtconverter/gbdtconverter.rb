# Copyright Vespa.ai. All rights reserved.
require 'indexed_search_test'
require 'environment'

class GbdtConverter < IndexedSearchTest

  def setup
    set_owner("hmusum")
    set_description("Ensure that vespa-gbdt-converter works as intended.")
    @mytmpdir = dirs.tmpdir
  end

  def test_gbdt_converter
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start

    gbdt_output = File.open("#{selfdir}/gbdt.xml").read
    vespa.adminserver.writefile(gbdt_output, "#{@mytmpdir}/gbdt.xml")
    vespa.adminserver.execute("vespa-gbdt-converter #{@mytmpdir}/gbdt.xml")
  end


end
