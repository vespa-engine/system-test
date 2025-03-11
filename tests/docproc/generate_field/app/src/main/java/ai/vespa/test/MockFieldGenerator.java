package ai.vespa.test;

import com.yahoo.document.datatypes.FieldValue;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.language.process.FieldGenerator;

public class MockFieldGenerator implements FieldGenerator {
    private final MockFieldGeneratorConfig config;

    public MockFieldGenerator(MockFieldGeneratorConfig config) {
        this.config = config;
    }

    @Override
    public FieldValue generate(String input, Context context) {
        var stringBuilder = new StringBuilder();

        for (int i = 0; i < config.repetitions(); i++) {
            stringBuilder.append(input);
            
            if (i < config.repetitions() - 1) {
                stringBuilder.append(" ");
            }
        }

        
        return new StringFieldValue(stringBuilder.toString());
    }
}
