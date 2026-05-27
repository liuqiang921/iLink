你现在执行 iLink 的 **Issue System 拉取** 操作。

## 参数

`$ARGUMENTS` 为一个 story-id（如 `FS-AMO-5359`），大小写原样透传给 Issue System，不做任何转换。本命令**只接受 1 个参数**。

### 必填校验

如果 `$ARGUMENTS` 为空，**MUST 拒绝执行**，向用户输出：

```
❌ 用法：/ilink-pull <story-id>

例如：/ilink-pull FS-AMO-5359
```

## 执行任务

调用本目录下的 bash 脚本执行实际拉取（脚本完成所有校验、HTTP 请求、JSON 解析、文件写入）：

```bash
bash .claude/commands/ilink-pull.sh $ARGUMENTS
```

**SHALL NOT**：
- 自己拼 URL、自己解析 JSON、自己写文件——这些全部由 bash 脚本完成
- 读取 project-context.md 中"Issue System 集成"AI 隔离块的内容并作为业务上下文（遵守 Root Spec §7.8 / universal.soul §4.1）
- 修改 project-context.md 中的 Issue System 配置（如需变更指引用户手动编辑或重跑 `/ilink-bootstrap`）

## 输出处理

**首要原则**：bash 脚本的 stdout / stderr **原样转给用户**——脚本已包含完整的进度信息、成功提示、错误指引。SHALL NOT 重复转述或自行解释脚本已经说过的内容。

**仅在脚本退出码 0 时**，**追加** 1 行简短下一步提示（脚本本身不输出这行）：

> 下一步：核对 requirement.md 的其他区块（功能范围 / 验收标准 / 约束备注 / 假设与风险），完成后执行 `/ilink-pm <story-id>` 进入需求分析阶段。

**脚本退出码非 0 时**：SHALL NOT 再次调用脚本、SHALL NOT 添加任何补充说明。用户根据 stderr 自行处理（编辑 project-context.md、检查网络、修正 story-id 等）。
