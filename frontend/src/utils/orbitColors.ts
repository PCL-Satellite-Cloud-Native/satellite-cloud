/**
 * 轨道配色（1 起始）。绿色系留给「任务运行中」高亮，轨道色与之区分。
 * 超过预设数量时用黄金角 HSL 生成，并跳过绿色色相区间。
 */
const ORBIT_PALETTE = [
  '#38bdf8', // 1 天蓝
  '#a78bfa', // 2 紫
  '#fb923c', // 3 橙
  '#f472b6', // 4 粉
  '#2dd4bf', // 5 青
  '#eab308', // 6 琥珀
  '#818cf8', // 7 靛
  '#f87171', // 8 珊瑚
] as const

/** 路由子网中心节点 */
export const ROUTER_CENTER_COLOR = '#fbbf24'

/** 3D 任务运行中高亮（仅卫星节点，不用于轨道连线） */
export const TASK_ACTIVE_COLOR_HEX = '#34d399'
export const TASK_ACTIVE_EMISSIVE_HEX = '#047857'

function skipGreenHue(hue: number): number {
  if (hue >= 95 && hue <= 155) return (hue + 65) % 360
  return hue
}

/** 返回 CSS 颜色（#hex 或 hsl） */
export function orbitColorHex(orbit: number): string {
  if (!orbit || orbit < 1) return '#94a3b8'
  if (orbit <= ORBIT_PALETTE.length) return ORBIT_PALETTE[orbit - 1]
  const hue = skipGreenHue((orbit * 137.508) % 360)
  return `hsl(${Math.round(hue)}, 68%, 58%)`
}

/** Three.js 0xRRGGBB */
export function orbitColorThree(orbit: number): number {
  const hex = orbitColorHex(orbit)
  if (hex.startsWith('hsl')) {
    const m = hex.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/)
    if (m) {
      const h = Number(m[1]) / 360
      const s = Number(m[2]) / 100
      const l = Number(m[3]) / 100
      return hslToRgbHex(h, s, l)
    }
  }
  return parseInt(hex.slice(1), 16)
}

function hslToRgbHex(h: number, s: number, l: number): number {
  let r = l
  let g = l
  let b = l
  if (s !== 0) {
    const hue2rgb = (p: number, q: number, t: number) => {
      let tt = t
      if (tt < 0) tt += 1
      if (tt > 1) tt -= 1
      if (tt < 1 / 6) return p + (q - p) * 6 * tt
      if (tt < 1 / 2) return q
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6
      return p
    }
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s
    const p = 2 * l - q
    r = hue2rgb(p, q, h + 1 / 3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1 / 3)
  }
  const ri = Math.round(r * 255)
  const gi = Math.round(g * 255)
  const bi = Math.round(b * 255)
  return (ri << 16) | (gi << 8) | bi
}

export function orbitLegendItems(maxOrbit = 3): Array<{ orbit: number; color: string }> {
  const items: Array<{ orbit: number; color: string }> = []
  for (let o = 1; o <= maxOrbit; o++) {
    items.push({ orbit: o, color: orbitColorHex(o) })
  }
  return items
}
