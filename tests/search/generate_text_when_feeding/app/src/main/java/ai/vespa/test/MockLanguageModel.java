package ai.vespa.test;

import ai.vespa.llm.InferenceParameters;
import ai.vespa.llm.completion.Completion;
import ai.vespa.llm.completion.Prompt;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;

public class MockLanguageModel implements ai.vespa.llm.LanguageModel {
    private final MockLanguageModelConfig config;

    public MockLanguageModel(MockLanguageModelConfig config) {
        this.config = config;
    }

    @Override
    public List<Completion> complete(Prompt prompt, InferenceParameters params) {
        var stringBuilder = new StringBuilder();

        for (int i = 0; i < config.repetitions(); i++) {
            stringBuilder.append(prompt.asString());
            
            if (i < config.repetitions() - 1) {
                stringBuilder.append(" ");
            }
        }

        return List.of(Completion.from(stringBuilder.toString().trim()));
    }

    @Override
    public CompletableFuture<Completion.FinishReason> completeAsync(Prompt prompt,
                                                                    InferenceParameters params,
                                                                    Consumer<Completion> consumer) {
        throw new UnsupportedOperationException();
    }
}
