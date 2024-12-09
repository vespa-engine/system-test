package ai.vespa.test;

import ai.vespa.llm.completion.Prompt;
import com.yahoo.language.process.Generator;

public class MockGenerator implements Generator {
    private final int repetitions;

    public MockGenerator(MockGeneratorConfig config) {
        this.repetitions = config.repetitions();
    }

    @Override
    public String generate(Prompt prompt, Context context) {
        var stringBuilder = new StringBuilder();

        for (int i = 0; i < repetitions; i++) {
            stringBuilder.append(prompt.asString());
            stringBuilder.append(" ");
        }

        return stringBuilder.toString();
    }
}
