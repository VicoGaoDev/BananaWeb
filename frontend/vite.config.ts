import { defineConfig, type PluginOption } from "vite";
import vue from "@vitejs/plugin-vue";
import { visualizer } from "rollup-plugin-visualizer";
import { resolve } from "path";

const shouldAnalyzeBundle = process.env.ANALYZE === "true";
const plugins: PluginOption[] = [
  vue(),
];

if (shouldAnalyzeBundle) {
  plugins.push(visualizer({
    filename: "stats.html",
    gzipSize: true,
    brotliSize: true,
    template: "treemap",
  }) as PluginOption);
}

export default defineConfig({
  base: "/",
  plugins,
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vue: ["vue", "vue-router", "pinia"],
          antd: ["ant-design-vue"],
          icons: ["@ant-design/icons-vue"],
          charts: ["echarts", "vue-echarts"],
          editor: ["@wangeditor/editor", "@wangeditor/editor-for-vue"],
          cloudbase: ["@cloudbase/js-sdk"],
          markdown: ["markdown-it"],
          uploads: ["cos-js-sdk-v5"],
        },
      },
    },
  },
  server: {
    port: 3000,
    proxy: {
      "^/api(/|$)": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
        timeout: 630_000,
        proxyTimeout: 630_000,
        configure(proxy) {
          proxy.on("proxyRes", (proxyRes, _req, res) => {
            const contentType = String(proxyRes.headers["content-type"] || "");
            if (!contentType.includes("text/event-stream")) return;
            proxyRes.headers["cache-control"] = "no-cache";
            proxyRes.headers["connection"] = "keep-alive";
            proxyRes.headers["x-accel-buffering"] = "no";
            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("Connection", "keep-alive");
            res.setHeader("X-Accel-Buffering", "no");
            proxyRes.on("data", () => {
              if (typeof (res as { flush?: () => void }).flush === "function") {
                (res as { flush: () => void }).flush();
              }
            });
          });
        },
      },
      "/uploads": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
});
