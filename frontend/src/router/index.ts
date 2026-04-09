import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/auth";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      component: () => import("@/components/layout/AppLayout.vue"),
      redirect: "/generate",
      children: [
        {
          path: "generate",
          name: "Generate",
          component: () => import("@/views/GenerateView.vue"),
        },
        {
          path: "history",
          name: "History",
          component: () => import("@/views/HistoryView.vue"),
        },
        {
          path: "admin/users",
          name: "UserManage",
          meta: { requiresAdmin: true },
          component: () => import("@/views/admin/UserManageView.vue"),
        },
        {
          path: "admin/dashboard",
          name: "Dashboard",
          meta: { requiresAdmin: true },
          component: () => import("@/views/admin/DashboardView.vue"),
        },
        {
          path: "admin/api-key",
          name: "ApiKeyManage",
          meta: { requiresAdmin: true },
          component: () => import("@/views/admin/ApiKeyView.vue"),
        },
      ],
    },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return { name: "Generate" };
  }
});

export default router;
