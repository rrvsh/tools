# Complete Local LLM Comparison for RTX 3070 8GB

**Date:** 2026-03-06  
**Hardware:** NVIDIA RTX 3070 8GB | AMD Ryzen 7 7800X3D | 32GB RAM

## All Models That Fit 8GB VRAM

### Tested Models Performance Summary

| Model | Size | VRAM Used | Speed (tok/s) | Response | Quality | Best For |
|-------|------|-----------|---------------|----------|---------|----------|
| **Qwen2.5 Coder 7B** | 4.7GB | ~5GB | 84.45 | 6.7s | ⭐⭐⭐⭐⭐ | **Coding** |
| **Nemotron Mini 4B** | 2.7GB | ~4.2GB | **143.19** | 4.6s | ⭐⭐⭐⭐ | Speed/Coding |
| Llama 3.1 8B | 4.9GB | ~6.3GB | 79.95 | 5.6s | ⭐⭐⭐⭐ | General |
| Llama 3.2 | 2.0GB | ~3.7GB | 166.42 | 2.6s | ⭐⭐⭐ | Speed |
| **Qwen3 8B** | 5.2GB | ~6.4GB | 71.66 | 28s* | ⭐⭐⭐⭐⭐ | **Reasoning** |

*Qwen3 generated 1886 tokens (very verbose)

---

## Detailed Model Analysis

### 🥇 **Qwen2.5 Coder 7B** - BEST FOR CODING
```
VRAM:        ~5GB (62% of 8GB)
Inference:   84.45 tokens/s
Prompt:      1897.68 tokens/s  
Total Time:  6.7s

Strengths:
✅ Specialized for code
✅ Excellent type hints & docstrings
✅ Error handling in generated code
✅ Clean, production-ready output
✅ Fits comfortably in VRAM

Best for: Software development, code review, refactoring
```

### 🥈 **Nemotron Mini 4B** - BEST SPEED/QUALITY BALANCE  
```
VRAM:        ~4.2GB (53% of 8GB)
Inference:   143.19 tokens/s (FASTEST!)
Prompt:      1617.49 tokens/s
Total Time:  4.6s

Strengths:
✅ 70% faster than Qwen2.5 Coder
✅ NVIDIA optimized for CUDA
✅ Smaller footprint leaves VRAM headroom
✅ Good code generation quality

Best for: Real-time coding, quick prototyping, multiple model loading
```

### 🥉 **Llama 3.1 8B** - BEST GENERAL PURPOSE
```
VRAM:        ~6.3GB (79% of 8GB)
Inference:   79.95 tokens/s
Prompt:      1177.17 tokens/s
Total Time:  5.6s

Strengths:
✅ Meta's latest - excellent all-rounder
✅ 128K context window
✅ Strong reasoning capabilities
✅ Great for non-coding tasks too

Best for: General assistant, writing, analysis, longer contexts
```

### **Qwen3 8B** - BEST FOR REASONING (BUT VERBOSE)
```
VRAM:        ~6.4GB (80% of 8GB)
Inference:   71.66 tokens/s
Prompt:      807.32 tokens/s
Total Time:  28s (generated 1886 tokens!)

Strengths:
✅ Best math/reasoning scores (MMLU-Pro: 74.3%)
✅ Excellent for complex problem solving
✅ Thinking mode available

Weaknesses:
❌ Very verbose responses
❌ Slower than alternatives

Best for: Complex reasoning, math problems, research
```

### **Llama 3.2 (2B)** - FASTEST OPTION
```
VRAM:        ~3.7GB (46% of 8GB)
Inference:   166.42 tokens/s (2x faster)
Prompt:      2992.26 tokens/s
Total Time:  2.6s

Strengths:
✅ Fastest responses
✅ Lowest VRAM usage
✅ Good for simple tasks

Weaknesses:
❌ Less detailed output
❌ No error handling
❌ Simpler code generation

Best for: Quick answers, simple coding, chat
```

---

## Other Models That Fit 8GB VRAM

Based on research, these models also fit comfortably:

### **Mistral 7B / Mistral Nemo 12B** (Q4/Q5)
- Excellent European model
- Strong performance
- ~4-5GB VRAM usage
- Good for multilingual tasks

### **Phi-4 (3.8B - 14B variants)**
- Microsoft's efficient models
- Phi-4 Mini (3.8B): Very fast, ~2.2GB
- Phi-4 Medium (14B): Needs Q4, fits in 8GB
- Strong reasoning for size

### **Gemma 2 9B** (Google)
- ~3.5GB for 2B, ~5GB for 9B
- Efficient architecture
- Good for research/tasks

### **DeepSeek R1 8B** (Distilled)
- Reasoning specialist
- Similar to Qwen3 8B
- ~5GB VRAM usage

### **Command R (4B - 35B variants)**
- Cohere's models
- Command R 7B: ~4GB
- Good for RAG, retrieval

### **Mixtral 8x7B** (MoE - Q4 only)
- Mixture of Experts
- Needs Q4 quantization
- ~6-7GB VRAM
- Very capable but slower

---

## VRAM Usage Guidelines for 8GB

### Model Size vs VRAM (with Q4/Q5 quantization):
```
2B-3B models:  ~2-3GB VRAM (very fast, lower quality)
4B-5B models:  ~3-4GB VRAM (balanced)
7B-9B models:  ~5-6GB VRAM (best quality/speed balance)
12B-14B models: ~6.5-7.5GB VRAM (slow, risk of offloading)
>14B models:   >8GB VRAM (requires partial CPU offload)
```

### Leave Headroom:
- Keep at least 1-2GB free for KV cache (longer conversations)
- Don't max out VRAM - can cause crashes
- 7-9B models are the sweet spot

---

## Recommendations by Use Case

### **For Coding (Opencode):**
1. **Qwen2.5 Coder 7B** - Best quality, production-ready code
2. **Nemotron Mini 4B** - 70% faster, still good quality
3. **Llama 3.1 8B** - Great all-rounder with code

### **For Speed:**
1. **Llama 3.2 (2B)** - 166 tokens/s
2. **Nemotron Mini 4B** - 143 tokens/s
3. **Phi-4 Mini** - Would be even faster (~200+ tokens/s)

### **For Reasoning/Complex Tasks:**
1. **Qwen3 8B** - 74.3% MMLU-Pro (but verbose)
2. **Llama 3.1 8B** - Best balance
3. **DeepSeek R1 8B** - Good alternative

### **For Multiple Models (Switching):**
Load smaller models that fit together:
- Llama 3.2 (2GB) + Nemotron Mini (2.7GB) = ~4.7GB total
- Leaves room for context

---

## Updated Configuration

Add these to your `opencode.json`:

```json
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen2_5-coder": {
          "id": "qwen2.5-coder:7b",
          "name": "Qwen2.5 Coder 7B (Best for Coding)"
        },
        "nemotron-mini": {
          "id": "nemotron-mini:4b",
          "name": "Nemotron Mini 4B (Fast)"
        },
        "llama3_1": {
          "id": "llama3.1:8b",
          "name": "Llama 3.1 8B (General)"
        },
        "llama3_2": {
          "id": "llama3.2:latest",
          "name": "Llama 3.2 (Fastest)"
        },
        "qwen3": {
          "id": "qwen3:8b",
          "name": "Qwen3 8B (Reasoning)"
        }
      }
    }
  }
}
```

---

## Quick Reference

**Fastest:** Nemotron Mini 4B (143 tok/s)  
**Best Code:** Qwen2.5 Coder 7B  
**Best General:** Llama 3.1 8B  
**Best Reasoning:** Qwen3 8B  
**Smallest:** Llama 3.2 (2GB)  
**Sweet Spot:** 7-9B models with Q4/Q5

**Avoid:** 14B+ models (too slow with offloading)

---

## Want to Test More?

Other good models to try:
- `mistral:7b` - European leader
- `phi4:mini` - Microsoft's fastest
- `gemma2:9b` - Google's efficient model
- `deepseek-r1:8b` - Reasoning specialist

All fit in your 8GB VRAM with proper quantization!
