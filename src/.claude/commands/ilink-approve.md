你现在执行 iLink 的 **审核通过（Human-Gate 推进 + Coach 协作复盘）** 操作。

> 本命令自 v1.6.0 起为 Slash Command（不再是 shell 脚本），内部串行执行：**校验前置 → 调用 Coach 子流程 → 写入 feedback.md → 推进 Status**。Coach 子流程详见 `iLink/iLink-root-spec.md` §4.7 与 `iLink/souls/coach.soul.md`。

## 执行任务

在 Story `$ARGUMENTS` 中找到处于 STAGING 状态的文档，先执行 Coach 子流程，再将其推进到下一阶段。

---

### 步骤 1：确认 Story 存在

检查 `iLink-doc/$ARGUMENTS/` 目录是否存在，不存在则提示用户先执行 `/ilink-init $ARGUMENTS`，结束。

### 步骤 2：按优先级查找 STAGING 文档

依次读取以下文件末尾的 Metadata Status，确定本次 approve 的目标文档：

| 优先级 | 文档 | STAGING 时的目标状态 | 后续命令 |
|-------|------|-------------------|---------|
| 1 | `$ARGUMENTS-review.master.md` | **不能自动推进**（上游根因） | 告知用户查看 [UPSTREAM_BLOCKERS]，与 Designer 讨论修改设计或修改需求定义后结束 |
| 2 | `$ARGUMENTS-design.master.md` | `PENDING_CODER` | `/ilink-coder $ARGUMENTS` |
| 3 | `$ARGUMENTS-pm.master.md` | `PENDING_DESIGNER` | `/ilink-design $ARGUMENTS` |

如果没有找到 STAGING 文档，告知用户当前没有需要审核的文档，建议执行 `/ilink-status $ARGUMENTS` 查看详细状态后结束。

> **注意**：QA review 文档处于 STAGING（上游根因）时 SHALL NOT 推进 Status，但 Coach 子流程仍 MUST 执行（评估的是这一轮人类与 AI 的协作，与 Status 是否推进无关）。

---

### 步骤 3：调用 Coach 子流程

读取 `iLink/souls/coach.soul.md`（Coach 角色规范）。

#### 3.1 摘录对话 bracket

按以下规则在**当前 Host CLI 主对话**中识别 bracket：

- **外层窗口起点**：本 Story 的 `/ilink-pm $ARGUMENTS` 命令完成之后的第一个人类 turn
- **外层窗口终点**：本次 `/ilink-approve $ARGUMENTS` 调用之前的最后一个人类 turn
- **内部分界**：外层内的 `/ilink-design $ARGUMENTS` slash 调用 turn

逐 turn 摘录原文，标注格式：
```
[turn-1] (user)
<原文>

[turn-2] (assistant)
<原文>

...

[--- /ilink-design 分界 ---]

[turn-N] (user)
...
```

**SHALL NOT** 改写、概括或选择性剔除任何 turn 的内容。

#### 3.2 计算直接编辑 diff

- 列出 `iLink-doc/$ARGUMENTS/.snapshots/` 目录下所有 `design.master.*.md` 文件
- 选择**最新**的快照（按文件名时间戳降序取第一个）
- 使用 `diff -u <最新快照> iLink-doc/$ARGUMENTS/$ARGUMENTS-design.master.md` 生成 unified diff
- 若 `.snapshots/` 目录不存在或为空，记录"无法判定直接编辑（缺少 design 快照）"

> 若本次目标是 PM 文档（步骤 2 命中优先级 3），跳过 3.2，直接编辑段记为"本段无直接编辑（PM 文档不做编辑检测）"。

#### 3.3 调用 subagent

通过 Agent 工具（`general-purpose` 类型）调用 subagent，传入以下 bundle（**SHALL NOT 传入 master doc、requirement.md、源码**）：

- `coach.soul.md` 全文
- 3.1 的对话摘录
- 3.2 的 diff 文本（或缺失说明）
- 当前时间戳：`TZ=Asia/Shanghai date +%Y-%m-%dT%H:%M:%S+08:00`

提示词模板：
```
你是 iLink Coach 子流程。请严格按照下方 coach.soul.md 的执行步骤（§6）和输出格式（§7）评估对话与 diff，输出单轮反馈 Markdown 段落。

【时间戳】<填入>

【coach.soul.md】
<填入全文>

【对话摘录】
<填入 3.1 内容>

【design diff】
<填入 3.2 内容>

请直接返回 §7.2 骨架对应的 Markdown 段落（不要包含其他解释）。
```

#### 3.4 追加写入 feedback.md

- 文件路径：`iLink-doc/$ARGUMENTS/$ARGUMENTS-feedback.md`
- 文件不存在时新建，**不写入** Metadata 印章
- 将 subagent 返回内容**追加**到文件末尾（前后加一个空行），SHALL NOT 覆盖历史轮次

#### 3.5 异常处理

如 subagent 调用失败或返回内容为空，**SHALL NOT 阻塞**后续 Status 推进。在 feedback.md 追加错误段：
```
## <时间戳> approve 复盘

> **Coach 子流程异常**：<简要错误原因>。本轮跳过协作复盘，Status 推进不受影响。
```

---

### 步骤 4：推进 Status

仅当步骤 2 命中优先级 2 或 3 时执行。使用 Edit 工具，在对应 STAGING 文档的 Metadata 区块中将 `Status: STAGING` 替换为目标状态值（PENDING_CODER 或 PENDING_DESIGNER）。

> 步骤 2 命中优先级 1（QA review STAGING）时跳过本步骤——Status 保持 STAGING，由人类讨论上游根因后另行处理。

---

### 步骤 5：报告

向用户报告以下内容：

1. ✅ Coach 反馈已追加到 `iLink-doc/$ARGUMENTS/$ARGUMENTS-feedback.md`
2. Status 推进结果（或"未推进"及原因）
3. 提示下一步命令（参见步骤 2 表格"后续命令"列）

> Coach 反馈不参与下游 AI 角色（Coder / QA）的输入读取——它只服务于人类的协作复盘，MUST 提交到 git 便于团队趋势观察。
