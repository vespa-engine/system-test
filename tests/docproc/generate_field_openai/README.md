# Generate field with OpenAI

This test can only be run locally and requires creating [app/src/main/application/files/secrets.txt](app/src/main/application/files/secrets.txt) 
containing OpenAI API key. This file is git ignored to avoid storing secrets in the repo.
This secret file is referenced in [app/src/main/application/services.xml](app/src/main/application/services.xml) 
used by [app/src/main/java/ai/vespa/test/LocalSecrets.java](app/src/main/java/ai/vespa/test/LocalSecrets.java).

In addition, to run this test locally, the name of the test method in [generate_field_openai.rb](generate_field_openai.rb)
need to be changed from `disable_generate_field_openai` to `test_generate_field_openai`.
Be careful, not to commit your changes to avoid CI/CD running this test.