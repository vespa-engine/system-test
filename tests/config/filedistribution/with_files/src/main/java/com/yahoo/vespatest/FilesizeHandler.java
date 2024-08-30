package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.filedistribution.fileacquirer.FileAcquirer;
import com.yahoo.test.FilesConfig;

import java.io.File;
import java.util.concurrent.TimeUnit;

public class FilesizeHandler extends AbstractRequestHandler {

    private final File file;

    public FilesizeHandler(FilesConfig filesConfig, FileAcquirer fileAcquirer) {
	try {
	    //System.err.println(this + " waiting for fileref: " + filesConfig.myFile());
	    file = fileAcquirer.waitFor(filesConfig.myFile(), 5, TimeUnit.MINUTES);
	    //System.err.println(this + " got file with fileref: " + filesConfig.myFile());
        } catch (InterruptedException e) {
            throw new RuntimeException("InterruptedException: ", e);
        }
    }

    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        try {
	    writer.write(String.valueOf(file.length()));
        } finally {
            writer.close();
        }
        return null;
    }

}
