import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
// 引入router路由
import router from './router'
const app = createApp(App)

// 2. 挂载 router
app.use(router)

app.mount('#app')
