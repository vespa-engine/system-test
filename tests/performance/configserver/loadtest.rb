require 'performance_test'
require 'performance/configserver/generator'

class ConfigserverLoadTest < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'app'
    @testfile = 'test.cfg'
    @defdir = "defbundle/src/main/resources/configdefinitions"
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def setup
    super
    set_owner("musum")
    set_description("Performance test of config server")
    FileUtils.cp_r(selfdir + "defbundle", @dirs.tmpdir)
  end

  def setup_generator(num_configs, num_fields, version)
    generator = Generator.new(num_configs, num_fields, version)
    generator.generate_def(dirs.tmpdir + @defdir)
    generator.generate_loadfile(dirs.tmpdir + @testfile)
  end

  def test_client_scaling
    setup_generator(150, 10, 1)

    copy_files_to_tmp_dir(vespa.nodeproxies.first[1])

    @node = @vespa.nodeproxies.first[1]
    # Set start and max heap equal to avoid a lot of GC while running test
    override_environment_setting(@node, "VESPA_CONFIGSERVER_JVMARGS", "-Xms2g -Xmx2g")
    deploy(@app)
    start

    node = @vespa.nodeproxies.first[1]
    num_requests_per_thread = 20000
    num_threads = 32
    loadtester = create_loadtester(node, node.name, 19070, num_requests_per_thread, num_threads, @dirs.tmpdir + @defdir)
    run_config_loadtester(loadtester, @dirs.tmpdir + @testfile)
  end

  def copy_files_to_tmp_dir(node)
    node.copy(dirs.tmpdir + @testfile, @dirs.tmpdir)
    node.copy(dirs.tmpdir + @defdir, @dirs.tmpdir + @defdir)
  end

  def teardown
    super
  end
end
