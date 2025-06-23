// Copyright Vespa.ai. All rights reserved.

package ai.vespa.test;

import com.yahoo.prelude.query.NearestNeighborItem;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.ErrorMessage;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Searcher that calculates the recall between a brute force (exact) nearest neighbor search,
 * and an approximate search over the hnsw index.
 */
@Before("blendedResult")
@After("transformedQuery")
public class NearestNeighborRecallSearcher extends Searcher {

    private static final Logger log = Logger.getLogger(NearestNeighborRecallSearcher.class.getName());

    private static class SimpleHit {
        String id;
        double relevance;
        SimpleHit(String id, double relevance) {
            this.id = id;
            this.relevance = relevance;
        }
        @Override
        public String toString() {
            return "{id='" + id + ", relevance=" + relevance + "}";
        }
    }

    private static class RelevanceMismatchException extends Exception {
        public RelevanceMismatchException(String msg) {
            super(msg);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        var props = query.properties();
        var enable = props.getString("nnr.enable");
        if (enable != null && enable.equals("true")) {
            String docTensor = props.getString("nnr.docTensor", "vec_m16");
            String queryTensor = props.getString("nnr.queryTensor", "q_vec");
            String label = props.getString("nnr.label", "nns");
            int targetHits = props.getInteger("nnr.targetHits", 10);
            int exploreHits = props.getInteger("nnr.exploreHits", 0);
            String idField = props.getString("nnr.idField", "id");
            log.log(Level.FINE, "NNRS.search(): docTensor=" + docTensor +
                    ", queryTensor=" + queryTensor + ", targetHits=" + targetHits +
                    ", exploreHits=" + exploreHits + ", idField=" + idField);
            var exactHits = executeNearestNeighborQuery(query, execution,
                    docTensor, queryTensor, label, targetHits, exploreHits, false, idField);

            var approxHits = executeNearestNeighborQuery(query, execution,
                    docTensor, queryTensor, label, targetHits, exploreHits, true, idField);

            try {
                int recall = calcRecall(exactHits, approxHits, targetHits);
                var hit = new Hit("recall/0");
                hit.setField("recall", recall);
                var result = new Result(query);
                result.hits().add(hit);
                result.setTotalHitCount(1);
                return result;
            } catch (RelevanceMismatchException ex) {
                log.log(Level.SEVERE, "NNRS.search(): ex='" + ex.getMessage() + "'");
                var result = new Result(query, ErrorMessage.createUnspecifiedError(ex.getMessage(), ex));
                // Adding a regular hit makes it easy to check in the Ruby code,
                // where errors currently are not parsed from the result set.
                var hit = new Hit("recall/0");
                hit.setField("error", ex.getMessage());
                result.hits().add(hit);
                result.setTotalHitCount(1);
                return result;
            }
        } else {
            return execution.search(query);
        }
    }

    private List<SimpleHit> executeNearestNeighborQuery(Query parentQuery, Execution parentExecution,
                                                        String docTensor, String queryTensor,
                                                        String label,
                                                        int targetHits, int exploreHits,
                                                        boolean approximate, String idField) {
        var nni = new NearestNeighborItem(docTensor, queryTensor);
        nni.setLabel(label);
        nni.setTargetNumHits(targetHits);
        nni.setHnswExploreAdditionalHits(exploreHits);
        nni.setAllowApproximate(approximate);

        var query = new Query();
        query.getModel().getQueryTree().setRoot(nni);
        String featureName = "ranking.features.query(" + queryTensor + ")";
        query.properties().set(featureName, parentQuery.properties().get(featureName));
        query.properties().set("summary", parentQuery.properties().getString("summary"));
        query.setHits(targetHits);

        var vespaChain = parentExecution.searchChainRegistry().getComponent("vespa");
        var execution = new Execution(vespaChain, parentExecution.context());
        var result = execution.search(query);
        execution.fill(result); // to get summary data.

        log.log(Level.FINE, "NNRS.execute(): result.hits().size=" + result.hits().size());
        var hits = new ArrayList<SimpleHit>();
        int cnt = 0;
        for (var itr = result.hits().deepIterator(); itr.hasNext(); ) {
            var hit = itr.next();
            var simpleHit = new SimpleHit(hit.getField(idField).toString(),
                    hit.getRelevance().getScore());
            log.log(Level.FINE, "NNRS.execute(): hit[" + cnt + "]='" + simpleHit + "'");
            hits.add(simpleHit);
            ++cnt;
        }
        return hits;
    }

    private int calcRecall(List<SimpleHit> exactHits, List<SimpleHit> approxHits, int targetHits) throws RelevanceMismatchException {
        int recall = 0;
        int i = 0;
        int j = 0;
        int exactSize = Math.min(exactHits.size(), targetHits);
        int approxSize = Math.min(approxHits.size(), targetHits);
        while ((i < exactSize) && (j < approxSize)) {
            var ex = exactHits.get(i);
            var ap = approxHits.get(j);

            if (ex.id.equals(ap.id)) {
                if (Math.abs(ex.relevance - ap.relevance) > 1e-5) {
                    throw new RelevanceMismatchException("Relevance mismatch (eps=1e-5) in document '" +
                            ex.id + "': exact[" + i + "].relevance=" + ex.relevance + ", approx[" + j + "].relevance=" + ap.relevance);
                }
                recall += 1;
                i += 1;
                j += 1;
            } else if (ex.relevance > ap.relevance) {
                i += 1;
            } else {
                j += 1;
            }
        }
        return recall;
    }

}
