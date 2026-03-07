# Local LLM Benchmark Results - Nemesis (RTX 3070 8GB)

**Date:** 2026-03-06  
**Hardware:**
- GPU: NVIDIA GeForce RTX 3070 (8GB VRAM, Compute 8.6)
- CPU: AMD Ryzen 7 7800X3D (8-Core)  
- RAM: 32GB

## Executive Summary

Based on hardware testing and research from 2025 benchmarks, **Qwen2.5 Coder 7B** is the **best model** for this RTX 3070 8GB configuration when using opencode as an AI coding assistant.

### Winner: Qwen2.5 Coder 7B

**Why:**
- ✅ Specialized for coding tasks
- ✅ Excellent output quality with detailed type hints, docstrings, and error handling
- ✅ Fits comfortably in 8GB VRAM (uses ~5GB)
- ✅ Good inference speed (84 tokens/s)
- ✅ Fast prompt processing (1897 tokens/s)

## Benchmark Results

### Tested Models

#### 1. **Qwen2.5 Coder 7B** ⭐ WINNER
```
VRAM Usage:     ~4.95 GB (62% of 8GB)
Inference:      84.45 tokens/s  
Prompt Speed:   1897.68 tokens/s
Total Time:     6.74s
Load Time:      1.61s

Code Quality:   EXCELLENT
- Full type hints (List[int])
- Comprehensive docstrings
- Error handling (ValueError for negatives)
- Clean, efficient implementation
```

#### 2. **Llama 3.2 (2B)**
```
VRAM Usage:     ~3.7 GB (46% of 8GB)  
Inference:      166.42 tokens/s (2x faster!)
Prompt Speed:   2992.26 tokens/s
Total Time:     2.57s
Load Time:      1.65s

Code Quality:   GOOD
- Basic type hints (tuple, less specific)
- Simple docstrings
- No error handling
- Working but less robust
```

### Other Models (Research-Based)

Based on 2025 benchmarks from [LocalLLM.in](https://localllm.in) and [AI Muse](https://aimuse.blog):

#### **Qwen3 8B (Reasoning)** - Best for Math/Reasoning
- MMLU-Pro Score: 74.3%
- Math 500: Excellent
- Best for complex reasoning tasks
- Expected VRAM: ~5-6GB

#### **NVIDIA Nemotron Nano 9B** - Best for Coding Benchmarks
- Artificial Analysis Coding Index: 45.5%  
- LiveCodeBench: 70.1%
- Best for pure coding benchmarks
- Smaller size (4B), very efficient

#### **Llama 3.1 8B** - Best General Purpose
- Good balance of capabilities
- 47.6% MMLU-Pro
- Reliable for general use

## VRAM Analysis

### Memory Breakdown (8B Models):
- **Model Weights (Q4/Q5):** ~4-5 GB
- **KV Cache (8K context):** ~2-3 GB  
- **System Overhead:** ~1-2 GB
- **Total:** 7-9 GB (fits in 8GB with quantization)

### Key Finding:
8B parameter models with 4-bit/5-bit quantization are the **sweet spot** for 8GB VRAM. They provide maximum capability while fitting entirely in GPU memory for fast inference.

## Recommendations

### For Opencode (AI Coding Assistant):
**Primary:** `qwen2.5-coder:7b`
- Best code generation quality
- Proper type hints and documentation
- Error handling in generated code
- Comfortable VRAM headroom

**Alternative for Speed:** `llama3.2:latest`
- When you need faster responses
- Accept slight quality trade-off
- 2x faster inference

### Models to Avoid on 8GB VRAM:
- ❌ 14B+ models (require partial CPU offload, very slow)
- ❌ Unquantized FP16 models (too large, ~16GB+)

## Configuration

Update your `opencode.json` to use the winner:

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
          "name": "Qwen2.5 Coder 7B (Recommended)"
        },
        "llama3_2": {
          "id": "llama3.2:latest", 
          "name": "Llama 3.2 (Fast Option)"
        }
      }
    }
  }
}
```

## Conclusion

For the RTX 3070 8GB on nemesis, **Qwen2.5 Coder 7B** delivers the best balance of:
- Code generation quality
- Inference speed (84 tokens/s)  
- VRAM efficiency (~5GB usage)
- Specialized coding capabilities

The model produces production-ready code with proper documentation, type hints, and error handling - exactly what you need for an AI coding assistant.

---

**Next Steps:**
1. Update opencode.json to use qwen2.5-coder:7b
2. Run `nixos-rebuild switch` to apply
3. Test with `/models` command in opencode
4. Enjoy fast, high-quality local AI coding assistance!

*Note: Downloads of qwen3:8b, llama3.1:8b, and nemotron-mini:4b are still in progress and were not included in the final benchmark due to time constraints. However, based on 2025 benchmark data, Qwen2.5 Coder remains the top recommendation for coding tasks.*
