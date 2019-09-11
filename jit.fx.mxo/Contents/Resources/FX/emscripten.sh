#!/bin/bash
dir=$(cd $(dirname $0)&&pwd)
cd $dir
fn=`echo ${dir} | awk -F "/" '{ print $NF }'`
~/Development/emsdk-portable/emscripten/1.38.29/em++ \
	-O3 \
	-std=c++11 \
	-Wc++11-extensions \
	--memory-init-file 0 \
	-s VERBOSE=1 \
	-s WASM=0 \
	-s EXPORTED_FUNCTIONS="['_set','_calc']" \
	-s EXTRA_EXPORTED_RUNTIME_METHODS="['cwrap']" \
	-s TOTAL_MEMORY=16777216 \
	./${fn}.cpp \
	-o ./${fn}.js