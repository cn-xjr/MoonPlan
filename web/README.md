# MoonPlan Studio

本地浏览器演示复用仓库的 MoonBit 排班内核。`web/bridge` 被编译为 WasmGC 外部库，导出预检和有预算的最公平排班接口；`app.js` 只负责编辑输入、调用导出函数和展示结果，没有 JavaScript 版求解器。

从仓库根目录运行：

```bash
moon build --target wasm-gc --release web/bridge
python -m http.server 8000
```

打开 `http://127.0.0.1:8000/web/`。Windows 如使用 Python Launcher，可将第二条命令换成 `py -3 -m http.server 8000`。需要支持 WasmGC 与 JavaScript 字符串内建功能的现代浏览器；不能直接双击 HTML，因为页面通过 HTTP 读取 `.wasm` 和公开样例。

可在表单中增删人员、岗位需求，或切换到 JSON 编辑完整的 `CoverageRequest`。支持导入、导出本地 JSON、确定性容量预检、有节点预算的最小工作量差距证明。`budget_exhausted` 表示搜索尚未完成，不代表无解或最优。所有输入和计算都留在当前浏览器；页面自身不向服务端提交排班数据。

浏览器从 `_build/wasm-gc/release/build/web/bridge/bridge.wasm` 读取构建产物，示例来自 `examples/coverage_week.json`。因此静态服务器的根目录必须是仓库根目录。构建产物不纳入版本控制，更新 MoonBit 源代码后应重新执行 `moon build` 并刷新页面。
