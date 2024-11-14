package com.yahoo.test;

import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;
import java.util.List;
import java.util.Map;

public class TestHandler extends ThreadedHttpRequestHandler {

    private final File contents;
    private final List<File> arrayOfUrls;
    private final Map<String, File> mapOfUrls;

    public TestHandler(TestConfig testConfig, Context context) {
        super(context);
        contents = testConfig.myurl();
        arrayOfUrls = testConfig.arrayOfUrls();
        mapOfUrls = testConfig.mapOfUrls();
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            if (httpRequest.getUri().getPath().endsWith("numfiles")) {
                return handleNumFiles();
            }
            return handleFileContents();
        } catch (Exception e) {
            return new HttpResponse(500) {
                @Override
                public void render(OutputStream outputStream) throws IOException {
                    outputStream.write(("Internal server error: " + e.getMessage()).getBytes());
                }
            };
        }
    }

    private HttpResponse handleFileContents() {
        final String fileContents = readContents();
        return new HttpResponse(200) {
            @Override
            public void render(OutputStream outputStream) throws IOException {
                outputStream.write(fileContents.getBytes());
            }
        };
    }

    private HttpResponse handleNumFiles() {
        return new HttpResponse(200) {
            @Override
            public void render(OutputStream outputStream) throws IOException {
                int numFiles = 0;
                if (contents.exists()) numFiles += 1;
                for (File f : arrayOfUrls) {
                    if (f.exists())
                        numFiles += 1;
                }
                for (File f : mapOfUrls.values()) {
                    if (f.exists())
                        numFiles += 1;
                }
                outputStream.write(String.format("%d", numFiles).getBytes());
            }
        };
    }

    private String readContents() {
        if (contents.exists() && contents.length() > 0) {
            try (BufferedReader br = new BufferedReader(new FileReader(contents))) {
                StringBuilder sb = new StringBuilder();
                String line = br.readLine();
                while (line != null) {
                    sb.append(line); sb.append("\n");
                    line = br.readLine();
                }
                return sb.toString();
            } catch (IOException e) {
                throw new RuntimeException("Exception reading file", e);
            }
        }
        throw new RuntimeException("Downloaded URL could not be found.");
    }

}

