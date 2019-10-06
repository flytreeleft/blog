---
layout: post
title: 数据库连接池耗尽
date: 2019-10-05 20:40:57
tags:
  - 连接池耗尽
  - Connection pool exhausted
categories:
  - JVM内存分析
---

## 提要

由于数据库连接十分耗时，采取**即需即连**的方式会导致应用响应缓慢，因此，在Java应用中均采用**数据库连接池**统一维护一定数量的`Connection`对象，连接池中的`Connection`均保持与数据库的长连接，这样，该连接将随时可用，从而提高应用响应和处理速度。

但是，在普遍的使用不当的情形中，最多的问题便是没有及时`释放连接`，这里的释放是指将`Connection`对象归还连接池。若连接未被释放，则连接池将被很快耗尽（Exhausted），从而无法提供新的连接，最终导致应用不能进行数据库操作，并在尝试获取新的连接时出现以下异常：
```java
...
Caused by: org.hibernate.exception.GenericJDBCException: Could not open connection
    at org.hibernate.exception.internal.StandardSQLExceptionConverter.convert(StandardSQLExceptionConverter.java:54)
    at org.hibernate.engine.jdbc.spi.SqlExceptionHelper.convert(SqlExceptionHelper.java:125)
    at org.hibernate.engine.jdbc.spi.SqlExceptionHelper.convert(SqlExceptionHelper.java:110)
    at org.hibernate.engine.jdbc.internal.LogicalConnectionImpl.obtainConnection(LogicalConnectionImpl.java:221)
    at org.hibernate.engine.jdbc.internal.LogicalConnectionImpl.getConnection(LogicalConnectionImpl.java:157)
    at org.hibernate.internal.SessionImpl.connection(SessionImpl.java:550)
    at org.springframework.orm.hibernate4.HibernateTransactionManager.doBegin(HibernateTransactionManager.java:426)
    ... 9 more
Caused by: org.apache.commons.dbcp.SQLNestedException: Cannot get a connection, pool error Timeout waiting for idle object
    at org.apache.commons.dbcp.PoolingDataSource.getConnection(PoolingDataSource.java:114)
    at org.apache.commons.dbcp.BasicDataSource.getConnection(BasicDataSource.java:1044)
    at org.hibernate.service.jdbc.connections.internal.DatasourceConnectionProviderImpl.getConnection(DatasourceConnectionProviderImpl.java:141)
    at org.hibernate.internal.AbstractSessionImpl$NonContextualJdbcConnectionAccess.obtainConnection(AbstractSessionImpl.java:292)
    at org.hibernate.engine.jdbc.internal.LogicalConnectionImpl.obtainConnection(LogicalConnectionImpl.java:214)
    ... 12 more
Caused by: java.util.NoSuchElementException: Timeout waiting for idle object
    at org.apache.commons.pool.impl.GenericObjectPool.borrowObject(GenericObjectPool.java:1174)
    at org.apache.commons.dbcp.PoolingDataSource.getConnection(PoolingDataSource.java:106)
    ... 16 more
```
<!-- more -->

## 案例分析

> 有关JVM内存转储方式的说明见[JVM内存分析：Tomcat内存泄漏](/the-jvm-dump-analyse-for-tomcat-memory-leak/)。

在本案例应用（约定称为「应用A」）的使用过程中偶尔会在前端弹出`Timeout waiting for idle object`的异常提示框。经过查看完整的异常堆栈（看上面）可发现，异常发生在从连接池获取`Connection`时，在对[GenericObjectPool](https://github.com/apache/commons-pool/blob/POOL_1_6/src/java/org/apache/commons/pool/impl/GenericObjectPool.java#L1174)源码分析后可初步确定是因为连接池已满而无法分配新的`Connection`造成的。

为进一步确认该问题，将应用A的内存转储（`sudo -u tomcat jmap -dump:format=b,file=heap-dump.bin <java_pid>`）并通过[Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)对其内存进行分析。

点击工具栏中的`OQL`图标，这里需要通过[OQL](https://www.ibm.com/developerworks/library/j-memoryanalyzer/#N103C9)进行一些复杂的过滤查询（OQL：`SELECT OBJECTS ds FROM org.apache.commons.dbcp.BasicDataSource ds`）：

![](/assets/images/jvm-dump/connection-pool-exhausted/java-memory-leak-oql-instanceof-basicdatasource-in-heap-dump.png)

> - OQL的语法可从MAT的`Help -> Help Contents`菜单中进入帮助手册查询到；
> - `org.apache.commons.dbcp.BasicDataSource`为应用中使用的`DataSource`的实现类，其内部引用`org.apache.commons.dbcp.PoolingDataSource`，并在`PoolingDataSource`中负责从连接池申请新的连接；

从图中可以看到，连接池`org.apache.commons.pool.impl.GenericObjectPool`的`_numActive`为<span style="color: red;">749</span>，而在应用中为其分配的最大活跃连接数（`maxActive`）为`750`。因此，可以进一步确定连接池的确已达到分配上限，在并发情况下将不会再分配更多连接，从而导致等待超时并抛出异常。

再看看内存中是否存在未被释放的MySQL连接。

由于MAT默认不分析`unreachable`对象，所以，在开始前需通过其自带的工具`ParseHeapDump.sh`（或`ParseHeapDump.bat`）[分析不可达对象](https://wiki.eclipse.org/MemoryAnalyzer/FAQ#How_to_analyse_unreachable_objects)：

```bash
# 运行该命令前需删除dump文件所在目录中由MAT生成的分析文件
$ ParseHeapDump.sh -keep_unreachable_objects heap-dump.bin
```

点击MAT的菜单`File -> Open Heap Dump`选择文件`heap-dump.bin`载入转储分析文件，然后，通过OQL（`SELECT cn, cn.isClosed, cn.io.mysqlConnection, cn.io.mysqlConnection.closed FROM INSTANCEOF com.mysql.jdbc.JDBC4Connection cn`）得到MySQL Connection对象如下：

![](/assets/images/jvm-dump/connection-pool-exhausted/java-memory-leak-oql-instanceof-mysql-connection-in-heap-dump.png)

> 点击工具栏中的分组图标可按照Class Loader对结果进行分组；
> 在MySQL驱动中的`Connection`所引用的相关对象为：
> - com.mysql.jdbc.JDBC4Connection#io:com.mysql.jdbc.MysqlIO
> - com.mysql.jdbc.MysqlIO#mysqlConnection:java.net.Socket
> - java.net.Socket#closed:boolean

可以发现，在36个连接中仅有2个是正常关闭的，其余的`Connection`未被关闭，但对应的`Socket`连接却处于关闭状态。这里可以假设出以下两种可能的情形：
- `Connection`在**使用时**出现网络中断，导致`Socket`非正常关闭；
- `Connection`在**使用后**未被正常关闭，并且在某个时刻发生了`Socket`连接中断；

对于第一种情形，`Socket`的异常关闭势必会抛出异常，并最终在使用方拦截到该异常并关闭`Connection`，而这里的`Connection`为非关闭状态，说明使用方并未准确做资源的释放处理。第二种情形，自然也是因为资源未被及时释放了。

因此，`Connection`没有被及时、准确地释放是相当肯定的事情了。

但这里依然有个疑问，为啥连接池里记录分配的连接为`749`，而实际查到的`Connection`对象只有30多个，其余的哪儿去了？

针对上述问题，限于基本功的问题，目前还没有确切的定论，但大致可推断是MySQL驱动中的`com.mysql.jdbc.AbandonedConnectionCleanupThread`对弱引用的`com.mysql.jdbc.JDBC4Connection`对象做了资源`主动回收`处理：

![](/assets/images/jvm-dump/connection-pool-exhausted/mysql-source-abandoned-connection-cleanup.png)

`com.mysql.jdbc.NonRegisteringDriver.ConnectionPhantomReference`为虚引用类`java.lang.ref.PhantomReference`的扩展类，其将在`java.lang.ref.Reference.ReferenceHandler#run`中等待JVM启动GC时进行清理活动。

> Java引用相关的知识可阅读[详解java.lang.ref包中的4种引用](https://benjaminwhx.com/2018/05/19/%E5%A4%A7%E8%AF%9DJava%E4%B8%AD%E7%9A%844%E7%A7%8D%E5%BC%95%E7%94%A8%E7%B1%BB%E5%9E%8B/)。

既然得到了看似很有道理的分析结论，那就应该有方法复现当前的问题。

首先，通过IDE工具查找应用中主动获取`Connection`对象而未释放的代码位置，最终找出以下几处：
- xx/xx/xx/XxQueryImpl.java @r74605: L357, L1607
- ...

经过调用分析后，可找到以下几个相关的Web API以用于复现验证：
- /a/xx/queryXx.mvc
- /a/xx/countXx.mvc
- ...

需要注意的是，一般MySQL服务端会限定并发连接数，为了快速复现当前问题，可通过以下语句调整MySQL的默认最大连接数（重启后将失效）：

```sql
-- 查看默认配置： show variables like '%connect%';
SET GLOBAL max_connections = 850;
```

在登录应用A后，在浏览器控制台中执行以下代码便可复现最开始提到的异常问题：

```js
var ctx = '/a';
var urls = [
    ctx + '/xx/queryXx.mvc',
    ctx + '/xx/countXx.mvc'
];
var waitTime = 0.1 * 1000;

function doRequest(urls, index) {
    if (!urls || urls.length === 0) return;

    var i = index || 0;
    var url = urls[0];
    $.ajax({url: url, success: function () {
        console.log(i, url, arguments);
        setTimeout(function() {
            doRequest(urls.slice(1), i + 1);
        }, waitTime);
    }});
}

var requestCount = 800;
var requestURLs = [];
for (var i = 0; i < requestCount / urls.length; i++) {
    requestURLs = requestURLs.concat(urls);
}
doRequest(requestURLs);
```

![](/assets/images/jvm-dump/connection-pool-exhausted/app-a-reproduct-timeout-wait-for-idle-object.png)

## 解决方案

找到了根本原因，解决方案就很简单了：
- 在`try {...} finally {...}`语句的`finally`块中关闭**主动获取**的`Connection`对象。

而本案例中的业务需求似乎比较特殊，具体方案需根据实际业务需求确定，但必须坚持以下原则：
- 在`finally`块中释放主动获取的`Connection`对象；
- 数据库类型无关：尽可能避免在代码中根据数据库类型做条件判断，首选[HQL](http://docs.jboss.org/hibernate/core/3.5/reference/en-US/html_single/#queryhql)所支持的<u>数据库无关</u>的查询语句和表达式

## 参考

- [Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)
- [Querying Java heap with OQL](https://blogs.oracle.com/sundararajan/querying-java-heap-with-oql)
- [OQL](https://www.ibm.com/developerworks/library/j-memoryanalyzer/#N103C9)
