import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/auth";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      component: () => import("@/components/layout/AppLayout.vue"),
      redirect: "/templates",
      children: [
        {
          path: "templates",
          name: "Templates",
          component: () => import("@/views/TemplatesView.vue"),
        },
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
          path: "credit-logs",
          name: "CreditLogs",
          component: () => import("@/views/CreditLogsView.vue"),
        },
        {
          path: "admin/templates",
          name: "TemplateManage",
          meta: { requiresAdmin: true },
          component: () => import("@/views/admin/TemplateManageView.vue"),
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
        {
          path: "admin/external-api-configs",
          name: "ExternalApiConfigManage",
          meta: { requiresSuperAdmin: true },
          component: () => import("@/views/admin/ExternalApiConfigView.vue"),
        },
      ],
    },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  if (to.meta.requiresSuperAdmin && !auth.isSuperAdmin) {
    return { name: "Templates" };
  }
  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return { name: "Templates" };
  }
});

export default router;
