// src/router/index.js

import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import('../components/HomeIndex.vue') // 假设你的主页在这里
  },
  {
    // 星座仿真系统
    path: '/simulation/Satelliteviewer',
    name: 'Satelliteviewer',
    component: () => import('../components/SatelliteViewer.vue') 
  },
  {
    // 卫星网络拓扑
    path: '/simulation/topology',
    name: 'Topology',
    component: () => import('../view/SatTopology.vue') 
  },
  {
    // 卫星网络拓扑
    path: '/simulation/topology2D',
    name: 'Topology2D',
    component: () => import('../components/SatTopology2D.vue') 
  },
  {
    // 卫星网络拓扑
    path: '/simulation/topology3D',
    name: 'Topology3D',
    component: () => import('../components/SatTopology3D.vue') 
  },
  {
    // 性能监控中台（Prometheus 风格假数据面板）
    path: '/monitor',
    name: 'MonitorDashboard',
    component: () => import('../view/MonitorDashboard.vue')
  },
  {
    path: '/remote-sensing',
    name: 'RemoteSensing',
    component: () => import('../view/RemoteSensing.vue')
  },
  // 404 路由：匹配所有未定义的路径，重定向回主页
  {
    path: '/:pathMatch(.*)*',
    redirect: '/'
  }
]

// 2. 创建路由实例
const router = createRouter({
  // 使用 HTML5 模式 (也就是 URL 里没有 # 号)
  history: createWebHistory(),
  routes
})

export default router
