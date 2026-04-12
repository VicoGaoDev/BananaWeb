import axios from "axios";
import router from "@/router";

const BASE = import.meta.env.VITE_API_BASE_URL || "";

const client = axios.create({
  baseURL: `${BASE}/api`,
  timeout: 30000,
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

client.interceptors.response.use(
  (res) => res.data,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      router.push("/templates");
    }
    return Promise.reject(error);
  }
);

export default client;
