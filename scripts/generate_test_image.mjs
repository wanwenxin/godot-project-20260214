#!/usr/bin/env node
/**
 * 使用阿里云 DashScope 文生图 API 生成一张测试图并保存到 assets/generated_images。
 * 用法：在项目根目录执行
 *   set DASHSCOPE_API_KEY=你的key && node scripts/generate_test_image.mjs
 * 或在 .env 同目录下配置 key 后执行 node scripts/generate_test_image.mjs
 */
import fs from "fs";
import path from "path";
import https from "https";

const API_BASE = "https://dashscope.aliyuncs.com/api/v1";
const KEY = process.env.DASHSCOPE_API_KEY;
const SAVE_DIR = path.join(
  process.cwd(),
  "assets",
  "generated_images"
);
const PROMPT = "A cute cat sitting on a windowsill, soft sunlight, digital art";
const MODEL = "flux-merged";

if (!KEY) {
  console.error("请设置环境变量 DASHSCOPE_API_KEY");
  process.exit(1);
}

function request(method, pathname, body = null) {
  const url = new URL(API_BASE + pathname);
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: url.hostname,
      path: url.pathname,
      method,
      headers: {
        Authorization: `Bearer ${KEY}`,
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
      },
    };
    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(data);
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  console.log("提交文生图任务...");
  const createRes = await request(
    "POST",
    "/services/aigc/text2image/image-synthesis",
    {
      model: MODEL,
      input: { prompt: PROMPT },
      parameters: {
        size: "1024*1024",
        seed: Math.floor(Math.random() * 10000),
        steps: 4,
      },
    }
  );

  const taskId = createRes.output?.task_id || createRes.task_id;
  if (!taskId) {
    console.error("未返回 task_id，响应:", JSON.stringify(createRes, null, 2));
    process.exit(1);
  }
  if (createRes.code) {
    console.error("API 错误:", createRes.message || createRes.code, createRes);
    process.exit(1);
  }

  console.log("任务 ID:", taskId, "轮询结果中...");
  let statusRes;
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    statusRes = await request("GET", `/tasks/${taskId}`);
    const status = statusRes.output?.task_status ?? statusRes.task_status;
    if (status === "SUCCEEDED") break;
    if (status === "FAILED") {
      console.error("任务失败:", JSON.stringify(statusRes, null, 2));
      process.exit(1);
    }
    console.log("  状态:", status || "-", "继续等待...");
  }

  const results = statusRes?.output?.results;
  if (!results?.length) {
    console.error("无图片结果:", JSON.stringify(statusRes, null, 2));
    process.exit(1);
  }

  const imageUrl = results[0].url;
  if (!imageUrl) {
    console.error("无图片 URL");
    process.exit(1);
  }

  if (!fs.existsSync(SAVE_DIR)) fs.mkdirSync(SAVE_DIR, { recursive: true });
  const outPath = path.join(SAVE_DIR, "test_image.png");

  console.log("下载图片到", outPath, "...");
  const buf = await new Promise((resolve, reject) => {
    https.get(imageUrl, (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    }).on("error", reject);
  });
  fs.writeFileSync(outPath, buf);
  console.log("已保存:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
