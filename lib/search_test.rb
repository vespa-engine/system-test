# Copyright Vespa.ai. All rights reserved.
require 'testcase'
require 'app_generator/search_app'
require 'search_apps'

class SearchTest < TestCase

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "search"
  end

  def can_share_configservers?
    true
  end

  def redeploy(app, cluster = "search")
    deploy_output = deploy_app(app)
    gen = get_generation(deploy_output).to_i
    vespa.storage[cluster].wait_until_content_nodes_have_config_generation(gen)
    return deploy_output
  end

  def stop_node_and_not_wait(cluster_name, node_idx)
    node = vespa.storage[cluster_name].storage[node_idx.to_s]
    puts "******** stop node and wait for node down(#{node.to_s}) ********"
    vespa.stop_content_node(cluster_name, node.index, 120)
    node.wait_for_current_node_state('d')
  end

  def stop_node_and_wait(cluster_name, node_idx)
    stop_node_and_not_wait(cluster_name, node_idx)
    puts "******** wait cluster up again ********"
    vespa.storage[cluster_name].wait_until_ready(120)
  end

  def start_node_and_wait(cluster_name, node_idx)
    node = vespa.storage[cluster_name].storage[node_idx.to_s]
    puts "******** start_node_and_wait for cluster up(#{node.to_s}) ********"
    vespa.start_content_node(cluster_name, node.index, 120)
    node.wait_for_current_node_state('u')
    vespa.storage[cluster_name].wait_until_ready(120)
  end

  def deep_find_tagged_child(obj, tag)
    if obj.is_a? Hash
      return obj if obj['tag'] == tag
      obj.each do |k,v|
        r = deep_find_tagged_child(v, tag)
        return r if r
      end
      return nil
    end
    if obj.is_a? Array
      obj.each do |v|
        r = deep_find_tagged_child(v, tag)
        return r if r
      end
      return nil
    end
    return nil
  end

end
