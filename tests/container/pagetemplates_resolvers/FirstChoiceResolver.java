// Copyright Vespa.ai. All rights reserved.
package com.yahoo.search.pagetemplates.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.pagetemplates.model.Choice;
import com.yahoo.search.pagetemplates.engine.Resolver;
import com.yahoo.search.pagetemplates.engine.Resolution;
import com.yahoo.search.pagetemplates.engine.resolvers.DeterministicResolver;

/** Like the deterministic resolver except that it takes the <i>first</i> option of all choices */
public class FirstChoiceResolver extends DeterministicResolver {

    /** Chooses the first alternative of any choice */
    @Override
    public void resolve(Choice choice, Query query, Result result, Resolution resolution) {
        resolution.addChoiceResolution(choice,0);
    }

}
