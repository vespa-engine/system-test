// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.*;

import java.util.logging.Logger;
import java.util.Iterator;

/**
 * @author Einar M R Rosenvinge
 */
public class RemoveProcessor extends DocumentProcessor {

    private static Logger log = Logger.getLogger(RemoveProcessor.class.getName());

    @Override
    public Progress process(Processing processing) {
		Iterator<DocumentOperation> it = processing.getDocumentOperations().iterator();
		while (it.hasNext()) {
			DocumentOperation op = it.next();
			if (!(op instanceof DocumentRemove)) {
				continue;
			}
			DocumentRemove documentRemove = (DocumentRemove)op;

			if (documentRemove.getId().toString().equals("id:test:worst::3")) {
				log.info("Not deleting " + documentRemove.getId() + ", removing from Processing");
				it.remove();
			} else {
				log.info("Deleting " + documentRemove.getId() + " (doing nothing in docproc)");
			}
		}
		return Progress.DONE;
	}

}
