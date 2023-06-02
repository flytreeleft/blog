[flytreeleft's Blog](https://flytreeleft.github.io)
========================================================

> The source code is [here](https://github.com/flytreeleft/blog).

## Usage

### Start local service

```bash
$ npm run dev

# With debug mode
$ npm run debug
```

### Build publish files

```bash
# The publish files will be put to the directory 'dist'
$ npm run build

# Clean
$ npm run clean
```

### Create new post

```bash
$ npm run create post <title>

# Create tags/categories page
## https://github.com/iissnan/hexo-theme-next/issues/51
## First create pages, then add line:
### `type: tags` or `type: categories` to tags/index.md or categories/index.md
$ npm run create page tags
$ npm run create page categories
```

### Deploy to github

```bash
$ npm run deploy
```

## About comments

个人十分期望能与他人对各种思想进行讨论和探索，不过，考虑到若为博客添加评论支持，那个人精力和情绪无可避免地会受到评论的影响，
当然，更多的时候还是对无人评论或关注所产生的失落感（人寻求共鸣与被关注的愿望是如此强烈且难以遏制）。

所以，在博客站点中未开启评论支持，若你有什么想法愿同我讨论，请发邮件至 flytreeleft@crazydan.org ，
在[这里](https://github.com/flytreeleft/blog/issues)创建issue也是可以的。
当然，如果能够在你的个人站点（或其他博客、微博站点）中写相关的文章一起讨论分享，那就更好了。

PS：如果是通过邮件形式进行讨论，且希望将部分或全部邮件内容公开，不论公开的仅仅是你个人的内容，还是我回复的内容，务必，请先获得我的同意！
