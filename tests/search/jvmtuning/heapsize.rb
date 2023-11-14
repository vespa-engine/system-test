# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'app_generator/container_app'

class HeapSize < SearchTest

  def setup
    set_owner("balder")
  end

  def make_app(with_jvm_options = nil)
    app = ContainerApp.new.
            container(Container.new('foo-bar').
                        jvmoptions(with_jvm_options))
  end

  def test_jvm_default_heap_size()
    deploy_app(make_app)
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms1536m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx1536m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=208m/)
  end

  def test_jvm_absolute_heap_size_by_jvm_options()
    deploy_app(make_app('-Xms1024m -Xmx2048m'))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms1024m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx2048m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=208m/)
  end

  def test_jvm_absolute_heap_size_by_jvm_options_is_not_capped()
    deploy_app(make_app('-Xms384m -Xmx512m'))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms384m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx512m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=208m/)
  end

  def test_jvm_absolute_heap_size_by_heapsize()
    deploy_app(make_app.
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('minHeapsize', '1600')).
                                               add('jvm', ConfigValue.new('heapsize', '2048'))))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms1600m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx2048m/)
    maxdirect = 2048/8 + 16 + 0 # Taken from the startup script.
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def test_jvm_absolute_min_heap_size_by_is_capped_at_heapsize()
    deploy_app(make_app.
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('minHeapsize', '2600')).
                                               add('jvm', ConfigValue.new('heapsize', '2048'))))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms2048m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx2048m/)
    maxdirect = 2048/8 + 16 + 0 # Taken from the startup script.
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def test_jvm_absolute_heap_size_by_heapsize_is_capped()
    deploy_app(make_app.
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('minHeapsize', '512')).
                                               add('jvm', ConfigValue.new('heapsize', '512'))))
    start
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms512m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx512m/)
    maxdirect = 512/8 + 16 + 0 # Taken from the startup script.
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def test_jvm_relative_heap_size()
    deploy_app(make_app.
                         config(ConfigOverride.new('search.config.qr-start').
                                               add('jvm', ConfigValue.new('heapSizeAsPercentageOfPhysicalMemory', '40'))))
    start
    free = vespa.adminserver.execute("free -m | grep Mem | tr -s ' ' | cut -f2 -d' '").to_i
    begin
      cglimit_bytes = vespa.adminserver.execute("cgget -nv -r memory.limit_in_bytes / 2>&1").to_i
      cglimit = cglimit_bytes >> 20
      free = [free, cglimit].min
    rescue
      # Ignored
    end

    puts "Free memory = " + free.to_s
    relative = (free - 1024) * 40 / 100
    puts "Relative memory for container " + relative.to_s
    maxdirect = relative/8 + 16 + 0 # Taken from the startup script.
    puts "MaxDirectMemorySize should be " + maxdirect.to_s
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xms#{relative}m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-Xmx#{relative}m/)
    assert(vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep") =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/)
  end

  def teardown
    stop
  end

end
