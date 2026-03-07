# Local LLM Benchmark Experiment - Nemesis (RTX 3070 8GB)

**Date:** 2026-03-06  
**Hardware:** 
- GPU: NVIDIA GeForce RTX 3070 (8GB VRAM, Compute 8.6)
- CPU: AMD Ryzen 7 7800X3D (8-Core)
- RAM: 32GB

**Goal:** Find the best performing local LLM for coding and general use on this hardware configuration.

## Initial Research Summary

Based on research from [LocalLLM.in](https://localllm.in/blog/best-local-llms-8gb-vram-2025) and [AI Muse](https://aimuse.blog/article/2025/06/08/ollama-performance-tuning-on-8gb-gpus-a-practical-case-study-with-qwen3-models), the key findings for 8GB VRAM:

- **Sweet spot:** 7-9B parameter models with 4-bit quantization
- **VRAM breakdown:** ~4GB for model weights + 2-3GB for KV cache (8K context) + 1-2GB system overhead
- **Best quantization:** Q5 (5-bit) offers optimal balance
- **14B models:** Generally too large, cause CPU-bound performance with offloading

## Candidate Models to Test

Based on 2025 benchmarks, these models excel in different areas:

### For Coding/Development:
1. **NVIDIA Nemotron Nano 9B** - Highest coding benchmarks
2. **Qwen2.5 Coder 7B** - Specialized for code
3. **DeepSeek R1 8B** - Strong creative coding

### For General/Reasoning:
1. **Qwen3 8B (Reasoning)** - Best math/reasoning scores (MMLU-Pro: 74.3%)
2. **Llama 3.1 8B** - Solid all-rounder
3. **Gemma 2 9B** - Google's efficient model

## Benchmark Plan

Each model will be tested with:
1. **Memory Usage** - VRAM consumption during inference
2. **Inference Speed** - Tokens per second
3. **Coding Test** - Simple code generation task
4. **Reasoning Test** - Logic/math problem
5. **Latency** - Time to first token

## Results

### Model 1: Qwen2.5 Coder 7B

**VRAM Usage:**
- Before: 853 MiB
- After: 5802 MiB
- Used: ~4.95 GB (fits comfortably in 8GB)

**Performance:**
- Prompt eval rate: 1897.68 tokens/s
- Inference rate: 84.45 tokens/s
- Total response time: 6.74s
- Load time: 1.61s

**Sample Output Quality:**
Generated a well-structured Python function with:
- Proper type hints (List[int])
- Complete docstring with parameters, returns, and raises sections
- Error handling for negative inputs
- Correct Fibonacci implementation
- Clean code structure

**Verdict:** Excellent performance and quality for coding tasks.

---

### Model 2: Llama 3.2 (2B parameters - baseline)

**VRAM Usage:**
- Before: 5802 MiB (after previous test)
- After: 3697 MiB
- Used: ~3.7 GB (much lighter than Qwen2.5 Coder)

**Performance:**
- Prompt eval rate: 2992.26 tokens/s (much faster!)
- Inference rate: 166.42 tokens/s (2x faster than Qwen!)
- Total response time: 2.57s (3x faster!)
- Load time: 1.65s

**Sample Output Quality:**
Generated a Python function with:
- Basic type hints (tuple instead of List[int])
- Simple docstring with Args/Returns
- No error handling for edge cases
- Working implementation but less robust

**Verdict:** Much faster but less detailed output. Good for quick tasks.

---

### Model 3: Qwen3 8B

*Testing pending...*

### Model 3: Qwen3 8B

*Testing pending...*

### Model 4: Nemotron Mini 4B

*Testing pending...*