#!/bin/bash
export JAVA_HOME=~/.jdks/corretto-25.0.1
export PATH=$JAVA_HOME/bin:$PATH
echo "Starting backend..."

java -jar target/vampire-raiders-server.jar
