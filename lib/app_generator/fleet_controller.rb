# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class FleetController < NodeBase
  tag "fleet-controller"

  def initialize(hostalias, index)
    super(:hostalias => hostalias, :index => index)
  end

end

class FleetControllers
  include ChainedSetter

  chained_setter :min_storage_up_ratio
  chained_setter :min_distributor_up_ratio
  chained_setter :transition_time
  chained_setter :min_time_between_cluster_states

  def initialize
    @min_storage_up_ratio = nil
    @min_distributor_up_ratio = nil
    @transition_time = nil
    @fleet_controllers = []
    @min_time_between_cluster_states = 0
  end

  def fleet_controller(hostalias)
    @fleet_controllers.push(
      FleetController.new(hostalias, @fleet_controllers.length))
    self
  end

  def tuning_xml(indent)
    XmlHelper.new(indent).
      tag("cluster-controller").
      tag("transition-time").content(@transition_time).close_tag.
      tag("min-storage-up-ratio").content(@min_storage_up_ratio).close_tag.
      tag("min-distributor-up-ratio").content(@min_distributor_up_ratio).close_tag.
      to_s
  end

end
