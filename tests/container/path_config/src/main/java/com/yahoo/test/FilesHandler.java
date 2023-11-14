// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.filedistribution.fileacquirer.FileAcquirer;

import java.io.*;
import java.util.concurrent.TimeUnit;
import java.util.List;
import java.util.ArrayList;

public class FilesHandler extends AbstractRequestHandler {

    private List<File> files = new ArrayList<File>();

    public FilesHandler(FileAcquirer fileAcquirer, PathsAndFilesConfig config) {
        try {
            //System.err.println(this + " waiting for fileref: " + config.files().fileVal());
            files.add(fileAcquirer.waitFor(config.files().fileVal(), 5, TimeUnit.MINUTES));
            //System.err.println(this + " got file with fileref: " + config.files().fileVal());

            files.add(config.paths().pathVal().toFile());
            files.add(config.paths().pathArr(0).toFile());
            files.add(config.paths().pathMap("one").toFile());

        } catch (InterruptedException e) {
            throw new RuntimeException("InterruptedException: ", e);
        }
    }

    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).
            connectFastWriter(handler);
        try {
            for (File f : files)
                writer.write(readFile(f));
        } finally {
            writer.close();
        }
        return null;
    }

    private String readFile(File file) {
        StringBuilder ret = new StringBuilder();
        try {
            LineNumberReader reader = new LineNumberReader(new InputStreamReader(new FileInputStream(file), "UTF-8"));
            try {
                String line;
                while ((line = reader.readLine()) != null) {
                    ret.append(line).append("\n");
                }
            } finally {
                reader.close();
            }
        } catch (IOException e) {
            throw new RuntimeException("IOException: ", e);
        }
        return ret.toString();
    }
}
