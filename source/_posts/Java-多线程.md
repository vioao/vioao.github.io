---
title: Java 多线程
seo_title: java-threads
date: 2020-07-23 17:12:38
tags: [多线程,面试]
categories: [Java]
---

本次本章从线程的基础讲到线程的相关实现类，每个章节算是一小块知识点，在每个知识点中，穿插地讲对应的知识原理，以及对应的常见面试题及其解答。多数面试题是前后环环相扣的。

### 什么是线程

线程是操作系统能够进行运算调度的最小单位。它被包含在进程之中，是进程中的实际运作单位。一条线程指的是进程中一个单一顺序的控制流，一个进程中可以并发多个线程，每条线程并行执行不同的任务。

同一进程中的多条线程将共享该进程中的全部系统资源，如虚拟地址空间，文件描述符和信号处理等等。但同一进程中的多个线程有各自的调用栈（Call Stack），自己的寄存器环境（Register Context），自己的线程本地存储（Thread-local Storage）。

一个进程可以有很多线程，每条线程并行执行不同的任务。在多核或多 CPU，或支持 Hyper-threading 的 CPU 上使用多线程程序设计的好处是显而易见的，即提高了程序的执行吞吐率。在单 CPU 单核的计算机上，使用多线程技术，也可以把进程中负责 I/O 处理、人机交互而常被阻塞的部分与密集计算的部分分开来执行，编写专门的 workhorse 线程执行密集计算，从而提高了程序的执行效率。

可能的问题，分别对应上面三段内容：

1. 什么是线程
2. 哪些数据存储是线程私有的
3. 为什么要使用多线程，即使用多线程的好处

<!-- more -->

### 线程的生命周期

我们从 JDK 中的定义来看一个 Thread 的生命周期及其对应的状态转换。JDK 在 Thread.java 中定义了其状态：
```java
    /**
     * A thread state.  A thread can be in one of the following states:
     * <ul>
     * <li>{@link #NEW}<br>
     *     A thread that has not yet started is in this state.
     *     </li>
     * <li>{@link #RUNNABLE}<br>
     *     A thread executing in the Java virtual machine is in this state.
     *     </li>
     * <li>{@link #BLOCKED}<br>
     *     A thread that is blocked waiting for a monitor lock
     *     is in this state.
     *     </li>
     * <li>{@link #WAITING}<br>
     *     A thread that is waiting indefinitely for another thread to
     *     perform a particular action is in this state.
     *     </li>
     * <li>{@link #TIMED_WAITING}<br>
     *     A thread that is waiting for another thread to perform an action
     *     for up to a specified waiting time is in this state.
     *     </li>
     * <li>{@link #TERMINATED}<br>
     *     A thread that has exited is in this state.
     *     </li>
     * </ul>
     *
     * <p>
     * A thread can be in only one state at a given point in time.
     * These states are virtual machine states which do not reflect
     * any operating system thread states.
     *
     * @since   1.5
     * @see #getState
     */
    public enum State {
        /**
         * Thread state for a thread which has not yet started.
         */
        NEW,

        /**
         * Thread state for a runnable thread.  A thread in the runnable
         * state is executing in the Java virtual machine but it may
         * be waiting for other resources from the operating system
         * such as processor.
         */
        RUNNABLE,

        /**
         * Thread state for a thread blocked waiting for a monitor lock.
         * A thread in the blocked state is waiting for a monitor lock
         * to enter a synchronized block/method or
         * reenter a synchronized block/method after calling
         * {@link Object#wait() Object.wait}.
         */
        BLOCKED,

        /**
         * Thread state for a waiting thread.
         * A thread is in the waiting state due to calling one of the
         * following methods:
         * <ul>
         *   <li>{@link Object#wait() Object.wait} with no timeout</li>
         *   <li>{@link #join() Thread.join} with no timeout</li>
         *   <li>{@link LockSupport#park() LockSupport.park}</li>
         * </ul>
         *
         * <p>A thread in the waiting state is waiting for another thread to
         * perform a particular action.
         *
         * For example, a thread that has called <tt>Object.wait()</tt>
         * on an object is waiting for another thread to call
         * <tt>Object.notify()</tt> or <tt>Object.notifyAll()</tt> on
         * that object. A thread that has called <tt>Thread.join()</tt>
         * is waiting for a specified thread to terminate.
         */
        WAITING,

        /**
         * Thread state for a waiting thread with a specified waiting time.
         * A thread is in the timed waiting state due to calling one of
         * the following methods with a specified positive waiting time:
         * <ul>
         *   <li>{@link #sleep Thread.sleep}</li>
         *   <li>{@link Object#wait(long) Object.wait} with timeout</li>
         *   <li>{@link #join(long) Thread.join} with timeout</li>
         *   <li>{@link LockSupport#parkNanos LockSupport.parkNanos}</li>
         *   <li>{@link LockSupport#parkUntil LockSupport.parkUntil}</li>
         * </ul>
         */
        TIMED_WAITING,

        /**
         * Thread state for a terminated thread.
         * The thread has completed execution.
         */
        TERMINATED;
    }
```

可见在 JDK 中定义的线程状态总共六种，各状态在特定条件下可以转换，其组成了一个线程的生命周期，为了方便理解，对其状态和转换整理成了列表和状态图的形式。

|状态|描述|
|--|--|
|  NEW | 线程新建但是还没有 start 的时候，即 new Thread() |
|  RUNNABLE |  调用了 Thread 的 start() 方法,此时线程可运行，但是也有可能需要等待其他操作系统资源，比如处理器资源，当获取到处理器资源之后，则进入 RUNNING 状态|
| BLOCKED | 当进入同步代码块时，如果需要等待获取锁，那么就会被阻塞进入该状态 |
| WAITING | 由于执行了 Object.wait()、`Thread.join()、LockSupport.park() 进入了等待状态|
| TIMED_WAITING | 由于执行了 Thread.sleep(long)、Object.wait(long)、Thread.join(long)、LockSupport.parkNanos、LockSupport.parkUntil，进入了有限时长的等待状态 |
|  TERMINATED | 线程 run 方法执行结束 |

{% asset_img threads.png 线程生命周期 %}

那么此处其实是有一些经典的面试题的：

**1. 线程的生命周期（这个上面已经给画出来了，此处不作答）**

**2.  wait 和 sleep 的区别？**
    
从上面可以看出，Thread.sleep(long) 和 Object.wait(long) 都能让线程从 RUNNABLE 状态转换到 TIMED_WAITING 状态。

那么它们有何区别？主要如下：

- 这是两个类的方法，sleep 方法属于 Thread 类，而 wait 是 Object 类的方法；
- sleep 调用后，仍然占有锁；而 wait 调用后，会释放锁；且 wait 需要在同步代码块中才能使用。

**3. 一个线程需要等待另一个线程结束才能开始，可以怎么实现？**
    
那么这个上面说的 Thread.join() 方法就可以很好地实现这个功能，另外也还有其他的一些方法，总结下：

- Thread.join()
- CountDownLatch
- wait/notify
    
**4. 手写阻塞队列（利用 wait/notify 来做）**

简易代码如下，要注意的点是：

- 方法需要加 synchronized，因为 wait 必须在同步代码块中才能调用；
- 调用 wait 其实释放的锁就是 synchronized 作用的锁，即当前对象。

```java
    public class CustomBlockingQueue<T> {
        private List<T> list = new LinkedList<T>();
        private int limit;

        public CustomBlockingQueue(int limit) {
            this.limit = limit;
        }

        public synchronized void put(T item) throws InterruptedException {
            while (list.size() == limit) {
                this.wait();
            }
            if (list.size() == 0) {
                this.notifyAll();
            }
            list.add(item);
        }

        public synchronized T take() throws InterruptedException {
            while (list.size() == 0) {
                this.wait();
            }
            if (list.size() == limit) {
                this.notifyAll();
            }
            return list.remove(0);
        }
    }
```

### 多线程相关类

这个模块我们直接从面试题开始入手讲解。首先是比较常见的三个类：Thread、Runnable、Callable，其对应了一个非常常见面试题。

#### 有哪几种方法可以实现多线程，各实现有何区别？

   - 继承 Thread 类，重写 `public void run()` 
   - 实现 Runnable 接口，实现 `public abstract void run();`
   - 实现 Callable 接口，实现 `V call() throws Exception;`

因为 Thread 是 implements 了 Runnable 的 ，所以其 run 方法和 Runnable 的一样，返回类型都是 void，即没有数据返回；但是 Callable 接口的返回类型是一个泛型 V，即是有返回数据的。

多线程的实现方式是知道了，但是当越来越多的线程创建后，线程该如何管理呢？另外，好比创建对象一样，创建线程是有资源消耗的，比如给线程分配内存，安排线程调度等；那么能否优化这些消耗呢？这就引入了线程池管理，相关的类有 ThreadPoolExecutor、ExecutorService、Executors。讲到这里，下面有一些和这些类相关的面试题，这些面试题会有些相关关系。

#### 如何管理线程？其对应有啥好处呢？
    
Java 中，JDK 中已经提供了基本的线程管理的类了，就是 ThreadPoolExecutor。使用线程池有如下的好处：
    
1. 降低资源消耗。重复利用已创建的线程，减少线程创建带来的开销。
2. 提高响应效率。略去了部分线程创建的时间消耗。
3. 提高线程可管理性。ThreadPoolExecutor 类包含少许线程管理方法。
4. 防止服务器过载。可以限制最大线程数，防止内存溢出、CPU耗尽。

一般面试过程中讲到 ThreadPoolExecutor 的话，那么有大概率又会出现如下的一些问题。所以说一般的面试都是环环相扣的，我们需要将面试引导到自己的强项中去。下面接着讲面试题。
 
#### 线程的创建执行流程
   
回答这个的问题都需要对 ThreadPoolExecutor 有个具体的了解，因此下面我们先讲一讲这个类。首先讲讲这个类的构造参数有哪些：
    
|名称 | 类型 | 含义|
|--|--|--|
|corePoolSize | int | 核心线程池大小|
|maximumPoolSize | int | 最大线程池大小|
|keepAliveTime | long | 线程最大空闲时间|
|unit | TimeUnit | 时间单位|
|workQueue | `BlockingQueue<Runnable>` | 线程等待队列|
|threadFactory | ThreadFactory | 线程创建工厂|
|handler | RejectedExecutionHandler | 拒绝策略|
    
这个问题其实是有一个坑的，如果你没有去了解过这个类的实现，那么你很有可能会以为线程的创建判断条件会是 corePoolSize -> maxPoolSize -> workQueue 这么一个流程。

但是其实不是，具体流程如下。

拟定当前线程数为 n，则

1. 当 n < corePoolSize 时，直接创建新线程执行新提交的任务（此时线程池中存在空闲线程也是一样的）。
2. 当 n >= corePoolSize 时，新任务将被放入 workQueue 中。
3. 当 workQueue 已满，且 maximumPoolSize  >  corePoolSize 时，创建新线程执行新提交的任务。
4. 当 workQueue 已满，n > maximumPoolSize，新提交的任务交给RejectedExecutionHandler 处理。
5. 当 n >  corePoolSize，且超过这部分的线程的空闲时间达到 keepAliveTime 时，会被回收。
6. 当设置 allowCoreThreadTimeOut(true) 时，线程池中 corePoolSize 范围内的线程的空闲时间达到 keepAliveTime 也将被回收。

 
#### 线程数超标了怎么办？你用了什么拒绝策略？
    
从上面可以看到，构造函数中有个类型为 RejectedExecutionHandler 的参数，该参数就是定义了线程数达到最大时的一个执行策略，默认的是 AbortPolicy，可以使用自己实现的拒绝策略，只要实现 RejectedExecutionHandler 即可，也可以使用 JDK 中默认定义的几种：

1. AbortPolicy，当达到最大限制的时候继续提交线程任务的话，它会直接抛出 RejectedExecutionException 异常。
2. DiscardPolicy，对拒绝任务直接无声抛弃，没有异常信息。
3. DiscardOldestPolicy，抛弃队列里面等待最久的一个线程，然后把新提交的任务加到队列。
4. CallerRunsPolicy，重试添加当前的任务，他会自动重复调用 execute() 方法，直到成功。
   

#### 有哪几种线程池？

这个其实问的就是通过 Executors 创建的几种线程池，不过其实我觉得这个问题有点不太合理哈，因为归根结底来说，这些只是对应的构造参数传递的不同罢了。总之呢，有如下几种：
```
1. newFixedThreadPool(int nThreads)
2. newWorkStealingPool(int parallelism)
3. newFixedThreadPool(int nThreads, ThreadFactory threadFactory)
4. newSingleThreadExecutor()
5. newCachedThreadPool()
```
这里我不细讲了，除了 newWorkStealingPool(int parallelism) ，其他的都是创建的一个 ThreadPoolExecutor  实例，总的来说就是对应 corePoolSize、maxPoolSize 、 workQueue 等构造参数设置不同而已。

newWorkStealingPool(int parallelism) 创建的是 ForkJoinPool 的实例。

各对比的使用场景可以参考：
> [五种线程池的对比与使用](https://www.jianshu.com/p/135c89001b61)


这些都是相对简单的使用场景，如果复杂一点的一般需要自己创建 ThreadPoolExecutor 进行个性化的设置，有时候可能还需要实现自己的 workQueue 队列。在自定义构造 ThreadPoolExecutor 的时候，通常问得比较多的一个问题就是对应线程池大小如何设置。

#### 如何设置线程池大小

怎么设置？当然是直接传参啊，哈哈哈哈哈。

其实这里主要是考察你对线程任务的理解和对系统设置时资源消耗的考虑了。因为为了保证系统的稳定性的同时，又需要尽可能地资源利用最大化，提高系统性能。这就需要考虑对线程数设置的计算调整。一般来说，线程数大小设置遵循如下规则：

> 最佳线程数目 =(( 线程等待时间 + 线程 CPU 时间 )/线程 CPU 时间 )* CPU 数目

但是其实这个公式也就是个参考值，一般我们通过这个计算出大体的最佳线程数，然后通过压测再做对应的调整以找到真实的最佳线程数大小。


### 总结

本次就只讲这么多，最后一起回顾下这次提到的一些问题，我们在脑海中回顾下，现在是否能直接回答得出来：

1. 什么是线程
2. 哪些数据存储是线程私有的
3. 为什么要使用多线程
4. 线程的生命周期
5. wait 和 sleep 的区别？
6. 一个线程需要等待另一个线程结束才能开始，可以怎么实现
7. 手写阻塞队列（利用 wait/notify 来做）
8. 有哪几种方法可以实现多线程，各实现有何区别？
9. 如何管理线程？其对应有啥好处呢？
10. 线程池中线程的创建执行流程
11. 线程池中线程数超标了怎么办
12. 有哪几种线程池
13. 如何设置线程池大小

还遇到过其他的面试题吗？在交流圈中交流吧。一起学习，一起进步。


----------
本文首发于 GitChat，[面试指南之 Java 多线程](https://gitbook.cn/gitchat/activity/5d143d1f96dae44e6dd82d11)

----------