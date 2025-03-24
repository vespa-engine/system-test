package ai.vespa.test;

import ai.vespa.secret.Secret;
import ai.vespa.secret.Secrets;
import com.yahoo.component.annotation.Inject;

public class LocalSecrets implements Secrets {
    private final String openAiKey;

    @Inject
    public LocalSecrets(LocalSecretsConfig config) {
        System.out.println("Starting LocalSecrets....");
        
        try {
            openAiKey = java.nio.file.Files.readString(config.secretsFile());
        } catch (java.io.IOException e) {
            throw new RuntimeException("Failed to read secret file: " + config.secretsFile(), e);
        }
    }

    @Override
    public Secret get(String key) {
        System.out.println("Key: " + key + " requested");

        if (key.equals("openAiKey")) {
            return () -> openAiKey;
        }

        throw new IllegalArgumentException("Secret with key '" + key + "' not found in secrets");
    }


}
