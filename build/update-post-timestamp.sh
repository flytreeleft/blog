#!/bin/bash

post_dir=content/_posts

# https://github.com/theme-next/hexo-theme-next/issues/893#issuecomment-498080459
# git ls-files -z | while read -d '' path; do touch -d "$(git log -1 --format="@%ct" "$path")" "$path"; done
for post in `ls -1 "$post_dir"/*.md`; do
    # %ai: 2018-02-25 16:53:50 +0800
    # %ad: Wed Oct 2 00:00:43 2019 +0800
    # %ct: 1570612408
    commit_date="$(git log -1 --format="%ct" "$post")"
    touch -d "@$commit_date" "$post"
done
