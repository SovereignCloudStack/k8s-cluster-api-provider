# File to be included
if test -z "$YQ"; then
  if yq --help | grep jq >/dev/null 2>&1; then
    YQ="yq --yaml-output"
    YQIN=""
  else
    YQ="yq eval"
    YQIN="-"
  fi
  export YQ YQIN
fi
