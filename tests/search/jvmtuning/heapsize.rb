# Copyright Vespa.ai. All rights reserved.
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
      cg1cmd = 'cgget -nv -r memory.limit_in_bytes /'
      cg2cmd = 'find /sys/fs/cgroup -name memory.max -print0 | xargs -0 grep -h -v max | sort -u'
      (cg1exitcode, cg1out) = vespa.adminserver.execute(cg1cmd, {:exitcode => true, :exceptiononfailure => false})
      (cg2exitcode, cg2out) = vespa.adminserver.execute(cg2cmd, {:exitcode => true, :exceptiononfailure => false})
      puts "cg1exitcode: #{cg1exitcode} out: #{cg1out}"
      puts "cg2exitcode: #{cg2exitcode} out: #{cg2out}"
      if cg1exitcode.to_i == 0
        puts "Using output from cgget: #{cg1out}"
        cglimit_bytes = cg1out.to_i
        cglimit = cglimit_bytes >> 20
        free = [free, cglimit].min
      elsif cg2exitcode.to_i == 0
        puts "Using output from /sys/fs/cgroup grep: #{cg2out}"
        cglimit_bytes = cg2out.to_i
        cglimit = cglimit_bytes >> 20
        free = [free, cglimit].min
      end
    rescue
      # Ignored
    end

    puts "Free memory = " + free.to_s
    relative = (free - 700) * 40 / 100
    puts "Relative memory for container " + relative.to_s
    maxdirect = relative/8 + 16 + 0 # Taken from the startup script.
    puts "MaxDirectMemorySize should be " + maxdirect.to_s
    ps_output = vespa.adminserver.execute("ps auxwww | grep 'foo[-]bar' | grep -v grep")
    assert(ps_output =~ /-Xms#{relative}m/, "Expected to find '-Xms#{relative}m' in output: #{ps_output}")
    assert(ps_output =~ /-Xmx#{relative}m/, "Expected to find '-Xmx#{relative}m' in output: #{ps_output}")
    assert(ps_output =~ /-XX:MaxDirectMemorySize=#{maxdirect}m/, "Expected to find '-XX:MaxDirectMemorySize=#{maxdirect}m' in output: #{ps_output}")
  end

  def teardown
    stop
  end

end
