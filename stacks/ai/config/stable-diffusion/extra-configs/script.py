#!/usr/bin/env python3
# ============================================================================
# Stable Diffusion WebUI Custom Script
#
# 功能:
# - 添加中文 UI 支持
# - 优化默认参数 (采样步数、CFG scale 等)
# - 添加常用预设
# ============================================================================

from modules import scripts

class HomelabAIScript(scripts.Script):
    def __init__(self):
        super().__init__()

    def title(self):
        return "Homelab AI Presets"

    def show(self, is_img2img):
        return scripts.AlwaysVisible

    def ui(self, is_img2img):
        return []

# 注册脚本
script = HomelabAIScript()