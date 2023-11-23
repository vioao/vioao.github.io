---
title: RocketMQ 概览
seo_title: rockketmq-for-beginner
date: 2019-11-18 11:38:51
tags: [RocketMQ,JAVA,大数据]
categories: [中间件]
---

### 简介
Apache RocketMQ 是阿里开源的一款高性能、高吞吐量的分布式消息中间件。相比于 Kafka，其拥有更好的实时性和消息可靠性。更适用于和 Money 相关的系统。它支持如下特性：
- 订阅/发布模式的消息
  > 支持消费组模式的消费，即一个消费组集群内只有一个实例会收到那一条消息。
- 延时消息
  > 只支持特定 Level 的延时设置，默认有 “1s 5s 10s 30s 1m 2m 3m 4m 5m 6m 7m 8m 9m 10m 20m 30m 1h 2h” 18个 Level。先扔到对应的延时队列，后台线程根据延时再将其挪到实际的 Topic 中。
- 顺序消息
  > 只保证在单个 Broker 的单个 Queue 内是有序的，全局不保证有序。和 Kafka 一样.。
- 消息持久化
  > [主从同步 + 同步刷盘] 模式保证了持久数据的安全性。4.5 版本后加入 [Dleger](https://github.com/openmessaging/openmessaging-storage-dledger/blob/master/docs/cn/introduction_dledger.md#dledger-%E7%9A%84%E5%AE%9E%E7%8E%B0) 更是支持了 主从自动切换。
- 消息过滤
  > RocketMQ的消费者可以根据Tag进行消息过滤，也支持自定义属性过滤。消息过滤目前是在Broker端实现，减少了r无用消息的网络传输。
- 消息回溯
  > 已消费过的消息，可以根据时间或 key 等维度来重新消费。在处理系统环境异常时很有用。
- 事务消息
  > 先发送到一个特殊的系统 Topic 中，然后利用 2PC + 事务回查机制，判断将消息转到真正的 Topic 还是抛弃。
- 死信队列
  > 消费失败并重试一定次数还是失败的的消息会先放到死信队列，需要手动进行重发
- 消息重试
  > 每个消费组有一个 “%RETRY%+consumerGroup” 的重试队列。重试的消息会按照延迟的时间先放到 “SCHEDULE_TOPIC_XXXX” 队列中，然后才会被保存至 “%RETRY%+consumerGroup” 的重试队列中。
- At-Least-Once
  > 消息消费有 ACK 机制，消费结束才返回对应的 ACK 相应。和 Kafka 不太一样，Kafka 追求消息的大量快速处理，默认都是异步，整合成一批来消费生产的。

<!-- more -->

RoeketMQ 总的来说大致可以分为几个部分：NameServer, Broker Server, Client ( Producer and Consumer )。物理部署逻辑图如下：

{% asset_img RocketMQ_A.png RocketMQ 物理架构 %}
NameServer：保存 Topic 路由信息，NameServer 实例之间不通信
Broker：Broker 有主从之分，Broker Name 相同的，BrokerId 为 0 的则为主服务器；每个 Broker 都需要向所有的 NameServer 注册，并周期性的向其发注册请求
Client（Consumer & Producer）：周期性的去 NameServer 获取路由信息，周期性的向所有 Broker 发送心跳

### NameServer
NameServer 有点类似于 Kafka 中 ZooKeeper 的作用，其充当一个路由注册中心，维护所有的 Broker 和 Topic 路由的信息。但是和 ZooKeeper 不同，集群内的 NameServer 之间是不通信的。 Broker 启动时需要向所有的 NameServer 实例注册，并定时向其发送心跳信息。因此，每个 NameServer 都是包含了所有的 Broker 和 Topic 的路由信息的，是一个完整的个体。

大致看下 NameServer 启动流程[**基于代码版本 4.5.2**]:
> 构建 NamesrvController --> NamesrvController 初始化 --> NamesrvController 启动

####  NamesrvController 初始化
```java
    // NamesrvController 初始化
    public boolean initialize() {
        // 加载配置
        this.kvConfigManager.load();
        
        this.remotingServer = new NettyRemotingServer(this.nettyServerConfig, this.brokerHousekeepingService);
        this.remotingExecutor = Executors.newFixedThreadPool(nettyServerConfig.getServerWorkerThreads(), new ThreadFactoryImpl("RemotingExecutorThread_"));
        // 根据构建的 remotingServer 和 remotingExecutor 去注册 RequestProcessor 来处理来自 Broker 和 Client 的请求
        this.registerProcessor();
        
        // 启动定时任务，每十秒扫描一次不活跃的 Broker，关闭其连接并移除
        this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {
            @Override
            public void run() {
                NamesrvController.this.routeInfoManager.scanNotActiveBroker();
            }
        }, 5, 10, TimeUnit.SECONDS);

        // 每 10min 打印一次 kvConfig. ({user.home}/namesvr/kvConfig.json)
        this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {
            @Override
            public void run() {
                NamesrvController.this.kvConfigManager.printAllPeriodically();
            }
        }, 1, 10, TimeUnit.MINUTES);

        if (TlsSystemConfig.tlsMode != TlsMode.DISABLED) {
            // Register a listener to reload SslContext
            // ... 省略部分代码
        }

        return true;
    }
```
可以看出，其主要的行为就是：
- 启动对应的 RemotingServer 用于网络通信
- 注册其对应的 RequestProcessor 用于处理接收的特定请求 
- 启动定时任务：扫描不活跃的 Broker 并移除之、打印对应的配置信息

RouteInfoManager 管理的数据:
```java
public class RouteInfoManager {
    private final static long BROKER_CHANNEL_EXPIRED_TIME = 1000 * 60 * 2;
    private final ReadWriteLock lock = new ReentrantReadWriteLock();
    private final HashMap<String/* topic */, List<QueueData>> topicQueueTable;
    private final HashMap<String/* brokerName */, BrokerData> brokerAddrTable;
    private final HashMap<String/* clusterName */, Set<String/* brokerName */>> clusterAddrTable;
    private final HashMap<String/* brokerAddr */, BrokerLiveInfo> brokerLiveTable;
    private final HashMap<String/* brokerAddr */, List<String>/* Filter Server */> filterServerTable;
}
```

#### NameServer 的 RequestProcessor
```java
public class NamesrvController {
    private void registerProcessor() {
        if (namesrvConfig.isClusterTest()) {
            this.remotingServer.registerDefaultProcessor(new ClusterTestRequestProcessor(this, namesrvConfig.getProductEnvName()),
                this.remotingExecutor);
        } else {
            this.remotingServer.registerDefaultProcessor(new DefaultRequestProcessor(this), this.remotingExecutor);
        }
    }
}

// 看看 NameServer 处理的 Request
public class DefaultRequestProcessor implements NettyRequestProcessor {

    @Override
    public RemotingCommand processRequest(ChannelHandlerContext ctx,
        RemotingCommand request) throws RemotingCommandException {
        if (ctx != null) {
            log.debug("receive request, {} {} {}",
                request.getCode(),
                RemotingHelper.parseChannelRemoteAddr(ctx.channel()),
                request);
        }
        switch (request.getCode()) {
            case RequestCode.PUT_KV_CONFIG:
                return this.putKVConfig(ctx, request);
            case RequestCode.GET_KV_CONFIG:
                return this.getKVConfig(ctx, request);
            case RequestCode.DELETE_KV_CONFIG:
                return this.deleteKVConfig(ctx, request);
            case RequestCode.QUERY_DATA_VERSION:
                return queryBrokerTopicConfig(ctx, request);
            case RequestCode.REGISTER_BROKER:
                Version brokerVersion = MQVersion.value2Version(request.getVersion());
                if (brokerVersion.ordinal() >= MQVersion.Version.V3_0_11.ordinal()) {
                    return this.registerBrokerWithFilterServer(ctx, request);
                } else {
                    return this.registerBroker(ctx, request);
                }
            case RequestCode.UNREGISTER_BROKER:
                return this.unregisterBroker(ctx, request);
            case RequestCode.GET_ROUTEINTO_BY_TOPIC:
                return this.getRouteInfoByTopic(ctx, request);
            case RequestCode.GET_BROKER_CLUSTER_INFO:
                return this.getBrokerClusterInfo(ctx, request);
            case RequestCode.WIPE_WRITE_PERM_OF_BROKER:
                return this.wipeWritePermOfBroker(ctx, request);
            case RequestCode.GET_ALL_TOPIC_LIST_FROM_NAMESERVER:
                return getAllTopicListFromNameserver(ctx, request);
            case RequestCode.DELETE_TOPIC_IN_NAMESRV:
                return deleteTopicInNamesrv(ctx, request);
            case RequestCode.GET_KVLIST_BY_NAMESPACE:
                return this.getKVListByNamespace(ctx, request);
            case RequestCode.GET_TOPICS_BY_CLUSTER:
                return this.getTopicsByCluster(ctx, request);
            case RequestCode.GET_SYSTEM_TOPIC_LIST_FROM_NS:
                return this.getSystemTopicListFromNs(ctx, request);
            case RequestCode.GET_UNIT_TOPIC_LIST:
                return this.getUnitTopicList(ctx, request);
            case RequestCode.GET_HAS_UNIT_SUB_TOPIC_LIST:
                return this.getHasUnitSubTopicList(ctx, request);
            case RequestCode.GET_HAS_UNIT_SUB_UNUNIT_TOPIC_LIST:
                return this.getHasUnitSubUnUnitTopicList(ctx, request);
            case RequestCode.UPDATE_NAMESRV_CONFIG:
                return this.updateConfig(ctx, request);
            case RequestCode.GET_NAMESRV_CONFIG:
                return this.getConfig(ctx, request);
            default:
                break;
        }
        return null;
    }
}
```

从上面可以看出，NameServer  主要处理如下几种类型的 Request，这也正是整个 NameServer 的作用:
- NameServer 的配置管理
  - UPDATE_NAMESRV_CONFIG
  - GET_NAMESRV_CONFIG
- kvConfig 的管理
  - PUT_KV_CONFIG
  - GET_KV_CONFIG
  - DELETE_KV_CONFIG 
  - GET_KVLIST_BY_NAMESPACE
- Broker 的管理
  - QUERY_DATA_VERSION
  - REGISTER_BROKER
  - UNREGISTER_BROKER
  - GET_BROKER_CLUSTER_INFO
  - WIPE_WRITE_PERM_OF_BROKER
- Topic 路由信息的管理
  - GET_ROUTEINTO_BY_TOPIC
  - GET_ALL_TOPIC_LIST_FROM_NAMESERVER
  - DELETE_TOPIC_IN_NAMESRV
  - GET_TOPICS_BY_CLUSTER
  - GET_SYSTEM_TOPIC_LIST_FROM_NS
  - GET_UNIT_TOPIC_LIST
  - GET_HAS_UNIT_SUB_TOPIC_LIST
  - GET_HAS_UNIT_SUB_UNUNIT_TOPIC_LIST

#### NameServer 处理 REGISTER_BROKER 请求
Broker 向 NameServer 注册，类似于充当了一个心跳的作用。从 BrokerController 中可以看出，Broker 启动的时候就需要向所有的 NameServer 发送 REGISTER_BROKER 请求去注册自己的相关信息，并定默认时每 30s 再去注册一次。
结合 NameServer 的 scanNotActiveBroker 定时任务，NameServer 便可以维护一个较为实时的 Broker 信息列表。

```java
public class BrokerController {
    public void start() throws Exception {
            // 定时去所有 NameServer 注册自己的信息
            this.scheduledExecutorService.scheduleAtFixedRate(new Runnable() {
            @Override
            public void run() {
                try {
                    BrokerController.this.registerBrokerAll(true, false, brokerConfig.isForceRegister());
                } catch (Throwable e) {
                    log.error("registerBrokerAll Exception", e);
                }
            }
        }, 1000 * 10, Math.max(10000, Math.min(brokerConfig.getRegisterNameServerPeriod(), 60000)), TimeUnit.MILLISECONDS);
    }
}
```
再看看 NameServer 如何处理该请求，大体流程如下：
1. 根据请求解析出请求头和请求体
   - 请求头信息包含：brokerName、brokerAddr、clusterName、haServerAddr、 brokerId、compressed
   - 请求体包含：filterServerList、TopicConfigSerializeWrapper[ConcurrentMap<String, TopicConfig> topicConfigTable、DataVersion dataVersion]
   
2. 根据请求头和请求体去更新 NameServer 本地维护的 clusterAddrTable、brokerAddrTable、brokerLiveTable、filterServerTable 等信息

看看其主要行为：
```java
public class RouteInfoManager {
    public RegisterBrokerResult registerBroker(
        final String clusterName,
        final String brokerAddr,
        final String brokerName,
        final long brokerId,
        final String haServerAddr,
        final TopicConfigSerializeWrapper topicConfigWrapper,
        final List<String> filterServerList,
        final Channel channel) {
        RegisterBrokerResult result = new RegisterBrokerResult();
        try {
            try {
                this.lock.writeLock().lockInterruptibly();

                //  更新对应的 clusterAddrTable 和 brokerAddrTable 信息
                Set<String> brokerNames = this.clusterAddrTable.get(clusterName);
                if (null == brokerNames) {
                    brokerNames = new HashSet<String>();
                    this.clusterAddrTable.put(clusterName, brokerNames);
                }
                brokerNames.add(brokerName);

                boolean registerFirst = false;

                BrokerData brokerData = this.brokerAddrTable.get(brokerName);
                if (null == brokerData) {
                    registerFirst = true;
                    brokerData = new BrokerData(clusterName, brokerName, new HashMap<Long, String>());
                    this.brokerAddrTable.put(brokerName, brokerData);
                }
                Map<Long, String> brokerAddrsMap = brokerData.getBrokerAddrs();
                //Switch slave to master: first remove <1, IP:PORT> in namesrv, then add <0, IP:PORT>
                //The same IP:PORT must only have one record in brokerAddrTable
                Iterator<Entry<Long, String>> it = brokerAddrsMap.entrySet().iterator();
                while (it.hasNext()) {
                    Entry<Long, String> item = it.next();
                    if (null != brokerAddr && brokerAddr.equals(item.getValue()) && brokerId != item.getKey()) {
                        it.remove();
                    }
                }

                String oldAddr = brokerData.getBrokerAddrs().put(brokerId, brokerAddr);
                registerFirst = registerFirst || (null == oldAddr);

                // 如果是新注册的主 Broker 则更新其对应的 topicQueueTable 信息
                if (null != topicConfigWrapper
                    && MixAll.MASTER_ID == brokerId) {
                    if (this.isBrokerTopicConfigChanged(brokerAddr, topicConfigWrapper.getDataVersion())
                        || registerFirst) {
                        ConcurrentMap<String, TopicConfig> tcTable =
                            topicConfigWrapper.getTopicConfigTable();
                        if (tcTable != null) {
                            for (Map.Entry<String, TopicConfig> entry : tcTable.entrySet()) {
                                this.createAndUpdateQueueData(brokerName, entry.getValue());
                            }
                        }
                    }
                }

                // 更新对应的 broker 的信息时间和版本
                BrokerLiveInfo prevBrokerLiveInfo = this.brokerLiveTable.put(brokerAddr,
                    new BrokerLiveInfo(
                        System.currentTimeMillis(),
                        topicConfigWrapper.getDataVersion(),
                        channel,
                        haServerAddr));
                if (null == prevBrokerLiveInfo) {
                    log.info("new broker registered, {} HAServer: {}", brokerAddr, haServerAddr);
                }

                // 添加对应的 filter
                if (filterServerList != null) {
                    if (filterServerList.isEmpty()) {
                        this.filterServerTable.remove(brokerAddr);
                    } else {
                        this.filterServerTable.put(brokerAddr, filterServerList);
                    }
                }

                // Broker 是从节点的话，设置其主节点地址和 HaServerAddr(保持和主的一致)
                if (MixAll.MASTER_ID != brokerId) {
                    String masterAddr = brokerData.getBrokerAddrs().get(MixAll.MASTER_ID);
                    if (masterAddr != null) {
                        BrokerLiveInfo brokerLiveInfo = this.brokerLiveTable.get(masterAddr);
                        if (brokerLiveInfo != null) {
                            result.setHaServerAddr(brokerLiveInfo.getHaServerAddr());
                            result.setMasterAddr(masterAddr);
                        }
                    }
                }
            } finally {
                this.lock.writeLock().unlock();
            }
        } catch (Exception e) {
            log.error("registerBroker Exception", e);
        }

        return result;
    }
}
```
### Client
RocketMQ 的 Client 从 NameServer 获取路由信息，并定时向所有的 Broker 发送心跳信息。

#### 生产者
##### 启动
生产者的话，我们主要从构造 `DefaultMQProducerImpl` 开始，随后就是启动该生产者了。构造函数主要是对 Executor 的一个初始化，暂且不看，我们直接看看其启动方法做的事情：
1. 注册 Producer Group
2. 调用 `MQClientInstance` 的 start 方法
    - 如果没有配置 NameServer 地址，首先获取 NameServerAddr
    - 启动网络应答模块 request-response channel
    - 启动系列周期定时任务
      - 每两分钟获取 NameServerAddr
      - 默认每 30s 从 NameServer 获取 Topic 路由信息
      - 默认每 30s 向所有 Broker 发送心跳信息 
      - 默认每 5s 提交持久化消费 offset 记录
      - 每分钟调整一次线程池
    - 启动拉取消息的线程服务
    - 启动 reblance 的线程服务
4. 向所有 Broker 发送心跳信息 并上传对应的 Filter class 信息
	```java
	 public class DefaultMQProducerImpl implements MQProducerInner {
	    public void start(final boolean startFactory) throws MQClientException {
	        switch (this.serviceState) {
	            case CREATE_JUST:
	                // ... 省略部分代码（用于状态调整的，只需启动一次即可）
	                // 创建 or 获取 MQClientInstance 实例，一个客户端只有一个 MQClientInstance 实例
	                this.mQClientFactory = MQClientManager.getInstance().getAndCreateMQClientInstance(this.defaultMQProducer, rpcHook);
	                // 注册对应的消费 Group
	                boolean registerOK = mQClientFactory.registerProducer(this.defaultMQProducer.getProducerGroup(), this);
	                // 启动 MQClientInstance
	                if (startFactory) {
	                    mQClientFactory.start();
	                }
	
	                // ...
	                break;
	        }
	        // 向所有的 Broker 发送心跳信息，同时将 filter class 上传到 Filter Server
	        this.mQClientFactory.sendHeartbeatToAllBrokerWithLock();
	    }
	}
    
	public class MQClientInstance {
	     public void start() throws MQClientException {
	        synchronized (this) {
	            switch (this.serviceState) {
	                case CREATE_JUST:
	                    this.serviceState = ServiceState.START_FAILED;
	                    // If not specified,looking address from name server
	                    if (null == this.clientConfig.getNamesrvAddr()) {
	                        this.mQClientAPIImpl.fetchNameServerAddr();
	                    }
	                    // Start request-response channel
	                    this.mQClientAPIImpl.start();
	                    // Start various schedule tasks
	                    this.startScheduledTask();
	                    // Start pull service
	                    this.pullMessageService.start();
	                    // Start rebalance service
	                    this.rebalanceService.start();
	                    // Start push service
	                    this.defaultMQProducer.getDefaultMQProducerImpl().start(false);
	                    log.info("the client factory [{}] start OK", this.clientId);
	                    this.serviceState = ServiceState.RUNNING;
	                    break;
	                case RUNNING:
	                    break;
	                case SHUTDOWN_ALREADY:
	                    break;
	                case START_FAILED:
	                    throw new MQClientException("The Factory object[" + this.getClientId() + "] has been created before, and failed.", null);
	                default:
	                    break;
	            }
	        }
	    }  
	}
	```

##### Produce
对于生产消息，有几点需要注意 ~~[代码较多就不贴了]~~ 
- 发送消息时如何选择 Broker 和 其中的 queue 
  > 大致就是根据 Topic 获取路由信息 -> 取随机数(后续则取得是之前的随机数+1)后取模获取 MessageQueue -> LatencyFaultTolerance 中判断其是否有效，有效则选择该 MessageQueue；否则的话，从 LatencyFaultTolerance 中选取一个 Broker；如果该 Broker 有的 writeQueueNums > 0, 则取模选其中的一个 queue；否则重新走一遍流程。  
  > 其中 LatencyFaultTolerance 的核心就是针对之前失败的请求，按照一定时间来做退避。即短时间内不再选取其作为发送目的地

- 发送的 Topic 如果还未创建的话是如何处理的
  > 如果 Topic 还未创建的话，这个时候从本地或是 NameServer 都是没办法根据该 Topic Name 获取到对应的路由信息的。
  不过 RocketMQ 是可以支持自动创建 Topic 的（生产不建议打开就是了）。
  其实际就是获取所有打开了 `autoCreateTopic` 配置的 Broker 的 默认 Topic: TBW102 （如果autoCreateTopic=true，该 Topic 会在 Broker 启动的时候自动被注册到 NameServer）的路由信息信息。
 
   但是这么做可能会导致消息的负载不均衡，我们以发送一个 UNKNOWN_TOPIC 为例说明下（开启了 autoCreateTopic）：
   > 1. 从 NameServer 获取 UNKNOWN_TOPIC 路由信息，但获取不到
   > 2. 获取 TBW102 路由信息
   > 3. 选择 Broker & Queue 发送消息到对应的 Broker
   > 4. Broker 收到消息后做对应的存储持久化，并将该 UNKNOWN_TOPIC 注册到 NameServer（此时 NameServer 含有 UNKNOWN_TOPIC 的路由信息了，但是只有该 Broker的）
   > 5. 客户端后台定时任务从 NameServer 获取路由信息并更新本地的记录
  
  假如在步骤5执行前，只有一条消息发送到了一个 Broker，那么此后岂不是该 Topic 的所有信息只能发送到这一个 Broker了，就失去了负载均衡的效果了。

  
- 发送的消息是事务消息时如何处理的

{% asset_img RocketMQ_T.png RocketMQ 事务消息 %}

   RT，流程如图所示。总的来说是有点类似于 2PC 的一个模式。但是加了个回查机制，这样可以处理网络请求的未知状态问题。
   首次发送的消息属于 Half 消息，包含了消息的所有信息，但是其并不会直接发送到对应的 Topic 中去，而是会发送到名为 RMQ_SYS_TRANS_HALF_TOPIC 的系统 Topic 中。Broker 会有定时任务去检查该 Topic 中还未处理的的消息，然后去回查事务的状态，判断该事务是需要 commit (转移到真实的 Topic Queue 中)还是 rollback；当然回查不会是无线的，默认是回查 15 次没结果的话就会回滚。
   那么如何才能知道该消息是否处理了？ RocketMQ 的做法是额外引入了个 Op 消息，就是对于每个 Message，在 Commit or Rollback 后，都会有一条对于的 Op 信息，没有的话就说明该消息还未处理完成。
   （为啥不使用拓展属性字段来表示？）
   详细的可以查看 RocketMQ GitHub 上的设计文档：[设计(design)](https://github.com/apache/rocketmq/blob/master/docs/cn/design.md)
#### 消费者
消费的启动整体和生产者类似。其中需要比较需要注意的是其内部的 Rebalance 的实现。这是一个后台定时任务，在启动 MQInstance 的时候就启动了。

##### Rebalance
我们这里主要看看针对集群消费模式的 Rebalnace。总的来说就是 RocketMQ 有个后台线程周期性的在执行 Rebanlance 的任务，默认为 20000ms。执行 Rebalance 实际是按照 Topic 来划分的，具体针对单个 Topic 进行 Rebalance 的流程大致如下：
1. 根据 Topic 获取其当前对应的 MessageQueue 和 Consumer ID
2. 根据配置的分配策略对数据进行分配处理，得出当前 Consumer 的消费 Mssageueue 列表。总共有如下几种分配策略
    - AllocateMachineRoomNearby
    - AllocateMessageQueueAveragely(默认)
    - AllocateMessageQueueAveragelyByCircle
    - AllocateMessageQueueByConfig
    - AllocateMessageQueueByMachineRoom
    - AllocateMessageQueueConsistentHash
    策略讲解参考 Blog：[RocketMQ-负载均衡](https://blog.csdn.net/mxlmxlmxl33/article/details/85949429)
3. 根据新的分配结果调整本地的消费分配数据 processQueueTable （`ConcurrentMap<MessageQueue, ProcessQueue>` ）
4. 如果本地消费分配缓存数据有调整，则调整本地拉取消息的线程任务；删除失效的 MessageQueue 相关拉取任务，添加新的 MessageQueue 相关拉取任务

代码如下：
```java
public abstract class RebalanceImpl {
    private void rebalanceByTopic(final String topic, final boolean isOrder) {
        switch (messageModel) {
            case BROADCASTING: {
                // 省了部分代码
            case CLUSTERING: {
                // 获取 Topic 当前对应的 MessageQueue 和 所有的 Consumer ID
                Set<MessageQueue> mqSet = this.topicSubscribeInfoTable.get(topic);
                List<String> cidAll = this.mQClientFactory.findConsumerIdList(topic, consumerGroup);
                // 省略部分代码
                if (mqSet != null && cidAll != null) {
                    List<MessageQueue> mqAll = new ArrayList<MessageQueue>();
                    mqAll.addAll(mqSet);

                    Collections.sort(mqAll);
                    Collections.sort(cidAll);
                    // 根据配置的分配算法重新分配
                    AllocateMessageQueueStrategy strategy = this.allocateMessageQueueStrategy;
                    List<MessageQueue> allocateResult = null;
                    try {
                        allocateResult = strategy.allocate(
                            this.consumerGroup,
                            this.mQClientFactory.getClientId(),
                            mqAll,
                            cidAll);
                    } catch (Throwable e) {
                        log.error("AllocateMessageQueueStrategy.allocate Exception. allocateMessageQueueStrategyName={}", strategy.getName(),
                            e);
                        return;
                    }

                    Set<MessageQueue> allocateResultSet = new HashSet<MessageQueue>();
                    if (allocateResult != null) {
                        allocateResultSet.addAll(allocateResult);
                    }
                    // 根据分配结果调整本地缓存的消费分配数据；内部处理时涉及到部分数据需要加锁处理
                    boolean changed = this.updateProcessQueueTableInRebalance(topic, allocateResultSet, isOrder);
                    if (changed) {
                        log.info(
                            "rebalanced result changed. allocateMessageQueueStrategyName={}, group={}, topic={}, clientId={}, mqAllSize={}, cidAllSize={}, rebalanceResultSize={}, rebalanceResultSet={}",
                            strategy.getName(), consumerGroup, topic, this.mQClientFactory.getClientId(), mqSet.size(), cidAll.size(),
                            allocateResultSet.size(), allocateResultSet);
                            // 如果本地消费数据有改变，则调整本地拉取消息的线程任务；对于每个 MessageQueue，都有一个对应的 PullTaskImpl 线程，该方法就是需要对线程池中的这些线程任务进行cancel或添加
                        this.messageQueueChanged(topic, mqSet, allocateResultSet);
                    }
                }
                break;
            }
        }
    }
}
```

### Broker Server
#### 整体设计架构
作为 RocketMQ 的核心部分，我们首先看看 Broker 其大体的一个架构。说有模块的都是基于其 Romoting Module 网络通信模块来实现的。

{% asset_img RocketMQ_B.png RocketMQ Broker Module %}

- Client Manager：管理客户端并维护 Consumer 的 Topic 订阅信息
- Store Service：负责消息存储服务
- HA Service： 负责主从 Broker 的数据同步
- Index Service：负责根据消息 Key 对其进行索引的服务

消息文件：
- CommitLog：消息数据的实际存储记录
- ConsumeQueue：消息消费队列，提高消息消费的性能。存储路径为：`$HOME/store/consumequeue/{topic}/{queueId}/{fileName}`，保存了指定 Topic下 的队列消息在 CommitLog 中的起始物理偏移量，消息大小和消息 Tag 的 HashCode 值。
- IndexFile：消息索引文件，方便通过 key 或时间区间来查询消息。存储路径为：`$HOME\store\index${fileName}`

其中 ConsumeQueue 和 IndexFile 是后台线程根据 CommitLog 异步生成的。

{% asset_img RocketMQ_M.png RocketMQ Message %}

#### 启动
1. initialize
    - 加载 topics.json、consumerOffset.json、subscriptionGroup.json、consumerFilter.json 文件恢复之前存储的相关数据
    - 初始化 ThreadPoolExecutor 
    - 注册对应请求的处理器
       - SendMessageProcessor: SEND_MESSAGE、SEND_MESSAGE_V2、SEND_BATCH_MESSAGE、CONSUMER_SEND_MSG_BACK
       - PullMessageProcessor: PULL_MESSAGE
       - QueryMessageProcessor: QUERY_MESSAGE、VIEW_MESSAGE_BY_ID
       - ClientManageProcessor: HEART_BEAT、UNREGISTER_CLIENT、CHECK_CLIENT_CONFIG
       - ConsumerManageProcessor: GET_CONSUMER_LIST_BY_GROUP、UPDATE_CONSUMER_OFFSET、QUERY_CONSUMER_OFFSET
       - EndTransactionProcessor: END_TRANSACTION
       - AdminBrokerProcessor: 命令较多，大多都是些和 Broker 相关的配置和状态获取调整的命令
    - 启动一些打印 Broker 运行相关信息的后台周期性线程：consumerOffset 持久化的周期性线程( 默认 5s 一次)、consumerFilter 持久化的周期性线程( 10s 一次)、Broker 保护启动探测线程（ 如果有开启的话[默认 false]，消费者消费太慢会被禁止消费）
    - 获取 NameServer 地址 和 SSL 、ACL、Deleger、Transaction 等的初始化
2. start
    - 启动各模块服务，messageStore、remotingServer、filterServerManager、brokerOuterAPI、brokerStatsManager等
    - 启动周期性任务（默认 30s 一次；最小间隔 10s，最大间隔 60s ）：向所有的 NameServer 注册该 Broker 的 Topic 等信息

#### 处理请求
上面已经说了，每个请求都有对应的 Processor；这里我们就从 SEND_MESSAGE 的请求来看看其实如何处理的，这里我们只看最简单的单个消息发送处理的逻辑：
```java
public class SendMessageProcessor extends AbstractSendMessageProcessor implements NettyRequestProcessor {
    @Override
    public RemotingCommand processRequest(ChannelHandlerContext ctx,
                                          RemotingCommand request) throws RemotingCommandException {
        SendMessageContext mqtraceContext;
        switch (request.getCode()) {
            // 如是果重试发回的消息，则判断这个消息对应的 topic 为 %RETRY%_consumerGroup 的是否创建过，没有则创建
            case RequestCode.CONSUMER_SEND_MSG_BACK:
                return this.consumerSendMsgBack(ctx, request);
            default:
                // 正常处理 SEND_MESSAGE、SEND_MESSAGE_V2、SEND_BATCH_MESSAGE 请求
                // 获取对应的请求数据
                SendMessageRequestHeader requestHeader = parseRequestHeader(request);
                if (requestHeader == null) {
                    return null;
                }
                // 消息追踪相关           
                mqtraceContext = buildMsgContext(ctx, requestHeader);
                this.executeSendMessageHookBefore(ctx, request, mqtraceContext);

                RemotingCommand response;
                if (requestHeader.isBatch()) {
                    response = this.sendBatchMessage(ctx, request, mqtraceContext, requestHeader);
                } else {
                     // 执行命令
                    response = this.sendMessage(ctx, request, mqtraceContext, requestHeader);
                }

                this.executeSendMessageHookAfter(response, mqtraceContext);
                return response;
        }
    }
    
    /**
     * 1. 写消息校验：Broker 是否可写、topic 是否是否与系统默认 topic 冲突、topic 和 queueId 是否有效等
     * 2. 根据 Request 构造 MessageExtBrokerInner 对象
     * 3. 判断是否是事务消息：是的话就走 prepareMessage 将其当做 Half 消息存储在系统默认的事务消息 Topic 中；不是的话就走正常的消息存储 messageStore.putMessage
     * 4. 根据 putMessage 的返回结果构造返回数据，并执行 BrokerStats 等数据的更新维护
     */
    private RemotingCommand sendMessage(final ChannelHandlerContext ctx,
                                        final RemotingCommand request,
                                        final SendMessageContext sendMessageContext,
                                        final SendMessageRequestHeader requestHeader) throws RemotingCommandException {

        final RemotingCommand response = RemotingCommand.createResponseCommand(SendMessageResponseHeader.class);
        final SendMessageResponseHeader responseHeader = (SendMessageResponseHeader)response.readCustomHeader();

        response.setOpaque(request.getOpaque());

        response.addExtField(MessageConst.PROPERTY_MSG_REGION, this.brokerController.getBrokerConfig().getRegionId());
        response.addExtField(MessageConst.PROPERTY_TRACE_SWITCH, String.valueOf(this.brokerController.getBrokerConfig().isTraceOn()));

        log.debug("receive SendMessage request command, {}", request);

        final long startTimstamp = this.brokerController.getBrokerConfig().getStartAcceptSendRequestTimeStamp();
        if (this.brokerController.getMessageStore().now() < startTimstamp) {
            response.setCode(ResponseCode.SYSTEM_ERROR);
            response.setRemark(String.format("broker unable to service, until %s", UtilAll.timeMillisToHumanString2(startTimstamp)));
            return response;
        }

        response.setCode(-1);
        super.msgCheck(ctx, requestHeader, response);
        if (response.getCode() != -1) {
            return response;
        }

        final byte[] body = request.getBody();

        int queueIdInt = requestHeader.getQueueId();
        TopicConfig topicConfig = this.brokerController.getTopicConfigManager().selectTopicConfig(requestHeader.getTopic());

        if (queueIdInt < 0) {
            queueIdInt = Math.abs(this.random.nextInt() % 99999999) % topicConfig.getWriteQueueNums();
        }

        MessageExtBrokerInner msgInner = new MessageExtBrokerInner();
        msgInner.setTopic(requestHeader.getTopic());
        msgInner.setQueueId(queueIdInt);

        if (!handleRetryAndDLQ(requestHeader, response, request, msgInner, topicConfig)) {
            return response;
        }

        msgInner.setBody(body);
        msgInner.setFlag(requestHeader.getFlag());
        MessageAccessor.setProperties(msgInner, MessageDecoder.string2messageProperties(requestHeader.getProperties()));
        msgInner.setPropertiesString(requestHeader.getProperties());
        msgInner.setBornTimestamp(requestHeader.getBornTimestamp());
        msgInner.setBornHost(ctx.channel().remoteAddress());
        msgInner.setStoreHost(this.getStoreHost());
        msgInner.setReconsumeTimes(requestHeader.getReconsumeTimes() == null ? 0 : requestHeader.getReconsumeTimes());
        PutMessageResult putMessageResult = null;
        Map<String, String> oriProps = MessageDecoder.string2messageProperties(requestHeader.getProperties());
        String traFlag = oriProps.get(MessageConst.PROPERTY_TRANSACTION_PREPARED);
        if (traFlag != null && Boolean.parseBoolean(traFlag)) {
            if (this.brokerController.getBrokerConfig().isRejectTransactionMessage()) {
                response.setCode(ResponseCode.NO_PERMISSION);
                response.setRemark(
                    "the broker[" + this.brokerController.getBrokerConfig().getBrokerIP1()
                        + "] sending transaction message is forbidden");
                return response;
            }
            putMessageResult = this.brokerController.getTransactionalMessageService().prepareMessage(msgInner);
        } else {
            putMessageResult = this.brokerController.getMessageStore().putMessage(msgInner);
        }

        return handlePutMessageResult(putMessageResult, response, request, msgInner, responseHeader, sendMessageContext, ctx, queueIdInt);
    }
}

/**
 * Store all metadata downtime for recovery, data protection reliability
 */
public class CommitLog {
	/**
	 * 1. messageStore.putMessage 主要是校验 Broker 状态（是否关闭、是否为主）；最终还是调用的 CommitLog 的 putMessage 方法
	 * 2. 填充数据，并将 commitlog append 到 MappedFile 中，其 fileSize 默认为 1G；如果该 MappedFile 写满了则创建个新文件重新写入
	 * 3. 使用 NIO 中的 MappedByteBuffer 相关技术将数据写入文件
	 */
    public PutMessageResult putMessage(final MessageExtBrokerInner msg) {
        // Set the storage time
        msg.setStoreTimestamp(System.currentTimeMillis());
        // Set the message body BODY CRC (consider the most appropriate setting
        // on the client)
        msg.setBodyCRC(UtilAll.crc32(msg.getBody()));
        // Back to Results
        AppendMessageResult result = null;

        StoreStatsService storeStatsService = this.defaultMessageStore.getStoreStatsService();

        String topic = msg.getTopic();
        int queueId = msg.getQueueId();

        final int tranType = MessageSysFlag.getTransactionValue(msg.getSysFlag());
        if (tranType == MessageSysFlag.TRANSACTION_NOT_TYPE
            || tranType == MessageSysFlag.TRANSACTION_COMMIT_TYPE) {
            // Delay Delivery
            if (msg.getDelayTimeLevel() > 0) {
                if (msg.getDelayTimeLevel() > this.defaultMessageStore.getScheduleMessageService().getMaxDelayLevel()) {
                    msg.setDelayTimeLevel(this.defaultMessageStore.getScheduleMessageService().getMaxDelayLevel());
                }

                topic = ScheduleMessageService.SCHEDULE_TOPIC;
                queueId = ScheduleMessageService.delayLevel2QueueId(msg.getDelayTimeLevel());

                // Backup real topic, queueId
                MessageAccessor.putProperty(msg, MessageConst.PROPERTY_REAL_TOPIC, msg.getTopic());
                MessageAccessor.putProperty(msg, MessageConst.PROPERTY_REAL_QUEUE_ID, String.valueOf(msg.getQueueId()));
                msg.setPropertiesString(MessageDecoder.messageProperties2String(msg.getProperties()));

                msg.setTopic(topic);
                msg.setQueueId(queueId);
            }
        }

        long elapsedTimeInLock = 0;
        MappedFile unlockMappedFile = null;
        MappedFile mappedFile = this.mappedFileQueue.getLastMappedFile();

        putMessageLock.lock(); //spin or ReentrantLock ,depending on store config
        try {
            long beginLockTimestamp = this.defaultMessageStore.getSystemClock().now();
            this.beginTimeInLock = beginLockTimestamp;

            // Here settings are stored timestamp, in order to ensure an orderly
            // global
            msg.setStoreTimestamp(beginLockTimestamp);

            if (null == mappedFile || mappedFile.isFull()) {
                mappedFile = this.mappedFileQueue.getLastMappedFile(0); // Mark: NewFile may be cause noise
            }
            if (null == mappedFile) {
                log.error("create mapped file1 error, topic: " + msg.getTopic() + " clientAddr: " + msg.getBornHostString());
                beginTimeInLock = 0;
                return new PutMessageResult(PutMessageStatus.CREATE_MAPEDFILE_FAILED, null);
            }

            result = mappedFile.appendMessage(msg, this.appendMessageCallback);
            switch (result.getStatus()) {
                case PUT_OK:
                    break;
                case END_OF_FILE:
                    unlockMappedFile = mappedFile;
                    // Create a new file, re-write the message
                    mappedFile = this.mappedFileQueue.getLastMappedFile(0);
                    if (null == mappedFile) {
                        // XXX: warn and notify me
                        log.error("create mapped file2 error, topic: " + msg.getTopic() + " clientAddr: " + msg.getBornHostString());
                        beginTimeInLock = 0;
                        return new PutMessageResult(PutMessageStatus.CREATE_MAPEDFILE_FAILED, result);
                    }
                    result = mappedFile.appendMessage(msg, this.appendMessageCallback);
                    break;
                case MESSAGE_SIZE_EXCEEDED:
                case PROPERTIES_SIZE_EXCEEDED:
                    beginTimeInLock = 0;
                    return new PutMessageResult(PutMessageStatus.MESSAGE_ILLEGAL, result);
                case UNKNOWN_ERROR:
                    beginTimeInLock = 0;
                    return new PutMessageResult(PutMessageStatus.UNKNOWN_ERROR, result);
                default:
                    beginTimeInLock = 0;
                    return new PutMessageResult(PutMessageStatus.UNKNOWN_ERROR, result);
            }

            elapsedTimeInLock = this.defaultMessageStore.getSystemClock().now() - beginLockTimestamp;
            beginTimeInLock = 0;
        } finally {
            putMessageLock.unlock();
        }

        if (elapsedTimeInLock > 500) {
            log.warn("[NOTIFYME]putMessage in lock cost time(ms)={}, bodyLength={} AppendMessageResult={}", elapsedTimeInLock, msg.getBody().length, result);
        }

        if (null != unlockMappedFile && this.defaultMessageStore.getMessageStoreConfig().isWarmMapedFileEnable()) {
            this.defaultMessageStore.unlockMappedFile(unlockMappedFile);
        }

        PutMessageResult putMessageResult = new PutMessageResult(PutMessageStatus.PUT_OK, result);

        // Statistics
        storeStatsService.getSinglePutMessageTopicTimesTotal(msg.getTopic()).incrementAndGet();
        storeStatsService.getSinglePutMessageTopicSizeTotal(topic).addAndGet(result.getWroteBytes());

        handleDiskFlush(result, putMessageResult, msg);
        handleHA(result, putMessageResult, msg);

        return putMessageResult;
    }
}
```
大体流程总结如下：
1. 根据 RequestCode 判断是否是重试发送的消息以及消息的类型：批量发送、事务消息 or 单条消息
2. 构造并校验消息数据：topic是否存在、是否与系统默认 topic 冲突、是否可写、broker 是否可写等
3. 根据是否是事务消息执行 `transactionalMessageService.prepareMessage` or `messageStore.pusMessage`
4. `messageStore.pusMessage` 中校验消息数据大小是否超标、Broker 是否为主等后调用 `commitLog.putMessage(msg)`
5. commitLog 中最终将 msg append 到 MappedFile 中
6. `commitLog.handleDiskFlush` 根据 `FlushDiskType` 来执行对应的 Flush 行为（取决于是同步刷盘还是异步刷盘）
7. `commitLog.handleHA` 根据主从同步模式执行相关行为

----
8. [Apache RocketMQ开发者指南](https://github.com/apache/rocketmq/tree/master/docs/cn)
