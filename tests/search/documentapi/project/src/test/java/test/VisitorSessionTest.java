// Copyright Vespa.ai. All rights reserved.
package test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentType;
import com.yahoo.documentapi.DocumentAccess;
import com.yahoo.documentapi.DumpVisitorDataHandler;
import com.yahoo.documentapi.SyncParameters;
import com.yahoo.documentapi.SyncSession;
import com.yahoo.documentapi.VisitorControlHandler;
import com.yahoo.documentapi.VisitorParameters;
import com.yahoo.documentapi.VisitorSession;
import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assume.assumeTrue;
import static test.Documents.newDocument;

/**
 * @author Simon Thoresen Hult
 */
public class VisitorSessionTest {

    @Before
    public void requireElasticSetup() {
        assumeTrue("INDEXED".equals(System.getProperty("searchType")));
    }

    @Test
    public void requireThatVisitSessionWorks() throws Exception {
        DocumentAccess access = DocumentAccess.createForNonContainer();
        SyncSession session = access.createSyncSession(new SyncParameters.Builder().build());

        DocumentType type = access.getDocumentTypeManager().getDocumentType("test");
        DocumentPut foo = new DocumentPut(newDocument(type, "id:tenant:test::foo", "fooVal"));
        DocumentPut bar = new DocumentPut(newDocument(type, "id:tenant:test::bar", "barVal"));
        session.put(foo);
        session.put(bar);

        final List<Document> out = new ArrayList<>();
        VisitorParameters params = new VisitorParameters("");
        params.setRoute("search-direct");
        params.setControlHandler(new VisitorControlHandler());
        params.setLocalDataHandler(new DumpVisitorDataHandler() {

            @Override
            public void onDocument(Document doc, long timeStamp) {
                out.add(doc);
            }

            @Override
            public void onRemove(DocumentId id) {

            }
        });
        VisitorSession visitor = access.createVisitorSession(params);
        assertTrue(visitor.waitUntilDone(60000));
        assertEquals(2, out.size());
        assertTrue(out.contains(foo.getDocument()));
        assertTrue(out.contains(bar.getDocument()));

        visitor.destroy();
        session.destroy();
        access.shutdown();
    }
}
