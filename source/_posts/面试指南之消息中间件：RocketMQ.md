---
title: 面试指南之消息中间件：RocketMQ
date: 2021-06-04 13:37:19
seo_title: interview-questions-rocketmq
tags: [RocketMQ,消息中间件,面试]
categories: [中间件]
---

@[toc]
### 序

该篇 Chat 会通过在段落的一开始引入一个或多个面试问题，然后围绕着该问题对对应的技术做介绍说明，最后在段落的最后会提供一个回答示例来结束这以问题。回答示例是基于笔者自己的经验的，读者可以结合自己的实际情况整理个更好的回答，可以的话在评论中展示出来让更多的同学参考学习。另外，通常面试题上下之间会有关联，是一个渐进的过程。类似面试过程中的由浅入深。

### 消息中间件简介

> **面试题：为什么你的系统中需要引入消息中间件？**

消息中间件是指一种在需要进行网络通信的系统进行通道的建立，数据或文件发送的中间件。消息中间件的一个重要作用是可以跨平台操作，为不同操作系统上的应用软件集成提供便利。

现在越来越多的分布式应用系统采用消息中间件方式来构建，人们通过使用消息中间件把应用扩展到不同的操作系统和不同的网络环境。基于消息的机制更适用于由事件驱动的应用，当一个事件发生时，消息中间件通知服务方应该进行如何操作。

通常，它具有低耦合、可靠投递、广播、流量控制、最终一致性 等一系列功能。这也是系统引入消息中间件的一般理由。

比如说：

1. 两个系统需要信息交互，但是各自所在的平台不同或使用的开发语言不同；
2. 有时系统的瞬时流量过大，系统处理不来，需要先接收请求留待后续满满处理；
3. 系统中的部分业务可以异步交给其他的系统去处理（eg. 邮件，短信等事件通知）。

<!-- more -->

**回答示例：**

>  核心系统中，用户下单后，有一系列的相关业务需要被触发，这些业务都可以是异步的。其中有财务系统需要获取订单金额等信息，通知中心需要或者该事件发送邮件和短信等给客户，风控系统需要相关的订单信息调整用户的信用级别等。一个个通知的十分繁琐重复且耦合大，关联系统的不可用可能还会影响到核心系统的正常运行，所以通过引入消息中间件的发布订阅模式，事件消息一次发送，有需要的关联系统订阅即可。使得核心系统和这些相关系统实现了解耦。

### RocketMQ 之 WHAT/WHY/HOW

上面对消息中间件进行了简单的介绍，这里使用 RocketMQ 来做了更详细的更有针对性的介绍说明。

#### WHAT & WHY

> **面试题：为什么选择 RocketMQ？**

RocketMQ 当然也是一种消息中间件，它具有消息中间件的公共特性，但是对于每一种消息中间件来说，他们都有自己的优缺点。我们在进行技术选型时，需要根据自己业务及团队的实际情况来选择最为合适的。所以，必须要对同种类的技术或中间件有个清晰的了解，了解他们的优缺点。这也是面试过程中常会出现的问题。

接下来带着问题来看下 RocketMQ 有何特点。

[Apache RocketMQ](https://rocketmq.apache.org/) 是阿里开源的一款高性能、高吞吐量的分布式消息中间件。相比于 Kafka，其拥有更好的实时性和消息可靠性。更适用于和 Money 相关的系统。它支持如下特性：

**订阅/发布模式的消息**

支持消费组模式的消费，即一个消费组集群内只有一个实例会收到那一条消息。

**延时消息**

只支持特定 Level 的延时设置，默认有“1s 5s 10s 30s 1m 2m 3m 4m 5m 6m 7m 8m 9m 10m 20m 30m 1h 2h”18个 Level。先扔到对应的延时队列，后台线程根据延时再将其挪到实际的 Topic 中。

**顺序消息**

只保证在单个 Broker 的单个 Queue 内是有序的，全局不保证有序。和 Kafka 一样.。

**消息持久化**

“主从同步 + 同步刷盘”模式保证了持久数据的安全性。4.5 版本后加入 [Dleger](https://github.com/openmessaging/openmessaging-storage-dledger/blob/master/docs/cn/introduction_dledger.md#dledger-%E7%9A%84%E5%AE%9E%E7%8E%B0) 更是支持了主从自动切换。

**消息过滤**

RocketMQ 的消费者可以根据 Tag 进行消息过滤，也支持自定义属性过滤。消息过滤目前是在 Broker 端实现，减少了无用消息的网络传输。

**消息回溯**

已消费过的消息，可以根据时间或 key 等维度来重新消费。在处理系统环境异常时很有用。

**事务消息**

先发送到一个特殊的系统 Topic 中，然后利用 2PC + 事务回查机制，判断将消息转到真正的 Topic 还是抛弃。

**死信队列**

消费失败并重试一定次数还是失败的的消息会先放到死信队列，需要手动进行重发。

**消息重试**

每个消费组有一个“%RETRY%+consumerGroup”的重试队列。重试的消息会按照延迟的时间先放到“SCHEDULE\_TOPIC_XXXX”队列中，然后才会被保存至“%RETRY%+consumerGroup”的重试队列中。

**At-Least-Once**

消息消费有 ACK 机制，消费结束才返回对应的 ACK 相应。和 Kafka 不太一样，Kafka 追求消息的大量快速处理，默认都是异步，整合成一批来消费生产的。

**ActiveMQ、RocketMQ、Kafka 对比：**

| - | ActiveMQ | RocketMQ  | Kafka |
| -- | -- | -- | -- |
| 客户端 SDK | Java, .NET, C++ etc.  | Java, C++, Go | Java, Scala etc. |
| 协议支持 | 推送模式，支持 OpenWire, STOMP, AMQP, MQTT, JMS  |  拉取模式，支持 TCP, JMS, OpenMessaging | 拉取模式，支持 TCP |
| 顺序消息 | 特定消费者和队列保证有序  | 保证有序且可拓展  | 保证消息分区内有序 |
| 定时消息 | 支持  | 不支持 | 不支持 |
| 批量消息 | 不支持	  | 支持 | 支持 |
| 广播消息 | 支持 | 支持 | 不支持 |
| 消息过滤 | 支持 | 支持 SQL92  | 支持, 可使用 Kafka Streams 来过滤 |
| 服务端触发重发送 | 不支持  | 支持 | 不支持 |
| 消息存储 | 支持，使用 JDBC 存储到数据库中  |  高性能低延迟的文件存储 | 高性能的文件存储 |
| 消息回溯 | 支持 | 支持时间戳和 offset 两种形式 | 支持 offset 的形式 |
| 消息优先级 | 支持 | 不支持 | 不支持 |
| 高可用 | 支持，但依赖于其存储模式，需要 zookeeper  | 支持，主从模式	 | 支持，需要 zookeeper |
| 消息跟踪 | 不支持 | 支持 | 不支持 |
| 配置 | 配置繁琐 | 开箱即用，无需过多关注配置 | 使用 key-value 的配置方式 |
| 管理运维工具 | 支持 | 支持，有命令和网页两种形式 | 支持，仅有命令形式 |


**回答示例：**

> 选择 RocketMQ，理由是 RocketMQ 在保证了可靠性的前提下，队列特性足够丰富，可运维程度比较高。其快速横向扩展的能力，也能保证未来几年我们对其性能的要求。另外RocketMQ基于Java语言开发，也降低了我们后续对其进行扩展和二次开发的难度

#### HOW

> **面试题：**
>
> 1. **如何发送顺序消息**
> 2. **如何发送事务消息**

通常来说，这里是考察你对特定消息中间件的了解和使用的熟悉程度的。因为顺序消息和事务消息通常是消息中间件的一个高级特性。

**顺序消息：**

顺序消息分为全局顺序消息与分区顺序消息，全局顺序是指某个 Topic 下的所有消息都要保证顺序；部分顺序消息只要保证每一组消息被顺序消费即可。

- 全局顺序：对于指定的一个 Topic，所有消息按照严格的先入先出（FIFO）的顺序进行发布和消费。 适用于性能要求不高，所有的消息严格按照 FIFO 原则进行消息发布和消费的场景
- 分区顺序：对于指定的一个 Topic，所有消息根据 sharding key 进行分区。 同一个分区内的消息按照严格的 FIFO 顺序进行发布和消费。 sharding key 是顺序消息中用来区分不同分区的关键字段，和普通消息的 Key 是完全不同的概念。 适用场景：性能要求高，以 sharding key 作为分区字段，在同一个区块中严格的按照 FIFO 原则进行消息发布和消费的场景。

**事务消息**

RocketMQ 事务消息（Transactional Message）是指应用本地事务和发送消息操作可以被定义到全局事务中，要么同时成功，要么同时失败。RocketMQ 的事务消息提供类似 X/Open XA 的分布事务功能，通过事务消息能达到分布式事务的最终一致。

**回答示例：**

>  **顺序消息**：RocketMQ 无法保证消息全局有序，但是同一个分区下的消息是有序的，所以保证消息有序需要保证三个点：

>  1. 消息发送有序
>  2. 消息发送到同一个分区
>  3. 消息消费有序
>
> 总的来说，就是需要使用单生产者单线程通过实现 MessageQueueSelector 发送消息使得消息发送到同一分区，单消费者单线程通过实现 MessageListenerOrderly 消费同一分区的消息。

> 但是这样的话，效率就会低很多且对分区的压力也打，所以可以结合业务做对应的调整，比如其实我么只需要保证同一个订单的消息有序就可以了，而不同订单的消息可以不用有序。那么我们可以根据订单号做 hash，保证同一订单的消息发送到同一个分区即可。
>
> **事务消息**：

> 1. 实现 TransactionListener 保存事务消息状态到本地并提供事务消息状态查询方法
> 2. 使用 TransactionMQProducer 发送消息
>
> [参考代码](https://github.com/apache/rocketmq/blob/master/docs/cn/RocketMQ_Example.md)

通常来说，这两个问题会接着被深入问对应的消息中间件的内部实现。请看“RocketMQ 之顺序消息”和“RocketMQ 之事务消息”。

### RocketMQ 基础组件

> **面试题：你们的 RocketMQ 部署情况？**

考察求职者对中间件的相关组件了解情况，以及考察求职者是否真的有使用过这个中间件。

![RocketMQ 架构图](https://images.gitbook.cn/3112a730-3bef-11ea-a474-b9c766c23b31)

如图，RocketMQ 整体包含四类组件：

**Producer**

消息生产者，可集群部署。Producer 随机与 NameServer 集群中的一个节点建立长连接，定期从 NameServer 获取 Topic 路由信息，并向提供 Topic 服务的 **Master** 建立长连接，且定时向 Master 发送心跳。Producer 通过 RcoketMQ 提供的客户端来发送消息，在客户端根据从 NameServer 获取的信息来做消息的负载均衡，选择对应的 Broker 进行连接投递消息。实现了低延迟且快速失败的消息投递。

**Consumer**

消息消费者，可集群部署。Consumer 随机与 NameServer 集群中的一个节点建立长连接，定期从 NameServer 获取 Topic 路由信息，并向提供 Topic 服务的 **Master 和 Slave** 建立长连接，且定时向 Master 发送心跳。支持 push 和 pull 两种消费方式（实际上都是 pull），并支持集群模式和广播模式的消费。

- 集群模式：同一个 Topic 的同一条消息只会被 ConsumerGroup 中的一个消费者实例消费
- 广播模式：广播给所有订阅了该 Topic 的 ConsumerGroup 中的所有消费实例

**NameServer**

NameServer 有点类似于 Kafka 中 ZooKeeper 的作用，支持 Broker 的动态注册和发现，其充当一个路由注册中心，维护所有的 Broker 和 Topic 路由的信息。但是和 ZooKeeper 不同，NameServer 是一个几乎无状态节点，可集群部署，节点之间无任何信息同步。 Broker 启动时需要向所有的 NameServer 实例注册，并定时向其发送心跳信息。因此，每个 NameServer 都是包含了所有的 Broker 和 Topic 的路由信息的，是一个完整的个体。

**Broker**

Broker主要负责消息的存储、投递和查询以及服务高可用保证。Broker 有主从之分，Broker Name 相同的，BrokerId 为 0 的则为主服务器；每个 Broker 都需要向所有的 NameServer 注册，并周期性的向其发注册请求。

Broker 部署方式：

-  单 Master 模式：这种方式风险较大，一旦 Broker 重启或者宕机时，会导致整个服务不可用。
- 多 Master 模式：一个集群内全是 Master，无 Slave。配置部署简单，单个 Master 宕机或重启维护对应用无影响，消息不会丢且性能高。但是，单台服务器器宕机期间，这台机器上未被消费的消息在机器恢复之前不可订阅，可用性收到影响，消息实时性会受到影响。
- 多 Master 多 Slave 模式—异步复制：每个 Master 配置一个 Slave，HA采用**异步复制**方式，主备有短暂消息延迟（毫秒级），因此如果 Master 出问题后（eg. 磁盘损坏），可能会丢失少部分消息。但是消息实时性不会受影响，同时 Master 宕机后，消费者仍然可以从 Slave 消费，而且此过程对应用透明，不需要人工干预，性能同多 Master 模式几乎一样。
- 多 Master 多 Slave 模式—同步双写：结构同上，但是 HA 采用的是**同步双写**的模式。性能比异步复制模式略低（大约低10%左右），发送单个消息的 RT 会略高，且目前版本在主节点宕机后，**备机不能自动切换为主机**。

**回答示例：**

> 我们的业务比较核心，属于和 Money 相关的系统，对消息的可靠性有非常高的要求，同时涉及到订单相关业务，因此对实时性也有一定的要求。所以我们采用的是 多主多从-同步双写 的模式，具体为 2主2从 的方式部署的。

这是一个比较简单的回答。在这一块，可能还会有更深入的问题。

> **面试题：**
>
> 1. 新增加/减少了消费者会如何
> 2. 新增加/减少了生产者会如何
> 3. 发送的 Topic 如果还未创建的话是如何处理的，会带来什么问题

这些问题涉及到对应的代码处理细节，在这里不做详细描述。可以参考《[深度解析 RocketMQ Topic 的创建机制](https://juejin.im/post/5ca0bffee51d4563c350548f)》和《[深入理解 RocketMQ Rebalance 机制](https://cloud.tencent.com/developer/article/1554950)》。


### RocketMQ 之重复消息

> **面试题：**

> 1. **RocketMQ 支持 Exactly Once 吗**
> 2. **什么时候消息会重复，如何处理重复消息**

RocketMQ 无法避免消息重复（Exactly-Once），但是不要不是选择 oneway 的发送模式，那么是可以保证 At-Least-Once 的。那么，RocketMQ 为什么不能保证 Exactly Once 呢？先看看如何才能保证 Exactly-Once：

- 发送阶段不允许发送重复的消息。
- 消费阶段不允许消费重复的消息。

只有满足了这两个条件，才能认为消息是 Exactly-Once 的。然而在分布式系统环境下，要实现这两条需要产生巨大的开销，RocketMQ 为了追求更高的性能，并没有保证该特性。要求使用者自行处理消息重复的问题。不过，虽然 RocketMQ 不能严格保证消息不重复，但是其实正常情况下也很少会出现重复的，一般只有在网络异常、Consumer 启动停止等异常情况下才可能会出现重复消息。

值得一说的是，Kafka 是支持 Exactly-Once 的。如果你简历中写了 Kafka 相关的，那么面试官很有可能会问你：

> 面试题：Kafka 如何实现 Exactly-Once 的？

有兴趣的可以去了解下，参考《[Kafka Exactly-Once 之事务性实现](http://matt33.com/2018/11/04/kafka-transaction/)》。

**如何处理消息重复：**

如果业务对消费重复非常敏感，务必要在业务层面进行去重处理。

- 借助缓存/关系型数据库对 msgId 或业务相关的唯一 Id 去重：在消费之前判断唯一键是否在关系数据库中存在。如果不存在则插入，并消费，否则跳过。
- 结合业务，将消息设计成幂等。重复消费不影响数据正确性。msgId 一定是全局唯一标识符，但是实际使用中，可能会存在相同的消息有两个不同 msgId 的情况（消费者主动重发、因客户端重投机制导致的重复等），这种情况就需要使业务字段进行重复消费。

**回答示例：**

> RcoketMQ 只能支持到 At-Least-Once。想要消息不重想要仔业务端保证。在我们项目中，因为对于会影响数据更新的消息，我们会将其设计成幂等的，使得根据相同的消息处理后，数据是一致的。对于影响到数据新增的消息，我们在消息中加入了数据相关的唯一主键，如果消息重复的话，插入数据时会抛出已存在的异常。

### RocketMQ 之顺序消息

> **面试题：如何实现顺序消息？**

前面如何使得消息有序的时候我们说过，需要单生产者单线程发，单消费者单线程收。使得消息有序。但是这里我们是默认 MQ 内部实现存储是保证消息有序的，忽略了 MQ 内部的实现存储是如何实现的。

那么 RocketMQ 内部存储实现是如何做的，他能保证消息到达和出去是有序的吗？

RocketMQ 消息是使用文件存储的，主要有以下三大类的数据：

**CommitLog**

存储所有的消息主体以及元数据，每个默认 1G，文件名为该文件大小的起始位置，长度为 20 位，左边补零。消息顺序写入 CommitLog，一个写满后就新建一个。

**ConsumeQueue**

消息消费队列，其目的主要是提高消息消费的性能。因为如果根据 Topic Name 去遍历 CommitLog 来消费的话效率很低。 所以引入 ConsumeQueue（逻辑消费队列）作为消费消息的索引，其保存了指定 Topic 下的队列消息在 CommitLog 中的起始物理偏移量 offset，消息大小和消息 Tag 的 HashCode 值。由后台服务异步构建。

**IndexFile**

提供了一种可以通过 key 或时间区间来查询消息的方法。由后台服务异步构建。

![RocketMQ Message Store](https://images.gitbook.cn/96a36610-3d8f-11ea-b148-0d2f459236d9)

可以看出，RocketMQ 采用的是混合型的存储结构，即为 Broker 单个实例下所有的队列共用一个日志数据文件 CommitLog 来存储。所有的 Topic 的数据公用 CmmoitLog 文件。

其内部存储最终通过封装的 MappedFile 使用 NIO 技术通过 FileChannel 写入到文件中。

![Message Store](https://images.gitbook.cn/955a00e0-3db5-11ea-afe8-2d38029f7016)

```MappedFile.java
    public boolean appendMessage(final byte[] data) {
        int currentPos = this.wrotePosition.get();

        if ((currentPos + data.length) <= this.fileSize) {
            try {
                this.fileChannel.position(currentPos);
                this.fileChannel.write(ByteBuffer.wrap(data));
            } catch (Throwable e) {
                log.error("Error occurred when append message to mappedFile.", e);
            }
            this.wrotePosition.addAndGet(data.length);
            return true;
        }

        return false;
    }
```

### RocketMQ 之事务消息

> **面试题：如何实现事务消息？**

![事务消息流程](https://images.gitbook.cn/5b757f10-3c18-11ea-9351-e1688e62ef26)

RcoketMQ 的事务消息有点类似于分布式事务的 2PC。具体流程如下：

1. Producer 向 MQ Server 发送 Half Message
2. MQ Server 返回 Half Message 的发送结果
3. Producer 执行提交对应的本地事务
4. Producer 根据本地事务结果向 MQ Server 发送 Commit 或 RollBack 请求

**假如 Producer 长时间没反馈给 MQ Server：**

5. MQ Server 主动向 Producer 请求回查事务状态（默认回查 15 次，还是没结果的话就回滚）
6. Producer 查询本地事务后，根据结果向 MQ Server 发送 Commit 或 RollBack 请求
7. MQ Server 根据 Producer 的反馈将消息丢弃或将其调整加入到 ConsumeQueue 使得消息可以被消费


**2PC 是啥啊？**

分布式事务的一个很常见的处理方案，这里不多说，请参考《[分布式事务之深入理解什么是2PC、3PC及TCC协议](https://www.cnblogs.com/wudimanong/p/10340948.html)》。

**Half Message 又是啥？它的作用是什么？**

Half Message 是 RocketMQ 为事务消息设计的，为了使之对用户无感，特别标记的一种消息。如果是 Half Message 的话，RocketMQ 会改变其原来的 Topic 和 Queue（改成一个系统保留的 Topic：RMQ\_SYS\_TRANS\_HALF\_TOPIC），同时将原来的 Topic 和 Queue 存到消息的属性中去，这样的话，该消息就不会被消费者消费的了。然后，RocketMQ 会开启一个定时任务，从 Topic 为 RMQ\_SYS\_TRANS\_HALF_TOPIC 中拉取消息进行消费，根据生产者组获取一个服务提供者发送回查事务状态请求，根据事务状态来决定是提交或回滚消息。

**回答示例：**

> RocketMQ 实现事务消息采取了类 2PC 的方式，同时增加回查补偿机制处理二阶段超时或者失败的消息。其核心主要有以下几点：

> 1. 改变事务消息原有的 Topic，将其存到 RMQ\_SYS\_TRANS\_HALF_TOPIC 这个保留 Topic 中
> 2. 定时从 RMQ\_SYS\_TRANS\_HALF_TOPIC 消费事务消息，并回查生产者该事务的状态来提交或者回滚
> 3. 增加了二阶段超时或失败的补偿机制，一定时间没收到生产者对应事务状态的返回话。会主动回查事务状态。

### RocketMQ 之高可用

> **面试题：如何保证高可用？**

>“高可用性”（High Availability）通常来描述一个系统经过专门的设计，从而减少停工时间，而保持其服务的高度可用性。

**RocketMQ 如何保证高可用的？**

需要服务不停机，通常来说就是通过冗余来来保证的。不管是 Kafka 还是 RocketMQ，都是如此。这里就说下 RocketMQ 的实现。主要是看 NameServer 和 Broker 是如何保证高可用的。

**NameServer**

由于各个Namesrv节点之间没有任何关联关系，不进行通信和数据交换，仅仅作为负载节点而存在。所以，当有节点挂掉时，其它节点不会受影响，而是继续提供服务。因此只需要冗余 NameSever 的实例数即可以保证 NameServer 的高可用。

**Broker**

RocketMQ 中，Borker 是通过主从的模式来保证高可用的。一个 Broker 可以有一个主和 N 个从，其中 BrokerId 为 0 的就是主。主 Broker 提供读写服务，而 Broker 只提供 Master 节点提供读写服务，Slave 节点只提供读服务。

Master 节点会将新的 CommitLog 发送给 Slave。而 Slave 节点需要上传本地 CommitLog 已经同步到的位置给 Master 节点。数据的同步可以是同步的，也可以是异步的。但是异步可能会导致数据丢失。

**回答示例：**

> 高可用的通常方法就是冗余，其中最常见的有主从模式和副本模式。比如说 Kafka 使用的就是副本模式。而 RocketMQ 使用的是主从模式，设计简单，操作方便。但是服务器的使用效率就不如 Kakfa 好而且还不支持主从自动切换。（如果你了解的话就接着说，不了解的话就停止别给自己埋坑）不过 RocketMQ 从 4.5 开始引入 DLedger 后，就支持主从切换了，balabalabala.....

### RocketMQ 之延时消息

RocketMQ 有一些特性，是其他 MQ 中间件不支持的，那么这些特性 RocketMQ 是如何实现的。这个问题可以开展开来，其实就是说，当你选择一个技术栈的时候，这个技术有其独特性，那么你需要了解其独特性，并最后能知道他为何这么特别，是如何做到的。这些都是我们在学习时可以吸取的东西。

在这里我们就只选择一个延时消息的特性来简单说明下。

**延时消息**

只支持特定 Level 的延时设置，默认有“1s 5s 10s 30s 1m 2m 3m 4m 5m 6m 7m 8m 9m 10m 20m 30m 1h 2h”18个 Level。先扔到对应的延时队列，后台线程根据延时再将其挪到实际的 Topic 中。

**实现原理**

其实是和事务消息相识的，延时消息会被存放到同一个系统保留 Topic（SCHEDULE\_TOPIC_XXXX）下，不同的延迟级别会对应不同的队列序号，当延迟时间到之后，由定时线程任务读取转换为普通的消息存到真实的 Topic 下，此时其才会在对应的 ConsumeQueue 中构建对应的消费者消费。

代码片段：
```java
public class CommitLog {
    public PutMessageResult putMessage(final MessageExtBrokerInner msg) {
         // ..... 省略
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
                // 真实的 topic 会被保存到 msg 的属性中
                MessageAccessor.putProperty(msg, MessageConst.PROPERTY_REAL_TOPIC, msg.getTopic());
                MessageAccessor.putProperty(msg, MessageConst.PROPERTY_REAL_QUEUE_ID, String.valueOf(msg.getQueueId()));
                msg.setPropertiesString(MessageDecoder.messageProperties2String(msg.getProperties()));

                msg.setTopic(topic);
                msg.setQueueId(queueId);
            }
        }
        // ......省略
    }
}
```

**回答示例：**

> 存储时，改变其 Topic 为 SCHEDULE\_TOPIC_XXXX，并将其真实的 Topic Name 等信息存储到消息的属性中。由于，该 Topic 为系统内部 Topic，消费端是无法消费该 Topic 的。所以该行为对客户端不可见。最后，等定时任务读取该消息时，再根据真实的 Topic 构建 ConsumeQueue，让消费者可以消费到该数据。

### 结束

对某个技术的考察我还是原来的说法，要知道 WHY/HOW/WHAT。需要我们有一个一探究竟的好奇心和相对应的行动力。

消息中间件其他可能的面试问题：

- RocketMQ 如何做到支持那么高并发的？
- RocketMQ 消息过滤怎么实现的？客户端实现 or 服务端实现？
- 让你设计一个 MQ 中间件，你会怎么设计？
- RocketMQ 消息发送失败怎么办？
- RocketMQ 消息挤压了怎么办？
- 想要切换消息中间件了怎么办？
- 现有消息中间件并发支持不够了怎么办？


----------
本文首发于 GitChat，未经授权不得转载，转载需与 GitChat 联系。
[面试指南之消息中间件：RcoketMQ](https://gitbook.cn/new/gitchat/activity/5e1ae7423d5c5427db832a02)