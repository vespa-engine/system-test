// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespa.config.testutil;

import com.yahoo.jrt.Acceptor;
import com.yahoo.jrt.Int32Value;
import com.yahoo.jrt.ListenFailedException;
import com.yahoo.jrt.Method;
import com.yahoo.jrt.Request;
import com.yahoo.jrt.Spec;
import com.yahoo.jrt.Supervisor;
import com.yahoo.jrt.Transport;

import java.util.HashMap;
import java.util.Map;

/**
 * A config server controller, capable of taking user input and perform actions on the config server.
 *
 * @author Ulf Lilleengen
 */
public class ConfigServerRunner {

	private static class ServerContext {
		public final TestConfigServer server;
		public final Thread thread;
		
		public ServerContext(int port, String defDir, String configDir) {
			server = new TestConfigServer(port, defDir, configDir);
			thread = new Thread(server);
			thread.start();
		}
	}

	public static final int DEFAULT_PORT = 12345;
	private final Map<Integer, ServerContext> serverMap = new HashMap<>();
    private final Supervisor supervisor = new Supervisor(new Transport());

    private String defDir;
    private final int configPort;
    private String configDir;
    private volatile boolean ready = false;

    public ConfigServerRunner(int port, String defDir, String configDir) {
        this.defDir = defDir;
        this.configDir = configDir;
        this.configPort = port;

        supervisor.addMethod(createDeployApplicationMethod());
        supervisor.addMethod(createStartMethod());
        supervisor.addMethod(createStopMethod());
        supervisor.addMethod(createPingMethod());
    }

    private void deployApplication(Request req) {
        String configDir = req.parameters().get(0).asString();
        this.configDir = configDir;
        System.out.println(configPort + ": deploying application " + configDir);
        for (ServerContext ctx : serverMap.values()) {
        	ctx.server.deployNewConfig(configDir);
    	}
        req.returnValues().add(new Int32Value(0));
    }

    private void startServer(Request req) {
        String defDir = req.parameters().get(0).asString();
        this.defDir = defDir;
        String configDir = req.parameters().get(1).asString();
        this.configDir = configDir;
        int port = req.parameters().get(2).asInt32();

        if (serverMap.get(port) != null) {
            System.out.println("Server already running on port " + port);
            req.returnValues().add(new Int32Value(1));
            return;
        }

        System.out.println("Starting server on port (" + port + "), defDir(" + defDir + "), configDir(" + configDir + ")");
        ServerContext sc = new ServerContext(port, this.defDir, this.configDir);
        serverMap.put(port, sc);
        req.returnValues().add(new Int32Value(0));
    }

    private void stopServer(Request req) {
    	if (serverMap.size() < 1) {
            System.err.println("No servers to stop");
            req.returnValues().add(new Int32Value(1));
            return;
        }
        try {
        	int port = req.parameters().get(0).asInt32();
            System.out.println(configPort + ": stopping server on port " + port);
            ServerContext sc = serverMap.get(port);
            if (sc == null) {
            	System.out.println("No server running on port " + port);
                req.returnValues().add(new Int32Value(2));
            	return;
            }
            sc.server.stop();
            sc.thread.join();
            serverMap.remove(port);
        } catch (InterruptedException e) {
            e.printStackTrace();
            System.exit(1);
        }
        req.returnValues().add(new Int32Value(0));
    }

    private void ping(Request request) {
        if (ready) {
            request.returnValues().add(new Int32Value(1));
        } else {
            request.returnValues().add(new Int32Value(0));
        }
    }

    public void run() {
        // TODO Auto-generated method stub
        Spec spec = new Spec("tcp/localhost:" + configPort);
        try {
            System.out.println("Listing...");
            Acceptor acceptor = supervisor.listen(spec);
            System.out.println("Done..");
            ready = true;
            supervisor.transport().join();
            System.out.println("Join1..");
            acceptor.shutdown().join();
            System.out.println("Join2..");
        } catch (ListenFailedException e) {
            System.out.println("Could not listen at " + spec);
            supervisor.transport().shutdown().join();
            System.exit(1);
        }
    }

    public Method createPingMethod() {
        return new Method("ping", "", "i",
                this::ping)
                .methodDesc("ping monitor to ensure that it is up")
                .returnDesc(0, "retCode", "1 if ready, 0 if not");
    }

    public Method createStartMethod() {
        return new Method("startServer", "ssi", "i",
                this::startServer)
                .methodDesc("start server")
                .paramDesc(0, "defDir", "Config def file directory")
                .paramDesc(1, "configDir", "Config file directory")
                .paramDesc(2, "port", "Port on which server should listen")
                .returnDesc(0, "retCode", "return code, 0 is OK");
    }

    public Method createStopMethod() {
        return new Method("stopServer", "i", "i",
                this::stopServer)
                .methodDesc("stop server")
                .paramDesc(0, "port", "Port on which server that should be stopped is running")
                .returnDesc(0, "ret code", "return code, 0 is OK");
    }

    public Method createDeployApplicationMethod() {
        return new Method("deployApplication", "s", "i",
                this::deployApplication)
                .methodDesc("deploy application")
                .paramDesc(0, "configDir", "Config file directory")
                .returnDesc(0, "ret code", "return code, 0 is OK");
    }

     public static void main(String[] args) {
            String defDir = TestConfigServer.DEFAULT_DEF_DIR;
            String configDir = TestConfigServer.DEFAULT_CFG_DIR;
            int port = ConfigServerRunner.DEFAULT_PORT;
            if (args.length > 0) {
                port = Integer.parseInt(args[0]);
            }
            if (args.length > 1) {
                defDir = args[1];
            }
            if (args.length > 2) {
                configDir = args[2];
            }
            ConfigServerRunner runner = new ConfigServerRunner(port, defDir, configDir);
            runner.run();
        }

}
