#!/bin/sh

set -e

GIT_REPO="${GITHUB_PAGES_REPO_AUTHOR}/${GITHUB_PAGES_REPO_NAME}"

# https://github.com/peaceiris/actions-gh-pages/blob/master/entrypoint.sh
function print_error() {
    echo -e "\e[31mERROR: ${1}\e[m"
}

function print_info() {
    echo -e "\e[36mINFO: ${1}\e[m"
}

if [ -n "${ACTIONS_DEPLOY_KEY}" ]; then
    # https://github.com/peaceiris/actions-gh-pages#1-add-ssh-deploy-key
    print_info "setup with ACTIONS_DEPLOY_KEY"

    mkdir /root/.ssh
    ssh-keyscan -t rsa github.com > /root/.ssh/known_hosts
    echo "${ACTIONS_DEPLOY_KEY}" > /root/.ssh/id_rsa
    chmod 400 /root/.ssh/id_rsa

    remote_repo="git@github.com:${GIT_REPO}.git"
elif [ -n "${PERSONAL_TOKEN}" ]; then
    print_info "setup with PERSONAL_TOKEN"

    remote_repo="https://x-access-token:${PERSONAL_TOKEN}@github.com/${GIT_REPO}.git"
elif [ -n "${GITHUB_TOKEN}" ]; then
    print_info "setup with GITHUB_TOKEN"
    print_error "Do not use GITHUB_TOKEN, See #9"

    remote_repo="https://x-access-token:${GITHUB_TOKEN}@github.com/${GIT_REPO}.git"
else
    print_error "not found ACTIONS_DEPLOY_KEY, PERSONAL_TOKEN, or GITHUB_TOKEN"
    exit 1
fi
# end


# https://github.com/igolopolosov/github-action-release-github-pages/blob/master/entrypoint.sh
print_info "Start"
print_info "Configure git"

COMMIT_EMAIL=`jq '.pusher.email' ${GITHUB_EVENT_PATH}`
COMMIT_NAME=`jq '.pusher.name' ${GITHUB_EVENT_PATH}`
COMMIT_MESSAGE=`jq '.commits[0].message' ${GITHUB_EVENT_PATH}`

git config --global user.email "${COMMIT_EMAIL}"
git config --global user.name "${COMMIT_NAME}"


print_info "Clone '${GITHUB_PAGES_REPO_NAME}'"
cd ${GITHUB_WORKSPACE}
git clone ${remote_repo}

print_info "Clean old files by running '${GITHUB_PAGES_CLEANUP_SCRIPT}'"
cd ./${GITHUB_PAGES_REPO_NAME}
eval "${GITHUB_PAGES_CLEANUP_SCRIPT}"

git status

print_info "Copy build from '../${PROJECT_BUILD_FOLDER}/'"
cp -r ../${PROJECT_BUILD_FOLDER}/* .

print_info "Commit changes with message: ${COMMIT_MESSAGE}"
git add .
git add -A
git status

git commit -m "Release: ${COMMIT_MESSAGE}"

print_info "Push changes to ${GITHUB_PAGES_RELEASE_BRANCH}"
git push ${remote_repo} ${GITHUB_PAGES_RELEASE_BRANCH}

print_info "Finish"
