# Oracle LLM (Qwen3-0.6B on Cloud Run)

本独立项目专用于在 **Google Cloud Run** 上部署极速轻量级大模型 **`Qwen3-0.6B`**，作为独立的超快 API 节点。

---

## 🎯 特性

* **极速冷启动**：模型体积仅约 **420 MB**，冷启动只需 **3 ~ 5 秒**；
* **双模式推理**：支持原生 **Thinking 思考模式** 与 **普通快速模式**；
* **零闲置成本**：配置 `--min-instances 0`，100% 运行在 Google Cloud Run 免费额度内；
* **独立运行**：独立的服务名 `oracle-llm`，与 `cloudrun-llm` 互不干扰。

---

## 🚀 部署命令

### 本地一键部署（通过 gcloud）：

* **Windows PowerShell**:
  ```powershell
  .\deploy.ps1
  ```

* **Linux / macOS**:
  ```bash
  chmod +x deploy.sh
  ./deploy.sh
  ```

---

## 🧪 测试调用

```bash
python3 test_client.py https://<YOUR_ORACLE_LLM_URL>
```
