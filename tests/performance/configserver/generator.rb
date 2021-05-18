# Generator for config values

class Generator

  attr_accessor :num_configs,:num_fields

  def initialize(num_configs, num_fields, version=1)
    @num_configs = num_configs
    @num_fields = num_fields
    @version = version
  end

  def get_defname(suffix)
    return "my#{suffix}"
  end

  def get_configname(num)
    return "My#{num}Config"
  end

  def get_fieldname(defname, field)
    return "field#{defname}_#{field}"
  end

  def generate_def(path)
    for i in 1..@num_configs
      defname = get_defname(i)
      f = File.new("#{path}/#{defname}.def", "w")
      f.puts("namespace=my")
      for field in 1..@num_fields
        name = get_fieldname(defname, field)
        f.puts("#{name} string default=\"#{name}\"")
      end
      f.close
    end
  end

  # Generate configs and return verification map.
  def generate_config_random(path)
    verification_map = {}
    for i in 1..@num_configs
      defname = get_defname(i)
      submap = {}
      f = File.new("#{path}/#{defname}.cfg", "w")
      for field in 1..@num_fields
        randomstring = "%04d" % (rand*10000).to_i
        value = "foo_#{randomstring}"
        name = get_fieldname(defname, field)
        f.puts("#{name} \"#{value}\"")
        submap[name] = value
      end
      verification_map[defname] = submap
      f.close
    end
    verification_map
  end

  def generate_loadfile(output)
    f = File.new(output, "w")
    for i in 1..@num_configs
      defname = get_defname(i)
      f.puts("my.#{defname},admin")
    end
    f.close
  end

  # Generate verification map for default values
  def generate_verification_map
    verification_map = {}
    for i in 1..@num_configs
      defname = get_defname(i)
      submap = {}
      for field in 1..@num_fields
        name = get_fieldname(defname, field)
        submap[name] = name
      end
      verification_map[defname] = submap
    end
    verification_map
  end

  def write_verification_map(output, verification_map)
    f = File.new(output, "w")
    verification_map.each do |deffile,submap|
      submap.each do |field,value|
        f.puts("#{deffile},#{field},#{value}")
      end
    end
    f.close
  end

  def generate_client_java(output)
    f = File.new(output, "w")
    f.puts("package com.yahoo.vespa.systemtest.gen;")
    f.puts("")
    f.puts("import static org.junit.Assert.*;")
    f.puts("import com.yahoo.vespa.config.benchmark.Tester;")
    f.puts("import java.util.Map;")
    f.puts("import com.yahoo.config.subscription.ConfigSubscriber;")
    f.puts("import com.yahoo.config.subscription.ConfigHandle;")
    for i in 1..@num_configs
      configName = get_configname(i)
      f.puts("import com.yahoo.my.#{configName};")
    end
    f.puts("")
    f.puts("public class TestStub implements Tester {")
    f.puts("    private ConfigSubscriber s;")
    for i in 1..@num_configs
      configName = get_configname(i)
      f.puts("    private ConfigHandle<#{configName}> h#{i};")
    end
    f.puts("")
    f.puts("    public void subscribe() {")
    f.puts("        s = new ConfigSubscriber();")
    for i in 1..@num_configs
      configName = get_configname(i)
      f.puts("        h#{i} = s.subscribe(#{configName}.class, \"admin\");")
    end
    f.puts("        assertTrue(\"Failed at waiting for config when subscribed\", s.nextConfig());")
    for i in 1..@num_configs
      configName = get_configname(i)
      f.puts("        assertTrue(\"Handle #{i} is not changed!\", h#{i}.isChanged());")
    end
    f.puts("    }")
    f.puts("")
    f.puts("    public boolean fetch() {")
    f.puts("        return s.nextConfig();")
    f.puts("    }")
    f.puts("")
    f.puts("    public boolean verify(Map<String, Map<String, String>> expected, long generation) {");
    f.puts("        if (generation != s.getGeneration()) return false;")
    for i in 1..@num_configs
      defname = get_defname(i)
      f.puts("        verify_#{defname}(expected.get(\"#{defname}\"));")
    end
    f.puts("        return true;")
    f.puts("    }")
    f.puts("")

    # Create a verify method for each config
    for i in 1..@num_configs
      defname = get_defname(i)
      f.puts("    private void verify_#{defname}(Map<String, String> expected) {");
      configName = get_configname(i)
      f.puts("        #{configName} c#{i} = h#{i}.getConfig();")
      for field in 1..@num_fields
        name = get_fieldname(defname, field)
        f.puts("        assertEquals(\"Field does not contain expected value\", expected.get(\"#{name}\"), c#{i}.#{name}());")
      end
      f.puts("    }")
      f.puts("")
    end

    f.puts("    public void close() {")
    f.puts("        s.close();")
    f.puts("    }")
    f.puts("}")
    f.close
  end
end
