package ai.vespa.test;

import ai.vespa.secret.Secret;
import ai.vespa.secret.Secrets;
import com.yahoo.component.annotation.Inject;

public class LocalSecrets implements Secrets {

    @Inject
    public LocalSecrets() {
        System.out.println("Starting LocalSecrets....");
    }

    @Override
    public Secret get(String key) {
        System.out.println("Key: " + key + " requested");
        
        if (key.equals("openAiKey")) {
            return () -> System.getenv("OPENAI_AI_KEY");
        }
        
        throw new IllegalArgumentException("Secret with key '" + key + "' not found in secrets");
    }


}
