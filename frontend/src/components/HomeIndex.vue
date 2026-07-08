<template>
  <div class="home-page">
    <div class="bg-layer" aria-hidden="true"></div>
    <div class="bg-overlay" aria-hidden="true"></div>

    <header class="site-header">
      <img
        class="brand-logo"
        src="/brand/img/pengchenglab-logo.png"
        alt="鹏城实验室 Peng Cheng Laboratory"
      />
      <button type="button" class="config-btn" @click="handleNavigate('/system/config')">
        <span class="config-icon" aria-hidden="true">⚙</span>
        系统配置
      </button>
    </header>

    <main class="home-main">
      <section class="hero">
        <p class="hero-eyebrow">Satellite Cloud Native Simulation</p>
        <h1 class="hero-title">卫星云原生软件仿真平台</h1>
        <p class="hero-subtitle">
          星座仿真、网络拓扑、性能监控与遥感业务一体化环境，支撑多星协同与云原生调度验证
        </p>
      </section>

      <section class="intro-panel">
        <div class="intro-panel-head">
          <span class="intro-badge">平台介绍</span>
        </div>
        <p class="intro-text">
          提供星座仿真系统、卫星网络拓扑、性能监控中台，以及通信与遥感两类业务仿真场景。可按场景配置
          <span class="tag">星座规模</span>
          <span class="tag">星网架构</span>
          <span class="tag">用户规模</span>
          <span class="tag">星网带宽</span>
          <span class="tag">星网容量</span>
          等参数，完成端到端验证与演示。
        </p>
      </section>

      <section class="modules-section" aria-label="功能模块">
        <h2 class="modules-heading">功能模块</h2>
        <div class="modules-grid">
          <article
            v-for="(item, index) in navItems"
            :key="index"
            class="module-card"
            :class="`module-card--${item.theme}`"
            tabindex="0"
            role="button"
            @click="handleNavigate(item)"
            @keydown.enter="handleNavigate(item)"
          >
            <div class="module-icon" aria-hidden="true">{{ item.icon }}</div>
            <div class="module-body">
              <h3>{{ item.title }}</h3>
              <p>{{ item.desc }}</p>
            </div>
            <span class="module-arrow" aria-hidden="true">→</span>
          </article>
        </div>
      </section>
    </main>

    <footer class="site-footer">
      <p>© {{ currentYear }} 鹏城实验室 · Satellite Cloud Native Platform</p>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
const currentYear = new Date().getFullYear();

const navItems = ref([
  {
    title: '星座仿真系统',
    desc: '三维轨道与星座态势可视化',
    icon: '🛰',
    theme: 'orbit',
    route: '/simulation/Satelliteviewer',
  },
  {
    title: '卫星网络拓扑',
    desc: '路由子网与 ISL 拓扑分析',
    icon: '🔗',
    theme: 'topology',
    route: '/simulation/topology',
  },
  {
    title: '性能监控中台',
    desc: '集群与业务指标观测',
    icon: '📊',
    theme: 'monitor',
    route: '/monitor',
    externalLink: import.meta.env.VITE_GRAFANA_URL || undefined,
  },
  {
    title: '通信应用',
    desc: '星间通信业务仿真（规划中）',
    icon: '📡',
    theme: 'comm',
    route: '/app/communication',
  },
  {
    title: '遥感应用',
    desc: '预处理至目标识别全流程',
    icon: '🌍',
    theme: 'rs',
    route: '/remote-sensing',
  },
  {
    title: '批量服务引擎',
    desc: '批量任务编排与调度（规划中）',
    icon: '⚡',
    theme: 'batch',
    route: '/engine/batch',
  },
]);

const handleNavigate = (item) => {
  if (!item) return;
  if (typeof item === 'string') {
    router.push(item);
    return;
  }
  if (item.externalLink) {
    window.open(item.externalLink, '_blank', 'noopener,noreferrer');
    return;
  }
  if (item.route) {
    router.push(item.route);
  }
};
</script>

<style scoped>
.home-page {
  position: relative;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  font-family: 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', Helvetica, Arial, sans-serif;
  color: #f5f8fc;
  overflow-x: hidden;
}

.bg-layer {
  position: fixed;
  inset: 0;
  z-index: 0;
  background-image: url('/brand/img/oa-login-bg.png');
  background-size: cover;
  background-position: center 35%;
  background-repeat: no-repeat;
  transform: scale(1.02);
}

.bg-overlay {
  position: fixed;
  inset: 0;
  z-index: 1;
  background:
    linear-gradient(115deg, rgba(8, 28, 58, 0.88) 0%, rgba(12, 45, 92, 0.62) 42%, rgba(18, 52, 88, 0.48) 100%),
    linear-gradient(to top, rgba(6, 18, 36, 0.75) 0%, transparent 45%);
  pointer-events: none;
}

.site-header {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px clamp(20px, 4vw, 48px);
  gap: 16px;
}

.brand-logo {
  height: clamp(40px, 5vw, 52px);
  width: auto;
  max-width: min(420px, 72vw);
  object-fit: contain;
  object-position: left center;
  filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.35));
}

.config-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 18px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.35);
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  color: #fff;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.25s ease, border-color 0.25s ease, transform 0.2s ease;
  white-space: nowrap;
}

.config-btn:hover {
  background: rgba(255, 255, 255, 0.22);
  border-color: rgba(255, 255, 255, 0.55);
  transform: translateY(-1px);
}

.config-icon {
  font-size: 1rem;
  line-height: 1;
}

.home-main {
  position: relative;
  z-index: 2;
  flex: 1;
  width: min(1120px, 100%);
  margin: 0 auto;
  padding: 0 clamp(20px, 4vw, 48px) 32px;
}

.hero {
  margin-top: clamp(8px, 3vh, 32px);
  margin-bottom: clamp(24px, 4vh, 40px);
  max-width: 720px;
}

.hero-eyebrow {
  margin: 0 0 12px;
  font-size: 0.82rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: rgba(173, 216, 255, 0.92);
  font-weight: 500;
}

.hero-title {
  margin: 0 0 16px;
  font-size: clamp(1.75rem, 4.2vw, 2.65rem);
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: 0.02em;
  text-shadow: 0 2px 24px rgba(0, 0, 0, 0.35);
}

.hero-subtitle {
  margin: 0;
  font-size: clamp(0.95rem, 1.8vw, 1.08rem);
  line-height: 1.75;
  color: rgba(230, 240, 255, 0.88);
  max-width: 640px;
}

.intro-panel {
  margin-bottom: clamp(28px, 4vh, 44px);
  padding: clamp(18px, 3vw, 26px) clamp(20px, 3vw, 28px);
  border-radius: 16px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(16px);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.18);
}

.intro-panel-head {
  margin-bottom: 12px;
}

.intro-badge {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 999px;
  background: rgba(64, 169, 255, 0.25);
  border: 1px solid rgba(135, 206, 255, 0.45);
  font-size: 0.82rem;
  font-weight: 600;
  color: #e6f4ff;
}

.intro-text {
  margin: 0;
  line-height: 1.85;
  font-size: 0.98rem;
  color: rgba(240, 246, 255, 0.92);
}

.tag {
  display: inline-block;
  margin: 2px 4px;
  padding: 2px 8px;
  border-radius: 6px;
  background: rgba(24, 144, 255, 0.22);
  border: 1px solid rgba(105, 192, 255, 0.35);
  color: #bae7ff;
  font-size: 0.88rem;
  font-weight: 500;
}

.modules-section {
  margin-bottom: 24px;
}

.modules-heading {
  margin: 0 0 18px;
  font-size: 1.05rem;
  font-weight: 600;
  color: rgba(230, 242, 255, 0.95);
  letter-spacing: 0.06em;
}

.modules-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: clamp(14px, 2vw, 22px);
}

.module-card {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 18px 16px;
  border-radius: 14px;
  border: 1px solid rgba(255, 255, 255, 0.16);
  background: rgba(255, 255, 255, 0.09);
  backdrop-filter: blur(14px);
  cursor: pointer;
  transition:
    transform 0.25s ease,
    background 0.25s ease,
    border-color 0.25s ease,
    box-shadow 0.25s ease;
  outline: none;
}

.module-card:hover,
.module-card:focus-visible {
  transform: translateY(-4px);
  background: rgba(255, 255, 255, 0.16);
  border-color: rgba(186, 231, 255, 0.45);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.22);
}

.module-icon {
  flex-shrink: 0;
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  font-size: 1.35rem;
  background: rgba(255, 255, 255, 0.12);
}

.module-card--orbit .module-icon { background: rgba(56, 158, 255, 0.28); }
.module-card--topology .module-icon { background: rgba(82, 196, 26, 0.22); }
.module-card--monitor .module-icon { background: rgba(250, 173, 20, 0.25); }
.module-card--comm .module-icon { background: rgba(114, 46, 209, 0.25); }
.module-card--rs .module-icon { background: rgba(19, 194, 194, 0.25); }
.module-card--batch .module-icon { background: rgba(245, 34, 45, 0.22); }

.module-body {
  flex: 1;
  min-width: 0;
}

.module-body h3 {
  margin: 0 0 6px;
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
}

.module-body p {
  margin: 0;
  font-size: 0.82rem;
  line-height: 1.5;
  color: rgba(220, 232, 248, 0.78);
}

.module-arrow {
  flex-shrink: 0;
  align-self: center;
  font-size: 1.1rem;
  color: rgba(186, 231, 255, 0.5);
  transition: transform 0.25s ease, color 0.25s ease;
}

.module-card:hover .module-arrow,
.module-card:focus-visible .module-arrow {
  transform: translateX(4px);
  color: #bae7ff;
}

.site-footer {
  position: relative;
  z-index: 2;
  padding: 20px clamp(20px, 4vw, 48px) 28px;
  text-align: center;
}

.site-footer p {
  margin: 0;
  font-size: 0.82rem;
  color: rgba(200, 218, 240, 0.65);
}

@media (max-width: 960px) {
  .modules-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .site-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .brand-logo {
    max-width: 100%;
  }

  .config-btn {
    align-self: flex-end;
  }

  .modules-grid {
    grid-template-columns: 1fr;
  }

  .bg-layer {
    background-position: center 20%;
  }
}
</style>
