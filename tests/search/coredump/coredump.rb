# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class CoreDump < SearchTest

  def setup
    set_description("Test that coredump control and limiting works")
    set_owner("balder")
    @valgrind = false
    @coredump_sleep = 30
  end

  def test_coredump_compression
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    corefile = "vespa-proton-bi.core." + pid + ".lz4"
    fullcorefile = "#{Environment.instance.vespa_home}/var/crash/" + corefile
    before = vespa.adminserver.execute("find #{Environment.instance.vespa_home}/var/crash/ -name " + corefile).strip
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    after = vespa.adminserver.execute("find #{Environment.instance.vespa_home}/var/crash/ -name " + corefile).strip
    assert_equal("", before)
    assert_equal(fullcorefile, after)
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("data", filetype)
    vespa.adminserver.execute("#{Environment.instance.vespa_home}/bin64/lz4 -d < " + fullcorefile + " > #{fullcorefile}.core")
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + ".core | cut -d ',' -f1").strip
    assert_equal("ELF 64-bit LSB core file x86-64", filetype)
    vespa.adminserver.execute("rm #{fullcorefile} #{fullcorefile}.core")
  end

  def test_coredump_overwrite
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|#{Environment.instance.vespa_home}/bin/vespa-core-dumper /bin/gzip #{Environment.instance.vespa_home}/var/crash/%e.core.gz\"")
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    corefile = "vespa-proton-bi.core.gz"
    fullcorefile = "#{Environment.instance.vespa_home}/var/crash/" + corefile
    vespa.adminserver.execute("cat /var/log/messages | gzip > /tmp/var_log_messages_before.gz")
    vespa.adminserver.execute("touch " + fullcorefile)
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("empty", filetype)

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|#{Environment.instance.vespa_home}/bin/vespa-core-dumper /bin/gzip #{Environment.instance.vespa_home}/var/crash/%e.core.gz overwrite\"")
    wait_for_hitcount("query=sddocname:music", 10000)
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("gzip compressed data", filetype)
    filetype = vespa.adminserver.execute("file -b -z " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("ELF 64-bit LSB core file x86-64", filetype)

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|#{Environment.instance.vespa_home}/bin/vespa-core-dumper #{Environment.instance.vespa_home}/bin64/lz4 #{Environment.instance.vespa_home}/var/crash/%e.core.%p.lz4\"")
    vespa.adminserver.execute("rm " + fullcorefile)
    vespa.adminserver.execute("cat /var/log/messages | gzip > /tmp/var_log_messages_after.gz")
    num_messages = vespa.adminserver.execute("zdiff /tmp/var_log_messages_before.gz /tmp/var_log_messages_after.gz | grep 'vespa-core-dumper' | wc -l").strip.to_i
    vespa.adminserver.execute("rm /tmp/var_log_messages_before.gz /tmp/var_log_messages_after.gz")
    assert_equal(5, num_messages)
  end

  def test_application_mmaps_in_core_limiting
    deploy("#{selfdir}/app")
    start
  end

  def teardown
    stop
  end

end
