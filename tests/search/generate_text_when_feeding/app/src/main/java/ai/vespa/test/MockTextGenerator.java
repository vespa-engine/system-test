package ai.vespa.test;

import ai.vespa.llm.completion.Prompt;
import com.yahoo.language.process.TextGenerator;

public class MockTextGenerator implements TextGenerator {
    private final MockTextGeneratorConfig config;

    public MockTextGenerator(MockTextGeneratorConfig config) {
        this.config = config;
    }

    @Override
    public String generate(Prompt prompt, Context context) {
        var stringBuilder = new StringBuilder();

        for (int i = 0; i < config.repetitions(); i++) {
            stringBuilder.append(prompt.asString());
            
            if (i < config.repetitions() - 1) {
                stringBuilder.append(" ");
            }
        }

        
        return stringBuilder.toString();
    }
}
