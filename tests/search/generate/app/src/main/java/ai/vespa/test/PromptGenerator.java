package ai.vespa.test;

import ai.vespa.llm.completion.Prompt;
import ai.vespa.llm.completion.StringPrompt;
import com.yahoo.language.process.Generator;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public class PromptGenerator implements Generator {

    private final String promptTemplate;
    private final Generator generator;

    public PromptGenerator(PromptGeneratorConfig config, MockGenerator mockGenerator) {
        System.out.println("Starting PromptGenerator....");
        this.promptTemplate = loadDefaultPrompt(config);
        this.generator = mockGenerator;
    }

    @Override
    public String generate(Prompt prompt, Generator.Context context) {
        return generator.generate(buildPrompt(prompt), context);
    }

    private Prompt buildPrompt(Prompt promptContext) {
        String prompt = promptTemplate.replace("{context}", promptContext.asString());
        return StringPrompt.from(prompt);
    }

    private String loadDefaultPrompt(PromptGeneratorConfig config) {
        if (config.prompt() != null && ! config.prompt().isEmpty()) {
            return config.prompt();
        } else if (config.promptTemplate().isPresent()) {
            Path path = config.promptTemplate().get();
            
            try {
                return new String(Files.readAllBytes(path));
            } catch (IOException e) {
                throw new IllegalArgumentException("Could not read prompt template file: " + path, e);
            }
        }
        return null;
    }

}
