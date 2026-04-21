#!/usr/bin/env bash
set -e
set -o pipefail

_is_same_image() {
  local rc=0
  local image_1="$(cat $1 | jq -r '.urlbase' | awk -F '[=_]' '{print $2}')"
  local image_2="$(cat $2 | jq -r '.urlbase' | awk -F '[=_]' '{print $2}')"
  [ $image_1 == $image_2 ] || rc=1
  return $rc
}

_get_image_url() {
  local url="https://www.bing.com$(cat $1 | jq -r '.url' | awk -F '&' '{print $1}')"
  echo $url
}

_get_image_filename() {
  local url4suffix=$(_get_image_url $1)
  local filename="$(cat $1 | jq -r '.startdate')"
  local suffix="${url4suffix##*.}"
  local is_zh=${2:-0}
  [ $is_zh == 0 ] && echo ${filename}.${suffix} || echo ${filename}-zh.${suffix}
}

_keep_latest_image() {
  local image="$1"
  local blur_edge="$(
    magick "$image" \
      -colorspace Gray \
      -blur 0x4 \
      -evaluate multiply 0.6 \
      -canny 0x1+12%+35% \
      -threshold 1% \
      -format '%[fx:mean]' info:
  )" || return 1

  awk -v x="$blur_edge" '
    BEGIN {
      if (x < 0.018) exit 0;
      else exit 1;
    }
  '
}

fetch_json() {
  local api="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&uhd=1&setmkt=en-us&ensearch=1"
  local api_zh="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&uhd=1&setmkt=zh-cn"
  curl -sSL $api | jq -r '.images[0]' > info.json
  curl -sSL $api_zh | jq -r '.images[0]' > info-zh.json
}

dl_wallpaper() {
  if _is_same_image info.json info-zh.json; then
    rm info-zh.json
    local url=$(_get_image_url info.json)
    local filename=$(_get_image_filename info.json)
    wget $url -O $filename
  else
    local url filename
    # en version
    url=$(_get_image_url info.json)
    filename=$(_get_image_filename info.json)
    wget $url -O $filename
    # zh version
    url=$(_get_image_url info-zh.json)
    filename=$(_get_image_filename info-zh.json 1)
    wget $url -O $filename
  fi
}

dl_latest() {
  local full_url=$(_get_image_url info.json)
  local base_url="${full_url%_UHD*}"
  local suffix="${full_url##*.}"
  mkdir -p dist
  wget "${base_url}_UHD.${suffix}" -O dist/latest.${suffix}
  wget "${base_url}_1920x1080.${suffix}" -O dist/latest-desktop.${suffix}
  wget "${base_url}_768x1280.${suffix}" -O dist/latest-mobile.${suffix}

  _keep_latest_image dist/latest-desktop.${suffix} || rm dist/latest*${suffix}
}

move_to_dir() {
  local url4suffix=$(_get_image_url info.json)
  local filename="$(cat info.json | jq -r '.startdate')"
  local suffix="${url4suffix##*.}"
  local target_path=$(echo $filename | xargs date "+%Y/%m/%d" -d)
  mkdir -p dist/$target_path
  mv -v info*.json *${suffix} dist/$target_path
}

fetch_json
dl_wallpaper
dl_latest
move_to_dir
