---
layout: post
title: JVM内存分析：线程死锁
date: 2019-10-07 22:50:34
tags:
  - 线程死锁
categories:
  - JVM内存分析
---

## 提要

线程转储可用于分析Java应用在某一运行时刻的内部线程的运行情况，包括线程数、线程状态（死锁、运行、等待等），并且可得到线程的执行轨迹，对于分析线程死锁十分有益。

通过JDK内置的工具`jstack`可转储Java线程：`sudo -u tomcat jstack -l <java_pid> > jstack.dump`，注意，`<java_pid>`为主进程ID，无法dump某个线程。

> 获取Java线程ID：`ps aux | grep java`；
> 需确保转储用户与线程用户相同，否则，易出现[Unable to open socket file: target process not responding or HotSpot VM not loaded](https://stackoverflow.com/questions/26140182/running-jmap-getting-unable-to-open-socket-file#answer-35963059)的问题；
> 当出现死锁时，dump操作可能失败，可以通过`kill -3 <java_pid>`终止死锁（其不会杀死进程或线程！）；

得到转储文件后，可将其上传到[fastThread](http://fastthread.io/index.jsp)进行在线分析，该服务可提供直观的分析图表和相关报告。

也可以下载IBM提供的工具[IBM Thread and Monitor Dump Analyze](ftp://public.dhe.ibm.com/software/websphere/appserv/support/tools/jca/jca447.jar)，其同样提供图表分析功能，但整体上没有fastThread的直观。其启动命令为：`java -jar jca447.jar`。
<!-- more -->

## 案例分析

以下为某次测试环境出现线程死锁后通过fastThread得到的分析报告内容：

<p>
<b><font color="#cc3300">pool-297-thread-25</font></b> is in deadlock with <b><font color="#cc3300">http-nio-8080-exec-548</font></b>
<br>
<b><font color="#003300">pool-297-thread-25</font></b> - priority:5 - threadId:0x00007fdf2784f800 - nativeId:0x1474 - state:<b><font color="#cc3300">BLOCKED</font></b><br>
stackTrace:<br>
java.lang.Thread.State: BLOCKED (on object monitor)<br>
at com.mysql.jdbc.ResultSetImpl.fastTimestampCreate(<font color="#000080">ResultSetImpl.java:1062</font>)<br>
<font color="#cc3300">
- waiting to lock <b>&lt;0x000000070618c2c0&gt;</b> (a com.mysql.jdbc.JDBC4Connection)<br>
at com.mysql.jdbc.ResultSetRow.getTimestampFast(<font color="#000080">ResultSetRow.java:1393</font>)<br>
- locked <b>&lt;0x00000007061996b8&gt;</b> (a java.util.GregorianCalendar)<br>
</font>
at com.mysql.jdbc.BufferRow.getTimestampFast(<font color="#000080">BufferRow.java:576</font>)<br>
at com.mysql.jdbc.ResultSetImpl.getTimestampInternal(<font color="#000080">ResultSetImpl.java:6588</font>)<br>
at com.mysql.jdbc.ResultSetImpl.getTimestamp(<font color="#000080">ResultSetImpl.java:6188</font>)<br>
at com.mysql.jdbc.ResultSetImpl.getTimestamp(<font color="#000080">ResultSetImpl.java:6226</font>)<br>
at org.apache.commons.dbcp.DelegatingResultSet.getTimestamp(<font color="#000080">DelegatingResultSet.java:300</font>)<br>
at org.apache.commons.dbcp.DelegatingResultSet.getTimestamp(<font color="#000080">DelegatingResultSet.java:300</font>)<br>
at org.apache.commons.dbcp.DelegatingResultSet.getTimestamp(<font color="#000080">DelegatingResultSet.java:300</font>)<br>
at org.hibernate.type.descriptor.sql.TimestampTypeDescriptor$2.doExtract(<font color="#000080">TimestampTypeDescriptor.java:67</font>)<br>
at ...<br>
at org.hibernate.loader.Loader.loadFromResultSet(<font color="#000080">Loader.java:1673</font>)<br>
at ...<br>
at org.hibernate.internal.SessionImpl.fireLoad(<font color="#000080">SessionImpl.java:1098</font>)<br>
at org.hibernate.internal.SessionImpl.immediateLoad(<font color="#000080">SessionImpl.java:1013</font>)<br>
at org.hibernate.proxy.AbstractLazyInitializer.initialize(<font color="#000080">AbstractLazyInitializer.java:173</font>)<br>
at <font color="#ff0000">org.hibernate.proxy.AbstractLazyInitializer</font>.getImplementation(<font color="#000080">AbstractLazyInitializer.java:285</font>)<br>
at org.hibernate.proxy.pojo.javassist.JavassistLazyInitializer.invoke(<font color="#000080">JavassistLazyInitializer.java:185</font>)<br>
at com.xx.zz.model.User_$$_jvst8ac_ac.equals(<font color="#000080">User_$$_jvst8ac_ac.java</font>)<br>
at java.util.Vector.indexOf(<font color="#000080">Vector.java:408</font>)<br>
- locked <b>&lt;0x000000070624bc10&gt;</b> (a java.util.Stack)<br>
at java.util.Vector.contains(<font color="#000080">Vector.java:367</font>)<br>
at com.xx.zz.json.JSONWriter.value(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONWriter.appendProp(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONWriter.bean(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONWriter.doValue(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONWriter.value(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONWriter.write(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.json.JSONUtil.serialize(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.slm.OlaEngine.getJsonObejct(<font color="#000080">OlaEngine.java:191</font>)<br>
at com.xx.zz.slm.OlaEngine.startMonitor(<font color="#000080">OlaEngine.java:61</font>)<br>
at <font color="#ff0000">com.xx.zz.slm.manager.XxxThreadPoolManager$1.run</font>(<font color="#000080">XxxThreadPoolManager.java:68</font>)<br>
- locked <b>&lt;0x000000070624bcb0&gt;</b> (a com.xx.zz.slm.manager.XxxThreadPoolManager$1)<br>
at java.util.concurrent.ThreadPoolExecutor.runWorker(<font color="#000080">ThreadPoolExecutor.java:1142</font>)<br>
at java.util.concurrent.ThreadPoolExecutor$Worker.run(<font color="#000080">ThreadPoolExecutor.java:617</font>)<br>
at java.lang.Thread.run(<font color="#000080">Thread.java:745</font>)<br>
Locked ownable synchronizers:<br>
- <b>&lt;0x0000000706073548&gt;</b> (a java.util.concurrent.ThreadPoolExecutor$Worker)<br>
<br>
<b><font color="#003300">http-nio-8080-exec-548</font></b> - priority:5 - threadId:0x00007fe02c00c000 - nativeId:0x146e - state:<b><font color="#cc3300">BLOCKED</font></b><br>
stackTrace:<br>
java.lang.Thread.State: BLOCKED (on object monitor)<br>
at com.mysql.jdbc.PreparedStatement.setTimestampInternal(<font color="#000080">PreparedStatement.java:4819</font>)<br>
<font color="#cc3300">
- waiting to lock <b>&lt;0x00000007061996b8&gt;</b> (a java.util.GregorianCalendar)<br>
- locked <b>&lt;0x000000070618c2c0&gt;</b> (a com.mysql.jdbc.JDBC4Connection)<br>
</font>
at com.mysql.jdbc.PreparedStatement.setTimestamp(<font color="#000080">PreparedStatement.java:4786</font>)<br>
at org.apache.commons.dbcp.DelegatingPreparedStatement.setTimestamp(<font color="#000080">DelegatingPreparedStatement.java:147</font>)<br>
at org.apache.commons.dbcp.DelegatingPreparedStatement.setTimestamp(<font color="#000080">DelegatingPreparedStatement.java:147</font>)<br>
at org.apache.commons.dbcp.DelegatingPreparedStatement.setTimestamp(<font color="#000080">DelegatingPreparedStatement.java:147</font>)<br>
at org.hibernate.type.descriptor.sql.TimestampTypeDescriptor$1.doBind(<font color="#000080">TimestampTypeDescriptor.java:58</font>)<br>
at ...<br>
at org.hibernate.persister.entity.AbstractEntityPersister.update(<font color="#000080">AbstractEntityPersister.java:3205</font>)<br>
at ...<br>
at org.hibernate.event.internal.DefaultFlushEventListener.onFlush(<font color="#000080">DefaultFlushEventListener.java:52</font>)<br>
at <font color="#ff0000">org.hibernate.internal.SessionImpl</font>.flush(<font color="#000080">SessionImpl.java:1240</font>)<br>
at <font color="#ff0000">com.xx.zz.StartProcessInstanceListener</font>.onEvent(<font color="#000080">StartProcessInstanceListener.java:114</font>)<br>
at ...<br>
at com.xx.zz.activiti.cmd.SuperCompleteTaskCmd.execute(<font color="#000080">SuperCompleteTaskCmd.java:68</font>)<br>
at ...<br>
at com.xx.zz.activiti.BaseActivitiTaskService.completeTask(<font color="#000080">BaseActivitiTaskService.java:82</font>)<br>
at com.xx.zz.BusinessProcessServiceImpl.completeTask(<font color="#000080">BusinessProcessServiceImpl.java:313</font>)<br>
at ...<br>
at com.sun.proxy.$Proxy1859.completeTask(<font color="#000080">Unknown Source</font>)<br>
at com.xx.zz.BaseController.completeTask(<font color="#000080">BaseController.java:216</font>)<br>
at <font color="#ff0000">com.xx.zz.CompleteTask.execute</font>(<font color="#000080">CompleteTask.java:57</font>)<br>
at ...<br>
at org.apache.coyote.AbstractProtocol$ConnectionHandler.process(<font color="#000080">AbstractProtocol.java:802</font>)<br>
at org.apache.tomcat.util.net.NioEndpoint$SocketProcessor.doRun(<font color="#000080">NioEndpoint.java:1410</font>)<br>
at org.apache.tomcat.util.net.SocketProcessorBase.run(<font color="#000080">SocketProcessorBase.java:49</font>)<br>
- locked <b>&lt;0x000000070624fcb0&gt;</b> (a org.apache.tomcat.util.net.NioEndpoint$NioSocketWrapper)<br>
at java.util.concurrent.ThreadPoolExecutor.runWorker(<font color="#000080">ThreadPoolExecutor.java:1142</font>)<br>
at java.util.concurrent.ThreadPoolExecutor$Worker.run(<font color="#000080">ThreadPoolExecutor.java:617</font>)<br>
at org.apache.tomcat.util.threads.TaskThread$WrappingRunnable.run(<font color="#000080">TaskThread.java:61</font>)<br>
at java.lang.Thread.run(<font color="#000080">Thread.java:745</font>)<br>
Locked ownable synchronizers:<br>
- <b>&lt;0x0000000705c194b0&gt;</b> (a java.util.concurrent.ThreadPoolExecutor$Worker)<br>
</p>

报告第一行即说明了`pool-297-thread-25`与`http-nio-8080-exec-548`两个线程出现了竞争死锁，前者已经锁住`<0x00000007061996b8> (a java.util.GregorianCalendar)`并正在尝试锁住`<0x000000070618c2c0> (a com.mysql.jdbc.JDBC4Connection)`，而后者已经锁住相同（内存地址相同）的JDBC Connection，并试图对`<0x00000007061996b8> (a java.util.GregorianCalendar)`加锁，因此，两者持锁等待，结果出现了死锁！

下面来分析一下两个线程在何时因为什么而发生了死锁。

线程`pool-297-thread-25`正在对某个BO（业务模型）做与监控相关的处理，并使用`JSONWriter`序列化该BO，由于Hibernate的懒加载特性，`AbstractLazyInitializer`还需要从数据库中获取级联对象的数据，并最终在获取JDBC时间戳时出现了资源竞争。

而线程`http-nio-8080-exec-548`是一个HTTP请求/响应线程，其负责处理流程任务的完成操作，其在尝试更新JDBC时间戳时先于前一个线程对JDBC Connection加锁成功，却未能锁住`GregorianCalendar`。

根据Hibernate的特性以及懒加载所带来的副作用不受重视的现实进行分析，可以大致还原出整个处理过程：
- 用户点击了任务完成按钮，应用也已经完成了对该任务的处理，并正在创建下一个任务实例；
- OLA（运营级别协议）的逻辑需要监听流程任务的创建事件，以便于及时得到相关的BO信息并做相关业务处理；
- 流程任务创建事件触发后，OLA先在任务创建的Listener中获取到BO对象，再将该BO对象放到OLA监控器中；
- OLA监控器会启动新的线程（由线程池分配和调度），并在线程中序列化该BO对象，进而做存储或其他事情；
- 这里存在两个线程：任务创建线程（`http-nio-8080-exec-548`）和OLA监控线程（`pool-297-thread-25`）；
- 而由于懒加载的缘故，BO的级联对象将继续持有查询时所使用的Session实例，而该Session在HTTP请求线程中将被独占使用，相应的JDBC Connection也是被独占的；
- 因此，JDBC Connection的共享导致了死锁；

## 解决方案

针对上述问题，根本的解决方案就是：
- 流程任务创建时，仅将与BO相关的id和类型传递给OLA监控器；
- OLA监控器在所创建的线程内独自创建Hibernate Session（注意用后释放），再根据BO的id和类型查询所需信息；

因此，需牢记接口数据的交互原则：
- 拒绝共享；
- 仅交换Plain数据（非对象、非结构），即核心基础数据，其他业务数据通过基础数据获取；
