# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require 'rubygems'
require 'environment'

# Add your testcases here
require 'test/hittest'
require 'test/resultsettest'
require 'test/test_result_model'
require 'test/testbasetest'
require 'test/data_generator_test'
require 'test/environment_test'
require 'test/executor_test'
require 'test/document_set_test'
require 'test/document_test'
require 'test/documentupdate_test'
require 'app_generator/test/test'
require 'app_generator/test/storagetest'
require 'app_generator/test/containertest'
require 'app_generator/test/configtest'
require 'test/distr_bucketdb_parser_test'
require 'test/distributionstates_test'

if File.exist?(Environment.instance.vespa_home)
  # Add tests that require a Vespa installation to run here
  require 'test/ssl_config_test'
else
  puts "WARNING: Skipping tests requiring a Vespa installation as none is found in #{Environment.instance.vespa_home}"
end
