package ai.vespa.test;

import ai.vespa.secret.Secret;
import ai.vespa.secret.Secrets;
import com.yahoo.component.annotation.Inject;

public class LocalSecrets implements Secrets {
    private static final String SECRET_FILE = "secrets/openAiKey.txt";
    private final String openAiKey;

    @Inject
    public LocalSecrets() {
        System.out.println("Starting LocalSecrets....");
        
        try {
            openAiKey = java.nio.file.Files.readString(java.nio.file.Path.of(SECRET_FILE)).trim();
        } catch (java.io.IOException e) {
            throw new RuntimeException("Failed to read secret file: " + SECRET_FILE, e);
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
