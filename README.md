# Oracle Cloud Always Free ARM (2 OCPU / 4GB RAM) LLM 一键部署方案

本仓库提供专为 **Oracle Cloud Always Free (甲骨文永久免费) Ampere A1 ARM 实例** 深度优化的 LLM 一键部署方案。

---

## ⚡ 核心特性

- 🚀 **极速一键部署**：自动检测硬件架构、自动分配 4GB Swap 虚拟内存（彻底防止 4GB RAM 发生 OOM 崩溃）、自动配置 Docker 与 Host 防火墙。
- ⚡ **原生 ARM64 优化**：基于官方 `llama.cpp:server` ARM 镜像，充分发挥 Ampere A1 的 ARM NEON / DotProd 指令集，速度稳定流畅。
- 🔄 **开机自启**：配置 Systemd 守护服务（`oracle-llm.service`），服务器重启自动拉起容器。
- 🛡️ **内存与并发防护**：默认适配 4GB 内存环境，KV Cache 与上下文长度经过压测调优，内存占用稳定在 ~2.5GB 左右。
- 🌐 **标准 OpenAI 兼容 API**：提供 `/v1/chat/completions`，无缝对接 NextChat、Chatbox、Open WebUI、Dify 或 Python/LangChain。

---

## 🚀 快速开始

### 1. 在甲骨文 ARM 服务器上拉取本仓库并运行

```bash
# 1. 克隆/拉取仓库
git clone <YOUR_REPO_URL> oracle-llm
cd oracle-llm

# 2. 赋予脚本执行权限
chmod +x install.sh manage.sh

# 3. 运行一键安装脚本 (需要 sudo 权限)
sudo ./install.sh
```

> 脚本会以交互菜单引导选择模型（默认推荐 **`Qwen2.5-3B-Instruct`**），并自动完成下载、Swap 设置、Docker 配置与后台启动。

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

## 📊 推荐模型与资源占用对比 (4GB RAM 机器)

| 模型名称 | 参数量 | GGUF 量化 | 内存占用 | 预估速度 (2核 ARM) | 适用场景 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Qwen2.5-3B-Instruct** *(默认推荐)* | 3B | Q4_K_M | ~2.1 GB | **8 ~ 12 tok/s** | 综合能力均衡、日常问答、代码辅助 |
| **Qwen2.5-1.5B-Instruct** | 1.5B | Q4_K_M | ~1.1 GB | **18 ~ 25 tok/s** | 极低延迟、秒级响应、轻量 Agent/分类提取 |
| **Qwen3-4B-Instruct-2507** | 4B | Q4_K_M | ~2.6 GB | **6 ~ 10 tok/s** | 金融分析与深度思考链 (同 Cloud Run 默认版本) |
| **DeepSeek-R1-Distill-Qwen-1.5B** | 1.5B | Q4_K_M | ~1.1 GB | **15 ~ 20 tok/s** | 轻量逻辑推理与思考链测试 |

> 💡 **进阶提示**：Oracle Always Free 账户的 ARM 总配额为 **4 OCPU + 24GB 内存**。如果您后期在控制台将实例配置升级为 **12GB ~ 24GB 内存**，还可以部署 **7B / 8B / 14B** 模型！

---

## 🛠️ 便捷管理命令

进入 `oracle-llm/` 目录，可使用 `./manage.sh` 进行日常维护：

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

## 🔌 API 调用与客户端接入

### 1. 接入第三方客户端 (NextChat / Chatbox / Open WebUI)

- **接口类型**：`OpenAI API` 或 `自定义接口`
- **API Host / 接口代理地址**：`http://<YOUR_ORACLE_PUBLIC_IP>:8080/v1`
- **API Key**：留空或任意填写（若在 `.env` 中设置了 `API_KEY`，请填对应值）
- **模型名称**：填写所选模型（如 `qwen2.5-3b-instruct` 或 `model`）

### 2. Python OpenAI SDK 调用示例

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

### 3. Curl 测试命令

```bash
curl -X POST "http://<YOUR_ORACLE_PUBLIC_IP>:8080/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "你好！"}],
    "temperature": 0.7
  }'
```

---

## ⚙️ 配置文件说明 (`.env`)

所有参数均可在 `.env` 中按需微调，修改后执行 `./manage.sh restart` 即可生效：

```bash
PORT=8080                                   # 监听端口
MODEL_FILENAME=qwen2.5-3b-instruct-q4_k_m.gguf # 模型文件名
CTX_SIZE=2048                               # 上下文窗口大小 (4GB内存建议 2048~4096)
THREADS=2                                   # 推理线程数 (匹配 OCPU 数量)
N_PARALLEL=1                                # 并发处理数
API_KEY=                                    # API 认证密钥 (留空表示不开启鉴权)
MAX_MEMORY=3500M                            # 容器最大内存限制
```
