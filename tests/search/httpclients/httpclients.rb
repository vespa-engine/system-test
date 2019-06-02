# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class HttpClients < IndexedSearchTest
  attr_reader :resultfile
  attr_reader :outputfile

  def setup
    set_owner("bjorncs")
    set_description("Tests querying Vespa from various HTTP clients.")
    @resultfile = dirs.tmpdir+"result.xml"
    @outputfile = dirs.tmpdir+"output"
    @script = dirs.tmpdir+"httpclient.py"
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")
    # copy scrape script and result file to node running test
    vespa.adminserver.copy("#{selfdir}/httpclient.py", "#{dirs.tmpdir}")
    vespa.adminserver.copy("#{selfdir}/result.xml", "#{dirs.tmpdir}")
  end

  def test_httpclients
    vespa.adminserver.execute("rm -f #{@outputfile}")

    qrserver = vespa.container.values.first
    hname = qrserver.name
    sport = qrserver.http_port

    query = "search/?query=sddocname:music&hits=1&timeout=30&format=xml"
    httpquery("#{@script} \"http://#{hname}:#{sport}/#{query}\" | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
    httpquery("wget -q -O -                      'http://#{hname}:#{sport}/#{query}' | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
    httpquery("wget -q -O - --no-http-keep-alive 'http://#{hname}:#{sport}/#{query}' | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
    httpquery("curl                          'http://#{hname}:#{sport}/#{query}' | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
    httpquery("curl -H \"Connection: Close\" 'http://#{hname}:#{sport}/#{query}' | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
    httpquery("curl -0                       'http://#{hname}:#{sport}/#{query}' | sed 's/ coverage-docs=.*\">/>/g' > #{@outputfile}")
  end

  def httpquery(command)
    10.times do
      vespa.adminserver.execute(command)
      if $?.exitstatus == 0
        break
      end
    end
    vespa.adminserver.execute("diff -Bu #{@resultfile} #{@outputfile}")
    vespa.adminserver.execute("rm -f #{@outputfile}")
  end

  def teardown
    stop
  end

end
