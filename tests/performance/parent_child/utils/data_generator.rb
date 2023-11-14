# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'json_document_writer'

class ParentChildDataGenerator

  attr_reader :campaign_docs, :campaign_updates, :ad_docs, :ad_updates, :advertiser_docs
  attr_reader :ranking_queries
  attr_reader :imported_budget_slow_queries, :imported_budget_fast_queries, :flattened_budget_slow_queries, :flattened_budget_fast_queries, :imported_root_budget_fast_queries

  def initialize(num_ad_docs, campaign_ad_ratio, advertiser_campaign_ratio, dir)
    @num_ad_docs = num_ad_docs
    @num_campaign_docs = (num_ad_docs / campaign_ad_ratio)
    @num_advertiser_docs = (@num_campaign_docs / advertiser_campaign_ratio)
    @campaign_ad_ratio = campaign_ad_ratio
    @advertiser_campaign_ratio = advertiser_campaign_ratio
    @dir = dir

    puts "ParentChildDataGenerator(ad=#{@num_ad_docs}, campaign=#{@num_campaign_docs}, advertiser=#{@num_advertiser_docs}, campaign_ad_ratio=#{@campaign_ad_ratio}, advertiser_campaign_ratio=#{@advertiser_campaign_ratio})"

    @advertiser_docs = write_advertiser_docs
    @campaign_docs = write_campaign_docs
    @campaign_updates = write_campaign_updates
    @ad_docs = write_ad_docs
    @ad_updates = write_ad_updates

    @ranking_queries = write_ranking_queries
    @imported_budget_slow_queries = write_matching_queries("imported_budget_slow", @num_campaign_docs)
    @imported_budget_fast_queries = write_matching_queries("imported_budget_fast", @num_campaign_docs)
    @flattened_budget_slow_queries = write_matching_queries("flattened_budget_slow", @num_campaign_docs)
    @flattened_budget_fast_queries = write_matching_queries("flattened_budget_fast", @num_campaign_docs)
    @imported_root_budget_fast_queries = write_matching_queries("imported_root_budget_fast", @num_advertiser_docs)
  end

  private

  class FileWriter
    attr_reader :json
    def initialize(file_name)
      @file_name = file_name
      @json = JsonDocumentWriter.new(File.open(file_name, "w"))
    end

    def close
      @json.close
      @file_name
    end
  end

  def advertiser_id(id)
    "id:advertiser:advertiser::#{id}"
  end

  def campaign_id(id)
    "id:campaign:campaign::#{id}"
  end

  def feed_file(prefix, num_docs)
    @dir + "#{prefix}.#{num_docs}.r#{@campaign_ad_ratio}-#{@advertiser_campaign_ratio}.json"
  end

  def write_advertiser_docs
    file = FileWriter.new(feed_file("advertiser.docs", @num_advertiser_docs))
    for id in 0...@num_advertiser_docs do
      file.json.put(advertiser_id(id),
                    { "root_budget_fast" => id})
    end
    file.close
  end

  def write_campaign_docs
    file = FileWriter.new(feed_file("campaign.docs", @num_campaign_docs))
    for id in 0...@num_campaign_docs do
      ref_id = (id % @num_advertiser_docs)
      file.json.put(campaign_id(id),
                    { "ref" => advertiser_id(ref_id),
                      "budget_slow" => id,
                      "budget_fast" => id})
    end
    file.close
  end

  def write_campaign_updates
    file = FileWriter.new(feed_file("campaign.updates", @num_campaign_docs))
    for id in 0...@num_campaign_docs do
      file.json.update(campaign_id(id),
                       { "budget_slow" => { "assign": id } })
    end
    file.close
  end

  def write_ad_docs
    file = FileWriter.new(feed_file("ad.docs", @num_ad_docs))
    for id in 0...@num_ad_docs do
      ref_id = (id % @num_campaign_docs)
      file.json.put("id:ad:ad::#{id}",
                    { "ref" => campaign_id(ref_id),
                      "flattened_budget_slow" => ref_id,
                      "flattened_budget_fast" => ref_id})
    end
    file.close
  end

  def write_ad_updates
    file = FileWriter.new(feed_file("ad.updates", @num_ad_docs))
    for id in 0...@num_ad_docs do
      ref_id = (id % @num_campaign_docs)
      file.json.update("id:ad:ad::#{id}",
                       { "flattened_budget_slow" => { "assign" => ref_id } })
    end
    file.close
  end

  def write_ranking_queries
    file_name = @dir + "ranking.queries.r#{@campaign_ad_ratio}-#{@advertiser_campaign_ratio}.txt"
    file = File.open(file_name, "w")
    file.write("/search/?query=sddocname:ad&hits=10\n")
    file.close
    file_name
  end

  def write_matching_queries(field, num_ids)
    file_name = @dir + "matching.queries.#{field}.#{num_ids}.r#{@campaign_ad_ratio}-#{@advertiser_campaign_ratio}.txt"
    file = File.open(file_name, "w")
    for id in 0...num_ids do
      file.write(matching_query(field, id) + "\n")
    end
    file.close
    file_name
  end

  def matching_query(field, value)
    "/search/?query=#{field}:#{value}&restrict=ad&hits=10&ranking=unranked"
  end

end

if __FILE__ == $0
  ParentChildDataGenerator.new(20, 5, 2, "tmp/")
end
