// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.Writer;
import java.util.Collection;

import com.yahoo.search.grouping.result.Group;
import com.yahoo.search.grouping.result.GroupList;
import com.yahoo.search.grouping.result.HitList;
import com.yahoo.search.query.context.QueryContext;
import com.yahoo.search.rendering.SectionedRenderer;
import com.yahoo.search.result.ErrorHit;
import com.yahoo.search.result.ErrorMessage;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.Result;

public class DemoRenderer extends SectionedRenderer<PrintWriter> {
    int indentation;

    @Override
    public void init() {
        indentation = 0;
    }

    @Override
    public String getEncoding() {
        return "utf-8";
    }

    @Override
    public String getMimeType() {
        return "text/plain";
    }

    @Override
    public PrintWriter wrapWriter(Writer writer) {
        return new PrintWriter(writer);
    }

    @Override
    public void beginResult(PrintWriter writer, Result result) throws IOException {
        indent(writer);
        writer.println("Begin result with " + result.getHitCount() + " hits.");
        ++indentation;
    }


    @Override
    public void endResult(PrintWriter writer, Result result) throws IOException {
        --indentation;
        indent(writer);
        writer.println("End result with " + result.getHitCount() + " hits.");
    }


    @Override
    public void error(PrintWriter writer, Collection<ErrorMessage> errorMessages) throws IOException {
        for (ErrorMessage message : errorMessages) {
            indent(writer);
            writer.println("ErrorMessage: " + message.toString());
        }
    }

    @Override
    public void emptyResult(PrintWriter writer, Result result) throws IOException {
        indent(writer);
        writer.println("Verifying empty result: " + (result.getHitCount() == 0));
    }

    @Override
    public void queryContext(PrintWriter writer, QueryContext queryContext) throws IOException {
        indent(writer);
        writer.println("Verifying non-empty query context: " + !queryContext.toString().isEmpty());
    }

    @Override
    public void beginHitGroup(PrintWriter writer, HitGroup hitGroup) throws IOException {
        beginGeneralGroup(writer, hitGroup, "hit group");
    }

    @Override
    public void endHitGroup(PrintWriter writer, HitGroup hitGroup) throws IOException {
        endGeneralGroup(writer, hitGroup, "hit group");
    }

    @Override
    public void hit(PrintWriter writer, Hit hit) throws IOException {
        indent(writer);
        writer.println("Hit: " + hit.getField("documentid"));
    }

    @Override
    public void errorHit(PrintWriter writer, ErrorHit errorHit) throws IOException {
        indent(writer);
        writer.println("ErrorHit: " + errorHit.errors().iterator().next().toString());
    }

    @Override
    public void beginGroup(PrintWriter writer, Group group) throws IOException {
        beginGeneralGroup(writer, group, "group");
    }

    @Override
    public void endGroup(PrintWriter writer, Group group) throws IOException {
        endGeneralGroup(writer, group, "group");
    }

    @Override
    public void beginHitList(PrintWriter writer, HitList hitList) throws IOException {
        beginGeneralGroup(writer, hitList, "hit list");
    }

    @Override
    public void endHitList(PrintWriter writer, HitList hitList) throws IOException {
        endGeneralGroup(writer, hitList, "hit list");
    }

    @Override
    public void beginGroupList(PrintWriter writer, GroupList groupList) throws IOException {
        beginGeneralGroup(writer, groupList, "group list");
    }

    @Override
    public void endGroupList(PrintWriter writer, GroupList groupList) throws IOException {
        endGeneralGroup(writer, groupList, "group list");
    }


    private void beginGeneralGroup(PrintWriter writer, Hit group, String groupName) {
        indent(writer);
        writer.println("Begin " + groupName + ": " + group.getRelevance());
        ++indentation;
    }

    private void endGeneralGroup(PrintWriter writer, Hit group, String groupName) {
        --indentation;
        indent(writer);
        writer.println("End " + groupName + ": " + group.getRelevance());
    }

    private void indent(PrintWriter writer) {
        for (int i = 0; i < indentation; ++i)
            writer.print("    ");
    }
}
