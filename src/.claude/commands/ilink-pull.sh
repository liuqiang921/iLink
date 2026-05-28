#!/usr/bin/env bash
# iLink ilink-pull — Claude 平台脚本
# 按 story-id 从 Issue System 拉取需求"描述"字段，写入 requirement.md 的"## 功能描述"区块
# 用法: bash .claude/commands/ilink-pull.sh <story-id>
# 依赖（Git Bash 在 Windows 上默认全部包含；macOS/Linux 系统默认提供）:
#   bash + awk + sed + grep + curl + printf + tr + od
# 无 python3 / jq / yaml 库 / Node.js 依赖

set -eo pipefail
# 注：未启用 set -u —— 输出消息中包含中文括号 `（）`，
# 与 `${VAR}` 紧邻时 bash 解析器会误把中文字节当成变量名后缀触发 unbound 错误

# ============================================================
# 1. 参数解析（严格只接受 1 个参数）
# ============================================================
if [[ $# -ne 1 || -z "${1:-}" ]]; then
  echo "❌ 用法：/ilink-pull <story-id>" >&2
  echo "" >&2
  echo "例如：/ilink-pull FS-AMO-5359" >&2
  echo "" >&2
  echo "story-id 大小写不做转换，原样传给 Issue System。本命令只接受 1 个参数。" >&2
  exit 1
fi

STORY="$1"

# 定位项目根：脚本位于 <project_root>/.claude/commands/ilink-pull.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PCTX="${PROJECT_ROOT}/project-context.md"
REQ_FILE="${PROJECT_ROOT}/iLink-doc/${STORY}/${STORY}-requirement.md"

# ============================================================
# 2. 校验 project-context.md 与配置块
# ============================================================
if [[ ! -f "${PCTX}" ]]; then
  echo "❌ 未找到 project-context.md（路径：${PCTX}）" >&2
  echo "   请先在项目根目录执行 /ilink-bootstrap" >&2
  exit 1
fi

# 从 AI 隔离块中提取配置。匹配以 "> - " 开头的列表项
# 注：管道末尾追加 `|| true`——grep 未匹配时返回 1，叠加 `pipefail` 会让整段命令
# 替换以非零退出码结束，触发 `set -e` 静默杀掉脚本，让下方那个"缺少配置块"的
# 友好错误提示永远走不到。用 `|| true` 把这条信号吞掉，把判空交给后续显式分支。
API_URL="$(grep -E '^>[[:space:]]*-[[:space:]]*api_url:' "${PCTX}" \
  | head -n 1 \
  | sed -E 's/^>[[:space:]]*-[[:space:]]*api_url:[[:space:]]*//' \
  | tr -d '\r' \
  | sed -E 's/[[:space:]]+$//' || true)"

PROJECT_NAME="$(grep -E '^>[[:space:]]*-[[:space:]]*project_name:' "${PCTX}" \
  | head -n 1 \
  | sed -E 's/^>[[:space:]]*-[[:space:]]*project_name:[[:space:]]*//' \
  | tr -d '\r' \
  | sed -E 's/[[:space:]]+$//' || true)"

if [[ -z "${API_URL}" ]]; then
  echo "❌ project-context.md 中缺少 Issue System 集成 block（找不到 api_url 配置行）" >&2
  echo "   请重跑 /ilink-bootstrap 自动补齐该块" >&2
  echo "   （注：重跑不会丢失原有内容，只会追加 KDOP 集成块；追加后还需手动把其中的 project_name 填为实际项目名）。" >&2
  exit 1
fi

if [[ -z "${PROJECT_NAME}" || "${PROJECT_NAME}" == "<待填写>" ]]; then
  echo "❌ project-context.md 中 issue_system 的 project_name 仍为 <待填写>" >&2
  echo "" >&2
  echo "   请编辑 project-context.md，在顶部 'Issue System 集成' 块中，将" >&2
  echo "     > - project_name: <待填写>" >&2
  echo "   改为本项目在 Issue System 中的实际名称，例如：" >&2
  echo "     > - project_name: AMO运维监控系统" >&2
  echo "   然后重试本命令。" >&2
  exit 1
fi

# ============================================================
# 3. 校验 requirement.md 存在
# ============================================================
if [[ ! -f "${REQ_FILE}" ]]; then
  echo "❌ 未找到 ${REQ_FILE}" >&2
  echo "   请先执行 /ilink-init ${STORY} <usage-value>" >&2
  exit 1
fi

# ============================================================
# 3.5 "功能描述"区块空模板检查（fail-fast：在发起网络调用前判断）
# ============================================================
CURRENT_DESC="$(awk '
  /^## 功能描述/ { found = 1; next }
  found && /^## / { exit }
  found { print }
' "${REQ_FILE}" | sed -E 's/[[:space:]]+$//' | grep -v '^$' || true)"

IS_EMPTY_TEMPLATE=0
if [[ -z "${CURRENT_DESC}" ]]; then
  IS_EMPTY_TEMPLATE=1
elif [[ "${CURRENT_DESC}" == "<请描述本需求要解决的问题和预期效果>" ]]; then
  IS_EMPTY_TEMPLATE=1
fi

if [[ ${IS_EMPTY_TEMPLATE} -eq 0 ]]; then
  echo "❌ ${STORY}-requirement.md 的「功能描述」已有内容，不会覆盖。" >&2
  echo "   如需重新从 Issue System 拉取，请手动清空该区块的内容（保留'## 功能描述'标题行），然后重试。" >&2
  exit 1
fi

# ============================================================
# 4. URL encode project_name（处理中文 UTF-8）
# ============================================================
# 纯 bash + od + tr 实现，不依赖 gawk 的 strtonum 扩展
# 安全字符集（RFC 3986 unreserved）: A-Z a-z 0-9 - _ . ~
# 已与 python urllib.parse.quote 离线对比，输出一致
urlencode() {
  local LC_ALL=C
  local input="$1"
  local i c byte_hex out=""
  for ((i=0; i<${#input}; i++)); do
    c="${input:i:1}"
    case "$c" in
      [a-zA-Z0-9._~-])
        out+="$c"
        ;;
      *)
        byte_hex=$(printf '%s' "$c" | od -An -tx1 | tr -d ' \n' | tr 'a-f' 'A-F')
        out+="%${byte_hex}"
        ;;
    esac
  done
  printf '%s' "${out}"
}

ENCODED_PROJECT="$(urlencode "${PROJECT_NAME}")"
FULL_URL="${API_URL}?issueId=${STORY}&projectName=${ENCODED_PROJECT}"

# ============================================================
# 5. HTTP 调用
# ============================================================
echo "→ 拉取: ${FULL_URL}"

RESP_FILE="$(mktemp)"
HTTP_CODE_FILE="$(mktemp)"
CURL_ERR_FILE="$(mktemp)"
TMP_BLOCK_FILE="$(mktemp)"
TMP_OUT_FILE="$(mktemp)"
cleanup() { rm -f "${RESP_FILE}" "${HTTP_CODE_FILE}" "${CURL_ERR_FILE}" "${TMP_BLOCK_FILE}" "${TMP_OUT_FILE}"; }
trap cleanup EXIT

# 注：把 curl 的 stderr 重定向到临时文件而不是直接丢弃，失败时回显，方便定位
# DNS 失败 / 连接被 reset / 证书问题等不同根因。
if ! curl -sS --max-time 10 --retry 1 \
       -o "${RESP_FILE}" \
       -w "%{http_code}" \
       "${FULL_URL}" > "${HTTP_CODE_FILE}" 2>"${CURL_ERR_FILE}"; then
  echo "❌ 连接不上 project-context.md 中配置的 URL 地址：${API_URL}" >&2
  echo "   请检查网络或 project-context.md 中 api_url 配置。" >&2
  if [[ -s "${CURL_ERR_FILE}" ]]; then
    echo "   curl 错误详情：" >&2
    sed 's/^/     /' "${CURL_ERR_FILE}" >&2
  fi
  exit 1
fi

HTTP_CODE="$(cat "${HTTP_CODE_FILE}")"

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "❌ Issue System 返回 HTTP ${HTTP_CODE}，请检查 URL 与 story-id 是否正确" >&2
  RESP_PREVIEW="$(head -c 200 "${RESP_FILE}")"
  echo "   响应前 200 字: ${RESP_PREVIEW}" >&2
  exit 1
fi

# ============================================================
# 6. JSON 解析（提取 data.描述）
# ============================================================
# 用 awk 编写的最小 JSON 字符串值提取器（已在 macOS BSD awk 验证）：
# - 找到 "<key>":"  起始
# - 一直读到下一个未转义的 "
# - 处理常见 JSON 转义 \n \t \r \" \\ \/
# - 不支持 \uXXXX（金证接口实测返回真实 UTF-8，无 unicode escape）
extract_string_field() {
  local key="$1"
  awk -v key="${key}" '
    # 在 json 中从位置 start_idx 起，定位 `"<key>" <空白>* : <空白>* "` 模式，
    # 返回开值引号后的下一个位置；找不到返回 0。
    function find_value_start(json, key, start_idx,    pat, idx, scan) {
      pat = "\"" key "\""
      idx = index(substr(json, start_idx), pat)
      if (idx == 0) return 0
      scan = start_idx + idx - 1 + length(pat)  # 此时 scan 指向 "key" 之后
      # 跳过空白
      while (scan <= length(json) && (substr(json, scan, 1) == " " || substr(json, scan, 1) == "\t" || substr(json, scan, 1) == "\n" || substr(json, scan, 1) == "\r")) scan++
      # 必须是冒号
      if (substr(json, scan, 1) != ":") return 0
      scan++
      # 跳过冒号后的空白
      while (scan <= length(json) && (substr(json, scan, 1) == " " || substr(json, scan, 1) == "\t" || substr(json, scan, 1) == "\n" || substr(json, scan, 1) == "\r")) scan++
      # 必须是开值引号
      if (substr(json, scan, 1) != "\"") return 0
      return scan + 1  # 指向值的第一个字符
    }
    function extract(json, key,    i, c, nc, out) {
      i = find_value_start(json, key, 1)
      if (i == 0) return ""
      out = ""
      while (i <= length(json)) {
        c = substr(json, i, 1)
        if (c == "\\") {
          nc = substr(json, i+1, 1)
          if      (nc == "n")  out = out "\n"
          else if (nc == "t")  out = out "\t"
          else if (nc == "r")  out = out "\r"
          else if (nc == "\"") out = out "\""
          else if (nc == "\\") out = out "\\"
          else if (nc == "/")  out = out "/"
          else                  out = out nc
          i += 2
        } else if (c == "\"") {
          return out
        } else {
          out = out c
          i++
        }
      }
      return ""
    }
    { json = json $0 ORS }
    END {
      result = extract(json, key)
      if (result == "") exit 1
      printf "%s", result
    }
  ' "${RESP_FILE}"
}

# 校验业务 code 字段（int，单独 grep 处理）
CODE="$(grep -oE '"code"[[:space:]]*:[[:space:]]*[0-9]+' "${RESP_FILE}" \
        | head -n 1 \
        | sed -E 's/.*:[[:space:]]*//' || true)"

if [[ "${CODE}" != "200" ]]; then
  MSG="$(extract_string_field "message" 2>/dev/null || echo "(无 message 字段)")"
  echo "❌ Issue System 返回业务错误 code=${CODE}, message=${MSG}" >&2
  exit 1
fi

# 提取 描述 字段
DESCRIPTION="$(extract_string_field "描述" 2>/dev/null || true)"

# 去除 HTML 标签，转换常见实体
DESCRIPTION="$(printf '%s' "${DESCRIPTION}" \
  | sed -E 's|<br[[:space:]]*/?>|\n|gi' \
  | sed -E 's|</p>|\n|gi' \
  | sed -E 's|<[^>]*>||g' \
  | sed 's|&nbsp;| |g; s|&amp;|\&|g; s|&lt;|<|g; s|&gt;|>|g; s|&quot;|"|g' \
  | awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' \
  | sed -E 's/[[:space:]]+$//')"

if [[ -z "${DESCRIPTION}" ]]; then
  echo "❌ 接口响应中 data.描述 字段缺失或为空" >&2
  echo "   请确认 story-id '${STORY}' 在 Issue System 中存在且已填写描述。" >&2
  RESP_PREVIEW="$(head -c 200 "${RESP_FILE}")"
  echo "   响应前 200 字: ${RESP_PREVIEW}" >&2
  exit 1
fi

# ============================================================
# 7. 写入 requirement.md（空模板检查已在步骤 3.5 完成）
# ============================================================
TIMESTAMP="$(TZ=Asia/Shanghai date +%Y-%m-%dT%H:%M:%S+08:00)"

{
  echo "## 功能描述"
  echo ""
  echo "${DESCRIPTION}"
  echo ""
  echo "> _来源: Issue System (${STORY}, pulled ${TIMESTAMP})_"
  echo ""
} > "${TMP_BLOCK_FILE}"

awk -v new_block_file="${TMP_BLOCK_FILE}" '
  BEGIN {
    new_content = ""
    while ((getline line < new_block_file) > 0) {
      new_content = new_content line "\n"
    }
    close(new_block_file)
  }
  /^## 功能描述/ {
    printf "%s", new_content
    skip = 1
    next
  }
  skip && /^## / { skip = 0 }
  !skip { print }
' "${REQ_FILE}" > "${TMP_OUT_FILE}"

mv "${TMP_OUT_FILE}" "${REQ_FILE}"

CHAR_COUNT="${#DESCRIPTION}"
echo ""
echo "✓ 已从 Issue System 拉取 ${STORY} 功能描述（约 ${CHAR_COUNT} 字符）"
echo "  写入: ${REQ_FILE}"
echo "  来源行: > _来源: Issue System (${STORY}, pulled ${TIMESTAMP})_"
