<template>
  <button
    type="button"
    class="back-home"
    :class="mode === 'fixed' ? 'back-home--fixed' : 'back-home--inline'"
    title="返回系统首页"
    @click="goHome"
  >
    <span class="back-home-icon" aria-hidden="true">←</span>
    <span>返回首页</span>
  </button>
</template>

<script setup>
import { useRouter } from 'vue-router'

defineProps({
  // 'fixed'：固定悬浮在视口右上角；'inline'：作为普通按钮嵌入父容器
  mode: { type: String, default: 'fixed' },
})

const router = useRouter()

function goHome() {
  router.push('/')
}
</script>

<style scoped>
.back-home {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: 999px;
  border: 1px solid rgba(125, 211, 252, 0.45);
  background: rgba(12, 35, 64, 0.75);
  backdrop-filter: blur(10px);
  color: #d9f1ff;
  font-size: 12.5px;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease, transform 0.15s ease;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.25);
}
.back-home:hover {
  background: rgba(38, 90, 150, 0.9);
  border-color: rgba(186, 231, 255, 0.8);
  color: #ffffff;
  transform: translateY(-1px);
}
.back-home:active {
  transform: translateY(0);
}
.back-home-icon {
  font-size: 14px;
  line-height: 1;
}

.back-home--fixed {
  position: fixed;
  top: 16px;
  right: 16px;
  z-index: 9990;
}
</style>
