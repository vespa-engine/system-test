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

  def get_lz4_program(node)
    lz4_program = "#{Environment.instance.vespa_home}/bin64/lz4"
    lz4_program = "/usr/bin/lz4" unless node.file_exist?(lz4_program)
    lz4_program
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
    lz4_program = get_lz4_program(vespa.adminserver)
    vespa.adminserver.execute("#{lz4_program} -d < " + fullcorefile + " > #{fullcorefile}.core")
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + ".core | cut -d ',' -f1").strip
    assert_equal("ELF 64-bit LSB core file x86-64", filetype)
    vespa.adminserver.execute("rm #{fullcorefile} #{fullcorefile}.core")
  end

  def test_coredump_overwrite
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.lz4\"")
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    corefile = "vespa-proton-bi.core.lz4"
    fullcorefile = "#{Environment.instance.vespa_home}/var/crash/" + corefile
    vespa.adminserver.execute("touch " + fullcorefile)
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("empty", filetype)

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 --force -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.lz4\"")
    wait_for_hitcount("query=sddocname:music", 10000)
    pid = vespa.adminserver.execute("pgrep vespa-proton-bi").strip
    vespa.adminserver.execute("/bin/kill -SIGSEGV " + pid)
    sleep @coredump_sleep
    filetype = vespa.adminserver.execute("file -b " + fullcorefile + " | cut -d ',' -f1").strip
    assert_equal("data", filetype)
    lz4_program = get_lz4_program(vespa.adminserver)
    vespa.adminserver.execute("#{lz4_program} -d < " + fullcorefile + " > #{fullcorefile}.core")
    filetype = vespa.adminserver.execute("file -b -z " + fullcorefile + ".core | cut -d ',' -f1").strip
    assert_equal("ELF 64-bit LSB core file x86-64", filetype)

    vespa.adminserver.execute("/sbin/sysctl kernel.core_pattern=\"|/usr/bin/lz4 -3 - #{Environment.instance.vespa_home}/var/crash/%e.core.%p.lz4\"")
    vespa.adminserver.execute("rm #{fullcorefile} #{fullcorefile}.core")
  end

  def test_application_mmaps_in_core_limiting
    deploy("#{selfdir}/app")
    start
  end

  def teardown
    stop
  end

end

