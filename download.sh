#!/bin/bash -e
set -o pipefail

#
# Alpha version, ugly code, refine needed.
#

fetch_json() {
  local api="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&uhd=1&setmkt=en-us&ensearch=1"
  local api_zh="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&uhd=1&setmkt=zh-cn"
  curl $api | jq -r '.images[0]' > info.json
  curl $api_zh | jq -r '.images[0]' > info-zh.json
}

download_wallpaper() {
  local target_path=$(cat info.json | jq -r '.startdate' | xargs date "+%Y/%m/%d" -d)
  mkdir -p $target_path
  mv info.json info-zh.json $target_path
  cd $target_path

  local image=$(cat info.json | jq -r '.urlbase' | awk -F '[=_]' '{print $2}')
  local image_zh=$(cat info-zh.json | jq -r '.urlbase' | awk -F '[=_]' '{print $2}')
  if [ "$image" == "$image_zh" ]; then
    rm info-zh.json
    local url="https://www.bing.com$(cat info.json | jq -r '.url' | awk -F '&' '{print $1}')"
    local filename="$(cat info.json | jq -r '.startdate').${url##*.}"
    wget $url -O $filename
  else
    local url="https://www.bing.com$(cat info.json | jq -r '.url' | awk -F '&' '{print $1}')"
    local filename="$(cat info.json | jq -r '.startdate').${url##*.}"
    wget $url -O $filename
    local url_zh="https://www.bing.com$(cat info-zh.json | jq -r '.url' | awk -F '&' '{print $1}')"
    local filename_zh="$(cat info-zh.json | jq -r '.startdate')-zh.${url##*.}"
    wget $url_zh -O $filename_zh
  fi
}

mkdir -p dist && cd dist
fetch_json
download_wallpaper
