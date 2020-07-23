---
title: '[译]深入理解 Node.js Worker Threads'
date: 2020-07-22 13:51:51
tags: [Node.js, 多线程]
categories: [Node.js]
---

最近工作中又有可能需要写 Node.js 应用了，距离上次写 Node.js 应用也有好些年了，所以就开始
重新熟悉下 Node.js 了。刚好最近又在学 Go，其最大的特点就是简单、轻量级的并发模型。非常容易
用它编写一个能够充分利用硬件资源的高性能应用。于是不免想起以前学习 Node.js 时会遇到的问题：如何
让 Node.js 充分利用多核 CPU 的资源。于是，让我发现了，Node.js 从 v10.5.0 开始引入
 worker_threads 模块来解决该问题。并让我发现了这篇文章。
 
此文为译文，原文如下。
> 译自 [Deep Dive into Worker Threads in Node.js](https://blog.insiderattack.net/deep-dive-into-worker-threads-in-node-js-e75e10546b11)

----

多年来，Node.js 一直都不是实现 CPU 密集型应用的最佳选择。其中最主要的原因就是 Node.js 仅仅
是 Javascript 而 JavaScript 是单线程的。作为该问题一个解决方法，Node.js 从 v10.5.0 开
始引入了实验性的 [Worker Threads](https://nodejs.org/api/worker_threads.html) 概
念，并将其体现在 `worker_threads` 模块，该模块从 Node.js v12 LTS 开始作为一个稳定功能
模块提供出来。在这边文章中，我将会说明它们是如何工作的，怎样使用 worker threads 才能获取最好
的性能。假如你对 Node.js worker threads 还不了解的话，我建议你查看它们的
[官方文档](https://nodejs.org/api/worker_threads.html) 。
                                   
> 注：文中引用的 Node.js 代码片段版本为 [921493e](https://github.com/nodejs/node/tree/921493e2287aa895679620155b5288b2e1587bfd) 。

<!-- more -->

### Node.js 的 CPU 密集型应用的历史

在 worker threads 出现前，就已经有很多种方案来完成基于 Node.js 的 CPU 密集型应用。常见的
有如下几种：

- 使用 `child_process` 模块，在子进程中运行耗费 CPU 的代码操作。
- 使用 `cluster` 模块，在多个进程中运行耗费 CPU 资源的代码操作。
- 使用第三方模块，如 Microsoft 的 [Napa.js](https://github.com/microsoft/napajs) 。

但是，由于性能局限、额外的引入学习成本、接受度的不足、不稳定性以及文档缺失等原因，这其中没有
一个方案是能被广泛接受的。

### 使用 worker threads 来执行 CPU 密集的代码操作

尽管 `worker_threads` 对于 JavaScript 的并发问题来说是一个优雅的解决方案，但是其实
 JavaScript 本身并没有引进将多线程的语言特性。实际上，`worker_threads` 是通过允许应用
可以运行多个独立的 JavaScript workers，workers 和 其父 workers 可以通过 Node.js 
 来通信。听起来很困惑？

**在 Node.js 中，每个 worker 有他自己的 V8 实例和事件循环机制(Event Loop)。但是，和子进程不同，workers 是可以共享内存的。**

在此文的后面我会解释它们是如何能够拥有独立的 V8 实例和事件循环(Event Loop)的。不过我们先来
看看我们能如何使用 worker threads。下面是一个基本用法的示例：`worker-simple.js`

```javascript
const {Worker, isMainThread, parentPort, workerData} = require('worker_threads');
if (isMainThread) {
 const worker = new Worker(__filename, {workerData: {num: 5}});
 worker.once('message', (result) => {
 console.log('square of 5 is :', result);
 })
} else {
 parentPort.postMessage(workerData.num * workerData.num)
}
```

在上面的例子中，我们将一个数字传给另一个 worker 来计算其平方值。在完成计算后，该 child worker
会将其结果发送给 main worker。尽管这看起来很简单，但是如果你不了解 Node.js 的 worker threads
的话，还是会觉得有些困惑的。

### worker threads 是如何工作的
JavaScript 并没有多线程的特性，所以 Node.js 的 Worker Threads 和其他支持多线程的高级
语言在处理上是不一样的。

在 Node.js 中，一个 worker 的职责就是执行 parent worker 提供给他的代码片段(worker script)。
这个 worker script 可以是一个单独的文件，也可以是一个能够被 `eval` 代码文本；它将被放在别
的 worker 中独立运行，且 该 worker 和其 parent worker 之间是可以传递消息的。在我们的例子
中，我们提供了 `__filename` 作为这个代码片段，那是因为 worker 和 parent worker 的执行
代码是一样的，只是在其中通过 `isMainThread` 来区分了。

每一个 worker 都通过一个 [message channel](https://nodejs.org/api/worker_threads.html#worker_threads_class_messagechannel)
来和其 parent worker 通信。child worker 可以通过 `parentPort.postMessage` 将信息
写入信道，而 parent worker 需要通过 `worker.postMessage()` 来将消息写入信道。看看下图
(图一)他们是如何工作的

{% asset_img message_channel.png Diagram 1: Message Channel between the parent and the child workers %}

> 一个信道就是一个简单的通信渠道。它有两个端口，被叫做 ‘ports'。在 [JavaScript](https://developer.mozilla.org/en-US/docs/Web/API/MessageChannel) / [NodeJS](https://nodejs.org/api/worker_threads.html#worker_threads_class_messagechannel)
> 中，信道的两端就只是被简单的叫做‘port1' 和 ‘port2'……

### Node.js workers 是如何并行运行的

现在，最大的问题就是,，既然 JavaScript 本身并不支持并行，那么两个 Node.js workers 是如何并行
执行的呢？

答案就是 [V8 Isolates](https://v8docs.nodesource.com/node-0.8/d5/dda/classv8_1_1_isolate.html) 。

**V8 Isolates** 是一个独立的 chrome V8 运行实例，其有独立的 JS 堆和微任务队列。这就为
每一个 Node.js worker 独立运行提供了保障。其缺陷就是，workers 之间没法直接访问对方的堆。

由于这个原因，每个 worker 都有其自己的 [libuv](https://github.com/libuv/libuv) event loop。

### 跨越 JS/C++ 的界限

Worker 的实例化和通信是通过 C++ 的 worker 来实现的。该模块的实现在 [worker.cc](https://github.com/nodejs/node/blob/921493e228/src/node_worker.cc) 。

Worker 的实现通过 `worker_threads` 模块暴露在了 JavaScript 的用户空间。这个 JS 的实现
被分成了两个 scripts ：

- [Worker 初始化脚本] - 负责初始化 worker 实例并设置 parent-child worker 之间的通信
使得 parent worker 可以将 metadata 传递给 child worker。
- [Worker 执行脚本] - 负责使用用户提供的 `workerData` 和 parent worker 提供的 
metadata 来执行用户的 JS 脚本。

下图（图二）提供了一个更清晰的说明。看看该图描述了些什么

{% asset_img worker_internals.png Diagram 2: Worker Implementation Internals %}

按照上面说的，我们可以把 worker 的设置进程分成两步。

- 初始化 worker
- 运行 worker

让我们看卡这两步都干了啥。

#### 初始化阶段

1. 用户空间的脚本通过 `worker_threads` 模块创建一个 worker 实例
2. Node.js 的 parent worker 初始化脚本调用 C++ 模块，创建一个空的 C++ worker 对象。
3. 当 C++ worker 对象被创建后，它生成一个线程 ID 并分配给自己
4. 当 worker 对象被创建的时候，parent worker 会初创建一个空的始化信道（让我们称它为 `IMC`）。就是上面图二的 “Initialisation Message Channel”
5. Node.js 的 parent worker 初始化脚本创建一个公共的 JS 信道（让我们称它为 `PMC`）。该信道是给用户空间的 JS 使用的，便于他们在 
parent worker 和 child worker 之间通过 `*.postMessage()` 方法来传递消息。就是上面图一和图二的红色部分
6. Node.js 的 parent worker 初始化脚本调用 C++ 模块，将初始化的 metadata 写入 IMC 来传递给 worker 的执行脚本。

> 初始化 metadata 是什么？ worker 执行脚本启动时需要知道的数据，eg. 脚本名称、worker 数据、 PMC 的 `port2` 以及一些其他信息。
> 根据我们的例子来说，初始化 metadata 就是类似如下的一条信息：  
> 嗨，Worker 执行脚本，使用 worker data `{num: 5}` 来运行 `worker-simple.js`。并将 PMC 的 `port2` 传递给它，以便它能从 PMC 
> 读取或写入消息。

下面这个代码片段展示了初始化 metadata 是如何被写入到 IMC 的。

```javascript

const kPublicPort = Symbol('kPublicPort');
// ...redacted...

const { port1, port2 } = new MessageChannel();
this[kPublicPort] = port1;
this[kPublicPort].on('message', (message) => this.emit('message', message));
// ...redacted...

this[kPort].postMessage({
  type: 'loadScript',
  filename,
  doEval: !!options.eval,
  cwdCounter: cwdCounter || workerIo.sharedCwdCounter,
  workerData: options.workerData,
  publicPort: port2,
  // ...redacted...
  hasStdin: !!options.stdin
}, [port2]);
```

在上面的片段中，`this[kPort]` 就是 IMC 的 end port。尽管此时已经向 IMC 写数据了，但是
worker 执行脚本还是无法获取这些数据，因为它还没有被启动呢。

#### 运行阶段

此时，初始化阶段完成。然后，就会调用 C++ 来启动这个 worker 线程。

1. 一个新的 v8 isolate 被创建并分配给这个 worker。这使得该 worker 可以拥有自己的运行时环境
2. libuv 被初始化。这使得该 worker 可以拥有自己的 event loop
3. Worker 初始化脚本被执行，启动 worker 的 event loop
4. Worker 初始化脚本 调用 C++ 模块从 IMC 读取初始化 metadata
5. Worker 执行脚本在 worker 中运行代码文件或代码片段。在我们的例子中就是 `worker-simple.js`

下面这个代码片段展示了 worker 是如何执行脚本的。

```javascript
const publicWorker = require('worker_threads');

// ...redacted...

port.on('message', (message) => {
  if (message.type === 'loadScript') {
    const {
      cwdCounter,
      filename,
      doEval,
      workerData,
      publicPort,
      manifestSrc,
      manifestURL,
      hasStdin
    } = message;

    // ...redacted...
    initializeCJSLoader();
    initializeESMLoader();
    
    publicWorker.parentPort = publicPort;
    publicWorker.workerData = workerData;

    // ...redacted...
    
    port.unref();
    port.postMessage({ type: UP_AND_RUNNING });
    if (doEval) {
      const { evalScript } = require('internal/process/execution');
      evalScript('[worker eval]', filename);
    } else {
      process.argv[1] = filename; // script filename
      require('module').runMain();
    }
  }
  // ...redacted...
```


#### 发现了什么吗？

在上面的代码片段中，你是否有发现 `workerData` 和 `parentPort` 属性是在
 `require('worker_threads')` 中被 worker 执行脚本设置的？
 
这就是为什么 `workerData` 和 `parentPort` 属性只能在 child worker thread 的代码
而不是 parent worker thread 的代码中被访问了。假如你尝试在 parent worker 的代码中获取
这些属性，你只能得到 `null`。

### 更好的使用 worker threads

现在我们了解了 Node.js Worker Threads 是怎么工作的了。了解他们的原来能让我们更好的使用
worker threads 来获取最佳的性能。当编写复杂的应用的时候（比 `worker-simple.js` 复杂的多）
，我们需要牢记下面两个点

- 尽管 worker threads 比实际的进程更加轻量级，但是大量频繁的创建使用它也是很昂贵的
- 使用 worker threads 来并行的执行 I/O 操作时不划算的，请直接使用 Node.js 自身的 I/O
操作，那会更高效

为了克服上述的第一个问题吗，我们需要实现 “Worker 线程池”。

#### Worker 线程池

通过使用线程池技术，使得当新任务来临时，我们可以通过 parent-child 信道将 其传递给一个可用
的 worker 来执行它，一旦这个 worker 完成了该 task，其可以用过同样的信道来将其执行结果传递
过来。

一旦正确的实现线程池，那么其将显著的提升应用性能。因为它能够减少额外的创建 threads 消耗。同样
值得一提的是，创建大量线程并不一定就是特别高效了，因为其还受制于硬件的资源。

下图是三种情况的一个性能比较，其实现了相同的功能：接受一个 string 然后给他加密并返回。三种不同
的服务如下：

- 没使用多线程的服务（no multi-threading）
- 使用了多线程但没有使用线程池的服务（multi-threading（no thread pool））
- 使用了多线程和线程池的服务（multi-threading（with thread pool））

{% asset_img worker_threads_efficient.png How efficient is it to use worker_threads %}

然而，Node.js 官方目前并没有提供线程池的使用。所以你需要依赖第三方的实现或者自己实现一个。
这是我自己实现的一个 [worker pool](https://repl.it/@dpjayasekara/threadpool) 。**它还不能被用于生产环境**