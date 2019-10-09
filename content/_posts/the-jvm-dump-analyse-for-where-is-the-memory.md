---
layout: post
title: JVM内存分析：内存都去哪儿了
date: 2019-10-05 21:41:47
tags:
  - 内存溢出
categories:
  - JVM内存分析
---

## 提要

在开始分析之前先了解一下下面几个相关术语：
- **Shallow Heap**：对象自身占用的内存大小（包含基本数据类型），不包括它引用对象的大小；
- **Retained Heap**：**Shallow Heap** + 所有直接或者间接引用对象占用的内存（即该对象被GC回收后，可以被回收的内存）；
- **GC Root**：被堆外对象引用的对象；
- **Dominator Tree**：以支配树方式描述的对象引用关系；

> 有关JVM内存转储方式的说明见[JVM内存分析：Tomcat内存泄漏](/the-jvm-dump-analyse-for-tomcat-memory-leak/)。

## 案例分析

最近服务器的内存又在狂飙了，网关响应缓慢，Jenkins完成构建需要长达2个多小时。到底疯狂到什么程度呢？用`htop`命令看看：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-high-memory-usage-analysis-via-htop.png)
<!-- more -->

不仅64G内存几乎耗尽，还占用了大量的交换分区空间（也就是虚拟内存），实在异常恐怖！

再查看哪些进程耗用内存较多，结果发现都是Docker容器内的应用进程消耗最多。那使用命令`docker stats --format "table {% raw %}{{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}{% endraw %}"`看看各个容器的内存使用情况：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-high-memory-usage-of-docker-apps.png)

从使用情况来看，有多个应用容器的内存使用量在5GB以上，而且部分应用实际上并没有什么耗内存的地方，却也占用了5GB，实在是不可理喻。

没有办法了，只能dump出应用的堆内存，再详细分析内存都消耗在哪些对象上了。

在容器内运行命令`sudo -u tomcat jmap -dump:format=b,file=heap-dump.bin <java_pid>`将Tomcat进程的堆内存转储至`heap-dump.bin`中。

转储完成后，通过[Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)自带的工具`ParseHeapDump.sh`分析堆内存（也同时分析其中的`unreachable`对象以得到对象内部数据）：`ParseHeapDump.sh -keep_unreachable_objects heap-dump.bin`。

最后，启动MAT并点击菜单`File -> Open Heap Dump`选择文件`heap-dump.bin`，得到如下结果：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-heap-dump-overview-in-mat.png)

结果很出乎意料：`int[]`数组居然占用了数十兆内存，总计占了1/4！

接着看看直方图（`Histogram`），注意需将结果按`Shallow Heap`降序排序：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-heap-dump-histogram-in-mat.png)

这更是惊人：`int[]`数据总共为`505,211,152`字节，也就是`481MB`！

惊讶继续！

右键点击`int[]`并选择`List objects -> with incoming references`（PS：同样按`Shallow Heap`降序排序）：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-heap-dump-incoming-references-of-int-in-mat.png)

从`incoming references`中可以发现以下问题：
- 几乎所有的`int[]`都是`unreachable`的；
- 靠前的`int[]`长度都达到数十万，甚至百万、千万；

那么，问题来了：
- 谁创建了这么多且这么大的数组，又为何创建？
- 数组里存的是什么数据，干什么用的？

第一个问题没有可解答的线索，因为查不到引用这些数组的对象。不过从第二个问题中应该能找寻到一些蛛丝马迹。

在`incoming references`中右键点击第一条并选择`Copy -> Save Value To File`，将数组内的数据保存到文件`int-bytes.bin`中。

因为得到的文件为二进制的，故需使用工具[hexedit](https://linux.die.net/man/1/hexedit)查看其内容（PS：也可用其他二进制查看工具）。

打开文件后向下翻页直至右侧出现有大量连续可识别的字符为止：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-binary-view-to-chars-in-hexedit.png)

截取其中的一段内容：

```
002CEEA8   00 00 00 00  00 00 00 00  00 00 00 01  00 00 00 00  F8 00 00 ED  00 00 00 3A  41 54 45 4D  46 4E 49 2D  72 65 73 2F  65 63 69 76  .......................:ATEMFNI-res/eciv
002CEED0   61 6A 2F 73  2E 78 61 76  2E 6C 6D 78  73 72 61 70  2E 73 72 65  75 63 6F 44  74 6E 65 6D  6C 69 75 42  46 72 65 64  6F 74 63 61  aj/s.xav.lmxsrap.sreucoDtnemliuBFredotca
002CEEF8   00 00 79 72  00 00 00 00  00 00 00 01  00 00 00 00  F8 00 00 3F  00 00 00 3A  00 45 00 4D  00 41 00 54  00 49 00 2D  00 46 00 4E  ..yr...............?...:.E.M.A.T.I.-.F.N
002CEF20   00 73 00 2F  00 72 00 65  00 69 00 76  00 65 00 63  00 2F 00 73  00 61 00 6A  00 61 00 76  00 2E 00 78  00 6D 00 78  00 2E 00 6C  .s./.r.e.i.v.e.c./.s.a.j.a.v...x.m.x...l
002CEF48   00 61 00 70  00 73 00 72  00 72 00 65  00 2E 00 73  00 6F 00 44  00 75 00 63  00 65 00 6D  00 74 00 6E  00 75 00 42  00 6C 00 69  .a.p.s.r.r.e...s.o.D.u.c.e.m.t.n.u.B.l.i
002CEF70   00 65 00 64  00 46 00 72  00 63 00 61  00 6F 00 74  00 79 00 72  00 00 00 00  00 00 00 01  00 00 00 00  F8 00 00 ED  00 00 00 AE  .e.d.F.r.c.a.o.t.y.r....................
002CEF98   41 54 45 4D  46 4E 49 2D  72 65 73 2F  65 63 69 76  61 6A 2F 73  2E 78 61 76  2E 6C 6D 78  73 72 61 70  2E 73 72 65  75 63 6F 44  ATEMFNI-res/ecivaj/s.xav.lmxsrap.sreucoD
002CEFC0   74 6E 65 6D  6C 69 75 42  46 72 65 64  6F 74 63 61  00 00 79 72  00 00 00 00  00 00 00 00  00 00 00 00  00 00 00 00  00 00 00 00  tnemliuBFredotca..yr....................
```

这里会发现一个问题：这些字符看起来很有规律，感觉很熟悉但却又很陌生。

不过仔细辨别还是可以发现：每四个相邻字符反序再组合也就能够还原出正确的字符串。比如，截图中便可识别出一串字符：`META-INF/services/javax.xml.parsers.DocumentBuilderFactory`。

为什么转存的二进制文件会出现字符串反序呢？其实，这便是著名的[大小端](http://www.ruanyifeng.com/blog/2016/11/byte-order.html)字节序。而该文件正好为**小端字节序**（低位字节在前，高位字节在后），和人类的读写顺序（大端字节序）正好相反。

有点「反人类」了。

为了确保能正常识别`int[]`中存储的内容，我们需要将小端字节序转换为大端字节序。

不幸的是，没能找到直接可用的大小端转换工具，于是拿起遗忘已久的**C语言**编写以下一段代码来进行转换：

```c
#include <stdint.h>
#include <stdio.h>

// https://stackoverflow.com/questions/2182002/convert-big-endian-to-little-endian-in-c-without-using-provided-func#answer-2637138
uint32_t swap_uint32( uint32_t val ) {
    val = ((val << 8) & 0xFF00FF00 ) | ((val >> 8) & 0xFF00FF );
    return (val << 16) | (val >> 16);
}

int main (int argc, char *argv[]) {
    char *in = argv[1];
    char *out = argv[2];

    FILE *file_in = fopen(in, "r");
    FILE *file_out = fopen(out, "w");
    if (file_in == NULL) {
        fprintf(stderr, "File '%s' not found!\n", in);
        return -1;
    }
    fprintf(stdout, "Reading from '%s'\n", in);

    uint32_t value;
    while (fread(&value, sizeof(value), 1, file_in) == 1) {
        uint32_t new_value = swap_uint32(value);

        if (fwrite(&new_value, sizeof(new_value), 1, file_out) != 1) {
            fprintf(stderr, "Failed to write to file '%s'!\n", out);
            break;
        }
    }
    fprintf(stdout, "[DONE] Write to '%s'\n", out);

    fclose(file_out);
    fclose(file_in);
    return 0;
}
```

使用**GCC**编译（`gcc -o swap-endian main.c`）并运行`swap-endian`以转换大小端：`./swap-endian ./int-bytes.bin ./int-bytes.bin.swap`。

然后，再用`hexedit`打开`int-bytes.bin.swap`并按组合键`Ctrl+G`跳转到刚才查看的位置。这下字符顺序终于正常了：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-binary-view-to-normal-chars-in-hexedit.png)

反序问题解决了，接下来就来擦亮眼睛去发现`int[]`中都有些什么吧。

最后从该数组中发现其包含了以下一些字符串：
- `jar:file:/xxx/xxx/xxx.jar`
- `META-INF/services/xxx.xxx.XxxXX`
- `/usr/lib/jvm/java-8-openjdk-amd64/jre/lib/xerces.properties`
- `com/sun/org/apache/xpath/internal/jaxp/XPathFactoryImpl.class`
- `org/activiti/db/mapping/entity/Task.xml`（及其内容）、`org.activiti.engine.impl.TablePageMap.class`
- `jar:file:/xxx/xxx/WEB-INF/lib/xercesImpl-2.6.2.jar!/META-INF/services/javax.xml.parsers.DocumentBuilderFactory`

有什么发现没？反正我是感觉这可能是`ClassLoader`的内容或者与此相关的某些东西。而且这些也不是业务对象数据，基本都是`*.class`、`*.java`以及<u>`jar`中的资源文件</u>的名称和内容，那这就和应用本身没啥关系了，问题出在JVM层面的可能性更大。

如果是这样，那为何会出现这样的问题呢？

我也是茫然无知，多番假设和验证后也没有结果，最后，只得Google了一下关键字`java big int array unreachable`，并从[Java String objects not getting garbage collected on time](https://stackoverflow.com/questions/11772512/java-string-objects-not-getting-garbage-collected-on-time)中找到了些线索：
- `This means the VM will eat memory until it hits the maximum and then, it will do one huge GC run`：即，<u>Java GC的开销很大（`evil`），因此其会尽可能多地使用内存直到超过最大限定值，非万不得已不会主动GC</u>
- `Unless you see OutOfMemoryException, you don't have a leak`：即，<u>如果没有抛出`OutOfMemoryException`异常，那么就不会是内存泄漏，那怕是内存被全部耗尽</u>
- `However when we inspect these char[], Strings we find that they do not have GC roots which means that they shouldn't be the cause of leak. Since they are a part of heap, it means they are waiting to get garbage collected`：即，<u>`Unreachable`对象不会引发内存泄漏，其属于堆内数据，正等待被垃圾回收</u>

联系实际情况：在Docker镜像构建配置中，Tomcat的启动脚本并未设置JVM的堆大小，而且从长时间的观察来看，容器的内存消耗会随时间逐步增长，并且在多次数据查询后内存使用也是会直线增长。再结合以上线索，便可初步确定这是JVM没有GC造成的。

按照以上思路，为Tomcat启动脚本设置JVM堆内存的最大值和初始值，再重启并运行一段时候后发现容器的内存使用情况趋于正常，静默下的内存消耗降至百兆，有数据查询时内存使用会上升到1GB左右，并在没有数据查询时出现回落：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-goto-normal-memory-usage-of-docker-apps.png)

内存使用也回归正常：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-normal-memory-usage-analysis-via-htop.png)

看来问题还真就是出在JVM的GC机制上，悬了长久的问题终于得到解决。

这里不禁要感叹：

<span style="font-size: 2em; color: red">原来你是这样的Java！！</span>

## 解决方案

对症下药，调整Docker镜像的`entrypoint`脚本为如下内容（PS：非全部内容，需根据实际情况调整）：

```bash
# 在JDK8以前的版本中需将“-XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m”改为“-XX:PermSize=512m -XX:MaxPermSize=512m”
java -Dcatalina.base=${TOMCAT_BASE} \
     -Dcatalina.home=${TOMCAT_HOME} \
     -Dwtp.deploy=${TOMCAT_BASE} \
     -Djava.util.prefs.userRoot=${JAVA_USER_PREFS} \
     -Djava.endorsed.dirs=${TOMCAT_HOME}/endorsed \
     -Djava.util.logging.config.file=${TOMCAT_BASE}/conf/logging.properties \
     -Dfile.encoding=UTF-8 \
     -server \
     -Xms1G -Xmx1G \
     -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m \
     -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${TOMCAT_HOME}/memdump.hprof \
     -XX:+PrintGCDetails -XX:+PrintGCCause -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps \
     -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=10M -Xloggc:${TOMCAT_HOME}/gc.log \
     -classpath ${TOMCAT_HOME}/bin/bootstrap.jar:${TOMCAT_HOME}/bin/tomcat-juli.jar:${JAVA_HOME}/lib/tools.jar \
     org.apache.catalina.startup.Bootstrap start
```

> 对Tomcat调整Java参数，需新增或编辑文件`${TOMCAT_HOME}/bin/setenv.sh`，并按[这里](#TOMCAT-HOME-bin-setenv-sh)的内容调整环境变量`JAVA_OPTS`的值。

在以上脚本中还指定了出现**OOM**时的堆转储文件以及[GC日志](https://confluence.atlassian.com/confkb/how-to-enable-garbage-collection-gc-logging-300813751.html)的存储位置。

获取到GC日志后可以通过在线工具[GCeasy](http://gceasy.io/)分析JVM的GC情况。注意：在生产环境中也应该设置**OOM**时的堆转储文件以便于分析内存溢出问题。

注意，以上内容并不一定是最佳设置，需根据实际情况进行调整，如果存在以下情况，可尝试适当增加`-Xms`（初始堆内存）和`-Xmx`（最大堆内存）的值：
- 应用需要加载大量的Class；
- 应用运行期间需要创建大量对象或在数组中存放大量数据；
- 从GC日志中发现进行GC的频率较高、间隔较短；

> 通过[GCeasy](http://gceasy.io/)也可以得到很好的改进建议；
> 堆内存分配过大会导致一次GC的耗时增加，而GC操作会挂起应用，因此，不可盲目设置过大值；

GC日志行的格式说明如下（[Understanding Garbage Collection Logs](https://plumbr.io/blog/garbage-collection/understanding-garbage-collection-logs)）：

![](/assets/images/jvm-dump/where-is-the-memory/jvm-no-gc-for-gc-log-line-information.png)

## 参考

- [Eclipse Memory Analyzer - MAT](http://www.eclipse.org/mat/downloads.php)
- [Java String objects not getting garbage collected on time](https://stackoverflow.com/questions/11772512/java-string-objects-not-getting-garbage-collected-on-time)
- [What are the Xms and Xmx parameters when starting JVMs?](https://stackoverflow.com/questions/14763079/what-are-the-xms-and-xmx-parameters-when-starting-jvms)
- [排查Java的内存问题](http://www.infoq.com/cn/articles/Troubleshooting-Java-Memory-Issues)
- [Java中堆内存和栈内存详解](https://www.cnblogs.com/whgw/archive/2011/09/29/2194997.html)
- [How to Enable Garbage Collection (GC) Logging](https://confluence.atlassian.com/confkb/how-to-enable-garbage-collection-gc-logging-300813751.html)
- [Understanding Garbage Collection Logs](https://plumbr.io/blog/garbage-collection/understanding-garbage-collection-logs)：解释`GC (Allocation Failure)`行的格式
- [JVM调优经验](http://lousama.com/2016/03/11/jvm%E8%B0%83%E4%BC%98%E7%BB%8F%E9%AA%8C/)
- [JVM参数优化（基础篇）](http://www.howardliu.cn/java/jvm-tuning-basic/)

## 附录

### ${TOMCAT_HOME}/bin/setenv.sh

```bash
#!/bin/sh

JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"

# Prevent to occur the error 'java.lang.NoClassDefFoundError: Could not initialize class javax.imageio.ImageIO'
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -Dawt.toolkit=sun.awt.HToolkit"

JAVA_OPTS="$JAVA_OPTS -server"
JAVA_OPTS="$JAVA_OPTS -Xms1G -Xmx1G"

# PermGen for JDK7, JDK6
JAVA_OPTS="$JAVA_OPTS -XX:PermSize=512m -XX:MaxPermSize=512m"
# PermGen for JDK8+
#JAVA_OPTS="$JAVA_OPTS -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m"

# Print heap dump log
JAVA_OPTS="$JAVA_OPTS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${CATALINA_HOME}/memdump.hprof"

# Print GC log
JAVA_OPTS="$JAVA_OPTS -XX:+PrintGCDetails -XX:+PrintGCCause -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps"
JAVA_OPTS="$JAVA_OPTS -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=10M"
JAVA_OPTS="$JAVA_OPTS -Xloggc:${CATALINA_HOME}/gc.log"
```
