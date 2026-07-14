#!/usr/bin/env bash
# 一键发布新版本到 GitHub Releases，并同步更新 GitHub Pages 的更新清单
#
# 用法:
#   export GITHUB_TOKEN=ghp_xxx        # 需要 repo 权限的 Personal Access Token
#   ./release.sh v1.1.0                # 发布说明从 RELEASE_NOTES.md 读取
#   ./release.sh v1.1.0 notes.md       # 指定说明文件
#   REPO=owner/repo ./release.sh v1.1.0
#
# 脚本会自动:
#   1. 创建 Release（tag = 参数）
#   2. 生成机器可读的 update.json 清单
#   3. 上传 update.html 与 update.json 作为 Release 资源
#   4. 同步 docs/index.html 与 docs/update.json 供 GitHub Pages 使用
set -u

REPO="${REPO:-yq2580/aijz}"
TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then echo "❌ 请先设置环境变量 GITHUB_TOKEN" >&2; exit 1; fi

TAG="${1:-}"; NOTES_FILE="${2:-RELEASE_NOTES.md}"
if [ -z "$TAG" ]; then echo "用法: $0 <版本tag> [说明文件]" >&2; exit 1; fi
if [ ! -f "$NOTES_FILE" ]; then echo "❌ 说明文件不存在: $NOTES_FILE" >&2; exit 1; fi

API="https://api.github.com/repos/$REPO"
PAGE_SRC="$( [ -f docs/index.html ] && echo docs/index.html || echo update.html )"
AUTH=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" -H "X-GitHub-Api-Version: 2022-11-28")
PY="${PYTHON:-python3}"

# 带重试的 HTTP 调用：代理偶尔瞬断（SSL_ERROR_SYSCALL，curl 返回 000）时自动重试
http() {
  local method="$1" out="$2" url="$3"; shift 3
  local code
  for i in 1 2 3 4 5 6; do
    code=$(curl -sS -o "$out" -w "%{http_code}" -X "$method" "$@" "$url")
    [ "$code" != "000" ] && break
    echo "  (网络瞬断, 重试 $i)" >&2; sleep 2
  done
  echo "$code"
}

get_sha() {
  local f="$1" out sha
  for i in 1 2 3 4 5; do
    out=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API/contents/$f")
    sha=$(echo "$out" | $PY -c "import sys,json;print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)
    [ -n "$sha" ] && { echo "$sha"; return; }
    sleep 2
  done
  echo ""
}

BODY=$(cat "$NOTES_FILE")
REL_PAYLOAD=$($PY -c "import json,sys;print(json.dumps({'tag_name':sys.argv[1],'name':sys.argv[2],'body':sys.argv[3],'prerelease':False}))" "$TAG" "${TAG#v}" "$BODY")

echo "== 创建 Release $TAG =="
CODE=$(http POST /tmp/rel.json "$API/releases" "${AUTH[@]}" -d "$REL_PAYLOAD")
if [ "$CODE" != "201" ]; then echo "❌ 创建失败 HTTP $CODE"; cat /tmp/rel.json; exit 1; fi
REL_ID=$($PY -c "import json;print(json.load(open('/tmp/rel.json'))['id'])")
UPLOAD=$($PY -c "import json;print(json.load(open('/tmp/rel.json'))['upload_url'].split('{')[0])")
echo "✅ release id=$REL_ID"

echo "== 生成 update.json =="
$PY -c "
import json
r=json.load(open('/tmp/rel.json')); tag=r['tag_name']
out={'version':tag.lstrip('v'),'tag':tag,'name':r['name'],'published_at':r['published_at'],'html_url':r['html_url'],
'notes':open('$NOTES_FILE').read().strip(),
'assets':[{'name':'update.html','url':f'https://github.com/$REPO/releases/download/{tag}/update.html'},
          {'name':'update.json','url':f'https://github.com/$REPO/releases/download/{tag}/update.json'}]}
open('/tmp/update.json','w').write(json.dumps(out,ensure_ascii=False,indent=2))
print('✅ update.json 已生成')
"

echo "== 上传资源 =="
CODE=$(http POST /tmp/u1.json "$UPLOAD?name=update.html" -H "Authorization: Bearer $TOKEN" -H "Content-Type: text/html" --data-binary @"$PAGE_SRC")
echo "update.html -> $CODE"
CODE=$(http POST /tmp/u2.json "$UPLOAD?name=update.json" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/update.json)
echo "update.json -> $CODE"

echo "== 同步到 docs/ (GitHub Pages) =="
b64h=$($PY -c "import base64;print(base64.b64encode(open('$PAGE_SRC','rb').read()).decode())")
b64j=$($PY -c "import base64;print(base64.b64encode(open('/tmp/update.json','rb').read()).decode())")
P1=$($PY -c "import json,sys;print(json.dumps({'message':'docs: update page','content':sys.argv[1]}))" "$b64h")
P2=$($PY -c "import json,sys;print(json.dumps({'message':'docs: update manifest','content':sys.argv[1]}))" "$b64j")
for f in index.html update.json; do
  SHA=$(get_sha "docs/$f")
  if [ "$f" = "index.html" ]; then PL="$P1"; else PL="$P2"; fi
  if [ -n "$SHA" ]; then
    PL=$($PY -c "import json,sys;d=json.loads(sys.argv[1]);d['sha']=sys.argv[2];print(json.dumps(d))" "$PL" "$SHA")
  fi
  CODE=$(http PUT /tmp/d.json "$API/contents/docs/$f" "${AUTH[@]}" -d "$PL")
  echo "docs/$f -> $CODE"
done

echo "== 完成 🎉 =="
echo "Release: https://github.com/$REPO/releases/tag/$TAG"
echo "Pages:   https://${REPO%/*}.github.io/${REPO#*/}/"
