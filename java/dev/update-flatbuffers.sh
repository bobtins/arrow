#!/bin/bash

# Script for generating Java source from the flatbuffer schema files
# which are located in format/*.fbs.
# Previously run as part of the Maven build.
# Now the schema files are checked into source;
# you only need to run this when the schema changes, then check in the generated files

# flatc version 
# this needs to match the flatbuffers JAR dependency in pom.xml
# TODO this is a bit old; other impls are using 1.12, the latest
FLATBUFFERS_VERSION=1.9.0

die() {
    echo "$THIS_NAME error: $1"
    exit 1
}

# orient yourself; this shell is under $ARROW/java/dev
# lots of quotes for when people do silly things like put spaces in dir names
whereAmI() {
    THIS_DIR="$(cd "$(dirname "$0")"; pwd -P)"
    THIS_NAME="$(basename "$0")"
    ARROW_DIR="$(dirname "$(dirname "$THIS_DIR")")"
    FORMAT_DIR="$ARROW_DIR/format"
    JAVA_FORMAT_DIR="$ARROW_DIR/java/format"
    FLATC_PATH="$JAVA_FORMAT_DIR/flatc"
    set |grep _DIR
    echo "running $THIS_NAME, flatc will go in $FLATC_PATH"
}

# original maven method; relies on an old unofficially provided flatc binary artifact
# only supports Mac or Linux and version 1.9.0
tryMaven() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     os=linux;;
        Darwin*)    os=osx;;
        *)          die "Maven method only supports OSX or Linux; uname returned $unameOut";;
    esac
    # echo "Found OS: $os"

    rm -f flatc*exe

    # get the flatbuffers artifact
    mvn dependency:get \
        -DgroupId=com.github.icexelloss \
        -DartifactId=flatc-$os-x86_64 \
        -Dversion=$FLATBUFFERS_VERSION \
        -Dpackaging=exe \
        -Ddest=.
    [ $? = 0 ] || die "mvn command failed"
    [ -e flatc*exe ] || die "no flatc found"
    mv flatc*exe flatc
}

# make sure the version of flatc matches what we're expecting
# generated source is only compatible with a specific version of the flatbuffers JAR

checkVersion() {
    this_version="$(./flatc --version)"
    case "${this_version}" in
        *$FLATBUFFERS_VERSION*)     ;; # cool
        *)          die "Arrow is using version $FLATBUFFERS_VERSION but this version is $this_version";;
    esac
}

# B E G I N
# figure out paths based on path of $0
whereAmI

# if you've already gotten flatc via maven or other means, skip trying maven
[ -e flatc ] || tryMaven || die "no flatc found"

# make it executable
chmod +x flatc

# test for matching version
checkVersion

# clobber the old source and run flatc
./flatc -j \
    -o gensrc \
    ../../format/*.fbs
