// Copyright Vespa.ai. All rights reserved.
package ai.vespa.test;

import com.yahoo.language.process.Embedder;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.Logger;

/**
 * Custom embedder that tracks batch sizes for testing dynamic batching.
 * Logs batch information to verify that documents are being batched together.
 *
 * @author bjorncs
 */
public class BatchTrackingEmbedder implements Embedder {

    private static final Logger logger = Logger.getLogger(BatchTrackingEmbedder.class.getName());
    private static final AtomicInteger batchCallCount = new AtomicInteger(0);
    private static final AtomicInteger singleCallCount = new AtomicInteger(0);

    @Override
    public List<Integer> embed(String text, Context context) {
        int callNum = singleCallCount.incrementAndGet();
        logger.info("Single embed call #" + callNum + " for text: " + text.substring(0, Math.min(50, text.length())));

        // Return a simple embedding: [text.length(), callNum, 0, 0]
        List<Integer> embedding = new ArrayList<>(4);
        embedding.add(text.length());
        embedding.add(callNum);
        embedding.add(0);
        embedding.add(0);
        return embedding;
    }

    @Override
    public Tensor embed(String text, Context context, TensorType tensorType) {
        List<Integer> integers = embed(text, context);
        return createTensorFromList(integers, tensorType);
    }

    @Override
    public Batching batchingConfig() {
        return new Batching(10, Duration.ofSeconds(15));
    }

    @Override
    public List<Tensor> embed(List<String> texts, Context context, TensorType tensorType) {
        int batchSize = texts.size();
        int callNum = batchCallCount.incrementAndGet();

        logger.info("BATCH embed call #" + callNum + " with batch size: " + batchSize);
        for (int i = 0; i < texts.size(); i++) {
            String preview = texts.get(i).substring(0, Math.min(30, texts.get(i).length()));
            logger.info("  Batch item [" + i + "]: " + preview + "...");
        }

        List<Tensor> tensors = new ArrayList<>(batchSize);
        for (int i = 0; i < batchSize; i++) {
            String text = texts.get(i);
            // Encoding: [text.length(), batchSize, i (position in batch), callNum]
            List<Integer> embedding = new ArrayList<>(4);
            embedding.add(text.length());
            embedding.add(batchSize);
            embedding.add(i);
            embedding.add(callNum);
            tensors.add(createTensorFromList(embedding, tensorType));
        }

        return tensors;
    }

    private Tensor createTensorFromList(List<Integer> integers, TensorType tensorType) {
        Tensor.Builder builder = Tensor.Builder.of(tensorType);
        for (int i = 0; i < integers.size(); i++) {
            builder.cell()
                    .label("x", i)
                    .value(integers.get(i));
        }
        return builder.build();
    }
}
