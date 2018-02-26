---
layout: post
title: 记一次惊心动魄的CentOS系统升级经历
date: 2018-02-15 09:47:42
tags:
  - CentOS
  - 系统升级
categories:
  - 运维管理
---

## [How to use yum history to roll back an update](https://access.redhat.com/solutions/64069)

```bash
# List all update histories
yum history

# Undo the specified transaction
yum history undo <transaction ID>
```

## [Fix 'has missing requires of'](https://www.linuxquestions.org/questions/linux-server-73/yum-update-errors-4175534903/#post5323670)

```bash
cp -a /var/lib/rpm /var/lib/rpm.bak
cp -a /var/lib/yum /var/lib/yum.bak

yum check \
    | grep "has missing requires of" \
    | awk '{print $1}' \
    | sed -E "s/^[0-9]+://g" \
    | while read p; do rpm -e --nodeps $p; done
```

## [Fix 'is a duplicate with'](https://community.centminmod.com/threads/yum-duplicates-problem.13129/#post-55753)

```bash
cp -a /var/lib/rpm /var/lib/rpm.bak
cp -a /var/lib/yum /var/lib/yum.bak

yum check \
    | grep "is a duplicate with" \
    | awk '{print $1}' \
    | sed -E "s/^[0-9]+://g" \
    | while read p; do rpm -e --justdb --nodeps $p; done
yum update

# If 'yum update' still get some duplicated packages, just running the following commands
## yum update | grep "is a duplicate with" | awk '{print $1}' | sed -E "s/^[0-9]+://g" | while read p; do rpm -e --justdb --nodeps $p; done
## yum update
```
