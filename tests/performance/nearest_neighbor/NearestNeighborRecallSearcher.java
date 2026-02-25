// Copyright Vespa.ai. All rights reserved.

package ai.vespa.test;

import com.yahoo.prelude.Location;
import com.yahoo.prelude.query.AndItem;
import com.yahoo.prelude.query.IntItem;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.NearestNeighborItem;
import com.yahoo.prelude.query.GeoLocationItem;
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
            int filterPercent = props.getInteger("nnr.filterPercent", 0);
            double radius = Double.parseDouble(props.getString("nnr.radius", "-1.0"));
            double latitude = Double.parseDouble(props.getString("nnr.latitude", "0.0"));
            double longitude = Double.parseDouble(props.getString("nnr.longitude", "0.0"));
            double approximateThreshold = Double.parseDouble(props.getString("nnr.approximateThreshold", "0.05"));
            double filterFirstThreshold = Double.parseDouble(props.getString("nnr.filterFirstThreshold", "0.00"));
            double filterFirstExploration = Double.parseDouble(props.getString("nnr.filterFirstExploration", "0.3"));
            double slack = Double.parseDouble(props.getString("nnr.slack", "0.00"));
            boolean lazyFilter = Boolean.parseBoolean(props.getString("nnr.lazyFilter", "false"));
            double timeout = Double.parseDouble(props.getString("nnr.timeout", "20"));
            boolean annTimeoutEnable = Boolean.parseBoolean(props.getString("nnr.annTimeoutEnable", "false"));
            double annTimeoutFactor = Double.parseDouble(props.getString("nnr.annTimeoutFactor", "0.5"));
            String idField = props.getString("nnr.idField", "id");
            log.log(Level.FINE, "NNRS.search(): docTensor=" + docTensor +
                    ", queryTensor=" + queryTensor + ", targetHits=" + targetHits +
                    ", exploreHits=" + exploreHits + ", idField=" + idField);
            var approxHits = executeNearestNeighborQuery(query, execution,
                    docTensor, queryTensor, label, targetHits, exploreHits, filterPercent, radius, latitude, longitude, approximateThreshold, filterFirstThreshold, filterFirstExploration, slack, lazyFilter, true, idField, timeout, annTimeoutEnable, annTimeoutFactor);

            var exactHits = executeNearestNeighborQuery(query, execution,
                    docTensor, queryTensor, label, targetHits, exploreHits, filterPercent, radius, latitude, longitude, approximateThreshold, filterFirstThreshold, filterFirstExploration, slack, lazyFilter, false, idField, timeout, annTimeoutEnable, annTimeoutFactor);

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
                                                        String docTensor, String queryTensor, String label,
                                                        int targetHits, int exploreHits, int filterPercent,
                                                        double radius, double latitude, double longitude,
                                                        double approximateThreshold, double filterFirstThreshold, double filterFirstExploration,
                                                        double slack, boolean lazyFilter, boolean approximate, String idField, double timeout, boolean annTimeoutEnable, double annTimeoutFactor) {
        var nni = new NearestNeighborItem(docTensor, queryTensor);
        nni.setLabel(label);
        nni.setTargetNumHits(targetHits);
        nni.setHnswExploreAdditionalHits(exploreHits);
        nni.setAllowApproximate(approximate);

        Item root = nni;
        if (filterPercent > 0) {
            IntItem intItem = new IntItem(filterPercent, "filter");

            AndItem andItem = new AndItem();
            andItem.addItem(nni);
            andItem.addItem(intItem);
            root = andItem;
        }

        if (radius >= 0.0) {
            double km2deg = 1000.000 * 180.0 / (Math.PI * 6356752.0);
            double actual_radius = radius * km2deg;
            Location.Point center = new Location.Point(latitude, longitude);
            Location location = Location.fromGeoCircle(center, actual_radius);
            GeoLocationItem geoLocationItem = new GeoLocationItem(location, "latlng");

            AndItem andItem = new AndItem();
            andItem.addItem(root);
            andItem.addItem(geoLocationItem);
            root = andItem;
        }

        var query = new Query();
        query.getModel().getQueryTree().setRoot(root);
        String featureName = "ranking.features.query(" + queryTensor + ")";
        query.properties().set(featureName, parentQuery.properties().get(featureName));
        query.properties().set("summary", parentQuery.properties().getString("summary"));
        query.setHits(targetHits);

        query.properties().set("ranking.matching.approximateThreshold", approximateThreshold);
        query.properties().set("ranking.matching.filterFirstThreshold", filterFirstThreshold);
        query.properties().set("ranking.matching.filterFirstExploration", filterFirstExploration);
        query.properties().set("ranking.matching.explorationSlack", slack);
        query.properties().set("ranking.matching.lazyFilter", lazyFilter);
        query.properties().set("ranking.anntimeout.enable", annTimeoutEnable);
        query.properties().set("ranking.anntimeout.factor", annTimeoutFactor);
        if (approximate) {
            query.properties().set("timeout", String.valueOf(timeout) + "s");
        } else {
            query.properties().set("timeout", "20s");
        }

        var vespaChain = parentExecution.searchChainRegistry().getComponent("vespa");
        var execution = new Execution(vespaChain, parentExecution.context());
        var result = execution.search(query);
        execution.fill(result); // to get summary data.

        log.log(Level.FINE, "NNRS.execute(): result.hits().size=" + result.hits().size());
        var hits = new ArrayList<SimpleHit>();
        int cnt = 0;
        for (var itr = result.hits().deepIterator(); itr.hasNext(); ) {
            var hit = itr.next();
            if (hit.getField(idField) == null) {
                 log.log(Level.WARNING, "NNRS.execute(): hit[" + cnt + "] was bad: '" + hit + "'");
                 throw new IllegalArgumentException("bad hit: " + hit);
            } else {
                 var simpleHit = new SimpleHit(hit.getField(idField).toString(),
                                               hit.getRelevance().getScore());
                 log.log(Level.FINE, "NNRS.execute(): hit[" + cnt + "]='" + simpleHit + "'");
                 hits.add(simpleHit);
             }
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

        // Adjust to targetHits value in case there are not enough exact hits.
        if (exactSize == 0) {
            return targetHits;
        } else if (exactSize < targetHits) {
            return (recall * targetHits) / exactSize;
        }

        return recall;
    }

}
