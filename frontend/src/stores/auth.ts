import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { UserInfo } from "@/types";

export const useAuthStore = defineStore("auth", () => {
  const token = ref(localStorage.getItem("token") || "");
  const user = ref<UserInfo | null>(
    (() => {
      try {
        const raw = localStorage.getItem("user");
        return raw ? JSON.parse(raw) : null;
      } catch {
        return null;
      }
    })()
  );

  const isLoggedIn = computed(() => !!token.value);
  const isAdmin = computed(() => user.value?.role === "admin");

  function setAuth(t: string, u: UserInfo) {
    token.value = t;
    user.value = u;
    localStorage.setItem("token", t);
    localStorage.setItem("user", JSON.stringify(u));
  }

  function updateUser(next: UserInfo) {
    user.value = next;
    localStorage.setItem("user", JSON.stringify(next));
  }

  function logout() {
    token.value = "";
    user.value = null;
    localStorage.removeItem("token");
    localStorage.removeItem("user");
  }

  return { token, user, isLoggedIn, isAdmin, setAuth, updateUser, logout };
});
