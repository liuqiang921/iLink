# ilink-approve

Run the iLink Human-Gate advance: Coach reflection subprocess (design-only) + Status advance.

## Usage

```
/ilink-approve <story>
```

## Preparation

The bash script `.qoder/commands/ilink-approve <story>` has already validated the STAGING document and reported which document will be advanced. Now in this slash invocation:

1. Read `iLink/iLink-root-spec.md` §4.7 (Coach role contract) and §6.4 (ilink-approve protocol)
2. Read `iLink/souls/coach.soul.md` (Coach role specification)

## Task

Execute the following steps in order. **Coach subprocess errors SHALL NOT block Status advance.**

### Step 1: Resolve target STAGING document

Re-confirm the STAGING document by checking, in priority order:

1. `iLink-doc/<story>/<story>-review.master.md` → if STAGING, target is QA review (no Status advance, Coach skipped)
2. `iLink-doc/<story>/<story>-design.master.md` → if STAGING, target advances to `PENDING_CODER`
3. `iLink-doc/<story>/<story>-pm.master.md` → if STAGING, target advances to `PENDING_DESIGNER`

If no STAGING document found, tell the user and stop.

Record `target_role` as `review` / `design` / `pm` for use in subsequent steps.

### Step 2: Coach subprocess（仅当 target_role == "design" 时执行）

> Root Spec §6.4：Coach 子流程仅在 design.master.md 推进场景启用。PM 与 review 推进场景跳过 Coach，但 MUST 保留 Status 推进逻辑。

If `target_role != "design"`，skip Steps 2.1–2.5，record `"本轮非 design 推进，跳过 Coach"`，and proceed directly to Step 3.

#### 2.1 Excerpt conversation bracket

Identify in the **current Qoder chat session**:

- **Outer window start**: first human turn after the `ilink-pm <story>` / `/ilink-pm <story>` invocation
- **Outer window end**: last human turn before this `/ilink-approve <story>` invocation
- **Internal divider**: the `/ilink-design <story>` (or `ilink-design <story>`) slash invocation turn

Excerpt every turn verbatim with `[turn-N] (user|assistant)` labels. Mark the divider as `[--- /ilink-design 分界 ---]`. **SHALL NOT** rewrite, summarize, or selectively skip turns.

#### 2.2 Compute design diff

- List `iLink-doc/<story>/.snapshots/design.master.*.md`
- Pick the latest by filename sort (descending)
- Run `diff -u <latest_snapshot> iLink-doc/<story>/<story>-design.master.md` to produce unified diff
- If no snapshot exists, record `"无法判定直接编辑（缺少 design 快照）"`

#### 2.3 Invoke Coach subagent

通过 Agent 工具（`general-purpose` 类型）调用 subagent。**SHALL NOT** 传入 master doc、requirement.md 或源码。

若当前环境不暴露 Agent 工具，请在当前对话中以"角色扮演 Coach 子流程"方式给出输出，并显式声明"未启用 fresh-context"。

调用方式：使用 Agent 工具，subagent_type 设为 `general-purpose`，prompt 填入下方模板内容。

Prompt template:
```
你是 iLink Coach 子流程。请严格按照下方 coach.soul.md 的执行步骤（§6）和输出格式（§7）评估对话与 diff，输出单轮反馈 Markdown 段落。

请使用下方【时间戳】的值作为 §7.2 骨架中的分节标题（## <时间戳值> approve 复盘）。

【时间戳】<TZ=Asia/Shanghai date +%Y-%m-%dT%H:%M:%S+08:00>

【coach.soul.md】
<full content>

【对话摘录】
<2.1 content>

【design diff】
<2.2 content>

请直接返回 §7.2 骨架对应的 Markdown 段落（不要包含其他解释）。以 ## <时间戳值> approve 复盘 开头。
```

#### 2.4 Append to feedback.md

- Path: `iLink-doc/<story>/<story>-feedback.md`
- Create the file if missing. **SHALL NOT** add `ILINK-PROTOCOL-METADATA` stamp.
- **Append** a blank line, then the subagent's response. **SHALL NOT** overwrite history.
- 如果 subagent 响应未以 `## <timestamp> approve 复盘` 标题行开头，Parent AI MUST 在响应前插入该标题行（使用 Step 2.3 prompt 中的同一时间戳）。

#### 2.5 Error handling

If subagent call fails or returns empty, append this error block to feedback.md and continue:
```
## <timestamp> approve 复盘

> **Coach 子流程异常**：<原因>。本轮跳过协作复盘，Status 推进不受影响。
```

### Step 3: Advance Status

Only when target is `design` or `pm`:

Use Edit/Write to replace `Status: STAGING` with the target status (`PENDING_CODER` or `PENDING_DESIGNER`) in the STAGING document's `# ILINK-PROTOCOL-METADATA` block.

When target is `review` (QA STAGING — upstream root-cause), **skip Status advance**. Tell the user to discuss upstream root cause, then re-run.

### Step 4: Report

Output to the user:

1. Coach 结果：
   - design target → ✅ Coach feedback appended to `iLink-doc/<story>/<story>-feedback.md`
   - PM/review target → ⏭️ Coach skipped（非 design 推进场景）
2. Status advance result (or "not advanced" with reason)
3. Next command:
   - design → `/ilink-coder <story>`
   - pm → `/ilink-design <story>`
   - review → discuss upstream blockers, then modify design or requirement and re-run

> Coach feedback is **NOT** consumed by downstream AI (Coder/QA). It serves human collaboration retrospection only. Commit `<story>-feedback.md` to git for team trend review.
