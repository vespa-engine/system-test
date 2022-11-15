# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search/resize/resizebase'

class ResizeContentCluster < ResizeContentClusterBase

  def initialize(*args)
    super(*args)
    @num_hosts = 1
  end

  def test_grow
    set_description("Test grow of elastic cluster")
    perform_grow(ResizeApps::GrowApp.new(self, @smalldictsize, @smallnumdocs, 0, @num_hosts))
  end

  def test_shrink
    set_description("Test shrink of elastic cluster")
    perform_shrink(ResizeApps::ShrinkApp.new(self, @smalldictsize, @smallnumdocs, 0, @num_hosts))
  end
end

class ResizeParentChildContentCluster < ResizeContentClusterBase

  def initialize(*args)
    super(*args)
    @num_hosts = 1
  end

  def test_grow_child
    set_description("Test grow of elastic cluster with parent and child docs")
    perform_grow(ResizeApps::GrowApp.new(self, @smalldictsize, @smallnumdocs, @smallnumdocs, @num_hosts))
  end

  def test_shrink_child
    set_description("Test shrink of elastic cluster with parent and child docs")
    app = ResizeApps::ShrinkApp.new(self, @smalldictsize, @smallnumdocs, @smallnumdocs, @num_hosts)
    app.slack_maxdocs_per_group = 750
    perform_shrink(app)
  end
end


class ResizeHDContentCluster < ResizeContentClusterBase

  def initialize(*args)
    super(*args)
    @num_hosts = 9
  end

  def test_hd_grow
    set_description("Test grow of hierarchical distribution elastic cluster")
    app = ResizeApps::HDGrowApp.new(self, @smalldictsize, @smallnumdocs, 0, @num_hosts)
    app.slack_minhits = 800
    perform_grow(app)
  end

  def test_hd_shrink
    set_description("Test shrink of hierarchical distribution elastic cluster")
    app = ResizeApps::HDShrinkApp.new(self, @smalldictsize, @smallnumdocs, 0, @num_hosts)
    app.slack_minhits = 300
    perform_shrink(app)
  end
end
