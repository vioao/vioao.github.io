---
title: Lock 和 synchronized
seo_title: java-concurrent-lock-and-synchronized
date: 2017-05-30 22:54:22
tags: [多线程]
categories: [Java]

---

## 前言
Java多线程编程中，保证线程安全通常会使用到`synchronized`和`Lock`。那么合适该使用`synchronized`，什么时候该使用`Lock`呢。这个就需要我们对`synchronized`和`Lock`有个清晰的了解。

---

## `Lock`和`synchronized`
**`synchronized`** 是JAVA提供的强制原子性的内置锁机制。一个`synchronized`有两部分:锁对象的引用 (`synchronized` 方法的锁，就是该方法所在对象本身)，以及这个锁保护的代码块。每个Java对象都可以作为一个用于同步的锁的角色，这些内置的锁被成为**内部锁**，线程进入 `synchronized` 块之前会自动获得锁，退出、报错异常、时会释放锁。内部锁是一种互斥锁，这就是说，至多只有一个线程可以获得锁，所以被 `synchronized` 声明的方法或代码块至多只有一个线程可以进入。从而保证了线程安全。
大致有如下用法:
```java
//作用于方法
public synchronized void synchronizedMethod(){
    //do something
}

// 作用与代码块
synchronized (syncObj){
    //do something
}
```

<!-- more -->

 **`Lock`**  接口定义了一些抽象了锁操作，与内部锁机制不同，它提供了更加灵活的， **无条件的**，**可轮训的**，**定时的**，**可中断的**锁获取操作。 `Lock` 的接口定义如下:

```java
/*
    以下为Lock接口定义的大致解释，建议自行阅读JDK源码学习
*/
 public interface Lock {
    // 获取锁，如果没有则会被阻塞
    void lock();
    // 获取锁，但是允许中断
    void lockInterruptibly() throws InterruptedException;
    // 尝试获取锁，如果此刻获取不到则返回false，否则返回true
    boolean tryLock();
    // 在一定时间内尝试获取锁
    boolean tryLock(long time, TimeUnit unit) throws InterruptedException;
    void unlock();
    // 返回一个新的Condition类别的实例
    Condition newCondition();
}
```
大致用法为:
```java
Lock lock = ...;
...
lock.lock();
try {
    // access the resource protected by this lock
} finally {
    lock.unlock();
}
```

从 `Lock` 接口的定义中可以看出，**`Lock` 和 `synchronized` 的区别:**
1. `Lock`  需要自己释放获得的锁(遗忘这个会容易导致错误，且不易排查)
2. `Lock` 支持**可中断**的锁获取操作
3. `Lock` 支持**可定时**的和**可轮训**的锁请求(由 `trylock` 方法实现),与无条件的锁获取想比，它具有更完善的错误恢复机制。
4. `Lock` 支持**非结构块**的锁，可以在不同的程序块中操作锁。

---

## `ReentranLock`
另外，我们有比较大的机会接触到 `Lock` 接口的实现类 `ReentranLock`，`ReentranLock` 支持公平性锁和**非公平性锁(默认)**,这个选择是通过构造函数传入一个 `boolean` 类型的参数决定的，其内部是通过继承了`AbstractQueuedSynchronizer`实现了一个`FairSync`和一个`NonFairSync`来实现的,这个可以在以后讲AQS的时候再深入讲解(大家也可以自行去阅读 `java.util.concurrent` 下的各个接口和类，相信会大有收获)。`ReentranLock` 也是一个标准的互斥锁：一次最多只有一个线程能够持有相同的`ReentranLock`。`ReentranLock` 提供了和`synchronized` 相同的互斥和内存可见性。所以通常会将 `ReentranLock` 和 `synchronized` 放在一起对比。
可能的面试问题场景如下:
> 面试官: 有哪几种实现同步的方式?
> 面试者:  `synchronized` 和 `ReentranLock`
> 面试官:  那`synchronized` 和 `ReentranLock` 有什么区别
> 面试者:  。。。

其实 `ReentranLock` 和 `synchronized` 的区别和`Lock` 和 `synchronized` 的区别是一致的，只不过`ReentranLock` **多了个公平队列的支持**！

---

## `ReentranLock` 和 `synchronized` 的选择
`ReentranLock` 是 `Lock` 接口的实现，所以其具有 `Lock`接口的特性。一般来说，不要`ReentranLock` 和 `synchronized` 混合使用，容易造成混淆。并且我们更倾向于使用简洁的内部锁机制`synchronized`。只有在需要使用`ReentranLock`的时候才应该使用。即:
> 当你需要 **可定时的，可寻轮的与可中断的锁获取操作，公平队列，或者非块结构的锁** 这些特性的时候才应该使用 `ReentranLock`。 否则最好还是使用 `synchronized` 。