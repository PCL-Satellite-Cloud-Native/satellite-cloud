<template>
    <div class="center">
        <div ref="host" class="viewport"></div>
    </div>

</template>

<script setup lang ="ts">
// 脚本开头先进行引用
import { onMounted,onBeforeMount,ref,watch } from 'vue';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';

// 之后开始定义数据结构
type Sat ={
    id: string;
    obrit: number;
    slot: number;
    r: [number, number, number]; // 位置坐标
    mesh: THREE.Mesh; // THREE.js 渲染对象
} 

</script>