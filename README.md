# Oracle Cloud Always Free ARM LLM 一键部署方案

本仓库提供专为 **Oracle Cloud Always Free (甲骨文永久免费) Ampere A1 ARM 实例** 深度优化的 LLM 一键部署方案。全面支持 **2 OCPU / 4GB RAM** 以及升级后的 **2 OCPU / 12GB RAM** 实例。

---

## ⚡ 核心特性

- 🚀 **极速一键部署**：自动检测硬件内存大小，智能推荐最优模型；自动分配 4GB Swap 虚拟内存；自动配置 Docker 与 Host 防火墙。
- ⚡ **原生 ARM64 优化**：基于官方 `llama.cpp:server` ARM 镜像，直连 Ampere A1 CPU NEON / DotProd 指令集，速度稳定流畅。
- 🔄 **开机自启**：配置 Systemd 守护服务（`oracle-llm.service`），服务器重启自动拉起容器。
- 🛡️ **内存安全隔离**：动态限制 Docker 容器内存上限，防止高负载突发导致操作系统崩溃。
- 🌐 **标准 OpenAI 兼容 API**：提供 `/v1/chat/completions`，无缝对接 NextChat、Chatbox、Open WebUI、Dify 或 Python/LangChain。

---

## 📊 模型选型指南与性能对比

根据你的服务器内存配置（4GB 或 12GB），可从以下精选模型中选择：

### 🌟 第一梯队：12GB 内存推荐（7B ~ 8B 旗舰级参数，智商与逻辑天花板）

> 适合拥有 **12GB 内存** 的实例，生成速度约为 **每秒 3.5 ~ 5.5 个字（正常阅读打字速度）**，输出质量极高：

| 模型名称 | 参数量 | GGUF体积 | 内存占用 | 推理速度 (2核 ARM) | 思考链 (`<think>`) | 特点与适用场景 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`DeepSeek-R1-Distill-Qwen-7B`** ⭐*(最强推荐)* | 7B | ~4.68 GB | ~5.5 GB | **3.5 ~ 5.0 tok/s** | ✅ 深度强化推理 | **逻辑与深度推演之王**：数学计算、复杂问题分析、多步骤推导。 |
| **`Qwen2.5-7B-Instruct`** ⭐ | 7B | ~4.68 GB | ~5.5 GB | **4.0 ~ 5.5 tok/s** | ❌ 无显式思考 | **7B 中文综合旗舰**：知识面极广，格式遵循与长文写作非常稳健。 |
| **`Qwen2.5-Coder-7B-Instruct`** | 7B | ~4.68 GB | ~5.5 GB | **4.0 ~ 5.5 tok/s** | ❌ 无显式思考 | **代码编写/重构神器**：代码补全、重构、Bug 排查能力顶尖。 |
| **`Meta-Llama-3.1-8B-Instruct`** | 8B | ~4.92 GB | ~6.0 GB | **3.5 ~ 4.5 tok/s** | ❌ 无显式思考 | **Meta 8B 经典旗舰**：英文理解、通用问答与工具调用出色。 |

---

### ⚡ 第二梯队：4GB ~ 12GB 内存推荐（1.5B ~ 4B 轻量级参数，极速响应与超长上下文）

> 适合 **4GB 内存**（防止 OOM）或在 **12GB 内存** 上开启 **8K~16K 超长上下文**，生成速度极快：

| 模型名称 | 参数量 | GGUF体积 | 内存占用 | 推理速度 (2核 ARM) | 思考链 (`<think>`) | 特点与适用场景 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`Qwen2.5-3B-Instruct`** ⭐*(4G默认)* | 3B | ~1.93 GB | ~2.1 GB | **8 ~ 12 tok/s** | ❌ 无显式思考 | **综合黄金平衡**：日常对话流畅秒回，中英文表现优秀。 |
| **`Qwen2.5-Coder-3B-Instruct`** | 3B | ~1.93 GB | ~2.1 GB | **8 ~ 12 tok/s** | ❌ 无显式思考 | **轻快代码助手**：占用极低，快速编写 Shell/Python 脚本。 |
| **`DeepSeek-R1-Distill-Qwen-1.5B`** | 1.5B | ~1.10 GB | ~1.3 GB | **16 ~ 22 tok/s** | ✅ 深度强化推理 | **极速思考链**：秒级推理分析，极低内存消耗。 |
| **`Qwen2.5-1.5B-Instruct`** | 1.5B | ~0.98 GB | ~1.1 GB | **18 ~ 25 tok/s** | ❌ 无显式思考 | **秒级极速响应**：高频中英翻译、新闻提取、轻量 Agent。 |
| **`Qwen3-4B-Instruct-2507`** | 4B | ~2.50 GB | ~2.7 GB | **6 ~ 10 tok/s** | ✅ 原生支持 | **金融与深度分析**：与 Cloud Run 版本保持一致的金融模型。 |

---

## 🚀 极简快速部署

在甲骨文 ARM 服务器终端中执行：

```bash
# 1. 克隆/拉取仓库
git clone https://github.com/StreamMao/oracle-llm.git
cd oracle-llm

# 2. 赋予脚本执行权限
chmod +x install.sh manage.sh

# 3. 运行一键安装脚本 (需要 sudo 权限)
sudo ./install.sh
```

> **智能安装提示**：
> * 如果检测到当前机器为 **12GB 内存**，脚本会自动将默认选项指向 **`[1] DeepSeek-R1-Distill-Qwen-7B`**（最大内存限制 `10000M`，上下文 `4096`）。
> * 如果检测到当前机器为 **4GB 内存**，脚本会自动将默认选项指向 **`[5] Qwen2.5-3B-Instruct`**（最大内存限制 `3500M`，上下文 `2048`）。

---

## ⚠️ 关键步骤：在甲骨文控制台放行 8080 端口

> **注意**：脚本已自动放行宿主机的 Linux 防火墙（iptables/ufw），但您仍需在 **甲骨文云后台 VCN 安全列表** 中添加入站规则：

1. 登录 [Oracle Cloud 控制台](https://cloud.oracle.com/)；
2. 进入 **网络 (Networking)** -> **虚拟云网络 (Virtual Cloud Networks)** -> 点击您的 VCN；
3. 点击 **安全列表 (Security Lists)** -> 选择 **Default Security List**；
4. 点击 **添加入站规则 (Add Ingress Rules)**：
   - **源 CIDR (Source CIDR)**: `0.0.0.0/0`
   - **IP 协议 (IP Protocol)**: `TCP`
   - **目标端口范围 (Destination Port Range)**: `8080`
   - **描述**: `LLM Server API`
5. 点击保存即可立即生效。

---

## 🛠️ 便捷运维命令 (`./manage.sh`)

```bash
# 查看服务运行状态、内存占用与健康检查
./manage.sh status

# 实时查看推理日志（流式打字输出）
./manage.sh logs

# 运行本地快速测试推理
./manage.sh test

# 重启 / 停止 / 启动 服务
./manage.sh restart
./manage.sh stop
./manage.sh start

# 拉取最新 llama.cpp 镜像并重启
./manage.sh update
```

---

## 🔄 手动切换模型方法

若想更换运行的模型，只需两步：

1. 编辑 `.env` 文件（参考 `.env.example` 中提供的链接与参数）：
   ```bash
   nano .env
   ```
2. 下载新模型并重启：
   ```bash
   # 举例：切换到 Qwen2.5-7B
   curl -L -C - -o models/qwen2.5-7b-instruct-q4_k_m.gguf https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf
   
   # 重启服务生效
   ./manage.sh restart
   ```

---

## 🔌 客户端接入示例

### 1. 接入第三方客户端 (NextChat / Chatbox / Open WebUI)

- **接口类型**：`OpenAI API`
- **API Host**：`http://<YOUR_ORACLE_PUBLIC_IP>:8080/v1`
- **API Key**：留空或任意填写（如 `none`）
- **模型名称**：填写当前模型（如 `DeepSeek-R1-Distill-Qwen-7B` 或 `model`）

### 2. Python OpenAI SDK 调用

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<YOUR_ORACLE_PUBLIC_IP>:8080/v1",
    api_key="none"
)

response = client.chat.completions.create(
    model="default",
    messages=[
        {"role": "system", "content": "你是一位专业的 AI 助理。"},
        {"role": "user", "content": "请用一句话介绍你自己。"}
    ],
    temperature=0.7,
    stream=True
)

for chunk in response:
    content = chunk.choices[0].delta.content or ""
    print(content, end="", flush=True)
print()
```
