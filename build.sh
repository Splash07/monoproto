#!/usr/bin/env bash
# This script is meant to build and compile every protocolbuffer for each
# service declared in this repository (as defined by sub-directories).
# It compiles using docker containers based on Namely's protoc image
# seen here: https://github.com/namely/docker-protoc

set -e

REPOPATH=github.com/Splash07
GIT_HOST=git@github.com:Splash07
ROOT_DIR=$(pwd)
CURRENT_BRANCH=${CIRCLE_BRANCH-"main"}

# Helper for adding a directory to the stack and echoing the result
function enterDir {
  echo "Entering $1"
  pushd $1 > /dev/null
}

# Helper for popping a directory off the stack and echoing the result
function leaveDir {
  echo "Leaving `pwd`"
  popd > /dev/null
}

# Enters the directory and starts the build / compile process for the services
# protobufs
function buildDir {
  currentDir="$1"
  echo "Building directory \"$currentDir\""

  enterDir $currentDir
  buildProtoForTypes $currentDir
  leaveDir
}

# Iterates through all of the languages listed in the services .protolangs file
# and compiles them individually
function buildProtoForTypes {
  target=${1%/}

  if [ -s .protolangs ]; then
    while read lang; do  
      reponame="monoproto-$target-$lang"
      rm -rf $REPOPATH/$reponame

      echo "Cloning repo: $GIT_HOST/$reponame.git"
      # Clone the repository down and set the branch to the automated one
      git clone $GIT_HOST/$reponame.git $REPOPATH/$reponame
      setupBranch $REPOPATH/$reponame
      
      mkdir -p out
      bufGenerate $target $lang
    
      # Copy the generated files into the repository dedicated for each language
      cp -R out/$lang/* $REPOPATH/$reponame/
      cp -R out/docs/* $REPOPATH/$reponame/

      commitAndPush $REPOPATH/$reponame
    done < .protolangs
  fi
}

# Finds all directories in the repository and iterates through them calling the
# compile process for each one
function buildAll {
  echo "Building service's protocol buffers"
  for d in */; do
    buildDir $d
  done
}

function setupBranch {
  enterDir $1

  echo "Creating branch"

  if ! git show-branch $CURRENT_BRANCH; then
    git branch $CURRENT_BRANCH
  fi

  git checkout $CURRENT_BRANCH

  if git ls-remote --heads --exit-code origin $CURRENT_BRANCH; then
    echo "Branch exists on remote, pulling latest changes"
    git pull origin $CURRENT_BRANCH
  fi

  leaveDir
}

function commitAndPush {
  enterDir $1

  git add -N .

  if ! git diff --exit-code > /dev/null; then
    git add .
    git commit -m "Auto Creation of Proto"
    git push origin HEAD
  else
    echo "No changes detected for $1"
  fi

  leaveDir
}

function bufGenerate {
  enterDir $ROOT_DIR
  target=$1
  lang=$2
  case $lang in 
    go)
      buf generate --template buf.gen.go.yaml -o $target/out $target
    ;;
  esac
  leaveDir
}

function bufLintAll {
  buf lint --config buf.yaml
}

bufLintAll
buildAll