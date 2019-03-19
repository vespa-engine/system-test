package com.yahoo.vespatest;

import com.yahoo.component.chain.dependencies.Before;
import com.yahoo.data.access.Inspectable;
import com.yahoo.data.access.Inspector;
import com.yahoo.log.LogLevel;
import com.yahoo.prelude.query.PredicateQueryItem;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.predicate.PredicateQueryParser;
import com.yahoo.search.querytransform.QueryTreeUtil;
import com.yahoo.search.result.ErrorHit;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.AsyncExecution;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.search.searchchain.FutureResult;
import com.yahoo.search.searchchain.PhaseNames;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Optional;
import java.util.Queue;
import java.util.logging.Logger;

import static java.util.stream.Collectors.joining;

/**
 * @author bjorncs
 */
@Before(PhaseNames.RAW_QUERY)
public class HitsVerificationSearcher extends Searcher {
    private static final String PREDICATE_FIELD_NAME = "boolean";
    private static final int QUEUE_SIZE = 128;
    private static final Logger log = Logger.getLogger(HitsVerificationSearcher.class.getName());

    private final PredicateQueryParser parser = new PredicateQueryParser();

    @Override
    public Result search(Query originalQuery, Execution execution) {
        String jsonFile = originalQuery.properties().getString("jsonFile");
        String outputFile = originalQuery.properties().getString("outputFile");

        if (jsonFile == null && outputFile == null) {
            log.log(LogLevel.INFO, "No json file and output file specified - will pass the query to next searcher.");
            return execution.search(originalQuery);
        }

        int totalHitCount = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(jsonFile));
             BufferedWriter writer = new BufferedWriter(new FileWriter(outputFile, false))) {
            int queryId = 0;
            Queue<FutureResult> futureResults = new ArrayDeque<>(QUEUE_SIZE);
            for (int i = 0; i < QUEUE_SIZE; i++) {
                createAndScheduleQuery(execution, reader, originalQuery)
                        .map(futureResults::offer);
            }
            while (!futureResults.isEmpty()) {
                Result result = futureResults.remove().get();
                writer.write(createHitString(queryId, result));
                totalHitCount += result.getHitCount();
                createAndScheduleQuery(execution, reader, originalQuery)
                        .map(futureResults::offer);
                ++queryId;
                if (queryId % 1000 == 0) {
                    log.log(LogLevel.INFO, queryId + " queries completed.");
                }
            }
            log.log(LogLevel.INFO, "All {0} queries completed. Total hitcount: {1}.",
                    new Object[]{queryId, totalHitCount});
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        Result result = new Result(originalQuery);
        result.setTotalHitCount(totalHitCount);
        return result;
    }

    private Optional<FutureResult> createAndScheduleQuery(
            Execution execution, BufferedReader reader, Query originalQuery) throws IOException {

        String json = reader.readLine();
        if (json == null) return Optional.empty();
        Query query = createQuery(json, originalQuery);
        return Optional.of(new AsyncExecution(execution).searchAndFill(query));
    }

    private Query createQuery(String json, Query originalQuery) {
        Query query = new Query(originalQuery);
        query.resetTimeout();
        query.setTimeout(10000);
        QueryTreeUtil.andQueryItemWithRoot(query, parseJsonQuery(json));
        return query;
    }

    private PredicateQueryItem parseJsonQuery(String json) {
        PredicateQueryItem item = new PredicateQueryItem();
        item.setIndexName(PREDICATE_FIELD_NAME);
        parser.parseJsonQuery(json, item::addFeature, item::addRangeFeature);
        return item;
    }

    private String createHitString(int queryId, Result result) {
        return result.hits().asList().stream()
                .map(SimpleHit::fromHit)
                .sorted()
                .map(SimpleHit::toString)
                .collect(joining(", ", queryId + ": [", "]\n\n"));
    }

    private static class SimpleHit implements Comparable<SimpleHit> {
        public final int id;
        public final long subqueryBitmap;

        private SimpleHit(int id, long subqueryBitmap) {
            this.id = id;
            this.subqueryBitmap = subqueryBitmap;
        }

        public static SimpleHit fromHit(Hit hit) {
            if (hit instanceof ErrorHit) {
                throw new RuntimeException(((ErrorHit) hit).errors().iterator().next().toString());
            }
            return new SimpleHit(getIdNumber(hit), getSubqueryBitmap(hit));
        }

        private static int getIdNumber(Hit hit) {
            String idString = hit.getDisplayId();
            int start = idString.indexOf("::") + 2;
            return Integer.parseInt(idString.substring(start));
        }

        private static long getSubqueryBitmap(Hit hit) {
            Inspectable summaryFeatures = (Inspectable) hit.getField("summaryfeatures");
            String summaryName = "subqueries(" + PREDICATE_FIELD_NAME + ")";
            Inspector obj = summaryFeatures.inspect();
            long lsb = obj.field(summaryName + ".lsb").asLong(0);
            long msb = obj.field(summaryName + ".msb").asLong(0);
            return msb << 32 | lsb;
        }

        @Override
        public int compareTo(SimpleHit o) {
            return Integer.compare(id, o.id);
        }

        @Override
        public String toString() {
            return String.format("(%d, 0x%x)", id, subqueryBitmap);
        }
    }
}
