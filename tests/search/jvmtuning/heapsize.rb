# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'docproc_test'
require 'search_test'

class HeapSize < SearchTest

  def setup
    set_owner("balder")
  end

  def test_jvm_default_heap_size()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").qrserver(QrserverCluster.new))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms1536m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx1536m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=267m/)
  end

  def test_jvm_absolute_heap_size_by_jvmargs()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").
                         qrserver(QrserverCluster.new.jvmargs("-Xms1024m -Xmx2048m")))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms1024m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx2048m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=267m/)
  end

  def test_jvm_absolute_heap_size_by_jvmargs_is_not_capped()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").
                         qrserver(QrserverCluster.new.jvmargs("-Xms384m -Xmx512m")))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms384m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx512m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=267m/)
  end

  def test_jvm_absolute_heap_size_by_heapsize()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").qrserver(QrserverCluster.new).
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('heapsize', '2048'))))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms2048m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx2048m/)
    maxdirect = 2048/8 + 75 + 0 # Taken from the startup scrip.
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def test_jvm_absolute_heap_size_by_heapsize_is_capped()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").qrserver(QrserverCluster.new).
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('heapsize', '512'))))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms512m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx512m/)
    maxdirect = 512/8 + 75 + 0 # Taken from the startup scrip.
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def test_jvm_relative_heap_size()
    deploy_app(SearchApp.new.sd(selfdir+"foo.sd").qrserver(QrserverCluster.new).
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('heapSizeAsPercentageOfPhysicalMemory', '40'))))
    start
    free = vespa.adminserver.execute("free -m | grep Mem | tr -s ' ' | cut -f2 -d' '")
    puts "Free memory = " + free
    relative = free.to_i * 40 / 100
    puts "Relative memory for container " + relative.to_s
    maxdirect = relative/8 + 75 + 0 # Taken from the startup scrip.
    puts "MaxDirectMemorySize should be " + maxdirect.to_s
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xms#{relative}m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-Xmx#{relative}m/)
    assert(vespa.adminserver.execute("ps auxwww | grep qrserver | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def teardown
    stop
  end

end
