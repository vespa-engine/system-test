# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.


class LocalityNode < VespaNode
  def initialize(*args)
    super(*args)
  end

  def config_id
    @service_entry["config-id"]
  end
end
