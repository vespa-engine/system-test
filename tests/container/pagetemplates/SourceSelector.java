// Copyright Vespa.ai. All rights reserved.
package com.yahoo.search.example;

import com.yahoo.search.*;
import com.yahoo.search.intent.model.*;
import com.yahoo.search.searchchain.*;
import com.yahoo.text.interpretation.Interpretation;

import java.util.List;

/**
 * A searcher which uses QLAS information to select a set of sources. The sources are added in the
 * intent model containing the interpretations.
 *
 * This is not a serious implementation, just a demonstration of the API's.
 *
 * @author bratseth
 */
public class SourceSelector extends Searcher {

    private final Source yst=new Source("yst");
    private final Source news=new Source("news");

    public @Override Result search(Query query,Execution execution) {
        IntentModel intentModel= IntentModel.getFrom(query); // Same as query.properties().get("IntentModel")
        for (InterpretationNode interpretationNode : intentModel.children()) { // If not set, there is a "default"
            for (IntentNode intentNode : interpretationNode.children())
                assignSources(intentNode,interpretationNode.getInterpretation());
        }
        query.getModel().getSources().addAll(intentModel.getSourceNames()); // Ignore query settings for simplicity
        return execution.search(query);
    }

    private void assignSources(IntentNode intentNode, Interpretation interpretation) {
        double newsAppropriateness=0;
        if (interpretation.getAll("place_name").size()>0) // A place is mentioned
            newsAppropriateness+=0.3;
        if (interpretation.getAll("person_name").size()>0) // A person is mentioned
            newsAppropriateness+=0.2;
        double ystAppropriateness=1-newsAppropriateness;
        intentNode.children().add(new SourceNode(yst,ystAppropriateness));
        intentNode.children().add(new SourceNode(news,newsAppropriateness));
    }

}
