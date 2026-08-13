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
