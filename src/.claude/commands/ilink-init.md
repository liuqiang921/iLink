你现在执行 iLink 的 **Story 初始化** 操作。

## 参数解析

`$ARGUMENTS` 包含两个由空格分隔的参数：`<story-id> <usage-value>`。

- `<story-id>`：本次要初始化的 Story ID
- `<usage-value>`：执行本命令前，用户在 Claude Code 中执行 `/usage` 查看到的"当前 session 已使用百分比"数值（仅数字，不含 % 号）

### 必填校验

如果 `$ARGUMENTS` 解析后不包含两个参数（即缺少 `<usage-value>`），**MUST 拒绝执行**，向用户输出：

```
❌ 缺少 usage-value 参数。请先在 Claude Code 中执行 /usage 查看"session 已用百分比"，然后以下列格式重试：

  /ilink-init <story-id> <已用百分比数字>

例如，/usage 显示 "5%" 已用，则执行：/ilink-init kcia-1520 5

无法查询时允许传入 0（语义为"故意跳过"，文件正常写入但 delta 标注不可信）。
```

允许 `<usage-value>` 为 `0`，语义为"用户故意跳过查询"。

## 执行任务

### 步骤 1：检查

检查目录 `iLink-doc/<story-id>/` 是否已存在。如果已存在，告知用户该 Story 已初始化，并建议执行 `/ilink-status <story-id>` 查看当前状态。

### 步骤 2：创建 Story 目录和需求定义模板

1. 创建目录 `iLink-doc/<story-id>/`
2. 创建文件 `iLink-doc/<story-id>/<story-id>-requirement.md`，内容如下：

```
# <story-id>：<请填写需求标题>

## 功能描述

<请描述本需求要解决的问题和预期效果>

## 功能范围

### In Scope（必须实现）

1. <功能点1>
2. <功能点2>

### Out of Scope（明确排除）

1. <排除项1>

## 验收标准

| AC-ID | 验收标准 | 验证方式 |
|-------|---------|---------|
| AC-01 | <Given... When... Then...> | 单元测试/代码审查 |
| AC-02 | <Given... When... Then...> | 单元测试/代码审查 |

## 约束备注

| 编号 | 约束类型 | 约束内容 |
|------|---------|---------|
| HC-01 | 技术 | <技术约束> |
| HC-02 | 业务 | <业务约束> |

## 假设与风险

| 编号 | 类型 | 内容 | 风险等级 |
|------|------|------|---------|
| AR-01 | 假设 | <假设条件> | M |

## 关联领域知识（可选）

<!-- 如果本需求涉及已有 Domain Knowledge 的模块，在此指定文件路径，PM 和 Designer 将纳入参考 -->
<!-- 示例：iLink-doc/domain/login-410301-domain-knowledge.md -->
<!-- 无关联时删除本节或留空 -->
```

### 步骤 3：创建 Usage 追踪文件（v1.6.0）

执行 shell 命令获取当前时间戳：`TZ=Asia/Shanghai date +%Y-%m-%dT%H:%M:%S+08:00`

创建文件 `iLink-doc/<story-id>/<story-id>-usage.md`，内容如下（将占位符替换为实际值）：

```markdown
# <story-id> — Usage Tracking

| 节点 | 时间戳 | Usage_Value | Usage_Unit |
|------|--------|------------|-----------|
| init | <实际时间戳> | <usage-value> | claude-5h-pct |

**Latest Delta**: (待 review 后计算)

> 说明：用户在 init 和每次 qa 执行前，查询 Claude Code 的 `/usage` 显示的"session 已用百分比"并传入命令。中间阶段不追踪。回流多次 qa 时按 review-1, review-2... 递增编号，Latest Delta 始终基于最后一次 review。
```

> Usage_Unit 字段**硬编码**为 `claude-5h-pct`，不接受用户输入。详细协议见 Root Spec §8.1.2。

## 完成后

告知用户：
1. 编辑 `iLink-doc/<story-id>/<story-id>-requirement.md`，填写需求内容
2. Usage 追踪文件已创建，记录 init 时刻 session 已用 `<usage-value>%`
3. 完成后执行 `/ilink-pm <story-id>` 继续流水线（PM/Design/Coder 阶段不需要 usage 参数）
