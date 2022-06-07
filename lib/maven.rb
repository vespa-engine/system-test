# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

module Maven
  DEFAULT_VESPA_POM_VERSION = '8-SNAPSHOT'

  def Maven.compile_bundles(bundles, testcase, admin_server, vespa_version)
    compiled = []
    # Compile bundles
    bundles.each { |bundle|
      next if compiled.include?(bundle)
      deps = bundle.params[:dependencies] || []
      deps.each do |dep|
        next if dep.class == String
        unless compiled.include?(dep)
          compiled << dep
          compile_bundle(dep, admin_server, testcase, vespa_version)
        end
      end
      compile_bundle(bundle, admin_server, testcase, vespa_version)
      compiled << bundle
    }
  end

  def Maven.compile_bundle(bundle, admin_server, testcase, vespa_version)
    tmp_bundle_dir = testcase.dirs.tmpdir + "bundles/work"
    testcase.output("Tmp bundle dir #{tmp_bundle_dir}")
    admin_server.execute("[ -d #{tmp_bundle_dir} ] && rm -rf #{tmp_bundle_dir}/ || true")
    admin_server.execute("mkdir -p #{tmp_bundle_dir}")
    # Remove from localhost as well
    `[ -d #{tmp_bundle_dir} ] && rm -rf #{tmp_bundle_dir}/ || true`

    # TODO :name is a bad name for this parameter
    unique_name = (bundle.params[:name] || '')
    testcase.output("unique name used in compile_bundle is empty") if unique_name == ''
    source = bundle.sourcedir
    bundlename = bundle.name
    testcase.output("Compiling bundle with sourcedir #{source}")
    if File.file?(source)
      tmp_sourcedir = create_sourcedir(tmp_bundle_dir + "#{unique_name}/", source, bundlename)
    else
      tmp_sourcedir = tmp_bundle_dir + "#{unique_name}/" + File.basename(source)
      copy_directory_structure(source, tmp_sourcedir)
    end

    haspom = Maven.create_pom_xml(vespa_version, tmp_sourcedir, bundle)
    admin_server.copy(tmp_sourcedir, tmp_sourcedir)
    bundle_content = admin_server.maven_compile(tmp_sourcedir, bundle, haspom, to_pom_version(vespa_version))
    bundle_dir = testcase.dirs.bundledir
    bundlepath = bundle_file_path(bundle_dir, bundle)
    FileUtils.mkdir_p(File.dirname(bundlepath))
    bundlefile = File.open(bundlepath, "w")
    bundlefile.write(bundle_content)
    bundlefile.close()
    admin_server.execute("mkdir -p #{File.dirname(bundlepath)}")
    admin_server.copy(bundlepath, File.dirname(bundle_file_path(bundle_dir, bundle)))
  end

  def Maven.create_sourcedir(basedir, sourcefile, bundlename)
    pkgs = bundlename.split(".")
    pkgs.pop
    pkgdir = pkgs.join("/")
    sourcedir = basedir + bundlename + "/src/main/java/" + pkgdir
    FileUtils.mkdir_p(sourcedir)
    FileUtils.cp(sourcefile, sourcedir + "/")
    return basedir + "/" + bundlename
  end

  def Maven.bundle_file_path(bundle_dir, bundle, tmp=nil)
    filename = bundle.params[:name].to_s+'/' +
        bundle.generate_final_name + '.jar'
    if tmp
      f = Tempfile.new(filename)
      path = f.path
      f.close
      FileUtils.rm(path)
      path
    else
      bundle_dir + filename
    end
  end

  # Copy a directory structure and ignore given entries
  def Maven.copy_directory_structure(src, dest, _ignore = [])
    ignore = (_ignore | ['.', '..'])
    FileUtils.mkdir_p(dest)
    Dir.foreach(src) do |name|
      next if ignore.include?(name)
      path = src + '/' + name
      if File.file?(path)
        FileUtils.copy(path, dest)
      elsif File.directory?(path)
        copy_directory_structure(path, dest + '/' + name, _ignore)
      else
        #puts "Ignoring unknown filetype: #{path}"
      end
    end
  end

  def Maven.create_pom_xml(vespa_version, sourcedir, bundle)
    if File.exist?(sourcedir + "/pom.xml")
      f = File.new(sourcedir + "/pom.xml", "r")
      doc = REXML::Document.new(f)
      elem = REXML::XPath.first(doc.root, "artifactId")
      bundle.artifact_id = elem.text
      elem = REXML::XPath.first(doc.root, "groupId")
      bundle.group_id = elem.text
      elem = REXML::XPath.first(doc.root, "version")
      bundle.version = elem.text
      return true
    end

    doc = REXML::Document.new(Maven.pom_xml(to_pom_version(vespa_version),
                                            bundle.extra_build_plugin_xml,
                                            bundle.bundle_plugin_config))
    elem = REXML::XPath.first(doc.root, "artifactId")
    elem.text = bundle.artifact_id
    elem = REXML::XPath.first(doc.root, "name")
    elem.text = bundle.name
    elem = REXML::XPath.first(doc.root, "groupId")
    elem.text = bundle.group_id
    elem = REXML::XPath.first(doc.root, "version")
    elem.text = bundle.version

    provided = bundle.params.fetch(:dependencies, [])
    elem = REXML::XPath.first(doc.root, "dependencies")
    provided.map { |dep|
      tag = elem.add_element("dependency")
      group = tag.add_element("groupId")
      group.text = dep.group_id
      artifact = tag.add_element("artifactId")
      artifact.text = dep.artifact_id
      version = tag.add_element("version")
      version.text = dep.version
      scope = tag.add_element("scope")
      scope.text = dep.params.fetch(:scope, "provided")
    }

    pomxml = File.open(sourcedir + "/pom.xml", "w")
    doc.write pomxml
    pomxml.close

    return false
  end


  def Maven.pom_xml(vespa_pom_version, extra_build_plugin_xml="", bundle_plugin_config="", new_values = {})
    maven_repository_settings =
      if Environment.instance.maven_snapshot_url != nil then
        "<repositories>
          <repository>
            <id>vespa-maven-libs-quarantine-local</id>
            <name>vespa-maven-libs-quarantine-local</name>
            <url>#{Environment.instance.maven_snapshot_url}</url>
            <snapshots>
              <enabled>false</enabled>
            </snapshots>
            <releases>
              <enabled>true</enabled>
            </releases>
          </repository>
        </repositories>

        <pluginRepositories>
          <pluginRepository>
            <id>vespa-maven-libs-quarantine-local-plugins</id>
            <name>vespa-maven-libs-quarantine-local-plugins</name>
            <url>#{Environment.instance.maven_snapshot_url}</url>
            <snapshots>
              <enabled>false</enabled>
            </snapshots>
            <releases>
              <enabled>true</enabled>
            </releases>
          </pluginRepository>
        </pluginRepositories>
      " else "" end

    values = {
      :groupId => 'override from bundle.rb',
      :artifactId => 'override from bundle.rb',
      :version => 'override from bundle.rb',
      :name => 'override from bundle.rb'
    }.merge(new_values)
    """
    <project xmlns=\"http://maven.apache.org/POM/4.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
      xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd\">
      <modelVersion>4.0.0</modelVersion>
      <groupId>#{values[:groupId]}</groupId>
      <artifactId>#{values[:artifactId]}</artifactId>
      <version>#{values[:version]}</version>
      <name>overridden from bundle.rb</name>
      <packaging>container-plugin</packaging>
      <description>
          Create a bundle from one or more classes and zero or more configdef files.
      </description>
      <url>https://vespa.ai</url>

      <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
      </properties>

      #{maven_repository_settings}

      <build>
        <!-- hacks other places in this file depends on the order of the
             plugins.
             TODO Fix the above mentioned nastiness. -->
        <plugins>

          <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.10.1</version>
            <configuration>
              <release>17</release>
            </configuration>
          </plugin>

          <plugin>
            <groupId>com.yahoo.vespa</groupId>
            <artifactId>bundle-plugin</artifactId>
            <version>#{vespa_pom_version}</version>
            <extensions>true</extensions>
            <configuration>
            #{bundle_plugin_config}
            </configuration>
          </plugin>

          <plugin>
            <groupId>com.yahoo.vespa</groupId>
            <artifactId>config-class-plugin</artifactId>
            <version>#{vespa_pom_version}</version>
            <extensions>true</extensions>
          </plugin>
" + extra_build_plugin_xml + "
        </plugins>
      </build>

      <dependencies>
        <dependency>
          <groupId>com.yahoo.vespa</groupId>
          <artifactId>container-dev</artifactId>
          <version>#{vespa_pom_version}</version>
          <scope>provided</scope>
        </dependency>
      </dependencies>

    </project>
    """
  end

  def Maven.to_pom_version(vespa_version)
    if not vespa_version
      DEFAULT_VESPA_POM_VERSION
    elsif vespa_version =~ /^\d+\.\d+\.\d+$/
      vespa_version
    elsif vespa_version =~ /^\d+-SNAPSHOT$/
      vespa_version
    else
      raise "Unable to translate vespa version into vespa pom version: " +
                vespa_version
    end
  end
end
