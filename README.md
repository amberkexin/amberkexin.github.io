# 我的个人主页

一个纯静态的个人主页模板，零依赖、零构建，直接丢到 GitHub Pages 就能跑。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `index.html` | 页面内容（文字都改这里） |
| `style.css` | 样式（配色、字号、间距都在顶部变量里） |

## 你需要改的地方

在 `index.html` 里搜索并替换这几处：

1. **`你的名字`** — 页面标题、导航栏、正文里都是占位
2. **`你`**（头像里的那个字）— 换成你名字的第一个字，或者用 `<img>` 换成真实头像
3. **一句话介绍** — `.subtitle` 那一段
4. **关于我 / 技能 / 项目** — 三块内容全按需替换
5. **链接** — 把所有 `https://github.com/yourname`、`you@example.com` 换成你自己的

改完记得把 `index.html` 里 `<title>` 也一起换掉。

## 改配色

打开 `style.css` 最上面的 `:root`，改这两个值就能换掉全站主色：

```css
--brand: #4f46e5;    /* 主色 */
--brand-2: #06b6d4;  /* 辅助色 */
```

页面自带浅色 / 深色两套主题，右上角按钮可切换，默认跟随系统。

## 本地预览

直接双击 `index.html`，或者：

```bash
python3 -m http.server 8000
# 然后打开 http://localhost:8000
```

## 部署到 GitHub Pages

### 一键脚本（推荐）

在终端里执行：

```bash
cd <本目录>
bash deploy.sh
```

脚本会依次问你：GitHub 用户名、仓库名、提交邮箱、以及一个 **Personal Access Token**。
Token 用隐藏输入，不会写进 `.git/config`，也不会留在任何文件里。

它自动完成：建远程仓库 → 本地提交 → 推送 → 开启 Pages → 打印访问网址。

Token 生成地址：<https://github.com/settings/tokens/new>

- 用 **Classic token**：勾选 `repo` 即可（脚本要建仓库并开 Pages）
- 用 **Fine-grained token**：Repository access 选目标仓库，权限给
  `Contents: Read and write` + `Pages: Read and write`；
  如果它没有建仓库的权限，就先去 <https://github.com/new> 手动建一个空的 public 仓库再跑脚本。

**跑完请立刻把 Token 删掉**：<https://github.com/settings/tokens>

### 手动部署

```bash
git init
git add .
git commit -m "init: personal homepage"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

推送后在仓库页面进入 **Settings → Pages**，把 **Source** 设为 `Deploy from a branch`，
分支选 `main`、目录选 `/ (root)`，保存。等 1 分钟左右，访问：

- 仓库名是 `<用户名>.github.io` → `https://<用户名>.github.io`
- 其他仓库名 → `https://<用户名>.github.io/<仓库名>/`
