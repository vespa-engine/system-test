// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.processing.execution.chain.ChainRegistry;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.federation.selection.FederationTarget;
import com.yahoo.search.federation.selection.TargetSelector;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.model.federation.FederationOptions;

import java.util.Arrays;
import java.util.Collection;


/**
 * @author tonyv
 */
public class TestTargetSelector implements TargetSelector<String> {
    String keyName = getClass().getName();

    @Override
    public Collection<FederationTarget<String>> getTargets(Query query, ChainRegistry<Searcher> searcherChainRegistry) {
        return Arrays.asList(
                new FederationTarget<>(searcherChainRegistry.getComponent("used-by-TestTargetSelector"), new FederationOptions(), "custom-data"));
    }

    @Override
    public void modifyTargetQuery(FederationTarget<String> target, Query query) {
        query.properties().set(keyName, "modifyTargetQuery called");
    }

    @Override
    public void modifyTargetResult(FederationTarget<String> target, Result result) {
        Hit hit = new Hit("target-selector-hit");
        hit.setField("title", target.getCustomData() + "--" + result.getQuery().properties().get(keyName));
        result.hits().add(hit);
    }
}
