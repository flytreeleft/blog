#!/bin/bash

repo='git@github.com:flytreeleft/flytreeleft.github.io.git'
branch=master
deploy_dir=deploy_dist
build_conf=${1:-config.yml}

user_email=$(git config user.email)
user_name=$(git config user.name)

try() {
    "$@" || exit 1
}

echo "Build blog."
try yarn install
try npm run clean

try npm run _build -- --config "${build_conf}"
[ -e _multiconfig.yml ] && try rm _multiconfig.yml

if [ ! -d $deploy_dir ]; then
    echo "Clone a new copy to $deploy_dir."
    try git clone $repo -b $branch $deploy_dir
fi

pushd $deploy_dir
    echo "Sync $repo with remote"
    try git config user.email $user_email
    try git config user.name $user_name
    try git pull origin $branch
    try git reset --hard origin/$branch
    try git clean -d -f
    try git rm -r *

    echo "Commit new dist files."
    try mv ../dist/* .
    try cp ../README.md .
    try git add *
    try git add -A
    try git commit -m "Site updated"

    echo "Push dist files to $repo."
    try git push origin master
popd
