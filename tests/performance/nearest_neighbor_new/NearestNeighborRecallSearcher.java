// Copyright Vespa.ai. All rights reserved.

package ai.vespa.test;

import com.yahoo.prelude.query.CompositeItem;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.NearestNeighborItem;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.ErrorMessage;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.search.yql.MinimalQueryInserter;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.function.Consumer;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Searcher that calculates the recall of a nearest neighbor query.
 *
 * The incoming query (e.g., a query from an fbench query file) is executed twice:
 * once as it is, and once with approximate=false on all nearestNeighbor items (the exact ground truth).
 * The recall is the number of hits that the two results have in common.
 * Everything else in the query (filters, geoLocation, ranking.matching.* settings, ...) is used as is.
 *
 * Query properties:
 *   nnr.enable=true             Enables this searcher.
 *   nnr.exactField              Field used for the exact search instead of the field in the query.
 *                               Used for quantized tensors, where an exact search over the quantized
 *                               tensor is not the source of truth. Disables the relevance check.
 *   nnr.exactRankProfile        Rank profile used for the exact search.
 *   nnr.targetHits              Overrides targetHits (and hits) in both searches.
 *   nnr.exploreHits             Overrides hnsw.exploreAdditionalHits in both searches.
 *   nnr.approximate             Overrides approximate in the approximate search.
 *   nnr.idField                 Summary field used to compare hits (default 'id').
 */
@Before("blendedResult")
@After("transformedQuery")
public class NearestNeighborRecallSearcher extends Searcher {

    private static final Logger log = Logger.getLogger(NearestNeighborRecallSearcher.class.getName());

    private record SimpleHit(String id, double relevance) {}

    private static class RelevanceMismatchException extends Exception {
        public RelevanceMismatchException(String msg) {
            super(msg);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        var props = query.properties();
        if ( ! "true".equals(props.getString("nnr.enable"))) {
            return execution.search(query);
        }
        String exactField = props.getString("nnr.exactField");
        String exactRankProfile = props.getString("nnr.exactRankProfile");
        Integer targetHits = props.getInteger("nnr.targetHits");
        Integer exploreHits = props.getInteger("nnr.exploreHits");
        String approximateString = props.getString("nnr.approximate");
        Boolean approximate = (approximateString != null) ? Boolean.parseBoolean(approximateString) : null;
        String idField = props.getString("nnr.idField", "id");

        query.getModel().getQueryTree(); // Make sure the query is parsed before cloning it
        var approxQuery = cloneWithOverrides(query, approximate, null, null, targetHits, exploreHits);
        var exactQuery = cloneWithOverrides(query, false, exactField, exactRankProfile, targetHits, exploreHits);

        int k = exactQuery.getHits();
        log.log(Level.FINE, () -> "NNRS.search(): exactQuery=" + exactQuery.getModel().getQueryTree() +
                ", approxQuery=" + approxQuery.getModel().getQueryTree() + ", k=" + k);
        var exactHits = executeQuery(exactQuery, execution, idField);
        var approxHits = executeQuery(approxQuery, execution, idField);
        // Guard against the executed query tree being replaced (e.g. by re-parsing the YQL), which would silently
        // make the exact search approximate and the recall 100%.
        forEachNearestNeighborItem(exactQuery, nni -> {
            if (nni.getAllowApproximate()) {
                throw new IllegalStateException("The exact query was executed with approximate=true: " + exactQuery);
            }
        });

        try {
            // For quantized tensors, the relevance of the full precision hits and the quantized hits will not
            // match exactly, so the check is disabled when a separate field is used for the exact search.
            boolean enableRelevanceCheck = (exactField == null);
            int recall = calcRecall(exactHits, approxHits, k, enableRelevanceCheck);
            return resultWithSingleHit(query, "recall", recall);
        } catch (RelevanceMismatchException ex) {
            log.log(Level.SEVERE, "NNRS.search(): ex='" + ex.getMessage() + "'");
            // Adding a regular hit makes it easy to check in the Ruby code,
            // where errors currently are not parsed from the result set.
            var result = resultWithSingleHit(query, "error", ex.getMessage());
            result.hits().addError(ErrorMessage.createUnspecifiedError(ex.getMessage(), ex));
            return result;
        }
    }

    /**
     * Returns a clone of the query with the given overrides applied to the query and its nearestNeighbor items.
     * Overrides that are null are not applied, i.e., the values in the query are used.
     */
    private static Query cloneWithOverrides(Query query, Boolean approximate, String field, String rankProfile,
                                            Integer targetHits, Integer exploreHits) {
        var clone = query.clone();
        // The query tree is already parsed: Remove the YQL so that it is not parsed again (by MinimalQueryInserter)
        // when the clone is executed, which would replace the query tree and undo the overrides below.
        clone.properties().set(MinimalQueryInserter.YQL, null);
        clone.setTimeout(10_000);
        if (approximate != null) {
            forEachNearestNeighborItem(clone, nni -> nni.setAllowApproximate(approximate));
        }
        if (field != null) {
            forEachNearestNeighborItem(clone, nni -> nni.setIndexName(field));
        }
        if (rankProfile != null) {
            clone.getRanking().setProfile(rankProfile);
        }
        if (targetHits != null) {
            clone.setHits(targetHits);
            forEachNearestNeighborItem(clone, nni -> nni.setTargetHits(targetHits));
        }
        if (exploreHits != null) {
            forEachNearestNeighborItem(clone, nni -> nni.setHnswExploreAdditionalHits(exploreHits));
        }
        return clone;
    }

    private static Result resultWithSingleHit(Query query, String field, Object value) {
        var hit = new Hit("recall/0");
        hit.setField(field, value);
        var result = new Result(query);
        result.hits().add(hit);
        result.setTotalHitCount(1);
        return result;
    }

    private static void forEachNearestNeighborItem(Query query, Consumer<NearestNeighborItem> action) {
        forEachNearestNeighborItem(query.getModel().getQueryTree().getRoot(), action);
    }

    private static void forEachNearestNeighborItem(Item item, Consumer<NearestNeighborItem> action) {
        if (item instanceof NearestNeighborItem nni) {
            action.accept(nni);
        } else if (item instanceof CompositeItem composite) {
            for (var child : composite.items()) {
                forEachNearestNeighborItem(child, action);
            }
        }
    }

    private List<SimpleHit> executeQuery(Query query, Execution parentExecution, String idField) {
        // Use the 'vespa' chain, which does not contain this searcher
        var vespaChain = parentExecution.searchChainRegistry().getComponent("vespa");
        var execution = new Execution(vespaChain, parentExecution.context());
        var result = execution.search(query);
        execution.fill(result); // to get summary data.
        if (result.hits().getError() != null) {
            throw new IllegalStateException("Query '" + query + "' failed: " + result.hits().getError());
        }

        log.log(Level.FINE, () -> "NNRS.execute(): result.hits().size=" + result.hits().size());
        var hits = new ArrayList<SimpleHit>();
        int cnt = 0;
        for (var itr = result.hits().deepIterator(); itr.hasNext(); ) {
            var hit = itr.next();
            if (hit.getField(idField) == null) {
                log.log(Level.WARNING, "NNRS.execute(): hit[" + cnt + "] was bad: '" + hit + "'");
                throw new IllegalArgumentException("bad hit: " + hit);
            }
            var simpleHit = new SimpleHit(hit.getField(idField).toString(), hit.getRelevance().getScore());
            log.log(Level.FINE, "NNRS.execute(): hit[" + cnt + "]='" + simpleHit + "'");
            hits.add(simpleHit);
            ++cnt;
        }
        return hits;
    }

    private int calcRecall(List<SimpleHit> exactHits, List<SimpleHit> approxHits, int k,
                           boolean enableRelevanceCheck) throws RelevanceMismatchException {
        int recall = 0;

        var map = new HashMap<String, Double>();
        for (SimpleHit hit : exactHits) {
            map.put(hit.id(), hit.relevance());
        }

        for (SimpleHit hit : approxHits) {
            Double exactRelevance = map.get(hit.id());
            if (exactRelevance != null) {
                recall += 1;
                if (enableRelevanceCheck && Math.abs(hit.relevance() - exactRelevance) > 1e-5) {
                    throw new RelevanceMismatchException("Relevance mismatch (eps=1e-5) in document '" +
                            hit.id() + "': relevance in exactHits is " + exactRelevance +
                            ", relevance in approxHits is " + hit.relevance());
                }
            }
        }

        // Adjust to k in case there are not enough exact hits.
        int exactSize = Math.min(exactHits.size(), k);
        if (exactSize == 0) {
            return k;
        } else if (exactSize < k) {
            return (recall * k) / exactSize;
        }

        return recall;
    }

}
