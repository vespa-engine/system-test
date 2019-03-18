# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class MalformedQueryReturns400 < ContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Check HTTP 400 is returned when sending malformed queries.")
  end

  def test_query_with_raw_space
    app = ContainerApp.new.container(
        Container.new.jetty(true))

    start(app)
    got_headers = "#{dirs.tmpdir}malformed_query_returns_400_headers"
    got_returncode = "#{dirs.tmpdir}malformed_query_returns_400_got"
    expected_returncode = "#{dirs.tmpdir}malformed_query_returns_400_expected"
    @container.copy("#{selfdir}expected_headers", "#{dirs.tmpdir}")

    @container.execute("rm -f #{got_headers} #{got_returncode} #{expected_returncode}")
    @container.execute("curl -D #{got_headers} \"http://localhost:#{@container.http_port}/t est\"")
    @container.execute("head -1 #{got_headers} >#{got_returncode}")
    @container.execute("head -1 #{dirs.tmpdir}expected_headers >#{expected_returncode}")
    @container.execute("diff -Bu #{expected_returncode} #{got_returncode}")
  end

  def teardown
    stop
  end

end
