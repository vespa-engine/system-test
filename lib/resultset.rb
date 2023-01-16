# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rexml/document'
require 'json'
require 'drb/drb'

class Resultset
  include DRb::DRbUndumped

  attr_accessor :responseheaders
  attr_accessor :responsecode
  attr_accessor :hitcount
  attr_reader :hit
  attr_reader :groupings
  attr_reader :errorlist
  attr_reader :json
  attr_accessor :query

  def initialize(data, query, response = nil)
    @hit = []
    @groupings = {}
    @errorlist = nil
    @hitcount = nil
    @query = query
    @xmldata = data
    if (response != nil)
      @responsecode = response.code
      @responseheaders = response.header.to_hash
    end
    parse
  end

  # Ruby's net/http lowercases all header names since HTTP headers are
  # case insensitive. This method lowercases the input header name as
  # well to match the case of the keys in the hash.
  def header(name)
    @responseheaders[name.downcase]
  end

  def parse
    return unless @xmldata
    if is_xml?
      parse_xml
    elsif is_json?
      parse_json
    end
  end

  def is_xml?
    # Don't check for a following question mark or xml text. This breaks tests and results where the xml header is omitted
    @xmldata.match(/\A\s*</) != nil
  end

  def is_json?
    @xmldata.match(/\A\s*[{|\[]/) != nil
  end

  def parse_json
    begin
      @hit = []
      @json = JSON.parse(@xmldata)
      parse_hits_json(@json)
    rescue Exception => e
      puts "#{e.message}, could not parse JSON: #{@xmldata}"
    end
    @json
  end

  def fixup_groupings(group)
    if group.is_a? Hash
      groupid = group['id']
      if groupid
        if groupid.start_with? 'index:search/'
          group.delete('id')
        end
        if groupid.start_with? 'index:storage.test/'
          group.delete('id')
        end
        if groupid.start_with? 'group:double:'
          dbl = groupid.sub('group:double:', '')
          val = group['value']
          if dbl == val
            group['value'] = val.to_f
            group['id'] = { 'group:double' => dbl.to_f }
          end
        end
      end
      if group['sddocname'] == 'test'
        group.delete('sddocname')
      end
      if group['source'] == 'search' || group['source'] == 'storage.test'
        group.delete('source')
      end
      group.each_value { |g| fixup_groupings(g) }
    elsif group.is_a? Array
      group.each { |g| fixup_groupings(g) }
    end
  end

  def parse_hits_json(json)
    return nil unless json && json['root']
    jroot = json['root']
    @errorlist = jroot['errors']
    return nil unless jroot['fields']
    begin
      @hitcount = jroot['fields']['totalCount']
      jroot['children'].each do |e|
        if e.key?('children') && ! e.key?('fields')
          id = e['id']
          fixup_groupings(e)
          @groupings[id] = e
        else
          hit = Hit.new
          hit.add_field("relevancy", e['relevance'])
          hit.add_field("documentid", e['id'])
          hit.add_field("source", e['source']) if e.key?('source')
          if e.key?('fields')
            e['fields'].each { |f| hit.add_field(f.first, f.last) }
          end
          add_hit(hit)
        end
      end
    rescue Exception
      return nil
    end
  end

  def xml
    if @xml == nil
      if @xmldata != nil
        @xml = parse_xml
      end
    end
    return @xml
  end

  def xmldata
    if @xmldata == nil
      to_xml
    end
    return @xmldata
  end

  def hit
    return @hit
  end

  def to_xml
    xml = REXML::Document.new()
    root = REXML::Element.new("result", xml)
    root.add_attribute("total-hit-count", @hitcount)
    @hit.each { |hit|
      root.add(hit.to_xml)
    }
    @xmldata = xml.to_s
  end

  def hitcount
    # Can be nil, return nil then, since nil.to_i is 0
    @hitcount ? @hitcount.to_i : @hitcount
  end

  def parse_xml
    begin
      @hit = []
      xml = REXML::Document.new(@xmldata).root
      parse_hits_xml(xml)
      if xml.attribute("total-hit-count") != nil
        @hitcount = xml.attribute("total-hit-count").to_s
      else
        @hitcount = @hit.size
      end
    rescue Exception => e
      puts "#{e.message}, could not parse XML: #{@xmldata}"
    end
    return xml
  end

  def parse_hits_xml(xml)
    if !xml
      return nil
    end
    xml.each_element("hit") do |e|
      newhit = Hit.new(e)
      add_hit(newhit)
    end
  end

  def add_hit(hit)
    @hit.push(hit)
  end

  def to_s
    stringval = ""
    hit.each do |h|
      stringval += h.to_s + "\n"
    end
    stringval
  end

  def inspect
    to_s
  end

  def setcomparablefields(fieldnamearray)
    hit.each {|h| h.setcomparablefields(fieldnamearray)}
  end

  def ==(other)
    (hitcount == other.hitcount && approx_cmp(groupings, other.groupings, "groupings") && hit == other.hit)
  end

  def check_equal(other)
    return false unless (hitcount == other.hitcount)
    return false unless (hit.size == other.hit.size)
    check_approx_eq(groupings, other.groupings, "groupings")
    hit.each_index { |i| hit[i].check_equal(other.hit[i]) }
    return true
  end

  def sort_results_by(sortfield)
    @hit = hit.sort {|a, b| a.field[sortfield] <=> b.field[sortfield]}
  end

  def get_field_array(sortfield)
    retval = []
    hit.each { |a|
      retval.push(a.field[sortfield])
    }
    return retval
  end

  # define class methods (by opening the class of Resultset)
  class << self

    # Compare two objects, but when finding floats, do approximate compare
    def approx_cmp(av, bv, k = '<unknown>')
      begin
        check_approx_eq(av, bv, k)
        return true
      rescue Exception => e
        puts e
        return false
      end
    end

    # Check two objects for equality, but when finding floats, do approximate compare
    def check_approx_eq(av, bv, k = '<unknown>')
      if av.equal? bv
        return true
      end
      if av.is_a? Numeric
        af = av.to_f
        bf = bv.to_f
        if (af + 1e-6 < bf)
          raise "Float values for '#{k}' differ: #{af} < #{bf}"
        end
        if (af - 1e-6 > bf)
          raise "Float values for '#{k}' differ: #{af} > #{bf}"
        end
      elsif av.is_a?(Hash) && bv.is_a?(Hash)
        check_approx_eq_hash(av, bv, k)
      elsif av.is_a?(Array) && bv.is_a?(Array)
        check_approx_eq_array(av, bv, k)
      elsif ! (av == bv)
        raise "Values for '#{k}' are unequal: '#{av}' != '#{bv}'"
      end
    end

    # Compare two arrays, but when finding floats, do approximate compare
    def check_approx_eq_array(a, b, k_in)
      if a.size != b.size
        raise "Different sizes of array: #{a.size} != #{b.size}"
      end
      a.each_index do |i|
        k ="#{k_in}[#{i}]"
        if a[i] && b[i]
          check_approx_eq(a[i], b[i], k)
        elsif a[i]
          raise "Expected '#{a[i]}' for '#{k}', got #{b[i]}"
        else
          raise "Expected #{a[i]} for '#{k}', got '#{b[i]}'"
        end
      end
    end

    # Compare two hashes, but when finding floats, do approximate compare
    def check_approx_eq_hash(a, b, k_in)
      if b.size > a.size
        b.each do |k,bv|
          unless a.has_key? k
            raise "Extra value for '#{k_in}.#{k}' is '#{bv}'"
          end
        end
      end
      a.each do |k,av|
        unless b.has_key? k
          raise "Missing value for field '#{k_in}.#{k}'"
        end
        bv = b[k]
        check_approx_eq(av, bv, "#{k_in}.#{k}")
      end
    end

  end

end
