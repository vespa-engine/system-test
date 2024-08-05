# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'environment'

class ComponentManyBundles < SearchContainerTest

  def timeout_seconds
    return 2400
  end

  def setup
    set_owner("gjoranv")
    set_description("Verifies that an application with many bundles can be successfully (re)deployed.")
    $num_handlers = 0
  end

  def enable_all_log_levels
    vespa.container.values.first.logctl("qrserver", "all=on")
  end

  def add_handler_bundles(app_dir, num_handlers)
    @project_dir = dirs.tmpdir + "project/"
    system("mkdir -p " + @project_dir + app_dir)
    system("cp -r #{selfdir}#{app_dir} #{@project_dir}")
    system("rm -rf  #{@project_dir}handler0")
    FileUtils.cp_r(selfdir+"handler0", @project_dir)

    clear_bundles
    handler = []
    for i in (0..num_handlers-1)
      if i > 0
        system("mkdir -p #{@project_dir}handler#{i}/src/main/java/com/yahoo/vespatest/")
        text = File.read(@project_dir+"handler0/src/main/java/com/yahoo/vespatest/Handler0.java")
        newtext = text.gsub(/Handler0/, "Handler#{i}")
        File.open(@project_dir+"handler#{i}/src/main/java/com/yahoo/vespatest/Handler#{i}.java", "w") {|file| file.puts newtext}
      end
      handler[i] = add_bundle_dir(@project_dir+"handler#{i}", "com.yahoo.vespatest.Handler#{i}", :name => "handler#{i}")
    end
    compile_bundles(@vespa.nodeproxies.values.first)
    deploy(@project_dir + app_dir, nil, :bundles => handler)
  end

  def test_many_bundles
    $num_handlers = 2
    deploy_output = add_handler_bundles("app", $num_handlers)

    start
    #enable_all_log_levels

    verify_all_handler_responses_and_remove_dirs($num_handlers, deploy_output)

    $num_handlers = 6
    puts ">>>>>>>>>>>> Deploying the 2. set of bundles with #{$num_handlers} handlers"
    deploy_output = add_handler_bundles("app2", $num_handlers)
    verify_all_handler_responses_and_remove_dirs($num_handlers, deploy_output)

    $num_handlers = 12
    puts ">>>>>>>>>>>> Deploying the 3. set of bundles with #{$num_handlers} handlers"
    deploy_output = add_handler_bundles("app3", $num_handlers)
    verify_all_handler_responses_and_remove_dirs($num_handlers, deploy_output)

    $num_handlers = 2
    puts ">>>>>>>>>>>> Re-deploying the 1. set of bundles with #{$num_handlers} handlers"
    deploy_output = add_handler_bundles("app", $num_handlers)
    verify_all_handler_responses_and_remove_dirs($num_handlers, deploy_output)
  end

  def verify_all_handler_responses_and_remove_dirs(num_handlers, deploy_output)
    for i in (0..num_handlers-1)
      verify_handler_response("Handler#{i}", deploy_output)
    end
  end

  def verify_handler_response(expected, deploy_output)
    container = vespa.container.values.first
    wait_for_application(container, deploy_output)

    result = container.search("/#{expected}")
    if expected == result.xmldata
      puts "Got expected response: #{expected}"
      return;
    end

    puts "Test failed: Did not get expected result: #{expected}, got: #{result.xmldata}"
    puts "Waiting to see how long it takes to get expected result."
    ok = false
    count = 0
    while (count < 10)
      begin
        count = count + 1
        result = container.search("/#{expected}")
        if expected == result.xmldata
          puts "Got #{expected} after #{count} seconds"
          ok = true
          break
        else
          puts "& Try #{count}: result: #{result.xmldata}, expected: #{expected}"
        end
        sleep 1
      end
    end
    if !ok
      puts "xxxxxxxxxxxxx  Writing jstack output to file   xxxxxxxxxxxxxx"
      qrsPid = container.execute("pgrep -f -o prelude")
      f = File.new(dirs.tmpdir+"/jstack.out", "w")
      f.puts(container.execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} jstack -l #{qrsPid}"))
      f.close
    end
    flunk "Did not get expected response"
  end

  def teardown
    stop
  end
end
