# iLink 使用者实操手册

> **读者**：使用 iLink 进行日常开发的工程师
> **前提**：项目已完成 Bootstrap（`project-context.md` 和入口文件已就位）
> **版本**：v1.6.0

---

## 目录

- [1. 三分钟上手](#1-三分钟上手)
- [2. 写需求定义——你最重要的工作](#2-写需求定义你最重要的工作)
- [3. 流水线操作详解](#3-流水线操作详解)
- [4. 审核设计——Human-Gate 实操](#4-审核设计human-gate-实操)
  - [4.6 Coach 协作复盘](#46-coach-协作复盘v160-新增)
- [5. 修订 STAGING 文档——ilink-refine 实操](#5-修订-staging-文档ilink-refine-实操)
- [6. 回流与熔断——出了问题怎么办](#6-回流与熔断出了问题怎么办)
- [7. 维护 project-context.md](#7-维护-project-contextmd)
- [8. 多 Story 并行开发](#8-多-story-并行开发)
- [9. 常见问题排查](#9-常见问题排查)
- [10. 反模式——千万别这样做](#10-反模式千万别这样做)
- [11. 认知模式——Domain Knowledge](#11-认知模式domain-knowledge)
- [附录 A：命令速查表](#附录-a命令速查表)
- [附录 B：文件地图](#附录-b文件地图)
- [附录 C：状态流转图](#附录-c状态流转图)

---

## 1. 三分钟上手

### 1.1 最小操作流程

```bash
# ① 创建 Story（v1.6.0：第二个参数为当前 session 已用量，先 /usage 或 /stats 查询）
/ilink-init kcia-1520 1200

# ② 编辑需求定义（这是你唯一需要手写的文件）
#    打开 iLink-doc/kcia-1520/kcia-1520-requirement.md，填写内容

# ③ 启动 AI 流水线（中间阶段不需要 usage 参数）
/ilink-pm kcia-1520          # AI 分析需求，输出业务合同
/ilink-design kcia-1520      # AI 做技术设计，输出文件清单

# ④ 你审核设计（这是你最重要的审核点）
#    阅读 iLink-doc/kcia-1520/kcia-1520-design.master.md
#    重点看 [TASK_ALLOCATION] 和 [DESIGN_DECISIONS]
ilink-approve kcia-1520      # 审核通过，推进到编码

# ⑤ AI 编码 + 审查（v1.6.0：qa 第二个参数同样为当前已用量）
/ilink-coder kcia-1520       # AI 写代码
/ilink-qa kcia-1520 1850     # AI 审查代码 + 写入 usage delta

# ⑥ 你做最终确认后提交
git add .
git commit -m "kcia-1520: 功能描述"
```

**整个过程中你只做三件事：写需求、审设计、最终提交。**

> **v1.6.0 起 — Usage 追踪硬接口**：`/ilink-init` 和 `/ilink-qa` 第二个参数为"当前 session/月度已用量"，**必填**。每个平台读各自原生的指标：
> - Claude Code：`/usage` 显示的"% used"
> - Qoder：`/usage` 显示的"已使用 credits"
> - Codex：`/status` 显示的 session "tokens used"
> - Gemini CLI：`/stats` 显示的 session "Total Tokens"
>
> 该数值仅写入 `<story>-usage.md` 用于事后观察，不参与契约链。无法查询时允许传 `0`，语义为"故意跳过"，对应 delta 标注为"不可信"。详见 §3.7。

### 1.2 遇到 STAGING 时

如果 AI 在某个阶段输出了 `STAGING`（表示有不确定项），你有四种处理方式：

```bash
# 方式 A（推荐）：修订对话，逐条确认
/ilink-refine kcia-1520      # AI 列出所有 [待确认] 项，你逐条决策
ilink-approve kcia-1520      # 确认完毕后推进

# 方式 B：直接编辑文档
# 手动修改 STAGING 文档中的阻塞项
ilink-approve kcia-1520

# 方式 C：修改上游重跑
# 修改需求定义，重新执行对应角色命令

# 方式 D：直接推进（承担风险）
ilink-approve kcia-1520      # 未解决的 [待确认] 项原样传入下游
```

### 1.3 查看进度

随时可以查看 Story 的当前状态：

```bash
ilink-status              # 查看所有 Story 概览
ilink-status kcia-1520    # 查看指定 Story 详情
```

---

## 2. 写需求定义——你最重要的工作

### 2.1 为什么需求定义这么重要

需求定义是整条流水线的**唯一人类输入**。AI 的 PM → Designer → Coder → QA 全部基于你写的需求定义展开。需求定义的质量直接决定最终代码的质量。

**一个写了 10 分钟的需求定义，能省你 2 小时的返工。**

### 2.2 需求定义模板

执行 `/ilink-init <story>` 后，会在 `iLink-doc/<story>/` 下生成模板：

```markdown
# <story> — 需求定义

## 1. 功能描述
（用 1-3 句话说清楚要做什么）

## 2. 功能范围
- In Scope:
  - （明确要做的事）
- Out of Scope:
  - （明确不做的事）

## 3. 验收标准
- AC-01: （可验证的条件）
- AC-02: （可验证的条件）

## 4. 约束备注
（已知的技术约束、兼容性要求、特殊注意事项）

## 5. 假设与风险
（你已知的假设、不确定的事项、潜在风险）

## 关联领域知识（可选）
（如果本需求涉及已有 Domain Knowledge 的模块，填写文件路径，PM/Designer 会参考）
<!-- 示例：iLink-doc/domain/auth-domain-knowledge.md -->
```

### 2.3 写好每个章节

#### § 1 功能描述

**目标**：让一个不了解背景的人在 10 秒内知道你要做什么。

```
❌ 差：优化登录模块
✅ 好：新增用户登录失败统计接口，供运维监控使用，返回最近 7 天每天的失败次数
```

#### § 2 功能范围

**这是最关键的章节。** AI 设计和编码的边界完全由这里决定。

```
❌ 差：
- In Scope: 登录失败统计

✅ 好：
- In Scope:
  - 新增 REST 接口 /api/cia/login-fail-stat，返回最近 N 天的失败统计
  - 在 fs_cia_login_log 表上增加索引优化查询性能
  - 支持按操作员维度和全局维度两种查询方式
- Out of Scope:
  - 登录失败实时告警（属于 kcia-1521）
  - 修改现有登录逻辑
  - 前端页面展示
```

**"Out of Scope" 同样重要。** 它防止 AI 多做事。

#### § 3 验收标准

每条验收标准 MUST 是**可验证的**——读完后能明确判断"做到了"还是"没做到"。

```
❌ 差：
- AC-01: 接口性能好

✅ 好：
- AC-01: GET /api/cia/login-fail-stat?days=7 返回 JSON 数组，
         格式 [{date: "2026-04-01", count: 15}, ...]
- AC-02: 百万级 login_log 数据下，接口响应时间 P99 < 200ms
- AC-03: 无登录记录时返回空数组 []，不返回错误
```

**QA 阶段会逐条核对验收标准。** 写得越精确，QA 越有效。

#### § 4 约束备注

把你知道但 AI 可能不知道的事写在这里：

```
## 4. 约束备注
- 必须兼容现有 fs_cia_login_log 表结构，不能加字段
- 接口需注册到 BEX 调度器，功能码前缀用 920
- 该接口不需要登录态验证（属于管理端接口，走 mng 服务）
- 参考现有接口：FsOperatorQueryHandler（查询类接口的标准实现模式）
```

**"参考现有接口"特别有用。** AI 会去读那个接口的代码，模仿它的实现模式。

### 2.4 需求定义自查清单

写完后用这个清单检查一遍：

- [ ] 功能描述能让不了解背景的人看懂
- [ ] In Scope 列出了所有要做的事
- [ ] Out of Scope 列出了容易被误解为要做但实际不做的事
- [ ] 每条验收标准都能明确判断"做到 / 没做到"
- [ ] 约束备注中写了 AI 不可能从代码中推断出的信息
- [ ] 如果有参考实现，已经写明了文件路径或类名

---

## 3. 流水线操作详解

### 3.1 /ilink-init — 创建 Story

```bash
/ilink-init kcia-1520 1200
#                     ^^^^
#       v1.6.0 必填：当前 session/月度已用量数字
```

**执行前**：先在 CLI 中执行平台原生 usage 命令查看"已用"数字（详见 §3.7）。

**执行效果**：
- 创建 `iLink-doc/kcia-1520/` 目录
- 生成 `kcia-1520-requirement.md` 模板
- 生成 `kcia-1520-usage.md`，写入 init 行（基线值 = 你传入的数字）

**执行后你要做的**：编辑需求定义，填写完整内容。

### 3.2 /ilink-pm — AI 需求分析

```bash
/ilink-pm kcia-1520
```

**AI 读取**：requirement.md + project-context.md
**AI 输出**：`kcia-1520-pm.master.md`（业务合同）

**业务合同包含**：
- A 层：功能摘要
- B 层：范围契约、硬约束、验收标准契约、假设与风险
- C 层：给 Designer 的调度通知

**你通常不需要审核 PM 输出。** Designer 在做设计时会天然审查 PM 的理解是否正确。
但如果你想看一眼确认 AI 是否理解了你的意图，可以快速扫一下 B1（范围契约）。

**可能的状态**：
- `PENDING_DESIGNER` — 正常，进入下一步
- `STAGING` — AI 认为需求有风险或不明确。有两种处理方式：
  - 执行 `/ilink-refine kcia-1520` 逐条确认 `[待确认]` 项（推荐）
  - 执行 `ilink-approve kcia-1520` 直接推进（承担风险）

### 3.3 /ilink-design — AI 技术设计

```bash
/ilink-design kcia-1520
```

**AI 读取**：pm.master.md + project-context.md + 源码
**AI 输出**：`kcia-1520-design.master.md`（技术设计）

**设计文档包含**：
- 设计概述和系统逻辑分析
- 技术设计方案（类设计、方法签名、接口设计）
- `[DESIGN_DECISIONS]` — AI 做的关键技术决策
- `[TASK_ALLOCATION]` — **文件级任务清单**（最重要）

**设计完成后状态为 `STAGING`**，等待你审核（见第 4 章）。

### 3.4 ilink-approve — 审核通过

```bash
ilink-approve kcia-1520
```

**前置条件**：存在 STAGING 状态的文档
**执行效果**：
- design.master.md STAGING → `PENDING_CODER`
- pm.master.md STAGING → `PENDING_DESIGNER`

> **v1.6.0 起**：每次 `ilink-approve` 都会先在独立子上下文中运行 **Coach 子流程**（仅评估你这次"沟通输入"和"直接编辑设计"的协作质量），将一段单轮反馈追加到 `iLink-doc/<story>/<story>-feedback.md`，然后再推进 Status。Coach 反馈是写给你看的（不会被 Coder/QA 读取），你可以选择参考或忽略；Coach 子流程异常**不阻塞** Status 推进。详见 §4.6。

### 3.5 /ilink-coder — AI 编码

```bash
/ilink-coder kcia-1520
```

**AI 读取**：design.master.md + project-context.md + 源码文件
**AI 输出**：修改/新增的源码文件 + `kcia-1520-code.master.md`

**重要**：Coder 直接写文件到磁盘。执行完后检查 `git diff` 查看实际变更。

**code.master.md 包含**：
- 变更清单（改了哪些文件、怎么改的）
- `[REVIEW_HANDOFF]` — 给 QA 的审查要点
- `[DEVIATIONS]` — 与设计的偏差说明（如果有的话）

### 3.6 /ilink-qa — AI 代码审查

```bash
/ilink-qa kcia-1520 1850
#                   ^^^^
#     v1.6.0 必填：当前 session/月度已用量数字
```

**执行前**：再次执行平台原生 usage 命令查看"已用"数字（详见 §3.7）。

**AI 读取**：code.master.md + 源码 + design.master.md + pm.master.md + project-context.md
**AI 输出**：
- `kcia-1520-review.master.md`（审查报告）
- 在 `kcia-1520-usage.md` 追加 review-N 行，并刷新文件末尾 `**Latest Delta**`

**可能的结论**：

| 状态 | 含义 | 你要做什么 |
|------|------|-----------|
| `COMPLETED` | 审查通过 | 你做最终审核后 `git commit` |
| `FAIL_BACK_TO_CODER` | 代码有问题，Coder 可修 | 执行 `/ilink-coder kcia-1520` 回流修复，下一次再 `/ilink-qa kcia-1520 <新已用量>` |
| `STAGING` | 上游问题（设计或需求有缺陷） | 看 `[UPSTREAM_BLOCKERS]`，可执行 `/ilink-refine` 讨论根因 |

> 回流多次 qa 时，`<story>-usage.md` 会按 review-1, review-2, ... 递增追加；Latest Delta 始终基于"最后一次 review"减"init 基线"。

### 3.7 /ilink-init 与 /ilink-qa 的 usage-value 参数（v1.6.0）

**为什么要这个参数**：让你看得见每个 Story 的真实 AI 消耗。`<story>-usage.md` 是事后归档，不参与契约链，缺失/写入失败也**不会阻塞**流水线。

**怎么取值**：在执行命令**之前**，先在当前 CLI 中输入对应原生命令，把"已用"数字读出来：

| 平台 | 查询命令 | 取哪个数字 | Usage_Unit（写入文件，自动） |
|------|---------|-----------|----------------------------|
| Claude Code | `/usage` | "% used" 的整数（如 `35`） | `claude-5h-pct` |
| Qoder | `/usage` | "已使用 credits" 的累计数（如 `1450`） | `qoder-credits-cumulative` |
| Codex | `/status` | session "tokens used"（如 `12000`） | `codex-session-tokens` |
| Gemini CLI | `/stats` | session "Total Tokens"（如 `25000`） | `gemini-session-tokens` |

**示例工作流**（以 Qoder 为例）：

```
你：/usage
Qoder 回显：已使用 1200 credits

你：/ilink-init kcia-1520 1200
（init 行写入：Usage_Value=1200，Usage_Unit=qoder-credits-cumulative）

…正常走 PM/Design/approve/Coder…

你：/usage
Qoder 回显：已使用 1850 credits

你：/ilink-qa kcia-1520 1850
（review-1 行追加：Usage_Value=1850；Latest Delta = 1850-1200 = 650）
```

**Latest Delta 的三种标注**：

| 情形 | 标注 | 解读 |
|------|------|------|
| `Usage_Value(review) > Usage_Value(init)` | `<delta> (<unit>)` | 正常，delta 即本 Story 的耗用 |
| `Usage_Value(review) < Usage_Value(init)` | `(跨 reset 边界, 不可比)` | session/月度计数被重置过（CLI 重启、Claude 5h 翻篇、Qoder 月度重置等），不可直接相减 |
| init 或 review 任一为 `0` | `<delta> (含 0 值, 不可信)` | 你某次故意跳过查询了，delta 仅供参考 |

**允许传 0**：当时无法查询（例如 CLI 卡住、网络问题、纯粹懒得查）时可以传 `0`，命令照常执行，文件正常写入但 delta 标注为"不可信"。**这是逃生通道，不要常态化使用**——0 值会污染整个 Story 的耗用统计。

**不需要 usage-value 的命令**：`/ilink-pm`、`/ilink-design`、`/ilink-coder`、`/ilink-refine`、`ilink-approve`、`ilink-status` 等中间阶段命令完全不需要传第二个参数。我们只在"开始（init）"和"收尾审查（qa）"两个时点采样。

**字段含义**（如果你打开 `<story>-usage.md` 想理解）：
- `节点`：`init` / `review-1` / `review-2` / …
- `时间戳`：`TZ=Asia/Shanghai` 当地时间
- `Usage_Value`：你传入的"已用"数字
- `Usage_Unit`：由命令硬编码，反映该平台的语义（不接受手填）

---

## 4. 审核设计——Human-Gate 实操

**这是你在整个流水线中最重要的审核节点。** 设计方向对了，后面基本不出大问题；设计方向错了，后面全部返工。

### 4.1 打开设计文档

```bash
# 查看设计文档
cat iLink-doc/kcia-1520/kcia-1520-design.master.md
```

### 4.2 审核 `[TASK_ALLOCATION]`（必看）

这是 Coder 的"白名单"。**Coder 只会修改这里列出的文件。**

```markdown
## [TASK_ALLOCATION]

| 任务 | 修改文件 | 修改类型 | 说明 |
|------|---------|---------|------|
| T-01 | .../FsLoginFailStatHandler.java | 新增 | 登录失败统计处理器 |
| T-02 | .../mapper/FsLoginFailStatMapper.xml | 新增 | MyBatis 查询映射 |
| T-03 | .../mapper/FsLoginFailStatMapper.java | 新增 | Mapper 接口 |
| T-04 | server/fs-cia-mng/.../application.yml | 修改 | 注册功能码 |
```

**你要检查**：

1. **该有的文件都列了吗？**
   - 比如新增接口通常需要：Handler + Mapper + XML + 注册配置
   - 如果少了 Mapper 接口，说明设计可能遗漏了数据层

2. **不该有的文件出现了吗？**
   - 比如你说了 Out of Scope 的某个模块，但设计里列了那个模块的文件

3. **修改类型合理吗？**
   - "修改"了一个你觉得不该碰的文件 → 要问为什么
   - "新增"的文件路径是否在正确的包下

### 4.3 审核 `[DESIGN_DECISIONS]`（必看）

```markdown
## [DESIGN_DECISIONS]

- DD-01: 选择在 fs-cia-mng 服务（SpringMVC）而非 fs-cia-lis 服务（WebFlux）中实现，
         因为统计接口是管理端功能，且 mng 已有类似的查询接口模式。

- DD-02: 使用 MultiJdbcTemplate 直接执行 SQL 而非 MyBatis Plus，
         因为统计查询涉及 GROUP BY + 日期函数，ORM 反而增加复杂度。
```

**你要检查**：
- 每个决策的理由是否成立
- 是否和你的预期一致
- 如果你不同意某个决策 → **现在修改成本最低**

### 4.4 快速审核 vs 深度审核

**简单 Story**（改配置、加简单接口）：看 `[TASK_ALLOCATION]` 的文件列表，确认没问题就 approve，1-2 分钟。

**复杂 Story**（新增模块、涉及多表关联、有性能要求）：仔细看设计概述、类设计、`[DESIGN_DECISIONS]`，可能需要 10-15 分钟。

### 4.5 审核不通过怎么办

如果设计有问题，**不要 approve**。有三种处理方式：

**方式 A（推荐）：执行 ilink-refine 修订**
```bash
/ilink-refine kcia-1520
# AI 会列出设计中的关键决策和待确认项
# 你逐条告诉 AI 哪些要改，AI 在原文档上就地修改
# 修订完成后执行 ilink-approve
```

**方式 B：你手动修改设计文档**
直接编辑 `design.master.md`，改完后执行 `ilink-approve kcia-1520`。

**方式 C：修改上游重跑**
如果根因在 PM 的需求理解，修改需求定义后重新执行 `/ilink-pm` 和 `/ilink-design`。

### 4.6 Coach 协作复盘（v1.6.0 新增）

每次 `ilink-approve` 都会触发一段 **Coach 协作复盘**，目的不是评价代码或设计本身，而是**评价你与 AI 协作的质量**——你提的问题精不精准？你定的范围严不严密？你直接编辑设计文档时，改动是否过界？

#### 4.6.1 Coach 在评什么

Coach 看两类输入：

1. **沟通输入**：从 `/ilink-pm` 完成到 `/ilink-approve` 之间，你说过的话（PM 段 + Design 段两段独立评估）。
2. **直接编辑**：本次 approve 推进的是 design 时，对比上一次 `/ilink-design` 的快照，看你手动改了什么、改了多少。

评估维度（评的是**你的输入**，不是 AI 的输出）：

| 维度 | 评估视角 |
|------|---------|
| 精准性 | 你的描述是否具体到 AC/字段/接口，还是停留在抽象目标 |
| 完善性 | 你是否覆盖了边界、异常、回滚等 AI 可能漏掉的角度 |
| 严密性 | 你的诉求之间是否自洽，有没有相互冲突的要求 |
| 清晰性 | AI 是否多次反问、是否表现出明显的歧义 |
| 抽象层 | 你是否在合适的层次表达——别在需求层讨论实现细节 |
| 范围纪律 | 你有没有在编码阶段口头追加需求、在 PM 段讨论实现 |

直接编辑额外看：可追溯性（改动是否在对话中讨论过）、改动幅度（是否远超本次讨论范围）。

#### 4.6.2 Coach 反馈写到哪里

`iLink-doc/<story>/<story>-feedback.md`——**单文件、追加写入、不带 Metadata**。每次 approve 追加一段时间戳标题的反馈，永不覆盖历史。

**反馈是写给你的，下游 AI 不会读它。** 它对流水线状态零影响——你可以参考、可以忽略，但请把它纳入 Git 提交，团队可以回看自己的协作轨迹。

#### 4.6.3 Coach 的产出形式

每次反馈是一段简短 Markdown，包含：

- **PM 段** / **Design 段** 各一段（2-3 句）：肯定 1 项 + 改进 ≤3 项，必须带 `[turn-N]` 或 `@diff-hunk` 证据
- **直接编辑反馈**（仅 design）：合规改动、问题改动、改动幅度判定
- **下次更高效的 1 句话**：可执行、聚焦最痛的一点

Coach 的写作纪律：**不献媚、不自我美化、不空话**。如果某段确实没有可改进项，会明确写"无显著改进点"，不会硬凑。

#### 4.6.4 你不需要做什么

- ✅ 你**不需要**回复 Coach 反馈
- ✅ 你**不需要**为了"看起来沟通良好"修改自己的提问方式
- ✅ Coach 异常时（子上下文返回失败/为空）**不阻塞** approve，会记录"Coach 子流程异常"后继续推进
- ✅ 直接编辑 design 时，建议保留 `iLink-doc/<story>/.snapshots/` 目录（已自动加入 `.gitignore`），它是 Coach 计算编辑 diff 的依据

---

## 5. 修订 STAGING 文档——ilink-refine 实操

### 5.1 什么是 ilink-refine

`ilink-refine` 是 iLink 的**修订对话协议**。当文档处于 STAGING 状态时，你可以通过它与 AI 逐条确认阻塞项，而**不需要重新生成整个文档**。

### 5.2 什么时候用

| 场景 | 是否用 refine |
|------|-------------|
| PM 输出 STAGING，有 `[待确认]` 项 | ✅ 用 refine 逐条确认 |
| Designer 输出 STAGING，你想微调设计决策 | ✅ 用 refine 讨论修改 |
| QA 输出 STAGING（上游根因），需讨论处理路径 | ✅ 用 refine 讨论根因 |
| 你已经知道答案，想直接推进 | ❌ 直接 `ilink-approve` |
| 需要大幅调整方向 | ❌ 修改上游重跑更合适 |

### 5.3 操作流程

```bash
# 1. 执行 refine
/ilink-refine kcia-1520

# 2. AI 会：
#    - 找到当前 STAGING 的文档（优先级：review > design > pm）
#    - 列出所有阻塞项（[待确认]、[UPSTREAM_BLOCKERS] 等）
#    - 逐条向你确认

# 3. 你逐条给出决策：
#    "AR-03 的假设成立，基础平台组确认本季度不升级 KDEncode"
#    → AI 记录为 [已确认 2026-04-14: 基础平台组确认本季度不升级 KDEncode]

# 4. 所有阻塞项处理完后
ilink-approve kcia-1520      # 正式推进状态
```

### 5.4 refine 的关键规则

- **修订不是重生成**：AI 只修改被讨论的条目，保留文档其余内容不变
- **状态不变**：refine 完成后文档仍是 STAGING，状态推进由 `ilink-approve` 负责
- **`[已确认]` 格式**：`[已确认 YYYY-MM-DD: <人类给出的决策依据>]`
- **`[已确认]` 的效力**：下游角色 MUST 将其视为绑定约束，不再质疑

### 5.5 各角色文档的 refine 重点

| 文档 | 阻塞项位置 | refine 目标 |
|------|-----------|------------|
| pm.master.md | B5 `[待确认]` + C1 通知项 | 逐条确认假设与风险 |
| design.master.md | [DESIGN_DECISIONS] 风险应对表 | 确认技术方向和设计假设 |
| review.master.md（STAGING） | [UPSTREAM_BLOCKERS] | 讨论上游根因，明确修改路径 |

---

## 6. 回流与熔断——出了问题怎么办

### 6.1 正常回流

QA 审查发现代码有问题，判定根因在 Coder 时：

```
QA 输出 Status: FAIL_BACK_TO_CODER
    ↓
你执行: /ilink-coder kcia-1520    ← Coder 读取 QA 的 [FIX_REQUESTS]
    ↓
Coder 修复后，先 /usage 或 /stats 查当前已用量，再执行:
    /ilink-qa kcia-1520 <新已用量>   ← 写入 review-2 行
```

**Coder 在回流时只修复 QA 指出的问题**，不会做额外修改。

### 6.2 回流计数与熔断

每次回流，`.retry_count` 文件中的计数 +1。

```
第 1 次回流 → 正常，Coder 修复
第 2 次回流 → 正常，Coder 修复
第 3 次回流 → 触发熔断警告 ⚠️
```

**熔断意味着**：AI 自动修复了 3 次还没通过 QA。这通常说明：
- 需求或设计本身有问题
- 或者修复方向偏离了

**你需要做的**：
1. 阅读最新的 `review.master.md`，看 QA 指出的问题
2. 阅读 `code.master.md` 中的 `[FIX_RESPONSE]`，看 Coder 尝试了什么
3. 判断是设计问题还是实现问题
4. 如果是设计问题 → 回到 Designer 阶段重新设计
5. 如果是实现问题 → 你手动介入修复代码

### 6.3 上游问题（STAGING）

QA 判定问题根因不在 Coder，而在设计或需求时：

```
QA 输出 Status: STAGING
    ↓
查看 review.master.md 中的 [UPSTREAM_BLOCKERS]
    ↓
执行 /ilink-refine kcia-1520（与 AI 讨论根因，明确修改路径）
    ↓
根据讨论结果决定：
├── 需求问题 → 修改需求定义，从 /ilink-pm 重新开始
└── 设计问题 → 修改设计或重新执行 /ilink-design
```

---

## 7. 维护 project-context.md

### 7.1 什么是 project-context.md

这是你项目的**知识库**，位于项目根目录。所有 AI 角色在执行任何任务前都会读它。

它包含：
- 项目概述和技术栈
- 技术约束（Java 版本、框架约束等）
- 模块职责和依赖关系
- 架构原则
- 构建命令
- 特殊说明

### 7.2 什么时候更新

| 发生了什么 | 是否更新 | 更新哪个章节 |
|-----------|---------|------------|
| 新增了一个子模块 | ✅ | §3 模块职责 |
| 升级了 Java 版本 | ✅ | §2 技术约束 |
| 换了构建命令或 profile | ✅ | §6 构建与测试 |
| 引入了新的框架或中间件 | ✅ | §2 技术约束 + §4 架构原则 |
| 修了一个 bug | ❌ | — |
| 加了几个接口 | ❌ | — |
| 重构了包命名 | ✅ | §5 包命名规范 |

### 7.3 怎么更新

**最简单的方式**：直接在对话中告诉 AI。

```
请更新 project-context.md：
- 技术约束新增：引入了 Kafka 2.8 作为消息队列
- 构建命令新增：mvn clean package -P kafka -pl server/fs-cia-lis -am -DskipTests
```

AI 会自动把信息写到 `project-context.md` 的对应章节。

**手动更新也可以**：直接编辑 `project-context.md` 文件。

### 7.4 不要写到 CLAUDE.md 或 AGENTS.md

**这两个文件是路由文件，不是知识库。** 它们的作用是引导 AI 去读 `project-context.md`。

如果你把项目信息写在 `CLAUDE.md` 里，会导致：
- `CLAUDE.md` 说一件事，`project-context.md` 说另一件事
- AI 不确定以哪个为准
- 不同平台（Claude/Codex/Qoder/Gemini）看到不同的信息

**所有项目知识 → `project-context.md`，无例外。**

---

## 8. 多 Story 并行开发

### 8.1 Story 隔离

每个 Story 有独立的目录和文档链：

```
iLink-doc/
├── kcia-1520/     ← Story A 的所有文档
│   ├── kcia-1520-requirement.md
│   ├── kcia-1520-pm.master.md
│   └── ...
└── kcia-1521/     ← Story B 的所有文档，完全隔离
    ├── kcia-1521-requirement.md
    └── ...
```

**文档层面完全隔离**，互不影响。

### 8.2 什么时候可以并行

| 场景 | 能否并行 | 原因 |
|------|---------|------|
| 两个 Story 改不同模块的不同文件 | ✅ 可以 | 无代码冲突 |
| 两个 Story 改同一个模块的不同文件 | ⚠️ 小心 | 可能有编译依赖 |
| 两个 Story 改同一个文件 | ❌ 串行 | 会有 Git 冲突 |
| 两个 Story 都改数据库 | ⚠️ 小心 | migration 顺序可能冲突 |

### 8.3 并行开发的建议

1. **先看 `[TASK_ALLOCATION]`**：两个 Story 的设计完成后，对比文件清单是否有交集
2. **无交集 → 放心并行**
3. **有交集 → 串行处理**：先完成并提交一个，再开始另一个
4. **不确定 → 问 AI**：在对话中描述两个 Story 的范围，让 AI 判断是否有冲突

### 8.4 不同人做不同 Story

同事 A 用 Claude Code 做 kcia-1520，同事 B 用 Qoder 做 kcia-1521——完全没问题。

两个人读的是同一份 `project-context.md`，产出到不同的 Story 目录，最终各自 `git commit`。

---

## 9. 常见问题排查

### 9.1 AI 说"找不到需求定义文件"

**原因**：你执行了 `/ilink-pm kcia-1520` 但没有先执行 `/ilink-init kcia-1520 <usage-value>`。

**解决**：
```bash
# v1.6.0：先在 CLI 中查"已用量"（详见 §3.7），再传入第二个参数
/ilink-init kcia-1520 1200
# 编辑需求定义后再执行
/ilink-pm kcia-1520
```

### 9.2 Designer 输出了 STAGING 但我觉得设计没问题

`STAGING` 是 Designer 的**默认状态**，所有设计都需要你审核后手动推进。这不是异常，而是 Human-Gate 机制的正常表现。

**解决**：审核设计后执行 `ilink-approve kcia-1520`。

### 9.3 PM 输出了 STAGING，有 `[待确认]` 项

**解决**：
```bash
# 推荐：使用 refine 逐条确认
/ilink-refine kcia-1520
# AI 会列出所有 [待确认] 项，你逐条给出决策
# 完成后执行 ilink-approve

# 或者：直接推进（承担风险）
ilink-approve kcia-1520
```

### 9.4 Coder 改了不在设计清单里的文件

查看 `code.master.md` 中的 `[DEVIATIONS]` 章节。Coder 如果偏离了设计，应该在这里说明理由。

**判断**：
- 理由合理（如发现设计遗漏了必要的依赖文件）→ 接受
- 理由不合理 → QA 通常会捕获这个问题；也可以手动撤销后重新执行

### 9.5 QA 一直 FAIL_BACK_TO_CODER，循环修不好

看 `ilink-status kcia-1520` 的回流次数：
- 1-2 次回流 → 正常，继续让 Coder 修
- 3 次 → 触发熔断，人工介入（见第 6.2 节）

### 9.6 project-context.md 内容过时了

```bash
/ilink-bootstrap
```

重新执行 Bootstrap 会**重新分析项目**并更新 `project-context.md`。不会覆盖你手动添加的内容，但会补充新发现的信息。

或者直接在对话中说："请更新 project-context.md 中的 §2 技术约束，Java 版本已从 8 升级到 17"。

### 9.7 我想跳过某个阶段

**强烈不建议**，但如果你确实需要：

| 想跳过 | 后果 | 替代方案 |
|-------|------|---------|
| PM | Designer 没有业务边界，设计可能发散 | PM 很快（30 秒），别跳 |
| Designer | Coder 没有文件清单，可能乱改 | 自己写个简单的设计要点给 Coder |
| Human-Gate | 设计未审核就编码，风险自担 | 快速扫一眼就 approve |
| QA | 没有代码审查，bug 风险增加 | QA 也很快（1-2 分钟），别跳 |

### 9.8 我想在非 iLink 模式下和 AI 对话

完全可以。iLink 不阻止你正常使用 AI。

执行了 Bootstrap 之后，AI 会读到 `CLAUDE.md` / `AGENTS.md` 中的 iLink 引导，但这只让 AI 知道项目知识在哪里。你可以正常问问题、让 AI 帮你改代码、debug 等等。

**区别**：非 iLink 模式下的修改不会有 Master Doc 记录，也不会经过链式审查。适合快速修复、探索性工作、或与 iLink 无关的任务。

---

## 10. 反模式——千万别这样做

### ❌ 反模式 1：需求写一句话就开工

```
## 1. 功能描述
优化登录
```

**后果**：PM 输出的业务合同范围模糊 → Designer 猜测设计方向 → Coder 写的代码可能不是你想要的 → 来回返工 3 轮。

**正确做法**：花 10 分钟写清楚功能范围和验收标准。

### ❌ 反模式 2：不审设计就 approve

```bash
/ilink-design kcia-1520
ilink-approve kcia-1520    # 看都不看就 approve
```

**后果**：设计方向如果有偏差，Coder 按错误方向写的代码，QA 按错误基线审查，全链路错。Coder 写的代码越多，浪费越大。

**正确做法**：至少看 `[TASK_ALLOCATION]` 的文件列表和 `[DESIGN_DECISIONS]`，确认方向正确。

### ❌ 反模式 3：在 Coder 阶段口头追加需求

```
"代码写得不错，顺便把登录日志也改一下吧"
```

**后果**：Coder 有白名单约束，追加的需求不在设计文件清单里。要么 Coder 拒绝（你觉得不灵活），要么 Coder 违反协议（QA 会标记偏差）。

**正确做法**：追加的需求开一个新 Story，或回到 Designer 阶段更新设计。

### ❌ 反模式 4：手动改了代码后继续走流水线

```
在 /ilink-coder 之后，你手动改了几个文件
然后执行 /ilink-qa
```

**后果**：QA 审查时对照的是 `code.master.md` 中的变更清单，你手动改的文件不在清单里。QA 可能漏审你的修改，也可能因为代码和 code.master.md 不一致而困惑。

**正确做法**：
- 小修改 → 在 QA 之后手动改，然后一起提交
- 大修改 → 回到 Coder 阶段重新执行，让 AI 把你的修改纳入变更清单

### ❌ 反模式 5：多人同时处理同一个 Story

```
同事 A 在执行 /ilink-design kcia-1520
同事 B 也在执行 /ilink-design kcia-1520
```

**后果**：两个 AI 实例同时写同一个 `design.master.md`，后写的覆盖先写的。

**正确做法**：一个 Story 在任一时刻只有一个人操作。

### ❌ 反模式 6：忽略 `[待确认]` 标记一路推进

```
PM 输出 STAGING，有 3 个 [待确认] 项
直接 ilink-approve，不看不管
Designer 基于猜测做设计
Coder 基于猜测写代码
最终发现猜错了，全部返工
```

**后果**：`[待确认]` 项原样传入下游，下游角色只能基于假设工作。假设错了，全链路返工。

**正确做法**：执行 `/ilink-refine` 逐条确认，花 5 分钟确认能省 2 小时返工。

---

## 11. 认知模式——Domain Knowledge

### 11.1 什么是认知模式

iLink v1.3 新增了**认知模式**，与交付模式（PM→Designer→Coder→QA）并行的独立工作线。

**交付模式**：AI 帮团队完成开发任务（写代码）
**认知模式**：AI 帮团队沉淀对现有代码的深度理解（写知识文档）

两条工作线独立运行，互不依赖。

### 11.2 什么是 Domain Knowledge

Domain Knowledge 是 AI 阅读现有源码后生成的结构化认知文档，包含 10 个标准章节：

| 章节 | 内容 |
|------|------|
| §1 模块概述 | 定位、职责边界、技术栈 |
| §2 业务实体 | 核心数据结构和关键字段 |
| §3 流程概览 | 核心业务流程（主流程 + 分支） |
| §4 内部机制 | 缓存策略、线程模型、状态机等 |
| §5 业务规则 | 从代码中提取的硬编码规则 |
| §6 设计决策 | 架构选型和权衡 |
| §7 配置参数 | 可调参数清单 |
| §8 故障模式 | 已知的失败路径和恢复策略 |
| §9 见贤思齐 | 与国际同类产品对标（如 Keycloak、Redis），将设计理念与工程实现分开评价 |
| §10 待确认事项 | AI 无法从代码确定的问题 |

#### §9「见贤思齐」：目的、方法与典型结论

**目的**：帮助团队既看到设计的精妙之处，也认清代码的真实质量。避免把"理论上的好设计"等同于"实践中的好代码"。

**方法**：选取国际同类产品或知名开源项目作为参照系，每个评价维度分别给出"设计理念评级"和"工程实现评级"（1-5 星）：

| 维度 | 回答的问题 | 评价内容 |
|------|-----------|---------|
| **设计理念** | "这个设计本身好不好？" | 架构选型、模式选择、抽象层次的合理性 |
| **工程实现** | "这个代码写得好不好？" | 代码质量、命名规范、重复代码、类职责等 |

**典型结论**：比如"流程编排模型设计理念 ★★★★☆，工程实现 ★★☆☆☆"——理念上三层配置+双层分离设计优秀，但实现上同名不同类、新旧版本并存、80+ 处命名问题把可维护性拉低。

**根本性反思**：设计理念决定上限，工程实现决定下限。好的设计如果没有好的实现来支撑，最终会变成"理论上的好设计，实践中的烂摊子"。

### 11.3 什么时候用

Domain Knowledge 适用于**已有的核心模块**，不适用于全新模块的开发。

| 场景 | 是否适用 |
|------|---------|
| 核心模块（认证、交易、清算）缺乏文档 | ✅ 非常适合 |
| 新人接手老模块，需要快速理解 | ✅ 非常适合 |
| 团队想对标国际产品做架构评估 | ✅ 适合 |
| 正在开发的全新功能模块 | ❌ 不适用（代码还不存在） |

### 11.4 怎么用

```bash
# 执行 Domain Engineer
/ilink-domain auth

# AI 会：
# 1. 阅读 auth 相关源码
# 2. 生成 iLink-doc/domain/auth-domain-knowledge.md
# 3. 标记 [待确认] 项，提示你审核

# 审核后在需求定义中关联（可选）：
# 后续涉及 auth 模块的需求，可在需求定义中指定：
# ## 关联领域知识（可选）
# iLink-doc/domain/auth-domain-knowledge.md
```

**Domain Knowledge 的审核很重要**：AI 生成的内容（尤其是§9「见贤思齐」）可能包含推测性内容，资深工程师应逐章审核，将 `[待确认]` 项确认为 `[已确认]`。重点审核「见贤思齐」章节中的对标结论和评级是否客观准确。

### 11.5 与交付流水线的关系

Domain Knowledge 对交付流水线是**可选增强**：

- 人类在需求定义中通过"关联领域知识"字段指定 Domain Knowledge 文件路径
- PM 会参考其中的业务规则（§5）
- Designer 会参考其中的业务实体（§2）、设计决策（§6）和见贤思齐（§9）
- 不指定则流水线照常运行，不受影响

---

## 附录 A：命令速查表

### 核心流水线命令（交付模式）

| 命令 | 阶段 | 谁执行 | 输出文件 |
|------|------|-------|---------|
| `/ilink-init <story> <usage-value>` | 初始化（v1.6.0：usage-value 必填） | 人类 | 需求定义模板 + `<story>-usage.md`（init 行） |
| `/ilink-pm <story>` | 需求分析 | AI | `<story>-pm.master.md` |
| `/ilink-design <story>` | 技术设计 | AI | `<story>-design.master.md` |
| `ilink-approve <story>` | 审核推进 | 人类 | （更新 Metadata Status + Coach 子流程追加 `<story>-feedback.md`） |
| `/ilink-coder <story>` | 编码 | AI | 源码文件 + `<story>-code.master.md` |
| `/ilink-qa <story> <usage-value>` | 审查（v1.6.0：usage-value 必填） | AI | `<story>-review.master.md` + `<story>-usage.md` 追加 review-N 行 |

> **v1.6.0 usage-value**：传入"当前 session/月度已用量"的整数。各平台原生命令：Claude `/usage`、Qoder `/usage`、Codex `/status`、Gemini `/stats`。详见 §3.7。

### 认知模式命令

| 命令 | 阶段 | 谁执行 | 输出文件 |
|------|------|-------|---------|
| `/ilink-domain <module>` | 认知分析 | AI | `domain/<module>-domain-knowledge.md` |

### 辅助命令

| 命令 | 用途 | 谁执行 |
|------|------|-------|
| `/ilink-refine <story>` | 修订 STAGING 文档（逐条确认阻塞项） | AI + 人类 |
| `ilink-status [story]` | 查看流水线状态与下一步建议 | 人类 |
| `/ilink-bootstrap` | 项目冷启动（生成项目知识库） | AI |

**注**：`/ilink-*` 是 AI 执行的 slash command，`ilink-*`（无斜杠）是 shell 脚本。

---

## 附录 B：文件地图

```
<project_root>/
├── project-context.md              ← 项目知识库（AI 每次都读）
├── CLAUDE.md                       ← Claude 入口路由
├── AGENTS.md                       ← Codex/其他 AI 入口路由
│
├── iLink/                          ← 框架文件（不要修改）
│   ├── iLink-root-spec.md             ← 根规范
│   ├── iLink-implementation-guide.md  ← 实施手册
│   └── souls/                         ← 角色规范
│       ├── universal.soul.md
│       ├── pm.soul.md
│       ├── design.soul.md
│       ├── coder.soul.md
│       ├── qa.soul.md
│       ├── domain.soul.md              ← 认知模式：Domain Engineer
│       ├── sdd.soul.md                 ← SDD 评估（v1.4.11）
│       └── coach.soul.md               ← 协作复盘（v1.6.0）
│
├── iLink-doc/                      ← 文档归档（提交到 Git）
│   ├── domain/                        ← Domain Knowledge（认知模式）
│   │   └── <module>-domain-knowledge.md
│   ├── kcia-1520/
│   │   ├── kcia-1520-requirement.md    ← 你写的
│   │   ├── kcia-1520-pm.master.md      ← AI 写的
│   │   ├── kcia-1520-design.master.md  ← AI 写的，你审核的
│   │   ├── kcia-1520-code.master.md    ← AI 写的
│   │   ├── kcia-1520-review.master.md  ← AI 写的
│   │   ├── kcia-1520-feedback.md       ← Coach 写的（v1.6.0）
│   │   ├── kcia-1520-usage.md          ← init/qa 时写入的耗用追踪（v1.6.0）
│   │   └── .snapshots/                 ← design 快照（v1.6.0，不提交）
│   └── kcia-1521/
│       └── ...
│
├── .claude/commands/               ← Claude CLI 命令
├── .codex/commands/                ← Codex CLI 命令
├── .qoder/commands/                ← Qoder CLI 命令
├── .gemini/commands/               ← Gemini CLI 命令
└── src/                            ← 源代码
```

**提交规则**：
- ✅ 提交：`iLink-doc/`（含 `<story>-feedback.md`、`<story>-usage.md`）、`project-context.md`、`CLAUDE.md`、`AGENTS.md`、`iLink/`、源码
- ❌ 不提交：`.retry_count`（信号文件）、`iLink-doc/<story>/.snapshots/`（design 快照，仅本地用于 Coach diff）

---

## 附录 C：状态流转图

```
                          ┌─────────────────────────────┐
                          │ /ilink-init <story> <usage> │
                          │  （人类创建Story + usage基线） │
                          └─────────────┬───────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  编辑需求定义     │
                          │ （人类手写）      │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │   /ilink-pm      │     STAGING
                          │ （AI 需求分析）   │───→ /ilink-refine 确认
                          └────────┬────────┘     → ilink-approve 推进
                                   │
                          PENDING_DESIGNER
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  /ilink-design   │
                          │ （AI 技术设计）   │
                          └────────┬────────┘
                                   │
                              STAGING ← 默认
                                   │
                                   ▼
                          ┌─────────────────┐
                     ⛔   │  人类审核设计     │
                          │  /ilink-refine   │ ← 可选：修订设计
                          │  ilink-approve   │ ← 推进
                          └────────┬────────┘
                                   │
                          PENDING_CODER
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  /ilink-coder    │
                          │ （AI 编码）       │
                          └────────┬────────┘
                                   │
                             PENDING_QA
                                   │
                                   ▼
                          ┌─────────────────────────────┐
                          │  /ilink-qa <story> <usage>  │
                          │ （AI 代码审查 + usage delta） │
                          └─────────────┬───────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
              COMPLETED    FAIL_BACK_TO     STAGING
              （通过）      _CODER          （上游问题）
                 │         （代码问题）         │
                 │              │              │
                 ▼              ▼              ▼
            git commit    /ilink-coder   /ilink-refine
                          （回流修复）    （讨论根因）
                               │
                               ▼
                          /ilink-qa
                          （重新审查）
                               │
                          ≥3次回流？
                          ├─ 否 → 继续
                          └─ 是 → ⚠️ 熔断，人工介入
```

---
