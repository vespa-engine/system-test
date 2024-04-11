# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class Bug4659212 < VdsTest

  def setup
    set_owner("balder")
    set_description("Test for bug 4659212")
    deploy_app(default_app.sd(selfdir + "music.sd"))
    start
  end

  def test_bug4659212
    feedfile(selfdir+"musictest.json")
    feedfile(selfdir+"update_arr_uri_add.json")
    vespa.adminserver.execute("vespa-visit -i")
  end

  def teardown
    stop
  end

end
