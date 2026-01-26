// Copyright Vespa.ai. All rights reserved.
package ai.vespa.test;

import com.yahoo.language.process.Embedder;
import com.yahoo.language.process.OverloadException;
import com.yahoo.language.process.TimeoutException;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

import java.util.List;

/**
 * Custom embedder that throws exceptions based on input text keywords.
 * Used for testing exception handling in the indexing pipeline.
 *
 * @author bjorncs
 */
public class ExceptionThrowingEmbedder implements Embedder {

    @Override
    public List<Integer> embed(String text, Context context) {
        throwException(text);
        throw new IllegalStateException("Should never reach here");
    }

    @Override
    public Tensor embed(String text, Context context, TensorType tensorType) {
        throwException(text);
        throw new IllegalStateException("Should never reach here");
    }

    private void throwException(String text) {
        String lowerText = text.toLowerCase();

        if (lowerText.contains("timeout")) {
            throw new TimeoutException("Embedder timed out - simulated timeout condition");
        }

        if (lowerText.contains("overload")) {
            throw new OverloadException("Embedder is overloaded - simulated overload condition");
        }

        throw new RuntimeException("Embedder encountered an error - simulated generic exception");
    }
}
