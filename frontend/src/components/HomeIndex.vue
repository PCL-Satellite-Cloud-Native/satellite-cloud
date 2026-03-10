<template>
  <div class="home-container">
    <header class="header-section">
      <h1 class="main-title">鹏城国家实验室卫星云原生软件仿真平台</h1>
      <div class="title-underline"></div>
    </header>

    <section class="intro-section">
      
      <div class="action-toolbar">
        <button class="config-btn" @click="handleNavigate('/system/config')">
          <span class="icon">⚙️</span>
          系统配置管理中心
        </button>
      </div>

      <div class="intro-card">
        <div class="intro-header">
          <span class="icon">ℹ️</span>
          <h2>平台介绍</h2>
        </div>
        <div class="intro-content">
          <p>
            在软件仿真平台中，提供星座仿真系统、卫星网络拓扑、性能监控中台、业务通信和遥感两类仿真场景。
            用户可以根据仿真场景配置参数，如：
            <span class="highlight">星座规模</span>、
            <span class="highlight">星网架构</span>、
            <span class="highlight">用户规模</span>、
            <span class="highlight">星网带宽</span>、
            <span class="highlight">星网容量</span> 等。
          </p>
        </div>
      </div>
    </section>

    <section class="nav-section">
       <div class="nav-grid">
         <div v-for="(item, index) in navItems" :key="index" class="nav-card" @click="handleNavigate(item)">
            <div class="card-image-wrapper">
               <img :src="item.imgUrl" :alt="item.title" class="card-img" />
            </div>
            <div class="card-footer">
               <h3>{{ item.title }}</h3>
               <span class="arrow">→</span>
            </div>
         </div>
       </div>
    </section>

    <footer class="footer">
      <p>© 2024 鹏城国家实验室 - Satellite SimPlat</p>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue';
// 1. 引入 useRouter 钩子
import { useRouter } from 'vue-router';
// 2. 获取 router 实例
const router = useRouter();
const navItems = ref([
  {
    title: '星座仿真系统',
    // 这是一个地球的示意图
    imgUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=400&auto=format&fit=crop', 
    route: '/simulation/Satelliteviewer' 
  },
  { 
    title: '卫星网络拓扑',
    // 这是一个网络拓扑示意图（节点 + 连线）
    imgUrl: 'https://images.pexels.com/photos/373543/pexels-photo-373543.jpeg?auto=compress&cs=tinysrgb&w=400', 
    route: '/simulation/topology'
  },
  { 
    title: '性能监控中台',
    imgUrl: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?q=80&w=400&auto=format&fit=crop', 
    route: '/monitor',
    // K8s 构建时设置 VITE_GRAFANA_URL 则点击跳转 Grafana；本地不设置则走 /monitor 页面
    externalLink: import.meta.env.VITE_GRAFANA_URL || undefined
  },
  { 
    title: '通信应用',
    // 这是一个通信图标风格
    imgUrl: 'https://cdn-icons-png.flaticon.com/512/3059/3059561.png', 
    route: '/app/communication'
  },
  { 
    title: '遥感应用',
    // 这是一个卫星图标风格
    imgUrl: 'https://cdn-icons-png.flaticon.com/512/4230/4230726.png', 
    route: '/app/remote-sensing'
  },
  { 
    title: '批量服务引擎',
    // 这是一个服务器图标风格
    imgUrl: 'https://cdn-icons-png.flaticon.com/512/2165/2165061.png', 
    route: '/engine/batch'
  }
]);

// 点击跳转逻辑：支持站内路由或外链（如 K8s 下性能监控中台直跳 Grafana）
const handleNavigate = (item) => {
  if (!item) return;
  if (item.externalLink) {
    window.open(item.externalLink, '_blank', 'noopener,noreferrer');
    return;
  }
  if (item.route) {
    router.push(item.route);
  } else {
    console.warn("未配置该模块的路由路径");
  }
};
</script>

<style scoped>
/* 全局容器样式：设置柔和的背景色 */
.home-container {
  min-height: 100vh;
  background-color: #f0f2f5; /* 浅灰蓝背景 */
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Microsoft YaHei', Arial, sans-serif;
  padding: 40px 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  
}

.header-section {
  text-align: center;
  margin-bottom: 30px; /*稍微减小一点和大标题的间距*/
}
/* 新增：右上角按钮容器 */
.header-right-actions {
  position: absolute;
  right: 0;           /* 靠右对齐 */
  top: 50%;           /* 垂直居中 */
  transform: translateY(-50%); /* 修正垂直居中偏移 */
}

/* 新增：配置按钮样式 */
.config-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  background-color: #fff;
  border: 1px solid #d9d9d9;
  color: #555;
  padding: 8px 20px;       /* 稍微加宽一点 */
  border-radius: 6px;      /* 圆角 */
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  box-shadow: 0 2px 4px rgba(0,0,0,0.02); /* 很淡的阴影 */
  transition: all 0.3s ease;
}

.config-btn:hover {
  color: #1890ff;
  border-color: #1890ff;
  background-color: #e6f7ff;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.15);
  transform: translateY(-1px); /* 悬浮微动效果 */
}


.main-title {
  color: #2c3e50;
  font-size: 2.2rem;
  font-weight: 700;
  margin-bottom: 10px;
  letter-spacing: 1px;
}

.title-underline {
  width: 80px;
  height: 4px;
  background: linear-gradient(90deg, #1890ff, #36cfc9);
  margin: 0 auto;
  border-radius: 2px;
}

.intro-section {
  width: 100%;
  max-width: 1000px;
  margin-bottom: 50px;
  /* 确保这个容器是 flex 列布局，方便排列工具栏和卡片 */
  display: flex;
  flex-direction: column; 
}
.action-toolbar {
  display: flex;
  justify-content: flex-end; /* flex-end 让按钮靠右，center 让按钮居中 */
  margin-bottom: 15px;       /* 让按钮和下面的卡片保持距离 */
  width: 100%;
}

.intro-card {
  background: #ffffff;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
  border-left: 5px solid #1890ff; /* 左侧强调色 */
  padding: 25px 30px;
  transition: transform 0.3s ease;
}

.intro-header {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
  border-bottom: 1px solid #eee;
  padding-bottom: 10px;
}

.intro-header h2 {
  font-size: 1.2rem;
  color: #333;
  margin: 0;
  margin-left: 10px;
  font-weight: 600;
}

.intro-content p {
  color: #555;
  line-height: 1.8;
  font-size: 1rem;
  text-align: justify;
}

.highlight {
  color: #1890ff;
  font-weight: 600;
  background-color: #e6f7ff;
  padding: 2px 6px;
  border-radius: 4px;
  margin: 0 2px;
}

/* 3. 导航网格样式 */
.nav-section {
  width: 100%;
  max-width: 1000px;
  flex-grow: 1;
}

.nav-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr); /* 3列 */
  gap: 30px; /* 卡片间距 */
}

/* 响应式：手机端变为1列 */
@media (max-width: 768px) {
  .nav-grid {
    grid-template-columns: 1fr;
  }
}

/* 导航卡片交互样式 */
.nav-card {
  background: white;
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
  transition: all 0.3s ease;
  display: flex;
  flex-direction: column;
}

.nav-card:hover {
  transform: translateY(-8px); /* 悬浮上移 */
  box-shadow: 0 12px 24px rgba(24, 144, 255, 0.15); /* 蓝色光晕阴影 */
}

/* 图片容器 */
.card-image-wrapper {
  height: 160px; /* 固定图片高度 */
  width: 100%;
  background-color: #fafafa;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
  box-sizing: border-box;
}

/* 图片自适应 */
.card-img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain; /* 保持图片比例 */
  transition: transform 0.3s;
}

.nav-card:hover .card-img {
  transform: scale(1.05); /* 图片微放大 */
}

/* 卡片底部标题 */
.card-footer {
  height: 60px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  background-color: #fff;
  border-top: 1px solid #f0f0f0;
}

.card-footer h3 {
  font-size: 1rem;
  color: #333;
  margin: 0;
  font-weight: 600;
}

.arrow {
  color: #1890ff;
  opacity: 0;
  transform: translateX(-10px);
  transition: all 0.3s ease;
}

.nav-card:hover .arrow {
  opacity: 1;
  transform: translateX(0);
}

/* 页脚 */
.footer {
  margin-top: 50px;
  color: #999;
  font-size: 0.9rem;
}
</style>