---
title: Kafka 概览

date: 2019-12-19 10:27:39
tags: [RocketMQ,JAVA,大数据]
categories: [中间件]
---

### 简介
[Apache Kakfa](http://kafka.apachecn.org/intro.html) 是一个分布式流处理平台，既可以当做普通的消息中间件用于消息发布订阅，也可以存储并处理流式数据，其分布式设计使得其有较好的容错性，水平拓展性等。
通常可以用于当做消息订阅发布用于业务系统中，或者用于大数据方向，接受存储大量的流式数据并和对应的大数据处理框架结合使用，eg. Kafka + Samza

从物理部署层面来讲，其主要有如下几个模块：
1. ZooKeeper
    用于元数据保存以及事件通知
2. Broker
    Kafka 的核心部分，用 scala 实现，负责处理客户端请求，持久化消息数据等
3. Client（Consumer & Producer）
    客户端，Java 实现。生产者消费者实现

下面分别从这几个模块来讲解 Kafka 相关的实现[**基于 Kafka 2.4**]。

<!-- more -->

#### 相关概念
- Broker
- Consumer
- Producer
- Controller
- GroupCoordinator
- TransactionCoordinator
- Topic
- Partition
- Replicas

### ZooKeeper
[Apache ZooKeeper](https://zookeeper.apache.org/) 在 Kafka 的作用中类似于元数据的存储以及元数据改变的的一个通知器的作用。看清楚其内部存储了哪些数据就可以知道其具体的一个作用。存储的主要数据如下
- 集群相关元数据
  - /cluster/id
     ```json
	  {
	      "version": 4,
	      "id": 1,
	 }
     ```
- Broker 节点相关元数据
  - /controller，存储中央控制器的 Id 等信息
     ```json
	  {
	      "version": 4,
	      "brokerId": 1,
	      "timestamp": "2233345666",
	 }
     ```
  - /controller_epoch，存储集群中中央控制器的选举次数
  - /brokers/ids/{id}，存储每个 Broker 的基本信息
     ```json
	  {
	      "version": 4,
	      "host": "localhost",
	      "port": 9092,
	      "jmx_port": 9999,
	      "timestamp": "2233345666",
	      "endpoints": ["CLIENT://host1:9092", "REPLICATION://host1:9093"],
	      "listener_security_protocol_map": {"CLIENT":"SSL", "REPLICATION":"PLAINTEXT"},
	      "rack": "dc1"
	 }
     ```
  - /brokers/seqid，用来生成 BrokerId 的，每次递增 1
- Topic Partition 相关元数据
  - /brokers/topics/{topic}，存储 topic 的分区和副本相关信息
     ```json
	  {
	      "version": 2,
	      "partitions": [1,2,3,4,5,6],      // ReplicaAssignment
	      "adding_replicas": [1,2,3],       // Adding ReplicaAssignment
	      "removing_replicas": [4,5,6],     // Removing ReplicaAssignment
	 }
     ```
  - /brokers/topics/{topic}/partitions/{partition}/state，分区的状态元数据
     ```json
	  {
	      "version": 1,
	      "leader": 1,
	      "leader_epoch": 1,
	      "controller_epoch": 1,
	      "isr": [1,2,3],  // In Sync Replicas
	 }
     ```
- Consumer 相关元数据
  - /consumers/{group}/offsets/{topic}/{partition}，存储 consumer 消费的 offset 记录，旧版本需要

- 其他类型节点
  - /admin/delete_topics/{topic}，存储需要删除的 Topic Name
  - /admin/preferred_replica_election
       ```json
	  {
	      "version": 1,
	      "partitions": [
	             { 
	               "topic": "topic_name", 
	               "partition": 1  //  partition number
	             }
	       ],
	 }
     ```
  - /isr_change_notification/isr_change_{sequenceNumber}，isr变动信息事件通知；数据结构同上

### Broker
#### 启动流程
首先主要看看 Kafka Broker 启动的一个流程，大致做了如下这些工作：
1.  初始化 ZooKeeper 客户端并创建最顶层的持久化节点
     - /consumers
     - /brokers/ids
     - /brokers/topics
     - /brokers/seqid
     - /config/changes
     - /admin/delete_topics
     - /isr_change_notification
     - /latest_producer_id_block
     - /log_dir_event_notification
2. 从 ZK 创建或获取 ClusterId （base64 处理的 uuid）
3. 加载本地 log.dirs 下 meta.properties 中的 Broker's Metadata(version、broker.id、cluster.id 等)
4. 创建 BrokerId （从配置文件中读取，或者利用 ZK 的 /brokers/seqid 节点来获取）
5. 启动 replica manager
    - 添加 isr-expiration 周期任务，周期: replicaLagTimeMaxMs/2；用于将超过 replicaLagTimeMaxMs 的同步时间的 replica 从 ISR 中移除
    - 添加 isr-change-propagation 周期任务，周期: 2500ms；传播 ISR 变动，即创建持久 ZK 节点：/isr_change_notification/isr_change_{sequenceNumber}
      > 如下情况会出发传播行为：
      > 1. isrChangeSet 不为空 & 且经过了 5s 
      > 2. 超过 60s 没有进行传播行为
    - 添加 shutdown-idle-replica-alter-log-dirs-thread 周期任务，周期 10s；关闭多余的线程任务
    - LogDirFailureHandler
6. 向 ZK 节点 /brokers/ids/{id} 注册 Broker 信息
7. 创建 BrokerMetadata 的 checkpoint
8. 启动 Kafka controller，监听 ControllerEvent [ Startup、IsrChangeNotification、Reelect、BrokerChange、ControllerChange、TopicChange 等] 并启动 controller 选举
    > 一个集群只有一个 broker 能成为 controller，主要负责如下内容(就是监听的上述的一些事件来触发的)：
    > 1. Broker 的上线、下线处理
    > 2. 新创建的 topic 或已有 topic 的分区扩容，处理分区副本的分配、leader 选举
    > 3. 管理所有副本的状态机和分区的状态机，处理状态机的变化事件
    > 4. topic 删除、副本迁移、leader 切换等处理
9. 启动 GroupCoordinator ；启动 delete-expired-group-metadata 周期任务，默认 60s 一次 清除 group 的 offsets
	```java
	 * Group contains the following metadata:
	 *
	 *  Membership metadata:
	 *  1. Members registered in this group
	 *  2. Current protocol assigned to the group (e.g. partition assignment strategy for consumers)
	 *  3. Protocol metadata associated with group members
	 *
	 *  State metadata:
	 *  1. group state
	 *  2. generation id
	 *  3. leader id
	 */      
	```
10. 启动事务协调者 transactionCoordinator
    - 启动周期任务 transaction-abort ，放弃超时了（默认 1min）的事务
    - 启动周期任务 transactionalId-expiration（默认开启），移除过期的（默认 1min） transactionalId
11. 启动动态配置管理
12. 启动 Request 处理服务

由于 Broker 集群中很多重要事件的处理都是由 Controller 来处理的，我们下面重点来看看 Controller 的选举和其事件处理机制（以删除 Topic 为例）。

#### Controller 选举
大致流程如下：
1. Broker 启动时启动 KafkaController
2. KafkaController 启动时启动发布 Startup 事件，并启动 ControllerEventManager 来监听事件
	```java
	  /**
	   * KafkaController.scala
	   * KafkaController 启动。
	   * 
	   * Invoked when the controller module of a Kafka server is started up. This does not assume that the current broker
	   * is the controller. It merely registers the session expiration listener and starts the controller leader
	   * elector
	   */
	  def startup() = {
	    zkClient.registerStateChangeHandler(new StateChangeHandler {
	      override val name: String = StateChangeHandlers.ControllerHandler
	      override def afterInitializingSession(): Unit = {
	        eventManager.put(RegisterBrokerAndReelect)
	      }
	      override def beforeInitializingSession(): Unit = {
	        val queuedEvent = eventManager.clearAndPut(Expire)
	
	        // Block initialization of the new session until the expiration event is being handled,
	        // which ensures that all pending events have been processed before creating the new session
	        queuedEvent.awaitProcessing()
	      }
	    })
	    // 将 Startuo 事件加入到 event queue 中
	    eventManager.put(Startup)
	    // 启动 eventmanager 来处理 event queue 中的任务
	    eventManager.start()
	  }
	  
	  /**
	   * ControllerEventManager.scala
	   * eventManager 启动后台线程处理 event queue（ LinkedBlockingQueue[QueuedEvent] ） 中的事件。
	   */
	  class ControllerEventThread(name: String) extends ShutdownableThread(name = name, isInterruptible = false) {
	    logIdent = s"[ControllerEventThread controllerId=$controllerId] "
	
	    override def doWork(): Unit = {
	      val dequeued = queue.take()
	      dequeued.event match {
	        case ShutdownEventThread => // The shutting down of the thread has been initiated at this point. Ignore this event.
	        case controllerEvent =>
	          _state = controllerEvent.state
	
	          eventQueueTimeHist.update(time.milliseconds() - dequeued.enqueueTimeMs)
	
	          try {
	            rateAndTimeMetrics(state).time {
	              dequeued.process(processor)
	            }
	          } catch {
	            case e: Throwable => error(s"Uncaught error processing event $controllerEvent", e)
	          }
	
	          _state = ControllerState.Idle
	      }
	    }
	  }
	```
3. ControllerEventManager Handle Startup 事件，交给 KafkaController 处理，触发了 Controller 的选举
	```java
	/**
	 * KafkaControkker.scala
	 * 这是 controller 需要处理的所有事件类型。
	 */
	override def process(event: ControllerEvent): Unit = {
	    try {
	      event match {
	        case event: MockEvent =>
	          // Used only in test cases
	          event.process()
	        case ShutdownEventThread =>
	          error("Received a ShutdownEventThread event. This type of event is supposed to be handle by ControllerEventThread")
	        case AutoPreferredReplicaLeaderElection =>
	          processAutoPreferredReplicaLeaderElection()
	        case ReplicaLeaderElection(partitions, electionType, electionTrigger, callback) =>
	          processReplicaLeaderElection(partitions, electionType, electionTrigger, callback)
	        case UncleanLeaderElectionEnable =>
	          processUncleanLeaderElectionEnable()
	        case TopicUncleanLeaderElectionEnable(topic) =>
	          processTopicUncleanLeaderElectionEnable(topic)
	        case ControlledShutdown(id, brokerEpoch, callback) =>
	          processControlledShutdown(id, brokerEpoch, callback)
	        case LeaderAndIsrResponseReceived(response, brokerId) =>
	          processLeaderAndIsrResponseReceived(response, brokerId)
	        case TopicDeletionStopReplicaResponseReceived(replicaId, requestError, partitionErrors) =>
	          processTopicDeletionStopReplicaResponseReceived(replicaId, requestError, partitionErrors)
	        case BrokerChange =>
	          processBrokerChange()
	        case BrokerModifications(brokerId) =>
	          processBrokerModification(brokerId)
	        case ControllerChange =>
	          processControllerChange()
	        case Reelect =>
	          processReelect()
	        case RegisterBrokerAndReelect =>
	          processRegisterBrokerAndReelect()
	        case Expire =>
	          processExpire()
	        case TopicChange =>
	          processTopicChange()
	        case LogDirEventNotification =>
	          processLogDirEventNotification()
	        case PartitionModifications(topic) =>
	          processPartitionModifications(topic)
	        case TopicDeletion =>
	          processTopicDeletion()
	        case ApiPartitionReassignment(reassignments, callback) =>
	          processApiPartitionReassignment(reassignments, callback)
	        case ZkPartitionReassignment =>
	          processZkPartitionReassignment()
	        case ListPartitionReassignments(partitions, callback) =>
	          processListPartitionReassignments(partitions, callback)
	        case PartitionReassignmentIsrChange(partition) =>
	          processPartitionReassignmentIsrChange(partition)
	        case IsrChangeNotification =>
	          processIsrChangeNotification()
	        case Startup =>
	          processStartup()
	      }
	    } catch {
	      case e: ControllerMovedException =>
	        info(s"Controller moved to another broker when processing $event.", e)
	        maybeResign()
	      case e: Throwable =>
	        error(s"Error processing event $event", e)
	    } finally {
	      updateMetrics()
	    }
	  }
	
	  /**
	   * KafkaControkker.scala
	   * 处理 Startup 事件
	   */
	  private def processStartup(): Unit = {
	    // 注册监听 Znode 节点: /controller 事件：Creation、Deletion、DataChange
	    zkClient.registerZNodeChangeHandlerAndCheckExistence(controllerChangeHandler)
	    // 执行选举行为
	    elect()
	  }
	
	  /**
	   * KafkaControkker.scala
	   * 进行 Controller 的选举。
	   */
	  private def elect(): Unit = {
	    activeControllerId = zkClient.getControllerId.getOrElse(-1)
	    /*
	     * We can get here during the initial startup and the handleDeleted ZK callback. Because of the potential race condition,
	     * it's possible that the controller has already been elected when we get here. This check will prevent the following
	     * createEphemeralPath method from getting into an infinite loop if this broker is already the controller.
	     */
	    // 如果已经是作为 controller 运行了，就不在进行后面的选举行为
	    if (activeControllerId != -1) {
	      debug(s"Broker $activeControllerId has been elected as the controller, so stopping the election process.")
	      return
	    }
	
	    try {
	      // Registers a given broker in zookeeper as the controller and increments controller epoch：
	      // 1. 首先创建初始化或获取节点 /controller_epoch 的值
	      // 2. 然后将 epoch + 1 后，同时设置 /controller_epoch 和 /controller
	      // 3. 成功的话则返回新的 epoch 和 zkVersion
	      // 4. 如果结果显示节点已存在则判断当前的 brokerId & epoch 和 zk 节点 /controller 和 /controller_epoch 上存储的是否一致，一致的话返回对应的数据，
	      //    不一致的话则抛出 ControllerMovedException 异常放弃该选举操作，后面的步骤就不执行了
	      val (epoch, epochZkVersion) = zkClient.registerControllerAndIncrementControllerEpoch(config.brokerId)
	      controllerContext.epoch = epoch
	      controllerContext.epochZkVersion = epochZkVersion
	      activeControllerId = config.brokerId
	
	      info(s"${config.brokerId} successfully elected as the controller. Epoch incremented to ${controllerContext.epoch} " +
	        s"and epoch zk version is now ${controllerContext.epochZkVersion}")
	      
		  /**
		   * This callback is invoked by the zookeeper leader elector on electing the current broker as the new controller.
		   * It does the following things on the become-controller state change -
		   * 1. Initializes the controller's context object that holds cache objects for current topics, live brokers and
		   *    leaders for all existing partitions.
		   * 2. Starts the controller's channel manager
		   * 3. Starts the replica state machine
		   * 4. Starts the partition state machine
		   * If it encounters any unexpected exception/error while becoming controller, it resigns as the current controller.
		   * This ensures another controller election will be triggered and there will always be an actively serving controller
		   */          
	      onControllerFailover()
	    } catch {
	      case e: ControllerMovedException =>
	        maybeResign()
	
	        if (activeControllerId != -1)
	          debug(s"Broker $activeControllerId was elected as controller instead of broker ${config.brokerId}", e)
	        else
	          warn("A controller has been elected but just resigned, this will result in another round of election", e)
	
	      case t: Throwable =>
	        error(s"Error while electing or becoming controller on broker ${config.brokerId}. " +
	          s"Trigger controller movement immediately", t)
	        triggerControllerMove()
	    }
	  }
	```

#### 删除 Topic
从上面可以看出，是 KakaController 在处理 TopicDeletion 事件。那么 TopicDeletion 事件是如何触发的呢？其实在上文的 ZooKeeper 栏目已经有相关说明
1. TopicDeletionHandler 监听 /admin/delete_topics 节点的子节点变动，如果子节点有任何改变，则 eventManager 会将 TopicDeletion 事件假如到 event queue 中交给后台线程去触发对应的 Processor
	```java
	// ZkData.scala
	object DeleteTopicsZNode {
	  def path = s"${AdminZNode.path}/delete_topics"
	}
	
	// KafkaController.scala
	class TopicDeletionHandler(eventManager: ControllerEventManager) extends ZNodeChildChangeHandler {
	  override val path: String = DeleteTopicsZNode.path
	
	  override def handleChildChange(): Unit = eventManager.put(TopicDeletion)
	}
	```
2. controller 处理 Topic 删除

	```java
	 /**
	  * KakaController.scala
	  * 处理 Topic 删除事件：
	  * 1. 如果该 Broker 不是 Controller 则直接返回不处理
	  * 2. 从 zk 获取需要删除的 topic
	  * 3. 判断这些 topic 是否实际存在，更新 zk 节点 s"${AdminZNode.path}/delete_topics" 删除实际不存在的节点数据
	  * 4. 对于实际存在且要删除的节点 topicsToBeDeleted，并触发删除行为：
	  *    4.1 判断 topic 是否有分区正在 BeingReassigned
	  *        如果有：将 topic 加入 ControllerContext 中的 topicsIneligibleForDeletion 集合
	  *        如果没有：将 topic 加入 ControllerContext 中的 topicsToBeDeleted Set 集合；
	  * 5. 遍历 topicsToBeDeleted 执行删除
	  *    5.1 所有副本完成了删除：删除 controller 缓存的和 zk 上该 topic 的相关数据
	  *    5.2 部分副本删除未完成：最终调用
	  *    5.3 试删除未开始删除流程且不在 topicsIneligibleForDeletion 中的 topic：
	  *        5.3.1 找到对应的 Partition，发送 UpdateMetadata 请求，让所有存活的 broker 更新信息已拒绝该被删除 Topic 的请求
	  *        5.3.2 给 replicas 发送 StopReplicaRequest 和 给 leader 发送 LeaderAndIsrRequest，让所有 replicas 变成 OfflineReplica 状态
	  *        5.3.3 给所有 replicas 发送 StopReplicaRequest with deletePartition=true，以让他们开始删除对应的持久化数据
	  */
	 private def processTopicDeletion(): Unit = {
	    if (!isActive) return
	    var topicsToBeDeleted = zkClient.getTopicDeletions.toSet
	    debug(s"Delete topics listener fired for topics ${topicsToBeDeleted.mkString(",")} to be deleted")
	    val nonExistentTopics = topicsToBeDeleted -- controllerContext.allTopics
	    if (nonExistentTopics.nonEmpty) {
	      warn(s"Ignoring request to delete non-existing topics ${nonExistentTopics.mkString(",")}")
	      zkClient.deleteTopicDeletions(nonExistentTopics.toSeq, controllerContext.epochZkVersion)
	    }
	    topicsToBeDeleted --= nonExistentTopics
	    if (config.deleteTopicEnable) {
	      if (topicsToBeDeleted.nonEmpty) {
	        info(s"Starting topic deletion for topics ${topicsToBeDeleted.mkString(",")}")
	        // mark topic ineligible for deletion if other state changes are in progress
	        topicsToBeDeleted.foreach { topic =>
	          val partitionReassignmentInProgress =
	            controllerContext.partitionsBeingReassigned.map(_.topic).contains(topic)
	          if (partitionReassignmentInProgress)
	            topicDeletionManager.markTopicIneligibleForDeletion(Set(topic),
	              reason = "topic reassignment in progress")
	        }
	        // add topic to deletion list
	        topicDeletionManager.enqueueTopicsForDeletion(topicsToBeDeleted)
	      }
	    } else {
	      // If delete topic is disabled remove entries under zookeeper path : /admin/delete_topics
	      info(s"Removing $topicsToBeDeleted since delete topic is disabled")
	      zkClient.deleteTopicDeletions(topicsToBeDeleted.toSeq, controllerContext.epochZkVersion)
	    }
	  }
	```

### Client
Client 端包括生产者和消费者，都是 Java 语言实现的。

#### Producer
##### 示例代码
先直接上一个 Producer 的发送实例，让大家有个直观的了解。
```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("acks", "all");
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

Producer<String, String> producer = new KafkaProducer<>(props);
for (int i = 0; i < 100; i++)
    producer.send(new ProducerRecord<String, String>("my-topic", Integer.toString(i), Integer.toString(i)));

producer.close();
```

##### 简介
Kafka 的生产者有如下特点：
- KafkaProducer 是线程安全的，通常来说，只有一个 Producer 实例会好过使用多个 Producer 实例。
- Producer 包含一个 buffer 空间，用来保存待发送消息；所以调用 send 方法的时候，实际是将消息 append 到对应的 buffer 上，然后立即返回。消息是由后台线程一起批量发送的
- Producer 为每一个 partition 都维护了这么一个 buffer，可通过 `batch.size` 属性设置其大小
- 生产者有自动重发机制，这取决于你的 `retries` 属性设置，但是自动重发可能导致消息重复
- 发送行为同样依赖于 `acks` 配置
  - acks=0， 不需要等待服务器的确认. 这时retries设置无效. Producer 只管发不管发送成功与否。延迟低，容易丢失数据。
  - acks=1， 表示 leader 写入成功（但是并没有刷新到磁盘）后即向 producer 响应。一旦leader副本挂了，就会丢失数据。
  - acks=all，等待数据完成副本的复制, 保证消息不丢失。
- 支持幂等和事务消息（事务消息后文说）

##### 初始化流程
即 KafkaProducer 实例创建的行为： 
1. 设置 ClientId (由参数传递或原子递增）
2. 配置 Metric 和 Serializer 等
3. 配置 interceptors
4. 初始化 RecordAccumulator
5. 初始化 metadata（此时还没有数据）
6. 初始化并启动 Sender 线程

##### 发送流程
发送代码如下：
```java
@Override
public Future<RecordMetadata> send(ProducerRecord<K, V> record, Callback callback) {
    // intercept the record, which can be potentially modified; this method does not throw exceptions
    ProducerRecord<K, V> interceptedRecord = this.interceptors.onSend(record);
    return doSend(interceptedRecord, callback);
}
```

具体发送逻辑由 doSend 完成，流程如下：
1. 获取或等待直到 metadata 可用
    
    主要逻辑在 `waitOnMetadata` : Wait for cluster metadata including partitions for the given topic to be available.  类似 NIO 的一个数据交互流程
    1. 本地对应的 metadata 会唤醒 Sender -> 唤醒 kafkaClient -> 唤醒 Selector(封装了 NIO 的 Selector，最终会调用其 wakeup),  解除 NetworkClient 的阻塞，方便后面的 IO 操作
    2. 后台 Sender run 方法, 触发 NetworkClient 的 poll 操作：
        - 发送 MetadataRequest 请求
        - selector.poll 从 socket 中获取数据 
        - metadataUpdater.handleCompletedMetadataResponse 更新 metadata
    
    对应的 metadata 结构如下：
	```java
	public class ProducerMetadata extends Metadata {
	    private static final long TOPIC_EXPIRY_NEEDS_UPDATE = -1L;
	    static final long TOPIC_EXPIRY_MS = 5 * 60 * 1000;
	
	    /* Topics with expiry time */
	    private final Map<String, Long> topics = new HashMap<>();
	    private final Logger log;
	    private final Time time;
	    //...
	}
	
	public class Metadata implements Closeable {
	    private final Logger log;
	    private final long refreshBackoffMs;
	    private final long metadataExpireMs;
	    private int updateVersion;  // bumped on every metadata response
	    private int requestVersion; // bumped on every new topic addition
	    private long lastRefreshMs;
	    private long lastSuccessfulRefreshMs;
	    private KafkaException fatalException;
	    private Set<String> invalidTopics;
	    private Set<String> unauthorizedTopics;
	    private MetadataCache cache = MetadataCache.empty();
	    private boolean needUpdate;
	    private final ClusterResourceListeners clusterResourceListeners;
	    private boolean isClosed;
	    private final Map<TopicPartition, Integer> lastSeenLeaderEpochs;
	    //...
	}
	```

2. 序列化 record 的 key 和 value

3. 根据 record 和 metadata 选择 partition
  
    partition 可以手动指定，没有指定的就使用系统的 Partitioner 来决定：
    - DefaultPartitioner：如果 `key!=null`，根据 key hash 选择 partition，否则按照 UniformStickyPartitioner 的逻辑来；可保证 key 相同的 record 发送到同一 partition
    - RoundRobinPartitioner："Round-Robin" 算法，均衡的将消息发送到所有 partition
    - UniformStickyPartitioner：根据 topic 选择 partition

4. 将记录 append 到 RecordAccumulator 中

5. 获取 append 结果，有新的 batch 创建或有 batch 满了的时候调用 sender.wakeup 解除 NetworkClient 的阻塞，使得后台 run 方法能 sendProducerData

##### 事务消息
先看看事务消息如何使用
```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("transactional.id", "my-transactional-id");
Producer<String, String> producer = new KafkaProducer<>(props, new StringSerializer(), new StringSerializer());

producer.initTransactions();

try {
    producer.beginTransaction();
    for (int i = 0; i < 100; i++)
        producer.send(new ProducerRecord<>("my-topic", Integer.toString(i), Integer.toString(i)));
    producer.commitTransaction();
} catch (ProducerFencedException | OutOfOrderSequenceException | AuthorizationException e) {
    // We can't recover from these exceptions, so our only option is to close the producer and exit.
    producer.close();
} catch (KafkaException e) {
    // For all other exceptions, just abort the transaction and try again.
    producer.abortTransaction();
}
producer.close();
```
##### 事务整体流程
![在这里插入图片描述](https://img-blog.csdnimg.cn/20191217164639495.jpg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTA4NjI3OTQ=,size_16,color_FFFFFF,t_70)

> 图片引用自 [Kafka 事务实现原理](https://zhmin.github.io/2019/05/20/kafka-transaction/)

##### 事务协调
TODO:

##### 发送流程
TODO:

#### Consumer
##### 示例代码
先直接上一个 Consumer 的消费实例，让大家有个直观的了解。
```java
Properties props = new Properties();
props.setProperty("bootstrap.servers", "localhost:9092");
props.setProperty("group.id", "test");
props.setProperty("enable.auto.commit", "true");
props.setProperty("auto.commit.interval.ms", "1000");
props.setProperty("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
props.setProperty("value.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Arrays.asList("foo", "bar"));
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records)
        System.out.printf("offset = %d, key = %s, value = %s%n", record.offset(), record.key(), record.value());
}
```

##### 简介
大致特点：
- KafkaConsumer 是非线程安全的
- consumer 只与必要的 broker 建立 TCP 连接来获取数据
- consumer 有 consumerGroup 的概念，groupId 相同的 consumer 在同一个 group，同一消息只会被 group 中的一个实例消费。
- consumer group 中的成员是变动的，当成员变动或订阅的 topic 变动时，就需要 rebalance，分配给成员的 topic partition 就会重新调整。
    - 成员超过 session.timeout.ms 没有发送心跳 ，leave group
    - 成员超过 max.poll.interval.ms 没有 poll，leave group
    - 成员关闭，leave group
    - 订阅的 Topic 的 partition 数量变动
    - 订阅的 Topic 被删除或新建
    - 新成员加入 group
    
    重分配时，ConsumerRebalanceListener 能被通知到，可以使用其做应用级别的事情。eg. 手动 offsets 提交等
- Kafka 消费的情况保存在一个内部 topic 中: `__consumer_offsets`。其专门用来存储 group 消费的情况，默认情况下有 50 个 partition，每个 partition 三个副本。

##### 消费流程
1. 订阅 topic
	```java
	consumer.subscribe(Arrays.asList("foo", "bar"));
	```
2. poll 拉取消息，有消息则立即返回，没消息则等到 timeout
	```java
	ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
	```
   1. pollHeartbeat: 检查 heartbeat 线程的状态，确保即使 coordinator 没准备好也不至于被 leave group
   2. lookupCoordinator: 找一个连接最少的 Node 来发送 FindCoordinatorRequest，收到结果后填充 coordinator 节点信息
   3. rejoinNeededOrPending: join group, join 完成后会根据是不是 leader 来执行不同的操作; 在此会设置对应的 assignment 等信息。为 leader 时，需要执行分配策略分配 topicpartition 并 同步到 followers，策略有
       - RangeAssignor
       - RoundRobinAssignor
       - StickyAssignor
       - CooperativeStickyAssignor
       具体说明参考文章 [Kafka分区分配策略](https://blog.csdn.net/u013256816/article/details/81123600)
   4. 触发异步提交 offset 信息
   5. 设置 fetch 的 postition（手动指定或获取的最新的提交的 offset）
   6. pollForFetches: 拉取记录，已有记录的话则直接返回；否则，发送 FetchRequest 请求，并等待可用记录并返回，但是如果正在 reblance 的话，则返回空集合。

---
更详细的，可以阅读这个系列的博客: [Kafka](http://matt33.com/tags/kafka/) ，写的很棒
