# Credential Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rotate所有 SSH 密钥与 Git Token，确保 Apifox 泄漏后只保留新凭证且有可追踪记录。

**Architecture:** 按“撤销→清点→排查→生成→分发→记录”顺序推进；所有资产、日志与验证写入 `docs/security/`，保证后续审计。

**Tech Stack:** macOS shell、OpenSSH、GitHub/GitLab Web UI、ssh-copy-id/bin/ssh-add-host、1Password/Bitwarden、Git。

---

### Task 1: 撤销旧凭证（安全负责人，≤4 小时）

**Files:** 无

- [ ] **Step 1:** 打开 GitHub/GitLab Token 页面 `https://github.com/settings/tokens`，切换到 Fine-grained/Classic 标签。
- [ ] **Step 2:** 删除所有与 Apifox 相关或近期使用的 PAT，记录被删 Token 名称与 ID 于本地便笺备用。
- [ ] **Step 3:** Settings → SSH and GPG keys 删除所有可疑 SSH key；Org/Repo Settings → Deploy keys 删除旧公钥；若仓库安装 GitHub App（用于 CI/Apifox），前往 Settings → Installed GitHub Apps/Organization Settings，撤销该 App 的 tokens 与 webhooks。
- [ ] **Step 4:** 登录每个服务器 `ssh <user>@host`，编辑 `~/.ssh/authorized_keys` 移除旧公钥；在 CI/CD Credential Store（GitHub Actions Secrets、Vault 等）删除旧 key 引用。
- [ ] **Step 5:** 本地执行 `ssh-add -D` 清空 ssh-agent，然后运行 `eval "$(ssh-agent -k)" && eval "$(ssh-agent)"` 重启代理，确保所有进程使用最新密钥。

### Task 2: 清点受影响资产（各系统 owner，≤24 小时）

**Files:** Create `docs/security/affected-assets-20260326.csv`

- [ ] **Step 1:** `mkdir -p docs/security`，创建 CSV 文件，写入表头：
  ```csv
  id,system_name,credential_type,storage_path_or_reference,owner,risk_level,created_at,last_rotated,status,notes
  ```
- [ ] **Step 2:** 为每个设备/服务器/CI/脚本添加一行，例如：
  `ROT-SSH-01,prod-server-1,SSH Key,~/.ssh/id_prod_old,userA,高,2025-11-01,2025-11-01,待轮换,Apifox 泄漏`
- [ ] **Step 3:** 将 CSV 添加到 git（后续统一提交），并上传一份到共享文档/表单（如 Google Sheet/Notion），使所有 owner 可同时更新；在密码管理器保存更详细的私钥位置或链接。

### Task 3: 轻量入侵排查（安全负责人并记录证据）

**Files:** Create/Append `docs/security/rotation-evidence.md`

- [ ] **Step 1:** GitHub Security Log：筛选过去 7 天 SSH/PAT 活动，将可疑事件（IP、时间、动作）复制到 `rotation-evidence.md`。
  - 若发现未知 IP 或未经授权的 token 使用：立即在 GitHub Settings 中暂时锁定账号（设置 require password reset）、撤销相关 sessions，并将对应凭证标记为“禁止回滚”，交由安全负责人进一步调查。
- [ ] **Step 2:** 服务器日志：执行 `sudo journalctl -u ssh.service --since "2026-03-19"`（或 `cat /var/log/auth.log`），将异常条目复制到 evidence 文件。
  - 若发现暴力破解或未知用户成功登录：禁用相关系统账户、限制源 IP，并告知所有 owner 暂停对应服务器的凭证回滚，直到调查完成。
- [ ] **Step 3:** Apifox 项目活动记录：若仍可访问控制台，检查共享链接/成员活动；如发现陌生访问，立即移除该成员/链接并记录。
  - 若已彻底卸载 Apifox，写明卸载日期及“不再保留任何凭证”，作为控制措施说明。

### Task 4: 生成新 SSH 密钥（各 owner，≤48 小时）

**Files:** 无

- [ ] **Step 1:** `mkdir -p ~/.ssh && cd ~/.ssh`，决定文件名 `id_apifox_rotated`。
- [ ] **Step 2:** 运行 `ssh-keygen -t ed25519 -C "apifox-rotation-20260326" -f ~/.ssh/id_apifox_rotated` 并设置强口令。
- [ ] **Step 3:** `chmod 600 ~/.ssh/id_apifox_rotated` 与 `chmod 644 ~/.ssh/id_apifox_rotated.pub`。
- [ ] **Step 4:** 将私钥与口令保存到 1Password/Bitwarden，自定义条目名称如 “SSH Key - apifox rotation 2026-03-26”。

### Task 5: 新建 Git Token 与相关 Secrets（各 owner，≤48 小时）

**Files:** 无

- [ ] **Step 1:** GitHub Developer settings → Personal access tokens → 创建 Fine-grained token，只勾选必要仓库 `Contents: Read/Write`，设置 90 天或更短的过期时间。
- [ ] **Step 2:** 将 token 立即存入密码管理器，备注用途、过期日以及需在第三方平台使用时改用临时 token/参数化调用（参考规范非功能性要求）。
- [ ] **Step 3:** 更新所有 CI/CD/脚本：
  - GitHub Actions：Settings → Secrets → Actions → 更新 `GH_TOKEN`。
  - Shell 环境：将 `.env` 或配置文件改成引用密码管理器命令（如 `export GH_TOKEN=$(op read "op://Vault/Git Token/password")`），避免明文。
  - 若第三方平台需访问，请改用临时 token（可脚本化生成）或通过参数传递，一次性使用后即作废。
- [ ] **Step 4:** 在便笺中列出所有使用位置，供 Task 7 统一记录。

### Task 6: 部署新密钥/Token 并验证（安全负责人 72 小时内完成确认）

**Files:** Modify `~/.ssh/config`; remote `~/.ssh/authorized_keys`

- [ ] **Step 1:** 更新 `~/.ssh/config`，为每个主机指定 `IdentityFile ~/.ssh/id_apifox_rotated`。
- [ ] **Step 2:** 运行 `ssh-copy-id -i ~/.ssh/id_apifox_rotated.pub <user>@<server>` 或 `bin/ssh-add-host --host <server> --user <user> --identity ~/.ssh/id_apifox_rotated`。
- [ ] **Step 3:** 验证 SSH：`ssh -i ~/.ssh/id_apifox_rotated <user>@<server>`，确保免密登录；将结果写入 Task7 记录中的“验证时间/结果”。
- [ ] **Step 4:** 验证 Git：`GIT_SSH_COMMAND="ssh -i ~/.ssh/id_apifox_rotated" git ls-remote git@github.com:your/repo.git` 或一次 `git push`，记录成功时间。
- [ ] **Step 5:** 验证 CI/CD：触发一次 dry-run 或无害部署，确认新的 token 可用。
- [ ] **Step 6:** **受控回滚**（仅在验证失败且确认日志无可疑访问时）：
  - 暂时重新添加旧凭证前，确保其仍未在任何平台授权；必要时创建临时 token 并设置 2 小时过期。
  - 记录回滚原因、起止时间、负责人；2 小时内再次尝试轮换并更新记录。

### Task 7: 记录轮换结果并提交

**Files:** Create `docs/security/credential-rotation-log.md`

- [ ] **Step 1:** 若文件不存在，创建并写入表头：
  ```markdown
  # Credential Rotation Log
  | 唯一ID | 系统名称 | 凭证类型 | 使用位置 | 存放方式/路径 | 负责人 | 风险级别 | 创建时间 | 本次轮换时间 | 验证结果/时间 | 回滚记录 |
  |--------|----------|----------|----------|---------------|--------|----------|----------|---------------|----------------|-----------|
  ```
- [ ] **Step 2:** 根据 Task1-6 结果，添加一行示例：
  `ROT-SSH-01 | prod-server-1 | SSH Key | ~/.ssh/id_apifox_rotated (1Password entry) | blaze | 高 | 2025-11-01 | 2026-03-26 | SSH/Git/CI 已验证 2026-03-26 15:30 | 无`
  - 若出现回滚，在“回滚记录”写明原因与时段。
- [ ] **Step 3:** `git add docs/security/affected-assets-20260326.csv docs/security/rotation-evidence.md docs/security/credential-rotation-log.md`
- [ ] **Step 4:** 在 `docs/security/credential-rotation-log.md` 顶部追加一段：`本次轮换完成时间：2026-03-26 18:00（示例），下一次轮换不晚于 2026-06-24`，用于跟踪定期轮换起点。
- [ ] **Step 5:** `git commit -m "docs: log credential rotation for apifox incident"`

### 手动验证清单
- [ ] Git/服务器/CI 不再显示旧 PAT 或 SSH key。
- [ ] `docs/security/affected-assets-20260326.csv` 覆盖全部资产且状态均为“已轮换”。
- [ ] `docs/security/rotation-evidence.md` 包含 Git/服务器日志与 Apifox 卸载说明。
- [ ] `docs/security/credential-rotation-log.md` 记录最新验证结果与回滚信息。
