package ai.vespa.test;

import ai.vespa.secret.Secret;
import ai.vespa.secret.Secrets;
import com.yahoo.component.annotation.Inject;

public class LocalSecrets implements Secrets {

    private static final String VOYAGE_API_KEY_ENV = "VESPA_SECRET_VOYAGE_API_KEY";
    private final String voyageApiKey;

    @Inject
    public LocalSecrets() {
        voyageApiKey = System.getenv(VOYAGE_API_KEY_ENV);
        if (voyageApiKey == null || voyageApiKey.isEmpty()) {
            throw new RuntimeException("Environment variable " + VOYAGE_API_KEY_ENV + " is not set");
        }
    }

    @Override
    public Secret get(String key) {
        if (key.equals("voyage_api_key")) {
            return () -> voyageApiKey;
        }

        throw new IllegalArgumentException("Secret with key '" + key + "' not found in secrets");
    }

}
