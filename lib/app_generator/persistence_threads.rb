# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class PersistenceThread

  attr_reader :count, :lowest_priority

  def initialize(count, lowest_priority)
    @count = count
    @lowest_priority = lowest_priority
  end

  def threads_xml(helper)
    helper.
      tag("thread", :count => @count, :"lowest-priority" => @lowest_priority).
      close_tag
  end

end

# Element under content/tuning
class PersistenceThreads

  def initialize
    @threads = []
  end

  def thread(count, lowest_priority=nil)
    @threads << PersistenceThread.new(count, lowest_priority)
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("persistence-threads").
      list_do(@threads) { |helper, t| t.threads_xml(helper) }.to_s
  end

end
