# Private reason: Depends on artifactory

require 'config_test'
require 'app_generator/search_app'

class UrlDownloadTest < ConfigTest

  def setup
    set_owner("lesters")
    set_description("Tests downloading files from urls")
    @valgrind = false
  end

  def teardown
    stop
  end

  def test_url_downloading
    add_bundle_dir(selfdir + "bundle", "app")
    deploy(selfdir + "/app")
    start
    container = vespa.container.values.first

    result = container.http_get2("/test/numfiles")
    puts "Number of downloaded files: " + result.body

    assert(result.code == "200")
    assert(result.body.to_i == 3)

    result = container.http_get2("/test/")

    assert(result.code == "200")
    assert(result.body.length > 0)
    assert(result.body.include? "cells")
  end

end
