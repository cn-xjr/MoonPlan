const $ = (id) => document.getElementById(id);
const wasmPath = "../_build/wasm-gc/release/build/web/bridge/bridge.wasm";
const samplePath = "../examples/coverage_week.json";
const state = { request: null, solver: null, editor: "form", busy: false };

function text(tag, value, className = "") {
  const node = document.createElement(tag);
  node.textContent = String(value);
  if (className) node.className = className;
  return node;
}

function clear(node) {
  node.replaceChildren();
}

function message(value, tone = "") {
  $("message").textContent = value;
  $("message").className = `message ${tone}`;
}

function setBusy(busy) {
  state.busy = busy;
  $("check").disabled = busy || !state.solver || !state.request;
  $("solve").disabled = busy || !state.solver || !state.request;
}

function commaList(value) {
  return String(value).split(",").map((part) => part.trim()).filter(Boolean);
}

function slotList(value) {
  return commaList(value).map(Number);
}

function editable(label, value, onChange, { wide = false, type = "text", min = null } = {}) {
  const wrapper = document.createElement("label");
  if (wide) wrapper.className = "wide";
  wrapper.append(text("span", label));
  const input = document.createElement("input");
  input.type = type;
  input.value = value;
  if (min !== null) input.min = min;
  if (type === "number") input.step = "1";
  input.addEventListener("input", () => {
    onChange(input.value);
    scenarioChanged();
  });
  wrapper.append(input);
  return wrapper;
}

function nextId(records) {
  return Math.max(0, ...records.map((item) => Number(item.id) || 0)) + 1;
}

function workerCard(worker) {
  const card = document.createElement("article");
  card.className = "record";
  const heading = text("div", "", "record-title");
  heading.append(text("span", `人员 #${worker.id}`));
  const remove = text("button", "移除", "remove");
  remove.type = "button";
  remove.addEventListener("click", () => {
    state.request.workers = state.request.workers.filter((item) => item !== worker);
    renderEditor();
    scenarioChanged();
  });
  heading.append(remove);
  card.append(heading);
  const fields = text("div", "", "field-grid worker-grid");
  fields.append(
    editable("姓名", worker.name, (value) => worker.name = value),
    editable("人员 ID", worker.id, (value) => worker.id = Number(value), { type: "number" }),
    editable("技能", worker.skills.join(", "), (value) => worker.skills = commaList(value), { wide: true }),
    editable("可用时段", worker.available_slots.join(", "), (value) => worker.available_slots = slotList(value), { wide: true }),
  );
  card.append(fields);
  return card;
}

function requirementCard(requirement) {
  const card = document.createElement("article");
  card.className = "record";
  const heading = text("div", "", "record-title");
  heading.append(text("span", `岗位 #${requirement.id}`));
  const remove = text("button", "移除", "remove");
  remove.type = "button";
  remove.addEventListener("click", () => {
    state.request.requirements = state.request.requirements.filter((item) => item !== requirement);
    renderEditor();
    scenarioChanged();
  });
  heading.append(remove);
  card.append(heading);
  const fields = text("div", "", "field-grid");
  fields.append(
    editable("岗位名称", requirement.name, (value) => requirement.name = value, { wide: true }),
    editable("岗位 ID", requirement.id, (value) => requirement.id = Number(value), { type: "number" }),
    editable("时段", requirement.slot, (value) => requirement.slot = Number(value), { type: "number" }),
    editable("所需技能", requirement.required_skill, (value) => requirement.required_skill = value),
    editable("需求人数", requirement.workers_needed, (value) => requirement.workers_needed = Number(value), { type: "number", min: "1" }),
  );
  card.append(fields);
  return card;
}

function updateCount() {
  if (!state.request) return;
  const positions = state.request.requirements.reduce((sum, item) => sum + Number(item.workers_needed || 0), 0);
  $("scenario-count").textContent = `${state.request.workers.length} 人 · ${positions} 岗位名额`;
}

function renderEditor() {
  if (!state.request) return;
  const workers = $("worker-list");
  const requirements = $("requirement-list");
  clear(workers);
  clear(requirements);
  state.request.workers.forEach((worker) => workers.append(workerCard(worker)));
  state.request.requirements.forEach((requirement) => requirements.append(requirementCard(requirement)));
  $("max-shifts").value = state.request.policy.max_shifts_per_worker;
  $("min-gap").value = state.request.policy.minimum_slot_gap;
  updateCount();
}

function scenarioChanged() {
  updateCount();
  clear($("summary"));
  emptyResults();
  message("场景已修改。请重新检查或求解。", "");
}

function emptyResults() {
  const box = text("div", "", "empty-state");
  box.append(text("div", "◌", "empty-symbol"), text("strong", "结果将在这里展开"), text("p", "先检查可行性，或直接求解最公平的排班。"));
  $("details").replaceChildren(box);
}

function switchEditor(target) {
  if (target === state.editor) return;
  if (target === "form") {
    try {
      const parsed = JSON.parse($("json-input").value);
      if (!parsed || !Array.isArray(parsed.workers) || !Array.isArray(parsed.requirements) || !parsed.policy) {
        throw new Error("需要包含 workers、requirements 和 policy 字段");
      }
      const checked = invoke("check_coverage", $("json-input").value);
      if (checked.error) throw new Error(checked.error);
      state.request = parsed;
      renderEditor();
      scenarioChanged();
    } catch (error) {
      message(`JSON 格式错误：${error.message}`, "error");
      return;
    }
  } else {
    $("json-input").value = JSON.stringify(state.request, null, 2);
  }
  state.editor = target;
  $("form-editor").classList.toggle("hidden", target !== "form");
  $("json-editor").classList.toggle("hidden", target !== "json");
  for (const name of ["form", "json"]) {
    const active = name === target;
    $(`${name}-tab`).classList.toggle("active", active);
    $(`${name}-tab`).setAttribute("aria-selected", String(active));
  }
}

function requestText() {
  return state.editor === "json" ? $("json-input").value : JSON.stringify(state.request);
}

function invoke(name, ...args) {
  if (!state.solver) throw new Error("MoonBit 求解器尚未加载");
  return JSON.parse(state.solver[name](...args));
}

function stat(label, value, note = "") {
  const card = text("div", "", "stat");
  card.append(text("p", label, "stat-label"), text("p", value, "stat-value"));
  if (note) card.append(text("div", note, "stat-note"));
  return card;
}

function showIssues(analysis) {
  clear($("summary"));
  const issues = analysis.issues || [];
  $("summary").append(stat("预检结论", analysis.preflight_passed ? "通过" : "缺口"), stat("确定性问题", issues.length), stat("下一步", analysis.preflight_passed ? "求解" : "调整"));
  clear($("details"));
  const block = text("section", "", "detail-block");
  block.append(text("h3", "预检报告"));
  if (!issues.length) {
    block.append(text("p", "未发现资格或容量层面的确定性缺口。预检通过不保证满足全部休息与分配规则。", "helper"));
  } else {
    for (const item of issues) {
      const card = text("div", "", "issue");
      card.append(text("code", item.code), text("p", item.message));
      block.append(card);
    }
  }
  $("details").append(block);
  message(analysis.preflight_passed ? "预检通过。可以继续运行完整求解。" : `发现 ${issues.length} 项确定性缺口，请修改输入后重试。`, analysis.preflight_passed ? "success" : "warning");
}

function showRoster(result) {
  const entries = result.roster.entries;
  const loads = new Map(state.request.workers.map((worker) => [worker.id, 0]));
  const groups = new Map();
  for (const entry of entries) {
    const id = entry.worker.id;
    loads.set(id, (loads.get(id) || 0) + 1);
    const slot = entry.requirement.slot;
    if (!groups.has(slot)) groups.set(slot, []);
    groups.get(slot).push(entry);
  }
  $("summary").replaceChildren(
    stat("工作量差距", result.balance.spread, "已证明最小"),
    stat("填补名额", entries.length, `${state.request.workers.length} 位人员`),
    stat("搜索节点", result.total_nodes, `${result.windows_checked} 个配额窗口`),
  );
  clear($("details"));
  const roster = text("section", "", "detail-block");
  const rosterHeader = text("div", "", "detail-header");
  rosterHeader.append(text("h3", "时段排班"), text("small", "按输入时段排序"));
  roster.append(rosterHeader);
  const grid = text("div", "", "roster-grid");
  for (const [slot, assignments] of [...groups.entries()].sort((a, b) => Number(a[0]) - Number(b[0]))) {
    const card = text("div", "", "slot-card");
    card.append(text("div", `时段 ${slot}`, "slot-title"));
    for (const entry of assignments) {
      const row = text("div", "", "assignment");
      row.append(text("span", `${entry.requirement.name} · ${entry.position}/${entry.requirement.workers_needed}`, "role"), text("span", entry.worker.name, "person"));
      card.append(row);
    }
    grid.append(card);
  }
  roster.append(grid);
  const workload = text("section", "", "detail-block");
  workload.append(text("h3", "人员工作量"));
  const list = text("div", "", "workload-list");
  const maximum = Math.max(1, ...loads.values());
  for (const worker of state.request.workers) {
    const count = loads.get(worker.id) || 0;
    const row = text("div", "", "workload-row");
    const track = text("div", "", "bar-track");
    const fill = text("div", "", "bar-fill");
    fill.style.width = `${100 * count / maximum}%`;
    track.append(fill);
    row.append(text("span", worker.name, "workload-name"), track, text("span", count, "workload-number"));
    list.append(row);
  }
  workload.append(list);
  $("details").append(roster, workload);
  message(`已证明：在当前硬规则下，工作量差距不可能小于 ${result.balance.spread}。`, "success");
}

function run(action) {
  if (state.busy || !state.solver) return;
  setBusy(true);
  message("MoonBit 求解器正在计算…");
  // Yield once so the busy state is painted before synchronous Wasm search.
  setTimeout(() => {
    try {
      const input = requestText();
      const analysis = invoke("check_coverage", input);
      if (analysis.error) throw new Error(analysis.error);
      if (state.editor === "json") state.request = JSON.parse(input);
      if (action === "check" || !analysis.preflight_passed) {
        showIssues(analysis);
        return;
      }
      const limit = Number($("node-limit").value);
      if (!Number.isSafeInteger(limit) || limit < 1 || limit > 2147483647) {
        throw new Error("节点上限应为 1 至 2147483647 的整数");
      }
      const result = invoke("solve_fairest_coverage", input, limit);
      if (result.error) throw new Error(result.error);
      if (result.status === "optimal") {
        showRoster(result);
      } else {
        showIssues(analysis);
        message(result.status === "budget_exhausted" ? `已用完 ${result.total_nodes} 个节点；尚不能断言无解或最优。可提高上限继续计算。` : "已完成搜索：当前硬规则下无可行排班。", "warning");
        $("summary").replaceChildren(stat("求解状态", result.status === "budget_exhausted" ? "未完成" : "无解"), stat("搜索节点", result.total_nodes), stat("配额窗口", result.windows_checked));
      }
    } catch (error) {
      clear($("summary"));
      emptyResults();
      message(error.message || String(error), "error");
    } finally {
      setBusy(false);
    }
  }, 0);
}

async function loadSample() {
  const response = await fetch(samplePath);
  if (!response.ok) throw new Error(`样例读取失败：HTTP ${response.status}`);
  state.request = await response.json();
  if (state.editor === "json") $("json-input").value = JSON.stringify(state.request, null, 2);
  renderEditor();
  scenarioChanged();
}

function wireEvents() {
  $("form-tab").addEventListener("click", () => switchEditor("form"));
  $("json-tab").addEventListener("click", () => switchEditor("json"));
  $("json-input").addEventListener("input", scenarioChanged);
  $("max-shifts").addEventListener("input", (event) => { state.request.policy.max_shifts_per_worker = Number(event.target.value); scenarioChanged(); });
  $("min-gap").addEventListener("input", (event) => { state.request.policy.minimum_slot_gap = Number(event.target.value); scenarioChanged(); });
  $("add-worker").addEventListener("click", () => {
    state.request.workers.push({ id: nextId(state.request.workers), name: "新人员", skills: ["support"], available_slots: [1] });
    renderEditor(); scenarioChanged();
  });
  $("add-requirement").addEventListener("click", () => {
    state.request.requirements.push({ id: nextId(state.request.requirements), name: "新岗位", slot: 1, required_skill: "support", workers_needed: 1 });
    renderEditor(); scenarioChanged();
  });
  $("load-sample").addEventListener("click", () => loadSample().catch((error) => message(error.message, "error")));
  $("upload").addEventListener("change", async (event) => {
    const file = event.target.files[0];
    if (!file) return;
    try {
      const parsed = JSON.parse(await file.text());
      if (!parsed || !Array.isArray(parsed.workers) || !Array.isArray(parsed.requirements) || !parsed.policy) throw new Error("文件不是 CoverageRequest JSON");
      state.request = parsed;
      if (state.editor === "json") $("json-input").value = JSON.stringify(parsed, null, 2);
      renderEditor(); scenarioChanged();
      message(`已导入 ${file.name}；请运行预检。`, "success");
    } catch (error) { message(`导入失败：${error.message}`, "error"); }
    event.target.value = "";
  });
  $("download").addEventListener("click", () => {
    try {
      const parsed = JSON.parse(requestText());
      const url = URL.createObjectURL(new Blob([JSON.stringify(parsed, null, 2) + "\n"], { type: "application/json" }));
      const link = document.createElement("a");
      link.href = url; link.download = "moonplan-coverage.json"; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 0);
    } catch (error) { message(`导出失败：${error.message}`, "error"); }
  });
  $("check").addEventListener("click", () => run("check"));
  $("solve").addEventListener("click", () => run("solve"));
}

async function main() {
  wireEvents();
  emptyResults();
  try {
    const [response] = await Promise.all([fetch(wasmPath), loadSample()]);
    if (!response.ok) throw new Error(`Wasm 模块读取失败：HTTP ${response.status}。请先运行 moon build --target wasm-gc --release web/bridge。`);
    const bytes = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes, {}, { builtins: ["js-string"], importedStringConstants: "_" });
    state.solver = instance.exports;
    $("runtime-dot").classList.add("ready");
    $("runtime-label").textContent = "MoonBit / WasmGC 已就绪";
    setBusy(false);
    message("公开样例已载入。可以修改场景并运行预检。", "success");
  } catch (error) {
    $("runtime-dot").classList.add("error");
    $("runtime-label").textContent = "求解器加载失败";
    message(error.message || String(error), "error");
  }
}

main();
