---
layout: post
title: Git使用案例
date: 2017-05-28 22:24:15
tags:
  - git
categories:
  - 开发工具
---

## 拆分子目录到新仓库

### 场景

通常为便于项目开发和调试，开发前期会将多个组件放在同一仓库中，而当各个组件的功能结构和代码逐渐区域稳定后，
便需要将其拆分出来进行独立开发和管理，以便于与其他项目共享组件。

此时，不仅需要将组件所在目录内的代码全部拆分到单独的仓库，同时，还需要确保历史记录能够完整保留。

<!--more-->

### 操作

```bash
# Clone the repository that contains the subfolder.
git clone https://github.com/USERNAME/REPOSITORY-NAME
cd REPOSITORY-NAME

# To filter out the subfolder from the rest of the files in the repository
## FOLDER-NAME: The folder within your project that you'd like to create a separate repository from.
## BRANCH-NAME: The default branch for your current project, for example, 'master' or 'gh-pages'
git filter-branch --prune-empty --subdirectory-filter FOLDER-NAME BRANCH-NAME

# Change the existing remote 'origin' (or other name) URL to the new repository URL
git remote set-url origin https://github.com/USERNAME/NEW-REPOSITORY-NAME.git

# [Optional] Change BRANCH-NAME to the default branch (e.g. 'master') of the new repository
git branch -m BRANCH-NAME master

# Push your changes to the new repository
git push -u origin master
```

**注意**：
- 在第二步操作后，当前目录将会只剩下子目录中的文件
- 最好在新的目录中进行上述操作：可以直接clone，也可以从复制已有项目到其他目录

若要拆分多个子目录，可通过如下命令筛选出目标目录并保留其历史：

```bash
git filter-branch \
    --index-filter ' \
        git rm --cached -qr --ignore-unmatch -- . \
        && git reset -q $GIT_COMMIT -- \
            path/to/dir1 path/to/dir2 path/to/file1 path/to/file2 ... \
        ' \
    --prune-empty -- --all
```

### 参考

- [Splitting a subfolder out into a new repository](https://help.github.com/articles/splitting-a-subfolder-out-into-a-new-repository/)

## 迁移子分支至新仓库

### 场景

某个项目仓库中可能存在多个功能特性（features）分支，在一段时候后，基于产品功能规划和开发维护等方面的考虑，
需要将某些特性分支独立成新的项目或子项目，将其迁移到新的仓库中。

### 操作

```bash
# Push 'feature-branch' to the branch 'master' (or others) of new repository
git push url://to/new/repository.git feature-branch:master

# [Optional] Delete the 'feature-branch' from current repository
git branch -d feature-branch

# Clone codes from new repository
git clone url://to/new/repository.git feature-branch
```

### 参考

- [How do I move a Git branch out into its own repository?](https://stackoverflow.com/questions/2227062/how-do-i-move-a-git-branch-out-into-its-own-repository)

## 合并多个仓库到一个仓库

```bash
# 分别在各个源仓库中，创建目标目录（即，在合并后的仓库中的目录），再将其全部代码转移到该目录中
dir="<target dir>"
mkdir $dir
git mv !($dir) $dir
git commit -m "迁移代码至目录$dir"

# 在目标仓库中，依次将各个源仓库合并至本仓库中
git remote add source /path/to/source/repo/dir
git fetch source

git merge --allow-unrelated-histories source/master
## 添加并提交冲突文件（没有时，可不需要该操作）
git add .gitignore && git commit

git remote remove source
```

## 修改变更提交人的信息

### 场景

基于项目长远发展考虑，将某个具有实用价值且吸引力极大的项目开源，
需要将项目从公司内部仓库开放到Github上，但相关开发人员在两个系统中所用帐号不一致，
为了便于issue交流以及PR提交，这时，需要更改历史中的提交人信息。

其实，大多数时候，很可能是要弃用内部仓库并将工作全部移到公共仓库时才有这么做的需求，其余情况并不需要这么做。

### 操作

- 部分替换：

```bash
git filter-branch --commit-filter \
        'if [ "$GIT_AUTHOR_NAME" = "OldAuthor Name" ]; then \
             export GIT_AUTHOR_NAME="Author Name"; \
             export GIT_AUTHOR_EMAIL=authorEmail@example.com; \
             export GIT_COMMITTER_NAME="Commmiter Name"; \
             export GIT_COMMITTER_EMAIL=commiterEmail@example.com; \
         fi; \
         git commit-tree "$@" '
# Push to the branch 'master' of the existing repository
git push --force origin master
```

- 全部替换：

```bash
git filter-branch --commit-filter \
        'export GIT_AUTHOR_NAME="Author Name"; \
         export GIT_AUTHOR_EMAIL=authorEmail@example.com; \
         export GIT_COMMITTER_NAME="Commmiter Name"; \
         export GIT_COMMITTER_EMAIL=commiterEmail@example.com; \
         git commit-tree "$@" '
# Push to the branch 'master' of the existing repository
git push --force origin master
```

**注意**：
- 若出现类似`Cannot create a new backup. A previous backup already exists in refs/original/. Force overwriting the backup with -f`的异常提示，则需要在`filter-branch`命令中添加选项`-f`，即`git filter-branch -f`，以强制进行修改
- 如果提交的分支是受保护的，则在提交时会出现`remote: GitLab: You are not allowed to force push code to a protected branch on this project.`的错误信息，此时，需要调整仓库设置，临时取消对目标分支的保护

### 参考

- [Could I change my name and surname in all previous commits?](https://stackoverflow.com/questions/4493936/could-i-change-my-name-and-surname-in-all-previous-commits)

## 修改历史提交备注信息

### 场景

在[拆分子目录](#拆分子目录到新仓库)和[迁移子分支](#迁移子分支至新仓库)两个场景中，
在新仓库中的历史提交记录的备注信息可能存在与项目不相关的信息或者包含原始项目中的一些敏感内容。
这个时候，就可能需要修改这些备注信息。

当然，也可能是因为发现以前的提交备注中包含错别字或者表达不清晰，为了避免对其他人产生误导或困惑，
将提交的备注信息予以纠正也是很有必要的。

### 操作

- 获取提交ID并Rebase到该提交

```bash
# List histories and get the commit id which should be modified
git log

# Rebase to 3 commits before the specified commit (e.g. 'ce0ac37c83')
git rebase --interactive ce0ac37c83~3
```

![](/assets/images/git-usage-cases-rebase-to-target-commit.png)

- 将提交所在行开始处的`pick`修改为`edit`

![](/assets/images/git-usage-cases-change-history-commit.png)

- 提交并应用修改

```bash
# New commit message
git commit --amend -m "fix that the dragging preview can not be shown"

# Apply the changes and return to HEAD
git rebase --continue

# Push to the branch 'master' of the existing repository
## Make sure that the remote branch 'master' is unprotected
git push --force origin master
```

**注意**：
- 如果需要放弃修改，则运行命令`git rebase --abort`
- 若直接`rebase`到目标commit，则该提交不会显示在可修改清单内，故，需选择从其之前的第N个（e.g. `~3`）提交开始
- 若提交至非空的仓库，需确保目标分支不是受保护（`protected`）的
- 在应用修改后，git将从修改位置开始重新构建commit tree，因此，从该位置开始到HEAD的commit id均会发生变化，但原始commit tree依然存在，通过`git diff ce0ac37c83`等可看到该提交的变更情况

### 参考

- [How to modify existing, unpushed commits?](https://stackoverflow.com/questions/179123/how-to-modify-existing-unpushed-commits)
