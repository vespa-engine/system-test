// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.*;
import com.yahoo.document.*;
import java.util.logging.Level;
import java.util.logging.Logger;

public class SleeperDocproc extends DocumentProcessor {

    private static Logger log = Logger.getLogger(SleeperDocproc.class.getName());

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation documentOperation : processing.getDocumentOperations()) {
		    for (long now = System.currentTimeMillis(), end = now + 5000; now < end; now = System.currentTimeMillis()) {
			    try {
					long tmp = end - now;
					log.log(Level.INFO, "Document (" + documentOperation.getId() + ") going to sleep for " + tmp + " milliseconds.");
					Thread.sleep(tmp);
		    	}
			    catch (InterruptedException e) {
					log.log(Level.INFO, "Document (" + documentOperation.getId() + ") sleep walking..");
			    }
			}
	    	log.log(Level.INFO, "Document (" + documentOperation.getId() + ") waking up.");
		}
        return Progress.DONE;
    }

}
