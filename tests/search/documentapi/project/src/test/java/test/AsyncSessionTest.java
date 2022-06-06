// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.DocumentType;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.documentapi.AsyncParameters;
import com.yahoo.documentapi.AsyncSession;
import com.yahoo.documentapi.DocumentAccess;
import com.yahoo.documentapi.DocumentResponse;
import com.yahoo.documentapi.Response;
import com.yahoo.documentapi.Result;
import org.junit.After;
import org.junit.Test;

import java.util.concurrent.Callable;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static test.AssertQuery.assertQuery;
import static test.Documents.newDocument;
import static test.Documents.newUpdate;

/**
 * @author Simon Thoresen Hult
 */
public class AsyncSessionTest {

    private final static int TIMEOUT_MILLIS = (int)TimeUnit.SECONDS.toMillis(60);
    private final DocumentAccess access = DocumentAccess.createForNonContainer();
    private final AsyncSession session = access.createAsyncSession(new AsyncParameters());

    @Test
    public void requireThatAsyncSessionWorks() throws Exception {
        DocumentType type = access.getDocumentTypeManager().getDocumentType("test");
        assertPut(newDocument(type, "id:tenant:test::foo", "bar"));
        assertGet("id:tenant:test::foo", "bar");

        assertUpdate(newUpdate(type, "id:tenant:test::foo", "baz"));
        assertGet("id:tenant:test::foo", "baz");

        assertRemove("id:tenant:test::foo");
        assertGet("id:tenant:test::foo", null);
    }

    @After
    public void after() {
        session.destroy();
        access.shutdown();
    }

    private void assertPut(final Document doc) throws Exception {
        System.out.println("Put '" + doc.getId() + "'..");
        assertSuccess(new Callable<Result>() {

            @Override
            public Result call() throws Exception {
                return session.put(doc);
            }
        });
        Response response = session.getNext(TIMEOUT_MILLIS);
        assertTrue(response.getTextMessage(), response.isSuccess());
    }

    private void assertUpdate(final DocumentUpdate upd) throws Exception {
        System.out.println("Update '" + upd.getId() + "'..");
        assertSuccess(new Callable<Result>() {

            @Override
            public Result call() throws Exception {
                return session.update(upd);
            }
        });
        Response response = session.getNext(TIMEOUT_MILLIS);
        assertTrue(response.getTextMessage(), response.isSuccess());
    }

    private void assertRemove(final String docId) throws Exception {
        System.out.println("Remove '" + docId + "'..");
        assertSuccess(new Callable<Result>() {

            @Override
            public Result call() throws Exception {
                return session.remove(new DocumentId(docId));
            }
        });
        Response response = session.getNext(TIMEOUT_MILLIS);
        assertTrue(response.getTextMessage(), response.isSuccess());
    }

    private void assertGet(final String docId, String expectedFieldValue) throws Exception {
        System.out.println("Get '" + docId + "'..");
        assertSuccess(new Callable<Result>() {

            @Override
            public Result call() throws Exception {
                return session.get(new DocumentId(docId));
            }
        });
        Response response = session.getNext(TIMEOUT_MILLIS);
        assertTrue(response.getTextMessage(), response.isSuccess());
        assertTrue(response instanceof DocumentResponse);
        Document doc = ((DocumentResponse)response).getDocument();
        System.out.println(doc);
        if (expectedFieldValue == null) {
            assertNull(doc);
        } else {
            assertNotNull(doc);
            assertEquals(new StringFieldValue(expectedFieldValue), doc.getFieldValue("my_str"));
        }
    }

    private static boolean assertSuccess(Callable<Result> task) throws Exception {
        long timeoutAt = System.currentTimeMillis() + TIMEOUT_MILLIS;
        while (System.currentTimeMillis() < timeoutAt) {
            Result result = task.call();
            if (result.isSuccess()) {
                return true;
            }
            if (result.type() == Result.ResultType.FATAL_ERROR) {
                throw result.error();
            }
            Thread.sleep(1000);
        }
        throw new TimeoutException();
    }
}
