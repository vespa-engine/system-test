// Copyright Vespa.ai. All rights reserved.
package ai.vespa.test;

import ai.vespa.llm.completion.Prompt;
import com.yahoo.document.datatypes.FieldValue;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.language.process.FieldGenerator;

public class MockFieldGenerator implements FieldGenerator {
    private final MockFieldGeneratorConfig config;

    public MockFieldGenerator(MockFieldGeneratorConfig config) {
        this.config = config;
    }

    @Override
    public FieldValue generate(Prompt prompt, Context context) {
        var stringBuilder = new StringBuilder();

        for (int i = 0; i < config.repetitions(); i++) {
            stringBuilder.append(prompt.asString());
            
            if (i < config.repetitions() - 1) {
                stringBuilder.append(" ");
            }
        }

        
        return new StringFieldValue(stringBuilder.toString());
    }
}
