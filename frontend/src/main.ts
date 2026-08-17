import { createApp, nextTick, type Plugin } from "vue";
import { createPinia } from "pinia";
import {
  Avatar,
  Badge,
  Button,
  Checkbox,
  Drawer,
  Dropdown,
  Form,
  FormItem,
  Input,
  InputPassword,
  Layout,
  LayoutContent,
  LayoutHeader,
  Menu,
  MenuDivider,
  MenuItem,
  Modal,
  SubMenu,
  TabPane,
  Tabs,
  Textarea,
  Tooltip,
  message,
} from "ant-design-vue";
import "ant-design-vue/dist/reset.css";
import App from "./App.vue";
import { initializeAppTheme } from "./lib/theme";
import router from "./router";
import "./styles/global.scss";

initializeAppTheme();

message.config({
  duration: 2.4,
  maxCount: 3,
});

const app = createApp(App);

let extendedAntdRegistration: Promise<void> | null = null;

function registerAntdComponents(components: unknown[]) {
  components.forEach((component) => {
    app.use(component as Plugin);
  });
}

async function registerExtendedAntdComponents() {
  if (extendedAntdRegistration) return extendedAntdRegistration;

  extendedAntdRegistration = import("ant-design-vue").then((antd) => {
    const {
      Alert,
      Card,
      Col,
      Collapse,
      CollapsePanel,
      DatePicker,
      Divider,
      Empty,
      Image,
      InputNumber,
      InputSearch,
      Pagination,
      Popover,
      Radio,
      RadioButton,
      RadioGroup,
      RangePicker,
      Row,
      Segmented,
      Select,
      SelectOption,
      Skeleton,
      Slider,
      Space,
      Spin,
      Switch,
      Table,
      TableColumn,
      TableSummaryCell,
      TableSummaryRow,
      Tag,
      Timeline,
      TimelineItem,
    } = antd;

    registerAntdComponents([
      Alert,
      Card,
      Col,
      Collapse,
      CollapsePanel,
      DatePicker,
      Divider,
      Empty,
      Image,
      InputNumber,
      InputSearch,
      Pagination,
      Popover,
      Radio,
      RadioButton,
      RadioGroup,
      RangePicker,
      Row,
      Segmented,
      Select,
      SelectOption,
      Skeleton,
      Slider,
      Space,
      Spin,
      Switch,
      Table,
      TableColumn,
      TableSummaryCell,
      TableSummaryRow,
      Tag,
      Timeline,
      TimelineItem,
    ]);
  }).catch((error) => {
    extendedAntdRegistration = null;
    throw error;
  });

  return extendedAntdRegistration;
}

registerAntdComponents([
  Avatar,
  Badge,
  Button,
  Checkbox,
  Drawer,
  Dropdown,
  Form,
  FormItem,
  Input,
  InputPassword,
  Layout,
  LayoutContent,
  LayoutHeader,
  Menu,
  MenuDivider,
  MenuItem,
  Modal,
  SubMenu,
  TabPane,
  Tabs,
  Textarea,
  Tooltip,
]);

router.beforeEach(async (to) => {
  if (to.name === "Home" || to.path === "/") return;
  await registerExtendedAntdComponents();
});

const APP_BOOT_FALLBACK_MS = 8000;
const APP_BOOT_FADE_MS = 400;

let appMounted = false;
let appBootHidden = false;

function mountApp() {
  if (appMounted) return;
  appMounted = true;
  app.mount("#app");
}

function waitForFirstPaint() {
  return new Promise<void>((resolve) => {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => resolve());
    });
  });
}

function hideAppBootScreen() {
  if (appBootHidden) return;
  appBootHidden = true;

  const boot = document.getElementById("app-boot");
  if (!boot) return;

  const remove = () => boot.remove();
  boot.classList.add("is-leaving");
  boot.addEventListener("transitionend", remove, { once: true });
  window.setTimeout(remove, APP_BOOT_FADE_MS);
}

async function revealApp() {
  try {
    await router.isReady();
    mountApp();
    await nextTick();
    await waitForFirstPaint();
  } catch {
    mountApp();
  } finally {
    hideAppBootScreen();
  }
}

app.use(createPinia());
app.use(router);
window.setTimeout(() => {
  mountApp();
  hideAppBootScreen();
}, APP_BOOT_FALLBACK_MS);
void revealApp();
