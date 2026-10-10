#!/usr/bin/env bash
#
# 修复 GH007：提交邮箱是私密邮箱，导致推送被 GitHub 拒绝
# 用法：在本目录下执行  bash fix-email.sh
#
set -euo pipefail

cyan()  { printf "\033[36m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1" >&2; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

API="https://api.github.com"

# ---------- 0. 环境检查 ----------
[ -d .git ] || { red "× 当前目录不是 git 仓库，请先 cd 到项目目录。"; exit 1; }
git rev-parse --verify HEAD >/dev/null 2>&1 || { red "× 还没有任何提交，请先运行 deploy.sh。"; exit 1; }
command -v curl >/dev/null || { red "× 未安装 curl。"; exit 1; }

echo
bold "== 修复提交邮箱导致的推送失败 =="
cyan "   原因 GH007：提交里带的是你的私密邮箱，GitHub 拒绝把它发布到公开仓库"
echo

# ---------- 1. 拿 Token ----------
read -r -s -p "Token（不显示，和刚才用同一个就行）: " GH_TOKEN
echo
echo
[ -n "${GH_TOKEN:-}" ] || { red "× Token 不能为空。"; exit 1; }

# ---------- 2. 读取账号信息，拼出隐私邮箱 ----------
printf "→ 读取你的账号信息 ... "
ME=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" "${API}/user")
LOGIN=$(printf '%s' "$ME" | tr ',' '\n' | grep '"login"' | head -1 | sed 's/.*:[[:space:]]*"//; s/".*//')
ID=$(printf '%s' "$ME" | tr ',' '\n' | grep '"id"' | head -1 | sed 's/.*:[[:space:]]*//')
if [ -z "${LOGIN:-}" ] || [ -z "${ID:-}" ]; then
  echo
  red "× 读不到账号信息，Token 可能无效或已过期。"
  exit 1
fi
green "$LOGIN"

CANDIDATE="${ID}+${LOGIN}@users.noreply.github.com"

echo
echo "  改用 GitHub 的隐私邮箱就能解决 —— 它同样能把提交算到你名下。"
cyan  "    ${CANDIDATE}"
echo
echo "  想核对准确地址：打开 https://github.com/settings/emails"
echo "  勾选 Keep my email addresses private 后，页面会直接显示你的这个地址。"
echo
read -r -p "  直接回车使用上面的地址，或粘贴你自己的: " INPUT_EMAIL
EMAIL="${INPUT_EMAIL:-$CANDIDATE}"

# ---------- 3. 更新本地身份并重写上一个提交 ----------
printf "→ 更新本地 git 邮箱 ... "
git config user.email "$EMAIL"
green "$EMAIL"

printf "→ 重写上一个提交的作者信息 ... "
git commit --amend --reset-author --no-edit -q
green "完成"

# ---------- 4. 重新推送 ----------
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [ -z "$REMOTE_URL" ]; then
  red "× 没有找到 origin 远程地址，请先运行 deploy.sh。"
  exit 1
fi
REPO=$(basename "$REMOTE_URL" .git)

printf "→ 重新推送到 %s/%s ... " "$LOGIN" "$REPO"
if ! git -c credential.helper= \
     push -q -u "https://${LOGIN}:${GH_TOKEN}@github.com/${LOGIN}/${REPO}.git" main 2>/tmp/gh_fix_push.err; then
  echo
  red "× 仍被拒绝，原始报错："
  cat /tmp/gh_fix_push.err
  echo
  echo "  如果报错还是 GH007，说明邮箱仍不是 GitHub 认可的隐私地址。"
  echo "  请到 https://github.com/settings/emails 复制页面显示的那个地址，重新运行本脚本。"
  exit 1
fi
green "已推送"

# ---------- 5. 确保 Pages 已开启 ----------
printf "→ 开启 GitHub Pages ... "
CODE=$(curl -s -o /tmp/gh_fix_pages.json -w "%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API}/repos/${LOGIN}/${REPO}/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')

case "$CODE" in
  201) green "已开启" ;;
  409) echo; cyan "  之前已开启，无需重复操作。" ;;
  *)   echo; cyan "  未能自动开启（HTTP ${CODE}），请手动到"
       cyan "  https://github.com/${LOGIN}/${REPO}/settings/pages 选 Branch: main / root 保存。" ;;
esac

# ---------- 6. 结果 ----------
if [ "$REPO" = "${LOGIN}.github.io" ]; then
  SITE_URL="https://${LOGIN}.github.io/"
else
  SITE_URL="https://${LOGIN}.github.io/${REPO}/"
fi

echo
bold "================ 完成 ================"
echo "  仓库地址: https://github.com/${LOGIN}/${REPO}"
echo "  网站地址: ${SITE_URL}"
echo
cyan "  首次发布要等 1～3 分钟构建，稍后再打开。"
cyan "  构建进度: https://github.com/${LOGIN}/${REPO}/actions"
bold "======================================"
echo
green "别忘了把 Token 删掉 → https://github.com/settings/tokens"
echo
