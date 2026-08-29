# ==============================================================================
# Oracle LLM Server (llama.cpp + Qwen3-0.6B)
# ==============================================================================
FROM ghcr.io/ggml-org/llama.cpp:server

# Download official Qwen3-0.6B Q4_K_M GGUF model (~420MB)
ADD https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/qwen3-0.6b-q4_k_m.gguf /models/model.gguf

# Configure llama-server via native environment variables
ENV LLAMA_ARG_MODEL=/models/model.gguf
ENV LLAMA_ARG_HOST=0.0.0.0
ENV LLAMA_ARG_PORT=8080
ENV LLAMA_ARG_CTX_SIZE=2048
ENV LLAMA_ARG_N_PARALLEL=1
ENV LLAMA_ARG_THREADS=2

ENV PORT=8080
ENV HOST=0.0.0.0

EXPOSE 8080
