// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.config.testutil;

import com.yahoo.cloud.config.ConfigserverConfig;
import com.yahoo.component.Version;
import com.yahoo.config.FileReference;
import com.yahoo.config.codegen.DefParser;
import com.yahoo.config.codegen.InnerCNode;
import com.yahoo.config.model.api.ConfigDefinitionRepo;
import com.yahoo.config.provision.ApplicationId;
import com.yahoo.config.provision.TenantName;
import com.yahoo.config.provision.Zone;
import com.yahoo.config.subscription.CfgConfigPayloadBuilder;
import com.yahoo.io.IOUtils;
import com.yahoo.jrt.Spec;
import com.yahoo.vespa.config.ConfigDefinitionKey;
import com.yahoo.vespa.config.ConfigKey;
import com.yahoo.vespa.config.ConfigPayload;
import com.yahoo.vespa.config.GenerationCounter;
import com.yahoo.vespa.config.GetConfigRequest;
import com.yahoo.vespa.config.PayloadChecksum;
import com.yahoo.vespa.config.PayloadChecksums;
import com.yahoo.vespa.config.buildergen.ConfigDefinition;
import com.yahoo.vespa.config.protocol.ConfigResponse;
import com.yahoo.vespa.config.protocol.SlimeConfigResponse;
import com.yahoo.vespa.config.server.RequestHandler;
import com.yahoo.vespa.config.server.SuperModelManager;
import com.yahoo.vespa.config.server.SuperModelRequestHandler;
import com.yahoo.vespa.config.server.filedistribution.FileDirectory;
import com.yahoo.vespa.config.server.filedistribution.FileServer;
import com.yahoo.vespa.config.server.host.HostRegistry;
import com.yahoo.vespa.config.server.monitoring.MetricUpdater;
import com.yahoo.vespa.config.server.monitoring.Metrics;
import com.yahoo.vespa.config.server.rpc.RpcRequestHandlerProvider;
import com.yahoo.vespa.config.server.rpc.RpcServer;
import com.yahoo.vespa.config.server.rpc.security.NoopRpcAuthorizer;
import com.yahoo.vespa.config.server.tenant.Tenant;
import com.yahoo.vespa.config.util.ConfigUtils;
import com.yahoo.vespa.flags.FlagSource;
import com.yahoo.vespa.flags.InMemoryFlagSource;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.time.Instant;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * A mock config server for use in testing.
 *
 * @author hmusum
 */
public class TestConfigServer implements RequestHandler, Runnable {

    private static final java.util.logging.Logger log = Logger.getLogger(TestConfigServer.class.getName());
    private static final TenantName tenantName = TenantName.from("default");
    public static final String DEFAULT_DEF_DIR = "configs/def-files";
    public static final String DEFAULT_CFG_DIR = "configs/foo";

    private final String defDir;
    private String configDir;
    private final int port;
    private final AtomicLong generation; // The generation of the set of configs we are currently serving
    private long getConfDelayTimeMillis = 0L; // To induce slow response

    /** a cache of config objects, mapping config key to raw config */
    private final Map<ConfigKey<?>, ConfigResponse> configCache = new LinkedHashMap<>();

    /** a cache of config definition objects, mapping config key to def md5sum */
    private final Map<ConfigKey<?>, String> defCache = Collections.synchronizedMap(new LinkedHashMap<> (100, 0.90f, true));
    private final Map<ConfigDefinitionKey, InnerCNode> defNodes = Collections.synchronizedMap(new LinkedHashMap<> (100, 0.90f, true));

    private final RpcServer rpcServer;

    public TestConfigServer(int port, String defDir, String configDir) {
        ConfigserverConfig configServerConfig = configserverConfig(port);
        FlagSource flagSource = new InMemoryFlagSource();
        SuperModelRequestHandler superModelRequestHandler = createSuperModelRequestHandler(configServerConfig, flagSource);
        this.rpcServer = new RpcServer(configServerConfig,
                                       superModelRequestHandler,
                                       dimensions -> new MetricUpdater(Metrics.createTestMetrics(), Collections.emptyMap()),
                                       new HostRegistry(),
                                       new FileServer(new FileDirectory(configServerConfig, flagSource)),
                                       new NoopRpcAuthorizer(),
                                       new RpcRequestHandlerProvider());
        rpcServer.setUpGetConfigHandlers();
        rpcServer.onTenantCreate(new MockTenant(tenantName, this));
        this.port = port;
        this.defDir = defDir;
        this.configDir = configDir;
        loadDefFiles();
        generation = new AtomicLong(1);
    }

    /**
     * Loads definitions and sets generation for current set of configs.
     * Configs are loaded at config resolving time.
     */
    private void loadDefFiles() {
        defCache.clear();
        for (File file : getFiles((new File(defDir)), (dir, name) -> name.endsWith(".def"))) {
            loadDefFile(file);
        }
    }

    private File[] getFiles(File dir, FilenameFilter filenameFilter) {
        return dir.listFiles(filenameFilter);
    }

    private void loadCfgFiles(String configId, String namespace) {
        for (File file : getFiles((new File(configDir)), (dir, name) -> name.endsWith(".cfg"))) {
            loadCfgFile(file, configId, namespace);
        }
    }

    @Override
    public boolean hasApplication(ApplicationId appId, Optional<Version> vespaVersion) {
      return true;
    }

    private String getConfigName(File file) {
        String[] nameComponents = file.getName().split("\\.");
        if (nameComponents.length >= 1) {
            return nameComponents[0];
        } else {
            throw new RuntimeException("Could not find config file " + file);
        }
    }

    private void addConfigDef(ConfigKey<?> key, String defMd5, InnerCNode cnode) {
        defCache.putIfAbsent(key, defMd5);
        defNodes.putIfAbsent(new ConfigDefinitionKey(key), cnode);
    }

    private void addConfig(ConfigKey<?> key, ConfigResponse configResponse) {
        // Always store, even if key exists in cache, since config can change without the key changing
        configCache.put(key, configResponse);
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
        List<String> lines = readLines(file);
        ConfigPayload payload = new CfgConfigPayloadBuilder().deserialize(lines);
        String xxhash = ConfigUtils.getXxhash64(payload);
        PayloadChecksums checksums = PayloadChecksums.from(new PayloadChecksum(xxhash, PayloadChecksum.Type.XXHASH64));
        ConfigKey<?> cKey = new ConfigKey<>(name, "", namespace);
        String defMd5 = defCache.get(cKey);
        if (defMd5 != null) {
            ConfigKey<?> key = new ConfigKey<>(name, configId, namespace);
            addConfig(key, createResponse(new CfgConfigPayloadBuilder().deserialize(lines), checksums, getApplicationGeneration()));
        } else {
            System.out.println("No config definition for " + namespace + "." + name + ", unable to add config");
        }
    }

    private List<String> readLines(File file) {
        try {
            String fileContents = IOUtils.readFile(file);
            return List.of(fileContents.split("\n"));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private ConfigResponse createResponse(ConfigPayload payload, PayloadChecksums payloadChecksums, long applicationGeneration) {
        return SlimeConfigResponse.fromConfigPayload(payload, applicationGeneration, false, payloadChecksums);
    }

    private void loadDefFile(File file) {
        String name = getConfigName(file);
        List<String> lines = readLines(file);
        String md5Sum = ConfigUtils.getDefMd5(lines);
        try {
            InnerCNode cnode = new DefParser(name, new FileReader(file)).getTree();
            String configId = "";
            String namespace = ConfigUtils.getDefNamespace(new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8));
            addConfigDef(new ConfigKey<>(name, configId, namespace), md5Sum, cnode);
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
        this.configDir = configDir;
        long gen = updateApplication();
        log.log(Level.INFO, "Activated config with generation " + gen + " from directory " + configDir +
                               " on config server using port " + port);
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
        String namespace;
        ConfigKey<?> key = req.getConfigKey();
        namespace = key.getNamespace();
        final ConfigDefinitionKey configDefinitionKey = new ConfigDefinitionKey(key);

        loadCfgFiles(key.getConfigId(), namespace);
        if (!defNodes.containsKey(configDefinitionKey)) {
            System.out.println("keys and values in defnode:" + defNodes);
            throw new RuntimeException("Configserver at " + port + " could not resolve config for " + req);
        }
        if (configCache.containsKey(key)) {
            return configCache.get(key);
        } else {
            throw new RuntimeException("Could not resolve config " + key);
        }
    }

    @Override
    public synchronized ConfigResponse resolveConfig(ApplicationId appId, GetConfigRequest req, Optional<Version> vespaVersion) {
        return resolveConfig(req);
    }

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
    public ApplicationId resolveApplicationId(String hostName) {
        return ApplicationId.defaultId();
    }

    @Override
    public Set<FileReference> listFileReferences(ApplicationId applicationId) {
        return Set.of();
    }

    @Override
    public boolean compatibleWith(Optional<Version> optional, ApplicationId applicationId) { return true; }

    public long getApplicationGeneration() {
        return generation.get();
    }

    public Spec getSpec() {
        return new Spec(null, port);
    }

    @Override
    public String toString() {
        return "Config server running on port " + port;
    }

    private ConfigserverConfig configserverConfig(int port) {
        String fileReferencesDir;
        try {
            fileReferencesDir = Files.createTempDirectory("filereferences").toString();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return new ConfigserverConfig.Builder()
                .fileReferencesDir(fileReferencesDir)
                .rpcport(port)
                .build();
    }

    private SuperModelRequestHandler createSuperModelRequestHandler(ConfigserverConfig configServerConfig, FlagSource flagSource) {
        SuperModelManager superModelManager = new SuperModelManager(configServerConfig,
                                                                    Zone.defaultZone(),
                                                                    new TestGenerationCounter(),
                                                                    flagSource);
        return new SuperModelRequestHandler(new TestConfigDefinitionRepo(),
                                            configServerConfig,
                                            superModelManager);
    }

    private static class MockTenant extends Tenant {

        MockTenant(TenantName tenantName, RequestHandler requestHandler) {
            super(tenantName, null, requestHandler, null, Instant.now());
        }

    }

    private static class TestConfigDefinitionRepo implements ConfigDefinitionRepo {
        @Override
        public Map<ConfigDefinitionKey, ConfigDefinition> getConfigDefinitions() { return Map.of(); }

        @Override
        public ConfigDefinition get(ConfigDefinitionKey key) { return null; }
    }

    private static class TestGenerationCounter implements GenerationCounter {
        @Override
        public long increment() { return 0; }

        @Override
        public long get() { return 0; }
    }

}
