package com.yahoo.vespaclient.test;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentId;
import com.yahoo.document.serialization.DeserializationException;
import com.yahoo.document.serialization.XmlStream;
import com.yahoo.documentapi.*;
import com.yahoo.documentapi.messagebus.protocol.DocumentListMessage;
import com.yahoo.documentapi.messagebus.protocol.EmptyBucketsMessage;
import com.yahoo.documentapi.messagebus.protocol.MapVisitorMessage;
import com.yahoo.log.LogLevel;
import com.yahoo.messagebus.Message;
import com.yahoo.vdslib.SearchResult;
import com.yahoo.vdslib.DocumentSummary;
import com.yahoo.documentapi.messagebus.protocol.DocumentListEntry;
import java.util.List;
import com.yahoo.document.BucketId;
import com.yahoo.vespavisit.VdsVisitHandler;

import org.apache.commons.cli.*;

import java.io.PrintStream;
import java.io.File;
import java.util.logging.Logger;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Date;

/**
 * A modified version of StdOutVisitorHandler that should ONLY be used
 * for the dynamic distribution bits system test.
 *
 * @author <a href="mailto:thomasg@yahoo-inc.com">Thomas Gundersen</a>
 * @author <a href="mailto:vekterli@yahoo-inc.com">Tor Brede Vekterli</a>
 * @version $Id$
 */
public class TestVisitorHandler extends VdsVisitHandler {
    private static final Logger log = Logger.getLogger(
                                        TestVisitorHandler.class.getName());
    private boolean printIds;
    private boolean indentXml;
    private int processTimeMilliSecs;
    private PrintStream out;
    private int documentThreshold;
    private File ackFile;
    private File killFile;
    private long startupKillFileModified = 0;
    private int currentDocumentCount = 0;

    private VisitorDataHandler dataHandler;
    private VisitorControlHandler controlHandler;

    public TestVisitorHandler(boolean printIds, boolean indentXml,
                                boolean showProgress, boolean showStatistics, boolean doStatistics,
                                boolean abortOnClusterDown, int processtime, String[] args) throws Exception
    {
        super(showProgress, showStatistics, abortOnClusterDown);

        this.printIds = printIds;
        this.indentXml = indentXml;
        this.processTimeMilliSecs = processtime;
        String charset = "UTF-8";
        try {
            out = new PrintStream(System.out, true, charset);
        } catch (java.io.UnsupportedEncodingException e) {
            System.out.println(charset + " is an unsupported encoding, " +
                               "using default instead.");
            out = System.out;
        }
        dataHandler = new DataHandler(doStatistics);
        controlHandler = new ControlHandler();

        if (args == null) {
            throw new IllegalArgumentException("No handler options given with --visitoptions");
        }

        Options options = new Options();
        options.addOption(OptionBuilder.withLongOpt("threshold")
                          .hasArg(true)
                          .withArgName("count")
                          .withDescription("Number of documents to accept before pausing on the ackfile")
                          .withType(Number.class)
                          .create("m"));
        options.addOption(OptionBuilder.withLongOpt("ackfile")
                          .hasArg(true)
                          .withArgName("filename")
                          .withDescription("File used for communicating to the handler that it should continue ACKing (touch file)")
                          .create("a"));
        options.addOption(OptionBuilder.withLongOpt("killfile")
                          .hasArg(true)
                          .withArgName("filename")
                          .withDescription("File used for communicating to the handler that it should stop (touch file)")
                          .create("k"));

        CommandLineParser parser = new PosixParser();
        CommandLine line = parser.parse(options, args);

        if (line.hasOption("m")) {
            documentThreshold = ((Number)line.getParsedOptionValue("m")).intValue();
        } else {
            throw new IllegalArgumentException("must specify --threshold");
        }

        if (line.hasOption("a")) {
            ackFile = new File(line.getOptionValue("a"));
        } else {
            throw new IllegalArgumentException("must specify --ackfile");
        }

        if (line.hasOption("k")) {
            killFile = new File(line.getOptionValue("k"));
        } else {
            throw new IllegalArgumentException("must specify --killfile");
        }

        if (!ackFile.exists()) {
            throw new IllegalArgumentException("given ackfile does not exist");
        }
        if (!killFile.exists()) {
            throw new IllegalArgumentException("given killfile does not exist");
        }
        startupKillFileModified = killFile.lastModified();
	log.log(LogLevel.INFO, "Instantiated test visitor handler");
    }

    public void onDone() {
    }

    public VisitorDataHandler getDataHandler() { return dataHandler; }

    class StatisticsMap extends LinkedHashMap<String, Integer> {
        int maxSize;

        StatisticsMap(int maxSize) {
            super(100, (float)0.75, true);
            this.maxSize = maxSize;
        }

        protected boolean removeEldestEntry(java.util.Map.Entry eldest) {
            if (size() > maxSize) {
                dump(eldest);
                return true;
            }

            return false;
        }

        private void dump(java.util.Map.Entry e) {
            out.println(e.getKey() + ":" + e.getValue());
        }

        public void dumpAll() {
            for (Map.Entry e : entrySet()) {
                dump(e);
            }
            clear();
        }
    }

    class DataHandler extends DumpVisitorDataHandler {
        boolean doStatistics;
	private boolean done = false;
        StatisticsMap statisticsMap = new StatisticsMap(10000);

        public DataHandler(boolean doStatistics) {
            this.doStatistics = doStatistics;
        }

        @Override
	public void onMessage(Message m, AckToken token) {
            if (processTimeMilliSecs > 0) {
                try {
                    Thread.sleep(processTimeMilliSecs);
                } catch (InterruptedException e) {}
            }

	    log.log(LogLevel.DEBUG, "onMessage: " + m);

            synchronized (getPrintLock()) {
                if (m instanceof MapVisitorMessage) {
                    onMapVisitorData(((MapVisitorMessage)m).getData());
                    ack(token);
                } else if (m instanceof EmptyBucketsMessage) {
                    onEmptyBuckets(((EmptyBucketsMessage)m).getBucketIds());
                    ack(token);
                } else {
                    super.onMessage(m, token);
                }
            }
        }

        @Override
        public void onDocument(Document doc, long timestamp) {
	    log.log(LogLevel.DEBUG, "onDocument: " + doc);
	    synchronized (this) {

		try {
		    out.print(doc.toXML(indentXml ? "  " : ""));
		} catch (Exception e) {
		    System.err.println("Failed to output document: "
				       + e.getMessage());
		    getControlHandler().abort();
		    return;
		}
		
		++currentDocumentCount;
		
		if (currentDocumentCount == documentThreshold) {
		    log.log(LogLevel.DEBUG, "Document threshold exceeded; pausing");
		    System.err.println("Taking a chill pill and waiting for the ACK file to be touched...");
		    // First, touch the file so that the system test knows it's OK to do a
		    // re-deployment of vespa
		    ackFile.setLastModified(new Date().getTime());
		    long lastModified = ackFile.lastModified();
		    assert(lastModified != 0);
		    try {
			do {
			    Thread.sleep(1000);
			} while (ackFile.lastModified() == lastModified);
		    } catch (InterruptedException e) {
			// This is just test utility code, don't bother with any cleanup
		    }
		    log.log(LogLevel.DEBUG, "Resumed from pause");
		    System.err.println("aaaaag after ten thousand years i'm finally free!!");
		}
	    }
        }

        @Override
        public void onRemove(DocumentId docId) {
            try {
		XmlStream stream = new XmlStream();
		stream.beginTag("remove");
		stream.addAttribute("documentid", docId);
		stream.endTag();
		assert(stream.isFinalized());
		out.print(stream);
            } catch (Exception e) {
                System.err.println("Failed to output document: "
                        + e.getMessage());
                getControlHandler().abort();
            }
        }

	public void onDocumentList(BucketId bucketId, List<DocumentListEntry> documents) {
            out.println("Got document list of bucket " + bucketId.toString());
	    log.log(LogLevel.DEBUG, "Got document list with " + documents.size() + " entries");
            for (DocumentListEntry entry : documents) {
                entry.getDocument().setLastModified(entry.getTimestamp());
                onDocument(entry.getDocument(), entry.getTimestamp());
            }
        }

        public void onEmptyBuckets(List<BucketId> bucketIds) {
            StringBuilder buckets = new StringBuilder();
            for(BucketId bid : bucketIds) {
                buckets.append(" ");
                buckets.append(bid.toString());
            }
            log.log(LogLevel.INFO, "Got EmptyBuckets: " + buckets);
        }

	public void onMapVisitorData(java.util.Map<String, String> data) {
            for (String key : data.keySet()) {
                if (doStatistics) {
                    Integer i = statisticsMap.get(key);
                    if (i != null) {
                        statisticsMap.put(key, Integer.parseInt(data.get(key)) + i);
                    } else {
                        statisticsMap.put(key, Integer.parseInt(data.get(key)));
                    }
                } else {
                    out.println(key + ":" + data.get(key));
                }
            }
        }

        public synchronized void onDone() {
            statisticsMap.dumpAll();
            super.onDone();
        }
    }

    public VisitorControlHandler getControlHandler() {
        return controlHandler;
    }

    class ControlHandler extends VisitorControlHandler {
        public void onProgress(ProgressToken token) {
            super.onProgress(token);
        }

        public void onDone(CompletionCode code, String message) {
            if (code != CompletionCode.SUCCESS) {
                if (code == CompletionCode.ABORTED) {
                    System.err.println("Visitor aborted: " + message);
                } else if (code == CompletionCode.TIMEOUT) {
                    System.err.println("Visitor timed out: " + message);
                } else {
                    System.err.println("Visitor aborted due to unknown issue "
				       + code + ": " + message);
                }
            }
            super.onDone(code, message);
        }

        @Override
	    public boolean isDone() {
            return killFile.lastModified() != startupKillFileModified;
	}

    }
}
