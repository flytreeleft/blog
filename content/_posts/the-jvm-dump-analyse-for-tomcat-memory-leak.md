---
layout: post
title: JVM内存分析：Tomcat内存泄漏
date: 2019-10-04 18:07:06
tags:
  - 内存泄漏
categories:
  - JVM内存分析
---

## 提要

通过内存转储可对Java应用内各对象的内存使用情况进行分析，从而找出过度消耗内存或无法及时释放的对象，进而为异常修复以及提升应用加载速度和运行性能提供帮助。

内存转储使用JDK自带的工具`jmap`（`sudo -u tomcat jmap -dump:format=b,file=heap-dump.bin <java_pid>`）将应用内存以二进制格式转储到`heap-dump.bin`中。

> 需确保转储用户与线程用户相同，否则会出现[Unable to open socket file: target process not responding or HotSpot VM not loaded](https://stackoverflow.com/questions/26140182/running-jmap-getting-unable-to-open-socket-file#answer-35963059)的问题；
>
> 转储文件可能会被放到临时目录中，该目录会在Tomcat重启时被删除，所以，一定要在重启前将转储文件转移到安全位置；
>
> 转储的文件一般为GB级，可通过命令`xz -k heap-dump.bin`进行高强度压缩，得到压缩文件`heap-dump.bin.xz`。解压使用命令`unxz -k heap-dump.bin.xz`，其中，`-k`选项均表示保留原文件，否则原文件将会被删除；
<!-- more -->

得到内存转储文件后，可通过[Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)对其进行分析。由于转储文件较大，所以，分析工具也需要分配较大内存方可正常运行，需编辑文件`MemoryAnalyzer.ini`，修改或添加`-Xmx4g`以增加MAT的堆内存。

在开始分析之前先了解一下下面几个相关术语：
- **Shallow Heap**：对象自身占用的内存大小（包含基本数据类型），不包括它引用对象的大小；
- **Retained Heap**：**Shallow Heap** + 所有直接或者间接引用对象占用的内存（即该对象被GC回收后，可以被回收的内存）；
- **GC Root**：被堆外对象引用的对象；
- **Dominator Tree**：以支配树方式描述的对象引用关系；

## 案例分析

应用运行环境：
- 独立的Docker容器
- JDK8 + Tomcat8
- Tomcat内运行有A和B两个业务应用，其他为Tomcat自带的`docs`、`manager`、`examples`、`host-manager`、`ROOT`（五个）应用

在开发环境中，应用经常出现内存泄漏（`OutOfMemoryError：Permgem space`）。其每次重启并运行一段时间后，也会消耗掉大量内存：

![](/assets/images/jvm-dump/tomcat-memory-leak/app-a-hight-cpu-memory-usage.png)

> **内存泄露**：指程序中动态分配内存给一些临时对象，但是对象不会被GC所回收，它始终占用内存。即被分配的对象可达但已无用。
>
> **内存溢出**：指程序运行过程中无法申请到足够的内存而导致的一种错误。内存溢出通常发生于Old段或Perm段垃圾回收后，仍然无内存空间容纳新的Java对象的情况。

从图中可以看到，Tomcat进程占用了接近50%的内存（8G+），这对仅有少量访问的应用来说是很不正常的。

话不多说，直接使用`jmap`（`sudo -u tomcat jmap -dump:format=b,file=heap-dump.bin <java_pid>`）将Tomcat的内存转储并下载到本地。再通过MAT对其进行分析。

这里得到的分析结果如下：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-overview-of-heap-dump.png)

然后，打开`Dominator Tree`以检查当前占用内存最高的有哪些对象：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-dominator-tree-of-heap-dump.png)

从中可发现`SessionFactoryImpl`和`ParallelWebappClassLoader`的内存占用比例最高，并且，在对结果进行正则过滤后可以发现：
- 这两个Class存在多个实例，其中，`SessionFactoryImpl`有10个实例，而`ParallelWebappClassLoader`有15个实例；
- 各个`SessionFactoryImpl`实例的Class以及Class Loader的地址均不相同；
- 而所有`ParallelWebappClassLoader`的Class和Class Loader的地址却是相同的；
- 另外，可以看到`SessionFactoryImpl`的Class Loader均为`ParallelWebappClassLoader`；

> 在Tomcat7和Tomcat8中默认的Class Loader为`ParallerWebappClassLoader`以支持Class并行加载，提高加载效率（并行加载机制需JDK7+环境）。

根据Java Class的加载原理可知，每个Class均对应一个唯一的Class Loader，不同的Class Loader所加载的Class是不同的，即使是Class名称（含包名）完全一致，也是互不相等的。也就是说，在当前的Tomcat内不仅存在多个`SessionFactoryImpl`实例，还同时存在多个`SessionFactoryImpl`的Class。

打开`Histogram`看看在Tomcat中存在多少个Class，而每个Class又产生了多少实例：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-histogram-of-heap-dump.png)

对上述两个目标过滤后可以发现，在Tomcat中确实存在10个同名的`SessionFactoryImpl`类，每个类均产生了一个实例，而`ParallelWebappClassLoader`虽然只有一个类，但却创建了15个实例。这和我们所预期的共识产生了明显冲突：
- Tomcat应该为每个应用创建且仅创建一个Class Loader以隔离不同的应用，加上Tomcat自带的应用，总共应该只有7个Class Loader才对；
- Hibernate SessionFactory在单个应用内应该是单例的，而在本案例中只有A和B两个应用才会创建SessionFactory实例，其实例数最多只能有两个；

于是抛出以下问题：
- Tomcat因为什么原因创建了额外的8个Class Loader？
- 额外的8个Hibernate SessionFactory实例又是为何创建的？
- Tomcat高内存占用是因为Class被重复加载以及存在相同的活跃对象所造成的？

先来看看Class Loader的`GC Root`引用情况（在`Histogram`内选中目标，再右键选择`Merge Shortest Paths to GC Roots`）：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-classloader-gc-root-in-heap-dump.png)

从结果中可以看到，Class Loader实际被11条线程所引用，通过名称可以判断有5条是应用所创建的Deamon线程，以及一条Hibernate Search线程和一条Tomcat的线程。

如此看来，Class Loader是被不同的线程所引用的，那很有可能是因为这些线程遇到死锁或长时间的阻塞而造成了其无法被及时回收，从而导致`PermGen`（永生代，负责存放Class、静态变量、常量等）内存被耗尽。

还可以怀疑`ASM`的动态特性是否会创建新的Class Loader实例。可能性是有的，但仔细分析也可以发现，若其自行实例化加载器，即使不考虑性能问题，其又如何确定从何处加载所需的Class？很明显，利用当前的Class Loader才是明智的选择。看看Tomcat源码[WebappLoader.java](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappLoader.java#L393)的第`394`行就知道自己去实例化Class Loader是多么不可靠：

![](/assets/images/jvm-dump/tomcat-memory-leak/tomcat8-creating-classloader-in-webapploader.png)

既然提到了Tomcat的源码，那就干脆把代码check下来研究一下（https://github.com/apache/tomcat/ ，本例使用分支`tag/8.5.6`）。

先看看[ParallelWebappClassLoader](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/ParallelWebappClassLoader.java#L23)是怎么回事。

该类本身逻辑很少，但其继承的父类[WebappClassLoaderBase](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappClassLoaderBase.java#L1446)却责任重大，需要做Class的加载和查询工作。该父类包含众多属性，而其中值得关注的是类型为`LifecycleState`的`state`属性，显然，这说明这个Class Loader是具有生命周期的，并且，很明显只能由Tomcat来控制其生命周期，因为其他Class无法知道其存在。

既然，`ParallelWebappClassLoader`包含这么多属性，那看看在前面发现的那些实例的`state`属性有何不同。

依然在`Histogram`中选中目标，在右键菜单中选择`List objects -> with outgoing references`，跳转到：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-classloader-instances-in-heap-dump.png)

展开每个实例，检查各实例的`state`情况：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-classloader-state-in-heap-dump.png)

检查后发现，有8个实例的`state`为`DESTROYED`，7个为`STARTED`。这说明，有8个Class Loader实际已经被销毁，只有7个是活跃的。再对前面的`GC Root`列表里的线程所引用的Class Loader进行比对，可以发现有8条线程正好引用的是这8个被销毁的Class Loader，也就是说：
- Tomcat在销毁Class Loader后，因线程无法被终止而使得该线程所引用的Class Loader无法被回收，进而导致该Class Loader所加载的Class也不会被回收，而线程所引用的实例对象也就同样无法被回收，其中，就包含`SessionFactoryImpl`；

这里的几个数字也很值得关注：`8`，`7`，`5`。正常情况下，Tomcat应该创建`5+2`（5个Tomcat自带应用，2个业务应用）个Class Loader，这正好是`7`个活跃态的Class Loader。那么，现在的这`15`个Class Loader都对应了哪些应用呢？

有过以编码方式内嵌`Jetty`等Servlet容器开发经验或者阅读过Tomcat源码的开发者应该知道，Servlet容器一般会有一个`Context`对象用以记录加载的webapp的名字、目录等信息，而Tomcat的该类的实现为[org.apache.catalina.core.StandardContext](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L159)。所以，找到`ParallelWebappClassLoader`关联的`Context`，就可以知道其负责加载的是哪个应用了。

在前面打开的`outgoing references`列表中查找Tomcat内的对象，最终发现`ParallelWebappClassLoader`的`resources#context`正是我们要找的：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-classloader-resources-context-in-heap-dump.png)

挨个检查后发现，7个活跃的Class Loader分别对应着Tomcat所加载的7个应用，但剩下的8个却没有`resources`属性。属性不存在，说明其应该是被置为了`null`，这也进一步验证Class Loader的确是被销毁了，且只能是被Tomcat销毁的。

到这里，事情还没有结束，因为还不知道其他8个Class Loader是哪个（或哪些）应用产生的呢！

试试从加载的jar等资源的路径来判断加载的是哪个应用？

在查遍可能的属性后，最终发现，在`ParallelWebappClassLoader#localRepositories`中便记录了所有加载的jar的URL地址：

![](/assets/images/jvm-dump/tomcat-memory-leak/java-memory-leak-classloader-localrepositories-in-heap-dump.png)

这下才算是圆满了，被销毁的8个Class Loader均对应到应用A的部署位置，也就是说，Tomcat对应用A进行过至少8次**销毁**处理。

被销毁8次？！这两者为何如此「苦大仇深」呢？

前面已经讨论过，销毁必然只能由Tomcat来做，应用内部不应该也没法主动进行销毁，除非有针对性的代码，但应用A中并没有提供这样的机制。

那继续分析Tomcat的源码。

在前面有提到`ParallelWebappClassLoader#state`的值会发生变化，那就找找代码里在哪些地方修改了该状态：

![](/assets/images/jvm-dump/tomcat-memory-leak/tomcat8-destroy-classloader-in-webappclassloader.png)

跟踪接口调用情况，可以发现在`WebappLoader`中实施了销毁动作：

![](/assets/images/jvm-dump/tomcat-memory-leak/tomcat8-destroy-classloader-in-webapploader.png)

最后的最后，发现Tomcat会在Class Loader中检查classpath中**已加载**的资源的变更情况，若发生变化，则将直接**reload**当前应用：

![](/assets/images/jvm-dump/tomcat-memory-leak/tomcat8-check-modified-in-webappclassloader.png)

> **已加载**指通过`ClassLoader#getResourceAsStream`或`ClassLoader#findResource`查找过的资源，在Tomcat中只有通过这两个接口查找到的资源才会被放到`org.apache.catalina.loader.WebappClassLoaderBase#resourceEntries`列表中。

这里记录下接口调用的跟踪路径：
> 查找引用：[org.apache.catalina.loader.WebappClassLoaderBase#destroy](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappClassLoaderBase.java#L1493)
>> 定位到：[org.apache.catalina.loader.WebappLoader#stopInternal](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappLoader.java#L433)
>> 查找引用：`org.apache.catalina.loader.WebappLoader`（注：查找`stopInternal`的引用无法确定其真实调用位置）
>>> 定位到：[org.apache.catalina.core.StandardContext#startInternal](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L4940)
>>> 转到：[org/apache/catalina/core/StandardContext.java:4977](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L4977)
>>>> 查找引用：[org.apache.catalina.core.StandardContext#getLoader](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L1762)
>>>>> 定位到：[org.apache.catalina.core.ContainerBase.ContainerBackgroundProcessor#processChildren](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/ContainerBase.java#L1357)
>>>>> 转到：[org/apache/catalina/core/ContainerBase.java:1372](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/ContainerBase.java#L1372)
>>>>>> 查找实现：[org.apache.catalina.core.StandardContext#backgroundProcess](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L5537)
>>>>>>> 转到：[org/apache/catalina/core/StandardContext.java:5545](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L5545)
>>>>>>>> 查找实现：[org.apache.catalina.loader.WebappLoader#backgroundProcess](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappLoader.java#L287)
>>>>>>>>> 转到：[org/apache/catalina/loader/WebappLoader.java:292](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappLoader.java#L292)
>>>>>>>>>> 查找实现：[org.apache.catalina.core.StandardContext#reload](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L3760)
>>>>>>>>>> 直接定位到：[org.apache.catalina.core.StandardContext#stopInternal](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L5376)
>>>>>>>>>> 转到：[org/apache/catalina/core/StandardContext.java:5447](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/core/StandardContext.java#L5447)
>>>>>>>>>>> 返回到：`org.apache.catalina.loader.WebappLoader#stopInternal`

分析[org.apache.catalina.loader.WebappLoader#backgroundProcess](https://github.com/apache/tomcat/blob/8.5.6/java/org/apache/catalina/loader/WebappLoader.java#L287)的逻辑可以确定webapp重载的两个条件：
- 应用启用了[reloadable](https://tomcat.apache.org/tomcat-5.5-doc/config/context.html#Common_Attributes)；
- `WEB-INF/classes`或`WEB-INF/lib`内的资源发生了变化；

经过前面的全面分析，现在终于可以还原真相了：
- 应用A在部署时，启用了热加载机制（真实情况也的确如此）：
  - 在CI构建中为了控制应用A和应用B的加载顺序，采用了定义`<Context/>`的方式按顺序加载两个应用；
  - 不幸的是，从网上拷贝了别人的配置，因而保留了`reloadable="true"`的设定：`<Context path="/app_a" reloadable="true" docBase="app_a.war" />`；
- 应用A在首次启动时会修改`WEB-INF/classes/config.properties`，而该文件会在`org.springframework.beans.factory.config.PropertyPlaceholderConfigurer`中通过`ClassLoader#getResourceAsStream`读取，从而被放入Tomcat的资源变更观察列表中，成为Tomcat的**已加载资源**；
- 首次启动会使Tomcat触发至少两次重载，从Tomcat的输出日志中可寻找到重载痕迹；
- 在应用A运行后，通过其配置中心也会造成对`WEB-INF/classes/config.properties`的修改，进而导致该应用再次被重载；
- 最后，加上应用A中存在无法结束的线程，使得其引用的对象以及关联的Class Loader无法被回收，从而导致内存消耗随着应用重载次数的增加而不断增加；

![](/assets/images/jvm-dump/tomcat-memory-leak/tomcat-webapp-reloading-log.png)

## 解决方案

对症下药，给出如下解决方案：
- 对应用A禁用热加载，因为：
  - 应用自身加载就很缓慢，无法做到快速重载；
  - 对配置的调整是确保应用重启后配置内容不丢失，而不是为了重新加载配置；
  - 热加载机制应尽量少用，以避免内存泄漏，或其他无法预期的问题；
- **改进并完善线程逻辑**，避免出现死锁，同时，确保应用在销毁前能够结束全部的线程；

为了避免因线程无法终止而造成内存泄漏，使用线程需注意以下事项：
- 非阻塞型异步任务线程，需确保整个逻辑执行过程中没有阻塞、竞争、死循环等阻碍线程结束的情况出现。除此之外，无须其他处理（[#异步任务线程](#异步任务线程)）；
- 非I/O阻塞型守护线程，可按如下过程实现或改进代码（[#非I/O阻塞型守护线程](#非I-O阻塞型守护线程)）：
  - 引入信号变量`interrupted`，并重写`java.lang.Thread#interrupt()`接口，在其中将信号量置为`true`；
  - 在`interrupt()`内继续调用`super.interrupt();`以确保能够打破等待局面（`BlockingQueue`为空的等待，或者，sleep未超时的等待）；
  - 循环条件改为`!this.interrupted`，并在循环内捕获`java.lang.InterruptedException`，以便在发生中断异常后`break`循环；
  - 如果，在中断后仍需处理已有数据，则捕获异常后不`break`循环，而是在`while`条件中增加数据队列是否为空的判断（[#非I/O阻塞型守护线程（数据清理）](#非I-O阻塞型守护线程（数据清理）)），当然，得**确保生产者已不再工作**；
- I/O阻塞型守护线程，同样需重写`java.lang.Thread#interrupt()`接口，并在其中关闭I/O连接，以迫使守护线程因`java.io.IOException`而结束等待，并最终终止循环（[#I/O阻塞型守护线程](#I-O阻塞型守护线程)）；
- 对于在Spring Bean中维护的线程，需实现`org.springframework.beans.factory.InitializingBean`和`org.springframework.beans.factory.DisposableBean`两个接口：
  - 在`InitializingBean#afterPropertiesSet`中创建并启动线程；
  - 在`DisposableBean#destroy`中结束线程以及其他清理工作；
- 非Sping应用可考虑通过`Runtime.getRuntime().addShutdownHook()`注册一个终止其他线程的线程。也可以在应用退出的位置（比如，main结束前，或者在`javax.servlet.ServletContextListener#contextDestroyed`里）自行终止所有线程；
- 结束线程仅可调用接口`java.lang.Thread#interrupt()`，而`java.lang.Thread#stop()`已被官方明确不建议使用，原因是，强行终止线程不能确保资源被有效释放，只能自行做释放工作，也就是前面针对阻塞线程提到的几种结束方式；

> **守护线程**指一直循环运行的线程，一般内部含有`while`循环；
>
> `java.util.concurrent.BlockingQueue#take()`和`java.lang.Thread#sleep(long)`均会阻塞线程，并且只有在等待过程中才能被`interrupt`并抛出中断异常；
>
> 线程内部在接收到中断消息后，会**重置**线程状态，因此，`Thread.currentThread().isInterrupted()`仅在<u>中断刚好发生在没有等待（等待刚好被打破或者还在数据处理过程中）</u>的情况下才会返回`true`，而在发生了中断异常后则为`false`。所以，该接口十分不可靠，建议不要使用；

## 参考

- [Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)
- [停止Java线程，小心interrupt()方法](http://blog.csdn.net/wxwzy738/article/details/8516253)
- [Java Multithreading Steeplechase: Stopping Threads](https://10kloc.wordpress.com/2013/03/03/java-multithreading-steeplechase-stopping-threads/)
- [MemoryLeakProtection](https://wiki.apache.org/tomcat/MemoryLeakProtection)
- [Anatomy of a PermGen Memory Leak](https://cdivilly.wordpress.com/2012/04/23/permgen-memory-leak/)

## 附录

### 异步任务线程

```java
public class AsyncTaskThread extends Thread {

    @Override
    public void run() {
        // NOTE：内部逻辑不能存在死锁、死循环、阻塞等代码
        doOnceTimeTask();
    }
}
```

### 非I/O阻塞型守护线程

```java
public class BlockingDaemonThread extends Thread {
    private volatile boolean interrupted = false;
    private BlockingQueue queue;

    @Override
    public void interrupt() {
        // 标记线程已被中断
        this.interrupted = true;
        // 继续由父类传递中断消息，以确保处于等待中的队列能够结束等待。
        // 队列为空时将一直等待，从而阻塞线程，只能由父类打破该状态。
        super.interrupt();
    }

    @Override
    public void run() {
        // 重置状态，以便复用线程
        this.interrupted = false;

        // 中断消息可能发生在队列刚好结束等待时，此时，线程无法捕获中断异常，因此，需通过信号量的状态判断是否终止循环。
        // 这里不使用Thread.currentThread().isInterrupted()，因为，这里希望在需要时能够重启该中断线程。
        while (!this.interrupted) {
            try {
                Object data = queue.take();
                processData(data);
            } catch (InterruptedException e) {
                // 接收到中断消息，结束循环。
                // NOTE：此时，线程的中断状态已被重置！！
                break;
            }
        }
    }
}
```

### 非I/O阻塞型守护线程（数据清理）

```java
public class CleanBlockingDaemonThread extends Thread {
    private volatile boolean interrupted;
    private BlockingQueue queue;

    @Override
    public void interrupt() {
        // 标记线程已被中断
        this.interrupted = true;
        // 继续由父类传递中断消息，以确保处于等待中的队列能够结束等待。
        // 队列为空时将一直等待，从而阻塞线程，只能由父类打破该状态。
        super.interrupt();
    }

    @Override
    public void run() {
        // 重置状态
        this.interrupted = false;

        // 在接收到中断后，一直处理，直到队列为空。
        // 如果没有中断，那就只能等待新的数据到来，或者，收到父类的中断消息
        while (!this.interrupted || !queue.isEmpty()) {
            try {
                Object data = queue.take();
                processData(data);
            } catch (InterruptedException e) {
                // NOTE：此时，线程的中断状态已被重置！！
            }
        }
    }
}
```

### I/O阻塞型守护线程

```java
public class IOBlockingDaemonThread extends Thread {
    private volatile boolean interrupted;
    private volatile ServerSocket server;

    @Override
    public void interrupt() {
        this.interrupted = true;
        this.server.close();
    }

    @Override
    public void run() {
        this.interrupted = false;
        this.server = new ServerSocket(9680);

        // 由于该线程内没有能接收中断消息的对象，中断异常永远不会发生，只能通过IO关闭异常终止循环。
        // 这里为了确保万无一失，依然使用了中断消息变量。
        while (!this.interrupted) {
            try {
                Socket socket = server.accept();
                processSocket(socket);
            } catch (IOException e) {
                // 终止循环，退出线程
                // NOTE：这里的线程状态不会变化！！
                break;
            }
        }
    }
}
```
