// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.pagetemplates.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.pagetemplates.model.Choice;
import com.yahoo.search.pagetemplates.engine.Resolver;
import com.yahoo.search.pagetemplates.engine.Resolution;
import com.yahoo.search.pagetemplates.engine.resolvers.DeterministicResolver;

/** Like the deterministic resolver except that it takes the <i>first</i> option of all choices */
public class MiddleChoiceResolver extends DeterministicResolver {

    /** Chooses the middle alternative of any choice */
    @Override
    public void resolve(Choice choice, Query query, Result result, Resolution resolution) {
        resolution.addChoiceResolution(choice,(int)choice.alternatives().size()/2);
    }

}
