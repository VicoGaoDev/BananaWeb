import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { resolve } from "path";

export default defineConfig({
  base: "/",
  plugins: [vue()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  server: {
    port: 3000,
    proxy: {
      "^/api(/|$)": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
        // 对话等同步上游调用可能超过默认代理超时
        timeout: 630_000,
        proxyTimeout: 630_000,
      },
      "/uploads": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
});
