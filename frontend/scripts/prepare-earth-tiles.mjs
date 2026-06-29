/**
 * 生成本地离线地球瓦片包 public/tiles/earth-hd/ 与全景图 public/assets/earth_hd.jpg
 *
 * 用法: npm run prepare:tiles
 *
 * 优先级：
 * 1. public/assets/earth_hd_source.jpg（≥250KB 或 --use-local，推荐 Blue Marble 等距圆柱图）
 * 2. 联网下载 NASA Blue Marble
 * 3. 从 node_modules/cesium 的 Natural Earth II 拼接（真实地理，离线可用）
 *
 * 内网 XYZ 瓦片（构建时）: VITE_MAP_TILES_URL=http://内网/{z}/{x}/{y}.png
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const outDir = path.join(root, 'public', 'tiles', 'earth-hd')
const assetsDir = path.join(root, 'public', 'assets')
const metaPath = path.join(assetsDir, 'earth_imagery_meta.json')

const SOURCE_URLS = [
  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/The_Blue_Marble_%28remastered%29.jpg/2048px-The_Blue_Marble_%28remastered%29.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/c/cb/The_Blue_Marble_%28remastered%29.jpg',
]

const TILE = 256
const MIN_REAL_BYTES = 250_000
const useLocalFlag = process.argv.includes('--use-local')

function cesiumNe2Dir() {
  return path.join(
    root,
    'node_modules',
    'cesium',
    'Build',
    'Cesium',
    'Assets',
    'Textures',
    'NaturalEarthII'
  )
}

function writeMeta(source, width, height, maxZoom) {
  fs.mkdirSync(assetsDir, { recursive: true })
  fs.writeFileSync(
    metaPath,
    JSON.stringify(
      {
        source,
        width,
        height,
        maxZoom,
        generatedAt: new Date().toISOString(),
      },
      null,
      2
    )
  )
}

async function isRealLocalSource(local) {
  if (!fs.existsSync(local)) return false
  const stat = fs.statSync(local)
  if (useLocalFlag && stat.size > 30_000) return true
  if (stat.size < MIN_REAL_BYTES) return false
  const meta = await sharp(local).metadata()
  return (meta.width || 0) >= 2048 && (meta.height || 0) >= 1024
}

async function downloadSourceImage(local) {
  for (const url of SOURCE_URLS) {
    try {
      console.log(`Downloading: ${url}`)
      const resp = await fetch(url, { signal: AbortSignal.timeout(60000) })
      if (!resp.ok) continue
      const buf = Buffer.from(await resp.arrayBuffer())
      if (buf.length < MIN_REAL_BYTES) continue
      fs.writeFileSync(local, buf)
      console.log(`Saved ${local} (${(buf.length / 1024 / 1024).toFixed(2)} MB)`)
      return 'blue-marble'
    } catch (err) {
      console.warn(`Download failed (${url}):`, err.message || err)
    }
  }
  return null
}

async function stitchNaturalEarthSource(local) {
  const ne2 = cesiumNe2Dir()
  const xml = path.join(ne2, 'tilemapresource.xml')
  if (!fs.existsSync(xml)) {
    throw new Error('Cesium Natural Earth II not found; run npm install first')
  }

  const z = 2
  const cols = Math.pow(2, z + 1)
  const rows = Math.pow(2, z)
  const layerW = cols * TILE
  const layerH = rows * TILE

  const composites = []
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      const tilePath = path.join(ne2, String(z), String(x), `${y}.jpg`)
      if (!fs.existsSync(tilePath)) {
        throw new Error(`Missing NE2 tile: ${tilePath}`)
      }
      composites.push({
        input: tilePath,
        left: x * TILE,
        top: y * TILE,
      })
    }
  }

  await sharp({
    create: {
      width: layerW,
      height: layerH,
      channels: 3,
      background: { r: 10, g: 30, b: 60 },
    },
  })
    .composite(composites)
    .jpeg({ quality: 92 })
    .toFile(local)

  console.log(`Stitched Natural Earth II → ${local} (${layerW}x${layerH})`)
  return 'natural-earth'
}

async function ensureSourceImage() {
  fs.mkdirSync(assetsDir, { recursive: true })
  const local = path.join(assetsDir, 'earth_hd_source.jpg')

  if (await isRealLocalSource(local)) {
    const meta = await sharp(local).metadata()
    console.log(`Using local source (${meta.width}x${meta.height})`)
    return { path: local, source: 'local' }
  }

  if (fs.existsSync(local)) {
    console.log('Local source is placeholder/synthetic; replacing…')
  }

  const downloaded = await downloadSourceImage(local)
  if (downloaded) {
    return { path: local, source: downloaded }
  }

  const neSource = await stitchNaturalEarthSource(local)
  return { path: local, source: neSource }
}

function maxZoomForSource(width) {
  if (width >= 8192) return 4
  if (width >= 4096) return 3
  return 2
}

function writeTilemapResource(maxZoom) {
  const levels = []
  for (let z = 0; z <= maxZoom; z++) {
    const upp = 0.703125 / Math.pow(2, z)
    levels.push(`        <TileSet href="${z}" units-per-pixel="${upp.toFixed(14)}" order="${z}"/>`)
  }
  const xml = `<?xml version="1.0" encoding="utf-8"?>
<TileMap version="1.0.0" tilemapservice="http://tms.osgeo.org/1.0.0">
  <Title>Earth HD Offline</Title>
  <SRS>EPSG:4326</SRS>
  <BoundingBox miny="-90" minx="-180" maxy="90" maxx="180"/>
  <Origin y="-90" x="-180"/>
  <TileFormat width="256" height="256" mime-type="image/jpeg" extension="jpg"/>
  <TileSets profile="geodetic">
${levels.join('\n')}
  </TileSets>
</TileMap>
`
  fs.writeFileSync(path.join(outDir, 'tilemapresource.xml'), xml)
}

async function buildTiles(sourcePath, sourceKind) {
  fs.rmSync(outDir, { recursive: true, force: true })
  fs.mkdirSync(outDir, { recursive: true })

  const meta = await sharp(sourcePath).metadata()
  const srcW = meta.width || 2048
  const srcH = meta.height || 1024
  const maxZoom = maxZoomForSource(srcW)
  writeTilemapResource(maxZoom)

  for (let z = 0; z <= maxZoom; z++) {
    const cols = Math.pow(2, z + 1)
    const rows = Math.pow(2, z)
    const layerW = cols * TILE
    const layerH = rows * TILE
    const layer = await sharp(sourcePath)
      .resize(layerW, layerH, { fit: 'fill' })
      .jpeg({ quality: 90 })
      .toBuffer()

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const tileDir = path.join(outDir, String(z), String(x))
        fs.mkdirSync(tileDir, { recursive: true })
        await sharp(layer)
          .extract({ left: x * TILE, top: y * TILE, width: TILE, height: TILE })
          .jpeg({ quality: 90 })
          .toFile(path.join(tileDir, `${y}.jpg`))
      }
    }
    console.log(`Zoom ${z}: ${cols * rows} tiles`)
  }

  await sharp(sourcePath).jpeg({ quality: 92 }).toFile(path.join(assetsDir, 'earth_hd.jpg'))
  console.log('Wrote public/assets/earth_hd.jpg')
  writeMeta(sourceKind, srcW, srcH, maxZoom)
}

async function main() {
  try {
    const { path: source, source: sourceKind } = await ensureSourceImage()
    await buildTiles(source, sourceKind)
    console.log(`Done. Tiles: ${outDir}`)
  } catch (err) {
    console.error(err)
    process.exit(1)
  }
}

main()
