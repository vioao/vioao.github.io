---
title: HashMap源码解析
seo_title: learn-hashmap-sourcecode
date: 2017-06-09 21:33:29
tags: [HashMap,Java,面试]
categories: [Java]

---

## 前言

其实之前也有看过HashMap的源码，觉得自己对其中的实现原理什么的都还算是比较了解了。其实当初看的时候就没有看的多仔细，只是应付面试的问题罢了。
这不，最近有人提出个问题自救就没法回答了。
> 问: 我们知道，初始化 `HashMap` 的时候,可以使用默认的构造函数，也可以使用一个带 `initialCapacity` 参数的构造函数用于构造一个已知大小的实例。这样可以减少扩容时的数据转移等操作从而提高性能，那么已知需要存1000个数据，初始的 `initialCapacity` 应该是多少?

听到这问题的时候，脑海中大致知道有个扩容之类的与之相关，但是具体的却是不记得了，很是尴尬。所以接下来就回去再次详细的看了看 `HashMap` 的源码，这里作为记录，在下面的内容中会涉及解惑该问题。

> 注: 此篇文章的分析是基于JDK7的

---

<!-- more -->

## `HashMap` 源码解析

在解析前我们简单说下 `HashMap` 的大致实现原理。 `HashMap` 内部是由 **数组+链表** 的数据结构组成的，数组的大小为`capacity`(默认初始大小为16，可以通过构造函数传入参数 `initialCapacity` 来改变)。`put`数据时,会根据传入的key进行hash然后对`capacity`取模得到数组下标index，然后将 整个Entry<K,V> 存入到对应的数组下标中去。

这里两个问题:
1. hash会有冲突的情况。hash冲突时会得到相同的index，这时候如果再直接存 `Entry<K,V>` 就会导致数据覆盖
> 解决方案: `HashMap` 在存入的时候实际上是以链表的形式存入的，并且通过判断链表中 `Entry` 的key值是否相等来决定是否将 `Entry` 加入到链表中。

2. 当容量不够时，HashMap如何处理。扩容？ 如何扩容？ 何时扩容？
> 这个问题是这次的主题。主要和 `loadFactor` 和 `initialCapacity` 两个参数有关，详细的在下面说。

---

### 构造函数
首先，我们先来看 `HashMap` 的构造函数,了解下影响`HashMap` 实例表现的一些参数。代码如下:
```java
    public HashMap(int initialCapacity, float loadFactor) {
        if (initialCapacity < 0)
            throw new IllegalArgumentException("Illegal initial capacity: " +
                                               initialCapacity);
        if (initialCapacity > MAXIMUM_CAPACITY)
            initialCapacity = MAXIMUM_CAPACITY;
        if (loadFactor <= 0 || Float.isNaN(loadFactor))
            throw new IllegalArgumentException("Illegal load factor: " +
                                               loadFactor);

        this.loadFactor = loadFactor;
        threshold = initialCapacity;
        init();//该方法提供给子类自己实现,HashMap中没有对其实现
    }
```

该构造函数有两个参数 `initialCapacity` 和 `loadFactor` 这两个参数能较大的影 `HashMap` 实例的表现。
> `initialCapacity`: `HashMap` 实例初次创建时其内部数组的大小,默认为16
> `loadFactor`: 负载因子,默认大小为0.75。表示数组中存在多少数据的时候 `HashMap` 需要进行扩容(capacity的增加)

比如说，使用默认构造函数创建的`HashMap` 实例。即 `initialCapacity=16` `loadFactor=0.75`，此时 `HashMap` 的最大容量 `capacity` 为16.那么当put进 `16*0.75=12` 个数据的时候，此时达到了负载，就需要扩容了。扩容后容量大小就是 `2 * capacity`. 扩容时需要rehash，并且需要 `copyArray ` 这会消耗一 定时间,所以当已知确定的容量的时候，最好在初始化的时候设置好容量。计算公式如下:
> 实际容量 = 最大容量  * 负载因子

通常来说， 默认的 `loadFactor`  值(0.75)在时间和空间的花费上提供了一个很好的权衡。更大的 `loadFactor`  会减小空间的使用率，但是会增加查找所花费的时间(这会影响到 `HashMap` 的多数行为，包括 `get` 和 `put`)。

为什么会增加查找锁花费的时间?
> 这是由于 `loadFactor` 越大,hash的時候就越容易冲突，导致链表长度增加，查找的时候就增加了线性的key值对比，导致效率变慢。

---

### `put` 操作

上源码:
```java

    /**
     * The table, resized as necessary. Length MUST Always be a power of two.
     */
    // 存放Entry的数组,大小必须是2的幂
    transient Entry<K,V>[] table = (Entry<K,V>[]) EMPTY_TABLE;

    /**
     * The next size value at which to resize (capacity * load factor).
     * @serial
     */
    // If table == EMPTY_TABLE then this is the initial capacity at which the
    // table will be created when inflated.
    int threshold; // threshold = capacity * load factor，是需要扩展容量时的容量大小

    /**
     * Associates the specified value with the specified key in this map.
     * If the map previously contained a mapping for the key, the old
     * value is replaced.
     *
     * @param key key with which the specified value is to be associated
     * @param value value to be associated with the specified key
     * @return the previous value associated with <tt>key</tt>, or
     *         <tt>null</tt> if there was no mapping for <tt>key</tt>.
     *         (A <tt>null</tt> return can also indicate that the map
     *         previously associated <tt>null</tt> with <tt>key</tt>.)
     */
    public V put(K key, V value) {
        // 如果数组为空,则初始化数组大小
        if (table == EMPTY_TABLE) {
            inflateTable(threshold);
        }
        // 如果key为null，单独调用putForNullKey(value)
        if (key == null)
            return putForNullKey(value);
         // 计算key的hash并根据hash和table的长度计算出数组下标i
        int hash = hash(key);
        int i = indexFor(hash, table.length);

        // 获取对应下标的链表，判断是否有key值相同的Entry，如果有就使用新值替换并返回oldValue
        for (Entry<K,V> e = table[i]; e != null; e = e.next) {
            Object k;
            if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
                V oldValue = e.value;
                e.value = value;
                e.recordAccess(this);
                return oldValue;
            }
        }

        modCount++;
        // 否则,加入Entry
        addEntry(hash, key, value, i);
        return null;
    }

    /**
     * Inflates the table.
     */
    private void inflateTable(int toSize) {
        // Find a power of 2 >= toSize
        int capacity = roundUpToPowerOf2(toSize);

        threshold = (int) Math.min(capacity * loadFactor, MAXIMUM_CAPACITY + 1);
        table = new Entry[capacity];
        initHashSeedAsNeeded(capacity);
    }


    /**
     * Adds a new entry with the specified key, value and hash code to
     * the specified bucket.  It is the responsibility of this
     * method to resize the table if appropriate.
     *
     * Subclass overrides this to alter the behavior of put method.
     */
    void addEntry(int hash, K key, V value, int bucketIndex) {
        // 如果当前size大于threshold且新下标对应位置有值，则需要扩展数组容量，进行resize
        if ((size >= threshold) && (null != table[bucketIndex])) {
            // resize,容量double
            resize(2 * table.length);
            hash = (null != key) ? hash(key) : 0;
            // 重新计算数组下标
            bucketIndex = indexFor(hash, table.length);
        }

        // 创建对应的Entry存入到对应的数组下标中去
        createEntry(hash, key, value, bucketIndex);
    }

     /**
      * Rehashes the contents of this map into a new array with a
      * larger capacity.  This method is called automatically when the
      * number of keys in this map reaches its threshold.
      *
      * If current capacity is MAXIMUM_CAPACITY, this method does not
      * resize the map, but sets threshold to Integer.MAX_VALUE.
      * This has the effect of preventing future calls.
      *
      * @param newCapacity the new capacity, MUST be a power of two;
      *        must be greater than current capacity unless current
      *        capacity is MAXIMUM_CAPACITY (in which case value
      *        is irrelevant).
      */
     void resize(int newCapacity) {
         // 超过了最大容量则放弃扩容
         Entry[] oldTable = table;
         int oldCapacity = oldTable.length;
         if (oldCapacity == MAXIMUM_CAPACITY) {
             threshold = Integer.MAX_VALUE;
             return;
         }

         // 创建新table,并将所有Entry重新计算下标存入的的table中去
         Entry[] newTable = new Entry[newCapacity];
         transfer(newTable, initHashSeedAsNeeded(newCapacity));
         table = newTable;
         threshold = (int)Math.min(newCapacity * loadFactor, MAXIMUM_CAPACITY + 1);
     }

     /**
      * Like addEntry except that this version is used when creating entries
      * as part of Map construction or "pseudo-construction" (cloning,
      * deserialization).  This version needn't worry about resizing the table.
      *
      * Subclass overrides this to alter the behavior of HashMap(Map),
      * clone, and readObject.
      */
     void createEntry(int hash, K key, V value, int bucketIndex) {
         Entry<K,V> e = table[bucketIndex];
         table[bucketIndex] = new Entry<>(hash, key, value, e);
         size++;
     }

     /**
      * Transfers all entries from current table to newTable.
      */
     void transfer(Entry[] newTable, boolean rehash) {
         int newCapacity = newTable.length;
         for (Entry<K,V> e : table) {
             while(null != e) {
                 Entry<K,V> next = e.next;
                 if (rehash) {
                     e.hash = null == e.key ? 0 : hash(e.key);
                 }
                 int i = indexFor(e.hash, newCapacity);
                 e.next = newTable[i];
                 newTable[i] = e;
                 e = next;
             }
         }
     }
```

总结下 `put` 操作大致步骤:
1. 判断table是否为空,为空则初始化
2. 判断key是否为null,为null则单独处理(这就是 `HashMap` 支持key为null, 这里就不细讲了，不是本篇主题，感兴趣的可以自己去看对应的源码)
3. 根据key进行hash并根据当前数组容量取模求下标,取table中对应下标的链表。遍历链表判断是否已有对应的key，有则替换，并返回旧值；没有则加入新的Entry,返回null

这其中需要注意过程中的 **扩容处理** 。在备注中都说的比较明白了。 至此，最开始的问题已经解决，收工。

---

最后说下，在新的JDK8中， 对 `HashMap` 做了优化，数组下标中存的不一定是链表结构，也可能是**树结构**。这样当冲突大的时候，查找会更快，从而提升效率。具体的还没有详细去学习，感兴趣的可以自己去学习下。

也可以参考如下博文了解下:
[HashMap源码注解 之 put()方法（六）](http://blog.csdn.net/fan2012huan/article/details/51233378)