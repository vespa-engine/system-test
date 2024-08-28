require 'config_test'
require 'search_test'
require 'environment'

class ConfigProxyCmd < CloudConfigTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_description("Test vespa-configproxy-cmd")
    set_owner("musum")
  end

  def test_dumpcache
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start

    node = vespa.adminserver
    dumpdir = "/tmp/proxy.cache.dump"

    node.execute("mkdir -p #{dumpdir}; chown #{Environment.instance.vespa_user} #{dumpdir}")
    assert_equal("success\n", node.execute("vespa-configproxy-cmd -m dumpcache #{dumpdir}"))
    node.execute("ls -lA #{dumpdir}")
    node.execute("rm -rf #{dumpdir}")
  end

  def test_cache_and_cachefull
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    node = vespa.adminserver
    hostname = node.hostname

    output = node.execute("vespa-configproxy-cmd -m cache 2>/dev/null | grep cloud.config.log.logd")
    assert_equal(output.lines.count, 1)

    output = node.execute("vespa-configproxy-cmd -m cachefull 2>/dev/null | grep cloud.config.log.logd")
    assert_match(/cloud.config.log.logd,hosts\/#{hostname}\/logd,\d+,MD5:\w{32},XXHASH64:\w/, output)
    assert_match(/"logserver":{"host":"#{hostname}"/, output)
  end

  def test_sources
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start

    node = vespa.configservers["0"]
    hostname = node.hostname
    port = node.ports[0]
    expected = <<EOS
Current source: tcp/#{hostname}:#{port}
All sources:
tcp/#{hostname}:#{port}

EOS
    assert_equal(expected, node.execute("vespa-configproxy-cmd -m sources"))

    # Update to new sources check that it had effect
    new_sources = "tcp/#{hostname}:19070,tcp/someotherhost:19070"
    expected = <<EOS
Updated config sources to: #{new_sources}
EOS
    assert_equal(expected, node.execute("vespa-configproxy-cmd -m updatesources #{new_sources}"))

    expected = <<EOS
Current source: tcp/.*
All sources:
tcp/#{hostname}:#{port}
tcp/someotherhost:19070

EOS
    assert_match(Regexp.new(expected), node.execute("vespa-configproxy-cmd -m sources"))
  end

  def teardown
    stop
  end

end
