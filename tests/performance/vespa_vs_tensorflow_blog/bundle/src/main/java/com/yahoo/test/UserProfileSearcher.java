// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.component.chain.dependencies.Provides;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

import java.util.Random;

@Provides("UserProfile")
@After("ImageRemoval")
public class UserProfileSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        query.getRanking().getFeatures().put("query(user_item_cf)", generateRandomProfile());
        return execution.search(query);
    }

    private Tensor generateRandomProfile() {
        Tensor.Builder builder = Tensor.Builder.of(TensorType.fromSpec("tensor<float>(d0[1],d1[128])"));
        Random random = new Random();
        for (int i = 0; i < 128; ++i) {
            builder.cell(random.nextDouble(), 0, i);
        }
        return builder.build();
    }

}
