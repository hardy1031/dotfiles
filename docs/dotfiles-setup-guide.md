# Dotfiles Setup Guide

あなたの specific な setup（mail-imap automation + Raycast scripts）を `dotfiles` repo にまとめて、新 PC で 1 command で再現できるようにする guide。

**Goal**：何も考えず、上から順に実行すれば repo が完成する。

---

## 0. あなたの現状

```
~/Library/LaunchAgents/com.local.mailcleanup.plist     ← launchd 設定
~/Scripts/mail-imap/                                    ← Python automation
├── cleanup.py
├── check_folder.py
├── check_mail.py
├── requirements.txt
├── .env                                               ← credentials（git に入れない）
└── logs/                                              ← runtime log（git に入れない）
```

**Plist の中身**：
- 毎朝 3:00 AM に `/Users/mymac/.pyenv/shims/python3 cleanup.py` を実行
- Working directory: `~/Scripts/mail-imap`
- Log: `~/Scripts/mail-imap/logs/`

---

## 1. Philosophy（なぜこの設計か）

### Problem
- Automation file が複数の system path に散らばっている
- Git 管理されていない、新 PC で再現できない、resume で見せられない

### Approach
**Symlink pattern**：
- 実 file は repo に 1 箇所（source of truth）
- OS が要求する場所（`~/Library/LaunchAgents/` 等）には symlink を貼る
- Edit は repo で、変更は即反映

### なぜ folder ごと symlink するか
`mail-imap/` は複数 file が連携して 1 つの module を構成している。論理的に 1 単位なので、folder 全体を 1 つの symlink として扱う。新 file 追加・削除で install.sh を再実行しなくていい。

### なぜ plist は変更不要か
Plist は `~/Scripts/mail-imap/cleanup.py` を指している。Symlink を貼った後も、OS から見える path は同じ（`~/Scripts/mail-imap` が symlink になっているだけで、その下の file は普通に見える）。だから plist は 1 文字も変えなくていい。

---

## 2. Layer の整理

```
┌─────────────────────────────────────────┐
│ Source of truth (git管理)                │
│ ~/dotfiles/                             │
│   ├── launchd/com.local.mailcleanup.plist│
│   └── scripts/mail-imap/                 │
└─────────────────────────────────────────┘
              ↑ symlink で繋ぐ
┌─────────────────────────────────────────┐
│ OS layer (固定 path)                      │
│ ~/Library/LaunchAgents/...plist          │
│ ~/Scripts/mail-imap/                     │
└─────────────────────────────────────────┘
              ↑ launchd が見る場所
```

**重要**：`.env` と `logs/` は repo に入れない。
- `.env` → 各 machine で手動配置（credentials なので）
- `logs/` → runtime に作られる、git で track しない

---

## 3. 完成形の repo structure

```
~/dotfiles/
├── README.md
├── .gitignore
├── install.sh
├── uninstall.sh
│
├── launchd/
│   └── com.local.mailcleanup.plist
│
├── scripts/
│   └── mail-imap/
│       ├── cleanup.py
│       ├── check_folder.py
│       ├── check_mail.py
│       ├── requirements.txt
│       ├── .env.example          ← template, .env 自体は gitignore
│       └── logs/                  ← .gitkeep だけ commit
│           └── .gitkeep
│
├── raycast/
│   └── (今後追加)
│
└── docs/
    └── architecture.md            ← optional
```

---

## 4. Setup 手順（上から順に実行）

### Step 1: Repo folder を作る

```bash
mkdir -p ~/dotfiles/{launchd,scripts,raycast,docs}
cd ~/dotfiles
git init
```

### Step 2: `.gitignore` を作る

```bash
cat > ~/dotfiles/.gitignore <<'EOF'
# Credentials - 絶対に commit しない
**/.env
**/.env.local
**/*.secret

# Logs - runtime に生成される
**/logs/*
!**/logs/.gitkeep

# macOS system files
.DS_Store
**/.DS_Store

# Python
__pycache__/
*.pyc
*.pyo
.venv/
venv/

# Backup files
*.backup
*.bak
EOF
```

### Step 3: 既存 file を repo に move

⚠️ **この step で automation が一時的に止まります**（次の step で symlink 貼るまで）。

```bash
# 3-1. launchd job を一旦止める
launchctl unload ~/Library/LaunchAgents/com.local.mailcleanup.plist

# 3-2. plist を repo に移動
mv ~/Library/LaunchAgents/com.local.mailcleanup.plist \
   ~/dotfiles/launchd/

# 3-3. mail-imap folder ごと repo に移動
mv ~/Scripts/mail-imap ~/dotfiles/scripts/

# 3-4. 確認
ls ~/dotfiles/launchd/
ls ~/dotfiles/scripts/mail-imap/
```

### Step 4: `.env` を git から除外する処理

`.env` は既に move されてる（folder ごと移動したから）。`.gitignore` のおかげで commit されないが、**`.env.example` を作って template として残す**。

```bash
# 4-1. .env.example を作る（template、実 credentials は含めない）
cat > ~/dotfiles/scripts/mail-imap/.env.example <<'EOF'
# IMAP credentials for mail cleanup
# Copy this file to .env and fill in real values
IMAP_HOST=imap.gmail.com
IMAP_PORT=993
EMAIL_ADDRESS=your_email@example.com
EMAIL_PASSWORD=your_app_password_here
EOF
```

実際の `.env` の中身を見て、`.env.example` を adjust：

```bash
# 実 .env の key 名を確認（値は見ないで key だけ）
grep -E "^[A-Z_]+=" ~/dotfiles/scripts/mail-imap/.env | cut -d= -f1
```

その output に合わせて `.env.example` の key を update。

### Step 5: `logs/` 用の `.gitkeep` を作る

`logs/` folder は git で track したいけど、中の log file は track したくない。`.gitkeep` という空 file を置いて folder だけ残す慣習。

```bash
# logs folder の中身を全部 remove（runtime で再生成される）
rm -f ~/dotfiles/scripts/mail-imap/logs/*

# .gitkeep を作る
touch ~/dotfiles/scripts/mail-imap/logs/.gitkeep
```

### Step 6: `install.sh` を作る

```bash
cat > ~/dotfiles/install.sh <<'INSTALL_EOF'
#!/bin/bash
#
# install.sh - Setup dotfiles symlinks
# Idempotent: 何度実行しても安全
#

set -euo pipefail

# === Configuration ===
DOTFILES="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

# === Helpers ===
log() {
    echo "[install] $*"
}

backup_if_real() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Backing up: $target -> $BACKUP_DIR/"
        mv "$target" "$BACKUP_DIR/"
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"
    backup_if_real "$target"
    ln -sf "$source" "$target"
    log "Linked: $target -> $source"
}

# === Pre-flight checks ===
if [ ! -d "$DOTFILES" ]; then
    echo "Error: $DOTFILES does not exist"
    exit 1
fi

log "Starting installation from $DOTFILES"

# === 1. launchd plists ===
log "=== Setting up launchd ==="
mkdir -p "$LAUNCHD_DIR"

if [ -d "$DOTFILES/launchd" ]; then
    for plist in "$DOTFILES"/launchd/*.plist; do
        [ -e "$plist" ] || continue
        name=$(basename "$plist")
        target="$LAUNCHD_DIR/$name"
        label="${name%.plist}"
        
        # 既に loaded されてたら unload
        if launchctl list | grep -q "$label"; then
            launchctl unload "$target" 2>/dev/null || true
        fi
        
        create_symlink "$plist" "$target"
        launchctl load "$target"
        log "Loaded: $label"
    done
fi

# === 2. Scripts (folder or file ごと symlink) ===
log "=== Setting up scripts ==="
mkdir -p "$SCRIPTS_DIR"

if [ -d "$DOTFILES/scripts" ]; then
    for entry in "$DOTFILES"/scripts/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        target="$SCRIPTS_DIR/$name"
        
        create_symlink "$entry" "$target"
        
        # File なら実行権限つける
        if [ -f "$entry" ]; then
            chmod +x "$entry"
        fi
    done
fi

# === 3. .env のチェック ===
log "=== Checking .env files ==="
ENV_FILE="$DOTFILES/scripts/mail-imap/.env"
ENV_EXAMPLE="$DOTFILES/scripts/mail-imap/.env.example"

if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
    log "⚠️  .env not found at: $ENV_FILE"
    log "    Copy .env.example to .env and fill in real values:"
    log "    cp $ENV_EXAMPLE $ENV_FILE"
    log "    vim $ENV_FILE"
fi

# === 4. Python dependencies ===
log "=== Python dependencies ==="
if [ -f "$DOTFILES/scripts/mail-imap/requirements.txt" ]; then
    log "ℹ️  Install Python dependencies with:"
    log "    pip3 install -r $DOTFILES/scripts/mail-imap/requirements.txt"
fi

# === 5. Raycast (manual step) ===
log "=== Raycast setup ==="
log "⚠️  Manual step:"
log "    Raycast preferences (Cmd+,) -> Extensions -> Script Commands"
log "    -> Add Script Directory: $DOTFILES/raycast"

# === Summary ===
log ""
log "✅ Installation complete!"
[ -d "$BACKUP_DIR" ] && log "📦 Backups: $BACKUP_DIR"
log ""
log "Verify with:"
log "  launchctl list | grep mailcleanup"
log "  ls -la $SCRIPTS_DIR"
INSTALL_EOF

chmod +x ~/dotfiles/install.sh
```

### Step 7: `uninstall.sh` を作る

```bash
cat > ~/dotfiles/uninstall.sh <<'UNINSTALL_EOF'
#!/bin/bash
#
# uninstall.sh - Remove dotfiles symlinks
# Repo の中の実 file は touch しない、symlink のみ削除
#

set -euo pipefail

DOTFILES="$HOME/dotfiles"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

log() {
    echo "[uninstall] $*"
}

# launchd jobs を unload して symlink 削除
if [ -d "$DOTFILES/launchd" ]; then
    for plist in "$DOTFILES"/launchd/*.plist; do
        [ -e "$plist" ] || continue
        name=$(basename "$plist")
        target="$LAUNCHD_DIR/$name"
        
        if [ -L "$target" ]; then
            launchctl unload "$target" 2>/dev/null || true
            rm "$target"
            log "Removed: $target"
        fi
    done
fi

# Script symlinks を削除
if [ -d "$DOTFILES/scripts" ]; then
    for entry in "$DOTFILES"/scripts/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        target="$SCRIPTS_DIR/$name"
        
        if [ -L "$target" ]; then
            rm "$target"
            log "Removed: $target"
        fi
    done
fi

log "✅ Uninstall complete (repo files in $DOTFILES are untouched)"
UNINSTALL_EOF

chmod +x ~/dotfiles/uninstall.sh
```

### Step 8: `install.sh` を実行して symlink を貼る

```bash
cd ~/dotfiles
./install.sh
```

期待される出力：
- `[install] Linked: ~/Library/LaunchAgents/com.local.mailcleanup.plist -> ...`
- `[install] Linked: ~/Scripts/mail-imap -> ...`
- `[install] Loaded: com.local.mailcleanup`
- `[install] ✅ Installation complete!`

### Step 9: 動作確認

```bash
# 9-1. Symlink が貼られてるか確認
ls -la ~/Library/LaunchAgents/com.local.mailcleanup.plist
# 出力に '->' が含まれてれば OK

ls -la ~/Scripts/mail-imap
# 同じく symlink

# 9-2. Symlink の target が repo を指してるか
readlink ~/Library/LaunchAgents/com.local.mailcleanup.plist
# -> /Users/mymac/dotfiles/launchd/com.local.mailcleanup.plist

readlink ~/Scripts/mail-imap
# -> /Users/mymac/dotfiles/scripts/mail-imap

# 9-3. launchd job が active か
launchctl list | grep mailcleanup
# PID または '-' が表示されれば registered

# 9-4. Manual で cleanup.py を test
cd ~/Scripts/mail-imap
python3 cleanup.py
# .env が読めて、いつも通り動けば OK
```

### Step 10: README.md を作る

```bash
cat > ~/dotfiles/README.md <<'README_EOF'
# Dotfiles

Personal macOS automation toolkit. Reproducible setup via symlink pattern.

## What's inside

### `launchd/` + `scripts/mail-imap/`
Scheduled email cleanup automation.

- **Trigger**: launchd, daily at 3:00 AM
- **What**: Python scripts that connect to IMAP and clean up old emails
- **Files**:
  - `cleanup.py` - main cleanup logic
  - `check_folder.py`, `check_mail.py` - helper utilities
  - `requirements.txt` - Python dependencies

### `raycast/`
Manual-trigger shortcuts via Raycast (one-keystroke workflows).

## Philosophy

- **Single source of truth**: actual files live in this repo. OS-required 
  locations (`~/Library/LaunchAgents/`, `~/Scripts/`) are symlinks pointing here.
- **Reproducible**: `git clone` + `./install.sh` recreates the entire setup.
- **Idempotent install**: re-running `install.sh` is safe.

## Prerequisites

- macOS
- Python 3 (via pyenv recommended)
- Raycast (for `raycast/` scripts)

## Setup

\`\`\`bash
# 1. Clone
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# 2. Install Python dependencies
pip3 install -r ~/dotfiles/scripts/mail-imap/requirements.txt

# 3. Configure credentials
cp ~/dotfiles/scripts/mail-imap/.env.example \
   ~/dotfiles/scripts/mail-imap/.env
vim ~/dotfiles/scripts/mail-imap/.env

# 4. Run install
cd ~/dotfiles
./install.sh

# 5. Manual: set Raycast script directory to ~/dotfiles/raycast
\`\`\`

## Daily workflow

Edit any file in `~/dotfiles/`, changes are reflected immediately via symlinks.

\`\`\`bash
cd ~/dotfiles
vim scripts/mail-imap/cleanup.py
# test, then commit
git add . && git commit -m "..." && git push
\`\`\`

For plist changes, reload the launchd job:
\`\`\`bash
launchctl unload ~/Library/LaunchAgents/com.local.mailcleanup.plist
launchctl load   ~/Library/LaunchAgents/com.local.mailcleanup.plist
\`\`\`

## Architecture

\`\`\`
~/dotfiles/scripts/mail-imap/cleanup.py        ← actual file
~/Scripts/mail-imap  →  symlink ↑              ← what OS sees
~/Library/LaunchAgents/...plist  →  symlink    ← what launchd loads
\`\`\`

## Uninstall

\`\`\`bash
cd ~/dotfiles
./uninstall.sh
\`\`\`

Removes symlinks only. Repo files are preserved.
README_EOF
```

### Step 11: GitHub に push

```bash
cd ~/dotfiles

# 11-1. 全 file を commit
git add .
git status   # 確認：.env が含まれていないこと！
git commit -m "Initial commit: dotfiles with mail-imap automation"

# 11-2. GitHub repo を作成
# Option A: gh CLI を使う場合
gh repo create dotfiles --public --source=. --push

# Option B: GitHub web で repo 作って手動 push
# git remote add origin https://github.com/YOUR_USERNAME/dotfiles.git
# git branch -M main
# git push -u origin main
```

⚠️ **Push 前に `.env` が含まれていないことを必ず確認**：
```bash
git ls-files | grep -i env
# 出力が `.env.example` のみであれば OK
# 万が一 `.env` が含まれていたら：
git rm --cached scripts/mail-imap/.env
git commit -m "Remove accidentally committed .env"
```

---

## 5. 新 PC で setup する flow（将来用）

```bash
# 1. Repo clone
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# 2. Python dependencies
pip3 install -r ~/dotfiles/scripts/mail-imap/requirements.txt

# 3. .env を作る
cp ~/dotfiles/scripts/mail-imap/.env.example \
   ~/dotfiles/scripts/mail-imap/.env
vim ~/dotfiles/scripts/mail-imap/.env

# 4. Install
cd ~/dotfiles
./install.sh

# 5. Raycast の script folder 設定（manual）
```

---

## 6. 日常の運用 flow

### File を edit する場合
```bash
# Repo の中の file を edit、即反映
vim ~/dotfiles/scripts/mail-imap/cleanup.py

# Test
python3 ~/Scripts/mail-imap/cleanup.py

# Commit
cd ~/dotfiles && git add . && git commit -m "..." && git push
```

### Plist を変更した場合（reload 必要）
```bash
launchctl unload ~/Library/LaunchAgents/com.local.mailcleanup.plist
launchctl load   ~/Library/LaunchAgents/com.local.mailcleanup.plist
```

### 新しい automation を追加する場合

例：新 plist `com.local.something.plist` を追加
```bash
# 1. Repo に新 plist と script を追加
vim ~/dotfiles/launchd/com.local.something.plist
vim ~/dotfiles/scripts/something.sh

# 2. install.sh を再実行（idempotent）
cd ~/dotfiles && ./install.sh

# 3. Commit
git add . && git commit -m "Add something automation"
```

### 別 machine で sync
```bash
cd ~/dotfiles && git pull
# Symlink 経由で即反映、再 install 不要（新 file が無い場合）
# 新 file 追加されてた場合は ./install.sh 再実行
```

---

## 7. Resume 記載例

### Personal Projects section
```
Personal Automation Toolkit (Dotfiles)
github.com/YOUR_USERNAME/dotfiles

- Built reproducible macOS automation setup with launchd-scheduled Python 
  scripts (IMAP-based daily email cleanup) and Raycast shortcuts.
- Designed symlink-based dotfiles architecture with idempotent install/uninstall 
  scripts; deployable on any macOS machine via single command.
- Separated credentials via .env pattern; safely public on GitHub.
```

### または一行 mention
```
Interests: macOS automation (launchd, Python, IMAP), dotfiles management, 
Raycast scripting
```

### 注意点
- 数値を入れる（"daily cleanup processing X emails", "saving Y min/day"）
- `launchd` を明記（OS-level の理解の signal、cron より modern）
- 過大表現しない（interview で深掘りされても答えられる範囲で）

---

## 8. Troubleshooting

| Symptom | 原因 | Fix |
|---------|------|-----|
| `launchctl list` で job が見えない | plist が load されてない | `launchctl load <path>` |
| Python script が動かない | dependencies 未 install | `pip3 install -r requirements.txt` |
| `.env not found` | credentials 未設定 | `.env.example` から copy して fill in |
| `pyenv: command not found` | pyenv 未 install | `brew install pyenv` |
| Symlink が壊れてる | repo の path 変わった | `./uninstall.sh && ./install.sh` |
| Git push で `.env` が含まれる | `.gitignore` 機能してない | `git rm --cached <file>` で外す |

---

## 9. Checklist（完了確認）

このChecklist が全部 ✅ になれば setup 完了：

- [ ] `~/dotfiles/` folder が存在し、folder 構造が正しい
- [ ] `.gitignore` が `.env` と `logs/*` を除外している
- [ ] `~/dotfiles/launchd/com.local.mailcleanup.plist` が存在
- [ ] `~/dotfiles/scripts/mail-imap/` 内に Python script 群がある
- [ ] `.env.example` がある（`.env` の template として）
- [ ] `~/Library/LaunchAgents/com.local.mailcleanup.plist` が symlink になってる
- [ ] `~/Scripts/mail-imap` が symlink になってる
- [ ] `launchctl list | grep mailcleanup` で job が見える
- [ ] `cleanup.py` を manual で実行して動く
- [ ] GitHub に push 済み、`.env` が含まれていない
- [ ] README.md が公開されている

---

## 10. 今後の拡張

新しい automation を足したい時はこの pattern を follow：

1. Trigger を decide：manual (Raycast) か scheduled (launchd) か
2. 該当 folder に file を追加
3. `install.sh` を再実行
4. Commit & push

Repo は **成長していく前提**。最初は mail-imap 1 つでも、徐々に他の automation が増えていく。これが GitHub の commit history としても healthy で、resume で見せた時に「継続的に improving している engineer」の signal になる。
