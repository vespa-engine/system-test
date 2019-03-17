// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.config.testutil;

import com.yahoo.cloud.config.ConfigserverConfig;
import com.yahoo.config.codegen.CNode;
import com.yahoo.config.codegen.DefParser;
import com.yahoo.config.codegen.InnerCNode;
import com.yahoo.config.model.api.ConfigDefinitionRepo;
import com.yahoo.config.provision.ApplicationId;
import com.yahoo.config.provision.NodeFlavors;
import com.yahoo.config.provision.TenantName;
import com.yahoo.component.Version;
import com.yahoo.config.provisioning.FlavorsConfig;
import com.yahoo.config.subscription.CfgConfigPayloadBuilder;
import com.yahoo.jrt.Spec;
import com.yahoo.vespa.config.*;
import com.yahoo.vespa.config.buildergen.ConfigDefinition;
import com.yahoo.vespa.config.protocol.ConfigResponse;
import com.yahoo.vespa.config.protocol.SlimeConfigResponse;
import com.yahoo.vespa.config.server.ReloadHandler;
import com.yahoo.vespa.config.server.RequestHandler;
import com.yahoo.vespa.config.GenerationCounter;
import com.yahoo.vespa.config.server.SuperModelManager;
import com.yahoo.vespa.config.server.SuperModelRequestHandler;
import com.yahoo.vespa.config.server.application.ApplicationSet;
import com.yahoo.vespa.config.server.filedistribution.FileServer;
import com.yahoo.vespa.config.server.host.HostRegistries;
import com.yahoo.vespa.config.server.monitoring.MetricUpdater;
import com.yahoo.vespa.config.server.monitoring.Metrics;
import com.yahoo.vespa.config.server.rpc.RpcServer;
import com.yahoo.vespa.config.server.tenant.TenantHandlerProvider;
import com.yahoo.vespa.config.util.ConfigUtils;
import com.yahoo.log.LogLevel;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * A mock config server for use in testing.
 *
 * @author hmusum
 */
public class TestConfigServer implements RequestHandler, ReloadHandler, TenantHandlerProvider, Runnable {

    private static final String TENANT_NAME = "default";

    private static final java.util.logging.Logger log = java.util.logging.Logger.getLogger(TestConfigServer.class.getName());

    public static final String DEFAULT_DEF_DIR = "configs/def-files";
    public static final String DEFAULT_CFG_DIR = "configs/foo";

    private final String defDir;
    private String configDir;
    private final int port;
    private AtomicLong generation; // The generation of the set of configs we are currently serving
    private long getConfDelayTimeMillis = 0L; // To induce slow response

    /** a cache of config objects, mapping config key to raw config */
    private final Map<ConfigKey, ConfigResponse> configCache = new LinkedHashMap<>();

    /** a cache of config definition objects, mapping config key to def md5sum */
    private final Map<ConfigKey, String> defCache = Collections.synchronizedMap(new LinkedHashMap<> (100, 0.90f, true));
    private final Map<ConfigDefinitionKey, InnerCNode> defNodes = Collections.synchronizedMap(new LinkedHashMap<> (100, 0.90f, true));

    private final RpcServer rpcServer;

    // TODO Refactor out a method for the deployment part here
    public TestConfigServer(int port, String defDir, String configDir) {
        ConfigDefinitionRepo configDefinitionRepo = new ConfigDefinitionRepo() {
            @Override
            public Map<ConfigDefinitionKey, ConfigDefinition> getConfigDefinitions() {
                return Collections.emptyMap();
            }

            @Override
            public ConfigDefinition get(ConfigDefinitionKey key) {
                return null;
            }
        };
        
        ConfigserverConfig configServerConfig = new ConfigserverConfig(new ConfigserverConfig.Builder());
        final NodeFlavors nodeFlavors = new NodeFlavors(new FlavorsConfig(new FlavorsConfig.Builder()));
        final SuperModelManager superModelManager = new SuperModelManager(configServerConfig, nodeFlavors, new GenerationCounter() {
            @Override
            public long increment() {
                return 0;
            }

            @Override
            public long get() {
                return 0;
            }
        });
        SuperModelRequestHandler handler = new SuperModelRequestHandler(configDefinitionRepo, configServerConfig, superModelManager);
        this.rpcServer = new RpcServer(new ConfigserverConfig(new ConfigserverConfig.Builder().rpcport(port)),
                                       handler, 
                                       dimensions -> new MetricUpdater(Metrics.createTestMetrics(), Collections.emptyMap()),
                                       new HostRegistries(),
                                       new com.yahoo.vespa.config.server.host.ConfigRequestHostLivenessTracker(),
                                       new FileServer(configServerConfig));
        rpcServer.onTenantCreate(TenantName.from(TENANT_NAME), this);
        this.port = port;
        this.defDir = defDir;
        this.configDir = configDir;
        generation = loadLiveApplication();
    }

    /**
     * Loads definitions and sets generation for current set of configs.
     * Configs are loaded at config resolving time.
     */
    private void loadDefFiles() {
        try {
            defCache.clear();
            for (File file : getDefFiles()) {
                loadDefFile(file);
            }
        } catch (FileNotFoundException e) {
            log.log(LogLevel.ERROR, "Error loading def: ", e);
        }
    }

    private File[] getCfgFiles() {
        FilenameFilter cfgFilter = (dir, name) -> name.endsWith(".cfg");
        return (new File(configDir)).listFiles(cfgFilter);
    }

    private File[] getDefFiles() {
        FilenameFilter defFilter = (dir, name) -> name.endsWith(".def");
        return (new File(defDir)).listFiles(defFilter);
    }

    private void loadCfgFiles(String configId, String namespace) {
        for (File file : getCfgFiles()) {
            loadCfgFile(file, configId, namespace);
        }
    }

    @Override
    public boolean hasApplication(ApplicationId appId, Optional<Version> vespaVersion) {
      return true;
    }

    private List<String> readFileContents(File file) {
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(
                    new java.io.InputStreamReader(
                            new java.io.FileInputStream(file), StandardCharsets.UTF_8));
            List<String> fileContents = new ArrayList<>();
            String line;
            while ((line = reader.readLine()) != null) {
                fileContents.add(line);
            }
            return fileContents;
        } catch (FileNotFoundException e) {
            System.err.println("File not found:" + file.getName());
        } catch (IOException ioe) {
            System.err.println("IO error when opening " + file.getName()
                    + ":" + ioe.getMessage());
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return null;
    }

    private String getConfigName(File file) {
        String[] nameComponents = file.getName().split("\\.");
        if (nameComponents.length >= 1) {
            return nameComponents[0];
        } else {
            return null;
        }
    }

    private void addConfigDef(ConfigKey key, String defMd5, InnerCNode cnode) {
        final ConfigDefinitionKey configDefinitionKey = new ConfigDefinitionKey(key);
        if (!defCache.containsKey(key)) {
            defCache.put(key, defMd5);
            defNodes.put(configDefinitionKey, cnode);
        }
    }

    private void addConfig(ConfigKey key, ConfigResponse configResponse) {
        // Always store, even if key exists in cache, since config can change without the key changing
        configCache.put(key, configResponse);
        if (key.getNamespace().equals("")) {
            ConfigKey newKey = new ConfigKey(key.getName(), key.getConfigId(), CNode.DEFAULT_NAMESPACE);
            configCache.put(newKey, configResponse);
        }
    }

    /**
     * Loads file and stores it in config cache.
     * @param file the File to load
     * @param configId a config id
     * @param namespace namespace of a config definition
     */
    private void loadCfgFile(File file, String configId, String namespace) {
        //System.out.println("Loading " + file.getName() + " for subscriber " + configId);
        String name = getConfigName(file);
        List<String> fileContents = readFileContents(file);

        ConfigPayload payload = new CfgConfigPayloadBuilder().deserialize(fileContents);
        String configMd5Sum = ConfigUtils.getMd5(payload);
        ConfigKey cKey = new ConfigKey(name, "", namespace);
        String defMd5 = defCache.get(cKey);
        InnerCNode targetDef = defNodes.get(new ConfigDefinitionKey(cKey));
        if (defMd5 != null) {
            ConfigKey key = new ConfigKey(name, configId, namespace);
            addConfig(key, createResponse(new CfgConfigPayloadBuilder().deserialize(fileContents), configMd5Sum, getApplicationGeneration(), targetDef));
        } else {
            System.out.println("No config definition for " + namespace + "." + name + ", unable to add config");
        }
    }

    private ConfigResponse createResponse(ConfigPayload payload, String configMd5Sum, long applicationGeneration, InnerCNode targetDef) {
        return SlimeConfigResponse.fromConfigPayload(payload, targetDef, applicationGeneration, false, configMd5Sum);
    }

    private void loadDefFile(File file) throws FileNotFoundException {
        String name = getConfigName(file);
        List<String> fileContents = readFileContents(file);
        String md5Sum = ConfigUtils.getDefMd5(fileContents);
        InnerCNode cnode = new DefParser(name, new FileReader(file)).getTree();
        try {
            String configId = "";
            String namespace = ConfigUtils.getDefNamespace(new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8));
            addConfigDef(new ConfigKey(name, configId, namespace), md5Sum, cnode);
        } catch (IOException e) {
            throw new RuntimeException("IOException: " + e.getMessage(), e);
        }
    }

    public static void main(String[] args) {
        TestConfigServer server;
        String defDir = DEFAULT_DEF_DIR;
        String configDir = DEFAULT_CFG_DIR;
        int port;
        if (args.length < 1) {
        	System.out.println("Usage: ConfigServer <port> [ <defsdir> ] [ <cfgdir> ]");
        	System.exit(1);
        }
        port = Integer.parseInt(args[0]);
        if (args.length > 1) {
            defDir = args[1];
        }
        if (args.length > 2) {
        	configDir = args[2];
        }
        server = new TestConfigServer(port, defDir, configDir);
        new Thread(server).start();
    }

    /**
     * For testing.  Sets new application package directory. Does not reload config (@see #reloadConfig())
     * @param configDir     directory to read config files from
     */
    public synchronized void deployNewConfig(String configDir) {
        log.info("Deploying the dir " + configDir);
        this.configDir = configDir;
        long gen = updateApplication();
        log.log(LogLevel.INFO, "Config reloaded successfully with new application generation " + gen);
    }

    protected AtomicLong loadLiveApplication() {
        loadDefFiles();
        return new AtomicLong(1);
    }

    public synchronized long updateApplication() {
        configCache.clear();
        loadDefFiles();
        return generation.incrementAndGet();
    }

    public synchronized ConfigResponse resolveConfig(GetConfigRequest req) {
        if (getConfDelayTimeMillis > 0) {
            try {
                Thread.sleep(getConfDelayTimeMillis);
            } catch (InterruptedException e) {
                throw new RuntimeException(e);
            }
        }
        //log.info("In resolveConfig");
        // Load config files for every call, to get the correct config id.  This is just a test server, after all.
        String namespace = "";
        ConfigKey<?> key = req.getConfigKey();
        namespace = key.getNamespace();
        final ConfigDefinitionKey configDefinitionKey = new ConfigDefinitionKey(key);

        loadCfgFiles(key.getConfigId(), namespace);
        if (!defNodes.containsKey(configDefinitionKey)) {
            System.out.println("keys and values in defnode:" + defNodes);
            throw new RuntimeException("Configserver at " + port + " could not resolve config for " + req.toString());
        }
        if (configCache.containsKey(key)) {
            return configCache.get(key);
        } else {
            // TODO: Remove? I don't think this is needed, throw an exception instead?
            return createResponse(ConfigPayload.empty(), ConfigUtils.getMd5(ConfigPayload.empty()), generation.get(), defNodes.get(key));
        }
    }

    @Override
    public synchronized ConfigResponse resolveConfig(ApplicationId appId, GetConfigRequest req, Optional<Version> vespaVersion) {
        return resolveConfig(req);
    }
    
    @Override
    public synchronized void removeApplication(ApplicationId applicationId) { }

    @Override
    public void removeApplicationsExcept(Set<ApplicationId> applications) { }

    @Override
    public final void reloadConfig(ApplicationSet application) { }

    @Override
    public Set<ConfigKey<?>> listConfigs(ApplicationId applicationId, Optional<Version> vespaVersion, boolean recurse) {
        return new HashSet<>();
    }

    @Override
    public Set<ConfigKey<?>> listNamedConfigs(ApplicationId appId, Optional<Version> vespaVersion, ConfigKey<?> key, boolean recurse) {
        return new HashSet<>();
    }

    @Override
    public Set<ConfigKey<?>> allConfigsProduced(ApplicationId appId, Optional<Version> vespaVersion) {
        return new HashSet<>();
    }
    
    @Override
    public Set<String> allConfigIds(ApplicationId appId, Optional<Version> vespaVersion) {
        return new HashSet<>();
    }

    /**
     * For testing. Sets a delay on resolveConfig to emulate slow response
     * @param getConfDelayTimeMillis time to wait before responding
     */
    public void setGetConfDelayTimeMillis(long getConfDelayTimeMillis) {
        this.getConfDelayTimeMillis = getConfDelayTimeMillis;
    }

    @Override
    public void run() {
        rpcServer.run();
    }

    public void stop() {
        rpcServer.stop();
    }

    @Override
    public RequestHandler getRequestHandler() {
        return this;
    }

    @Override
    public ReloadHandler getReloadHandler() {
        return this;
    }
    
    @Override
    public ApplicationId resolveApplicationId(String hostName) {
        return ApplicationId.defaultId();
    }

    public long getApplicationGeneration() {
        return generation.get();
    }

    public Spec getSpec() {
        return new Spec(null, port);
    }

}
