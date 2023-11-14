// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.grouping.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.grouping.Continuation;
import com.yahoo.search.grouping.GroupingRequest;
import com.yahoo.search.grouping.request.*;
import com.yahoo.search.grouping.result.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

/**
 * @author Simon Thoresen
 */
public class TestSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution exec) {
        GroupingRequest minReq = GroupingRequest.newInstance(query);
        minReq.setRootOperation(
            new AllOperation()
            .setGroupBy(new LongValue(69))
            .addChild(new EachOperation()
                      .setLabel("min")
                      .addOutput(new SumAggregator(new MinFunction(
                                     new AttributeValue("value"),
                                     new AttributeValue("price")))
                                 .setLabel("min"))));

        GroupingRequest maxReq = GroupingRequest.newInstance(query);
        maxReq.setRootOperation(
            new AllOperation()
            .setGroupBy(new LongValue(69))
            .addChild(new EachOperation()
                      .setLabel("max")
                      .addOutput(new SumAggregator(new MaxFunction(
                                     new AttributeValue("value"),
                                     new AttributeValue("price")))
                                 .setLabel("max"))));

        GroupingRequest valReq = GroupingRequest.newInstance(query);
        valReq.setRootOperation(
            new AllOperation()
            .setGroupBy(new AttributeValue("value"))
            .setMax(1)
            .addOrderBy(new AvgAggregator(new AttributeValue("value")))
            .addChild(new EachOperation()
                      .setLabel("val")
                      .addOutput(new AvgAggregator(new AttributeValue("value"))
                                 .setLabel("val"))));
        Continuation page2 = Continuation.fromString("BGBEAABEBCBC");
        valReq.continuations().add(page2);

        Result res = exec.search(query);
        Hit hit = new Hit("TestResult");
        hit.setField("min", checkResult(minReq.getResultGroup(res), "min", 104));
        hit.setField("max", checkResult(maxReq.getResultGroup(res), "max", 1004));
        hit.setField("val", checkResult(valReq.getResultGroup(res), "val", 21));
        res.hits().add(hit);
        return res;
    }

    private String checkResult(Group grp, String label, int exp) {
        if (grp == null) {
            return "FAIL(" + label + "): did not get root group";
        }
        if (grp.size() != 1) {
            return "FAIL(" + label + "): expected 1 group list, got " + grp.size();
        }
        GroupList lst = grp.getGroupList(label);
        if (lst == null) {
            return "FAIL(" + label + "): did not get '" + label + "' group list";
        }
        if (lst.size() != 1) {
            return "FAIL(" + label + "): expected 1 group, got " + lst.size();
        }
        Hit hit = lst.get(0);
        if (!(grp instanceof Group)) {
            return "FAIL(" + label + "): expected Group, got " + hit.getClass();
        }
        grp = (Group)hit;
        Object obj = grp.getField(label);
        if (obj == null) {
            return "FAIL(" + label + "): did not get result output";
        }
        if (!(obj instanceof Long)) {
            return "FAIL(" + label + "): expected Long, got " + obj.getClass();
        }
        if ((Long)obj != exp) {
            return "FAIL(" + label + "): expected " + exp + ", got " + obj;
        }
        return "PASS: " + label;
    }
}
