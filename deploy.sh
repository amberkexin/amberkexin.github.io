#!/usr/bin/env bash
#
# GitHub Pages 一键发布脚本
# 用法：在本目录下执行  bash deploy.sh
#
set -euo pipefail

cyan()  { printf "\033[36m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1" >&2; }
bold()  { printf "\033[1m%s\033[0m\n" "$1"; }

API="https://api.github.com"

# ---------- 0. 环境检查 ----------
[ -f "index.html" ] || { red "× 没找到 index.html，请在网页文件所在目录运行这个脚本。"; exit 1; }
command -v git  >/dev/null || { red "× 未安装 git。"; exit 1; }
command -v curl >/dev/null || { red "× 未安装 curl。"; exit 1; }

echo
bold "== GitHub Pages 一键发布 =="
echo

# ---------- 1. 收集信息 ----------
read -r -p "GitHub 用户名: " GH_USER
[ -n "${GH_USER:-}" ] || { red "× 用户名不能为空。"; exit 1; }

read -r -p "仓库名（例如 my-homepage，或 ${GH_USER}.github.io）: " GH_REPO
[ -n "${GH_REPO:-}" ] || { red "× 仓库名不能为空。"; exit 1; }

cyan "提示：若你在 GitHub 开了邮箱隐私保护，这一项要填隐私邮箱"
cyan "      形如 <ID>+<用户名>@users.noreply.github.com"
cyan "      地址见 https://github.com/settings/emails（勾选 Keep my email addresses private 后显示）"
cyan "      填错的话推送会被 GitHub 拒绝，报错 GH007。"
read -r -p "提交用邮箱: " GH_EMAIL
[ -n "${GH_EMAIL:-}" ] || { red "× 邮箱不能为空。"; exit 1; }

read -r -p "提交显示名（直接回车默认 ${GH_USER}）: " GH_NAME
GH_NAME="${GH_NAME:-$GH_USER}"

echo
cyan "需要一个 Personal Access Token（只在这一步输入，不会写到磁盘）："
echo "  生成地址 → https://github.com/settings/tokens/new"
echo "  · Classic token：勾选  repo  这一项即可（脚本要建仓库+开 Pages）"
echo "  · Fine-grained：Repository access 选目标仓库，权限给"
echo "      Contents: Read and write   /   Pages: Read and write"
echo "      （fine-grained 可能没有建仓库权限，届时手动在网页建好空仓库即可）"
echo
read -r -s -p "Token（输入时不显示）: " GH_TOKEN
echo
echo
[ -n "${GH_TOKEN:-}" ] || { red "× Token 不能为空。"; exit 1; }

# ---------- 2. 校验 token ----------
printf "→ 校验 Token ... "
CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${GH_TOKEN}" "${API}/user")
if [ "$CODE" != "200" ]; then
  echo
  red "× Token 无效或已过期（HTTP ${CODE}）。"
  exit 1
fi
green "通过"

# ---------- 3. 创建远程仓库（已存在则跳过） ----------
printf "→ 检查 / 创建远程仓库 %s/%s ... " "$GH_USER" "$GH_REPO"
CODE=$(curl -s -o /tmp/gh_pages_create.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API}/user/repos" \
  -d "{\"name\":\"${GH_REPO}\",\"private\":false,\"auto_init\":false}")

case "$CODE" in
  201) green "已创建" ;;
  422) echo; cyan "  仓库已存在，继续。" ;;
  403|404) echo; red "× 当前 Token 没有创建仓库的权限（HTTP ${CODE}）。"
          red "  请手动到 https://github.com/new 建一个空的 public 仓库（不要勾 README），然后重新运行本脚本。"
          exit 1 ;;
  *)   echo; red "× 创建仓库失败（HTTP ${CODE}）。"; cat /tmp/gh_pages_create.json 2>/dev/null; exit 1 ;;
esac

# ---------- 4. 本地提交 ----------
printf "→ 配置 git 身份 ... "
git config user.name  "$GH_NAME"
git config user.email "$GH_EMAIL"
green "完成"

printf "→ 准备 main 分支 ... "
git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
green "完成"

printf "→ 提交文件 ... "
git add -A
if git diff --cached --quiet; then
  cyan "  没有新改动，跳过提交。"
else
  git -c user.name="$GH_NAME" -c user.email="$GH_EMAIL" \
      commit -q -m "Deploy personal homepage" 
  green "已提交"
fi

# ---------- 5. 推送 ----------
printf "→ 推送到 GitHub ... "
REMOTE_URL="https://github.com/${GH_USER}/${GH_REPO}.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"
# token 只作为一次性 URL 使用，push 结束后 remote 恢复为干净地址
if ! git -c credential.helper= \
     push -q -u "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git" main 2>/tmp/gh_pages_push.err; then
  echo
  if grep -q "GH007" /tmp/gh_pages_push.err; then
    red "× 推送被拒：提交里的邮箱是你账号的私密邮箱，GitHub 不允许它出现在公开提交里。"
    echo
    echo "  解决办法（推荐前者）："
    echo "  A. 改用 GitHub 隐私邮箱，然后运行同目录下的修复脚本："
    echo "       bash fix-email.sh"
    echo "     它会自动读到你正确的隐私邮箱、重写这次提交并重新推送。"
    echo "  B. 到 https://github.com/settings/emails 取消勾选"
    echo "       Block command line pushes that expose my email"
    echo "     （不推荐：这会让你的真实邮箱随提交一起公开）"
  else
    red "× 推送失败。常见原因："
    echo "  1) 远程仓库不是空的（建仓库时勾了 Add a README）"
    echo "     → 解决：删掉远程仓库重新建一个空的，或者执行下面两行后再重跑本脚本"
    echo "         git remote add origin ${REMOTE_URL}"
    echo "         git pull --rebase origin main"
    echo "  2) Token 缺少 Contents: Read and write 权限"
  fi
  echo
  echo "  ----- git 原始报错 -----"
  cat /tmp/gh_pages_push.err
  exit 1
fi
git remote set-url origin "$REMOTE_URL"
green "已推送"

# ---------- 6. 开启 GitHub Pages ----------
printf "→ 开启 GitHub Pages ... "
CODE=$(curl -s -o /tmp/gh_pages_enable.json -w "%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API}/repos/${GH_USER}/${GH_REPO}/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')

case "$CODE" in
  201) green "已开启" ;;
  409) echo; cyan "  Pages 之前已开启，无需重复操作。" ;;
  *)   echo; cyan "  未能自动开启（HTTP ${CODE}）。不影响代码，请手动到"
       cyan "  https://github.com/${GH_USER}/${GH_REPO}/settings/pages 选择 Branch: main / root 再保存。"
       ;;
esac

# ---------- 7. 结果 ----------
if [ "$GH_REPO" = "${GH_USER}.github.io" ]; then
  SITE_URL="https://${GH_USER}.github.io/"
else
  SITE_URL="https://${GH_USER}.github.io/${GH_REPO}/"
fi

echo
bold "================ 完成 ================"
echo "  仓库地址: https://github.com/${GH_USER}/${GH_REPO}"
echo "  网站地址: ${SITE_URL}"
echo
cyan "  首次发布一般需要 1～3 分钟构建，稍等一下再打开。"
cyan "  想看构建进度: https://github.com/${GH_USER}/${GH_REPO}/actions"
bold "======================================"
echo
green "最后一步：回到 GitHub 把刚才这个 Token 删掉 → https://github.com/settings/tokens"
echo
