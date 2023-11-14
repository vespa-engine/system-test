// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package concretedocs;

import com.yahoo.document.*;
import com.yahoo.document.annotation.SpanTree;
import com.yahoo.docproc.*;
import com.yahoo.concretedocs.Base;
import com.yahoo.concretedocs.Usebase;
import java.util.logging.Logger;

/**
 * A dummy document processor for testing concrete struct inheritance.
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
        logger.info("CDDP Concrete processing Usebase :" + v.toJson());

        var f1 = v.getF1();
        logger.info("CDDP f1 is: " + f1.getClass());
        logger.info("CDDP f1.name = " + f1.getName());
        logger.info("CDDP f1.age = " + f1.getAge());

        var f2 = v.getF2();
        logger.info("CDDP f2 is: " + f2.getClass());
        logger.info("CDDP f2.name = " + f2.getName());
        logger.info("CDDP f2.age = " + f2.getAge());

        var f3 = v.getF3();
        logger.info("CDDP f3 is: " + f3.getClass());
        logger.info("CDDP f3.name = " + f3.getName());
        logger.info("CDDP f3.age = " + f3.getAge());
        logger.info("CDDP f3.desc = " + f3.getDesc());

        var f4 = v.getF4();
        logger.info("CDDP f4 is: " + f4.getClass());
        logger.info("CDDP f4.basicinfo is: " + f4.getBasicinfo().getClass());
        logger.info("CDDP f4 basicinfo.name = " + f4.getBasicinfo().getName());
        logger.info("CDDP f4 basicinfo.age = " + f4.getBasicinfo().getAge());
        logger.info("CDDP f4 occupation = " + f4.getOccupation());

        var f5 = v.getF5();
        logger.info("CDDP f5 is:" + f5 + " -> " + f5.getClass());

        for (var elem : f5) {
            logger.info("CDDP f5 element is:" + elem.getClass());
            logger.info("CDDP f5 element.name = " + elem.getName());
            logger.info("CDDP f5 element.age = " + elem.getAge());
        }
        return Progress.DONE;
    }

}
