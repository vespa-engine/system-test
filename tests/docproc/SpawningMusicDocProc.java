// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.google.inject.Inject;
import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentTypeManager;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.config.DocumentmanagerConfig;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.document.update.FieldUpdate;

import java.util.ArrayList;
import java.util.List;

/**
 * Document processor that spawns a new document.
 *
 * @author Einar
 * @author dybdahl
 */
public class SpawningMusicDocProc extends DocumentProcessor {

    private final DocumentType type;

    @Inject
    public SpawningMusicDocProc(DocumentmanagerConfig docManCfg) {
        DocumentTypeManager manager = new DocumentTypeManager(docManCfg);
        this.type = manager.getDocumentType("music");
    }

    @Override
    public Progress process(Processing processing) {
        List<DocumentOperation> toBeAdded = new ArrayList<>();
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (!(op instanceof DocumentPut)) {
                continue;
            }
            Document doc = ((DocumentPut)op).getDocument();

            long time = System.nanoTime();
            processDoc(doc, time);
            toBeAdded.add(spawnUpdate(time));
        }
        processing.getDocumentOperations().addAll(toBeAdded);
        return Progress.DONE;
    }

    private DocumentUpdate spawnUpdate(long time) {
        DocumentId newId = new DocumentId("id:music:music::0");
        DocumentUpdate upd = new DocumentUpdate(type, newId);
        upd.addFieldUpdate(FieldUpdate.createAssign(type.getField("title"), new StringFieldValue("Updated " + time)));
        return upd;
    }

    private void processDoc(Document doc, long time) {
        doc.setFieldValue("title", "document " + time);
    }

}