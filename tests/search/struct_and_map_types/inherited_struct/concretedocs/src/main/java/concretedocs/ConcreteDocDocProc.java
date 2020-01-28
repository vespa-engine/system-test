// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package concretedocs;

import com.yahoo.document.*;
import com.yahoo.document.annotation.SpanTree;
import com.yahoo.docproc.*;
import com.yahoo.concretedocs.Base;
import com.yahoo.concretedocs.Usebase;
import java.util.logging.Logger;

/**
 * An dummy document processor for testing concrete struct inheritance.
 *
 * @author balder
 */
public class ConcreteDocDocProc extends DocumentProcessor {

    private static final Logger logger = Logger.getLogger(ConcreteDocDocProc.class.getName());

    public Progress process(Processing processing) {
        // Just checking this type is available
        Usebase testDoc = new Usebase(new DocumentId("id:ns:usebase::dummy"));
        if (!testDoc.getId().toString().equals("id:ns:usebase::dummy")) return Progress.FAILED;

        Document document = ((DocumentPut)processing.getDocumentOperations().get(0)).getDocument();
        if (document instanceof Usebase) return processUsebase((Usebase)document);
        return Progress.FAILED;
    }

    private Progress processUsebase(Usebase v) {
        logger.info("Concrete processing Usebase :" + v.toJson());
        return Progress.DONE;
    }

}
