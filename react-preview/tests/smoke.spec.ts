import { test, expect } from "@playwright/test";

test("login and preview entry work without production credentials", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));

  await page.goto("/");
  await expect(page.getByRole("heading", { name: "تسجيل الدخول" })).toBeVisible();
  await expect(page.getByAltText("شعار سلسلة").first()).toBeVisible();

  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await expect(page.getByText("وضع المعاينة")).toBeVisible();
  await expect(page.getByRole("button", { name: "الملخص التنفيذي" })).toBeVisible();
  await expect(page.getByRole("button", { name: "عن البرنامج" })).toHaveCount(1);
  await expect.poll(() => page.locator("html").evaluate(el => getComputedStyle(el).getPropertyValue("--silsila-table-header-bg").trim().toLowerCase())).toBe("#3e007d");
  await expect.poll(() => page.locator("html").evaluate(el => getComputedStyle(el).getPropertyValue("--silsila-table-header-color").trim().toLowerCase())).toBe("#ffffff");

  expect(pageErrors).toEqual([]);
});

test("main menus are grouped into basic data, movements and reports", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();

  await page.getByRole("button", { name: "المبيعات" }).click();
  await expect(page.getByRole("button", { name: "بيانات أساسية" })).toBeVisible();
  await expect(page.getByRole("button", { name: "حركات" })).toBeVisible();
  await expect(page.getByRole("button", { name: "تقارير" })).toBeVisible();

  await page.locator(".nav-main-toggle").filter({ hasText: "عن البرنامج" }).click();
  await page.locator(".nav-subgroup-toggle").filter({ hasText: "معلومات البرنامج" }).click();
  await page.locator(".nav-item").filter({ hasText: "عن البرنامج" }).click();
  await expect(page.getByRole("heading", { name: "منظومة إدارة الأعمال المتكاملة" })).toBeVisible();

  await page.getByRole("button", { name: "الملخص التنفيذي" }).click();
  await expect(page.getByRole("heading", { name: "مؤشرات الأداء الرئيسية" })).toBeVisible();
});

test("sidebar collapse toggle stays available and exit dialog supports all choices", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();

  await page.setViewportSize({ width: 1280, height: 900 });
  await page.locator(".collapse").click();
  await expect(page.locator(".sidebar")).toHaveClass(/collapsed/);
  await expect(page.locator(".collapse")).toHaveAttribute("aria-label", "إظهار القوائم");
  await page.locator(".collapse").click();
  await expect(page.locator(".sidebar")).not.toHaveClass(/collapsed/);
  await expect(page.locator(".collapse")).toHaveAttribute("aria-label", "إخفاء القوائم");

  await page.getByRole("button", { name: "خروج من البرنامج" }).click();
  await expect(page.getByRole("dialog", { name: "تأكيد الخروج من البرنامج" })).toBeVisible();
  await page.getByRole("button", { name: "لا", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);

  await page.getByRole("button", { name: "خروج من البرنامج" }).click();
  await page.getByRole("button", { name: "إلغاء الأمر" }).click();
  await expect(page.getByText("وضع المعاينة")).toBeVisible();

  await page.getByRole("button", { name: "خروج من البرنامج" }).click();
  await page.getByRole("button", { name: "نعم، خروج" }).click();
  await expect(page.getByRole("heading", { name: "تسجيل الدخول" })).toBeVisible();
});

test("mobile preview does not create page-level horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await page.getByRole("button", { name: "فتح القوائم" }).click();
  await expect(page.locator(".sidebar")).toHaveClass(/mobile-open/);
  await expect(page.locator(".nav-main-toggle").first()).toBeVisible();
  await expect(page.locator(".nav-main-toggle").first()).toBeVisible();
  await expect(page.locator(".nav-item").first()).toBeVisible();
  await page.locator(".collapse").click();
  await expect(page.locator(".sidebar")).not.toHaveClass(/mobile-open/);

  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth
  }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport + 2);
});

test("all seven foundation screens open from general settings", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));

  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();

  for (const title of [
    "سياسات البرنامج",
    "بيانات الشركة",
    "فروع الشركة",
    "الأنشطة",
    "فئات الأنشطة",
    "مجموعات البراندات",
    "البراندات"
  ]) {
    await page.locator(".nav-item").getByText(title, { exact: true }).first().click();
    await expect(page.getByRole("heading", { name: title, exact: true })).toBeVisible();
    if (title === "سياسات البرنامج") {
      await expect(page.getByRole("navigation", { name: "تصنيفات سياسات البرنامج" })).toBeVisible();
      await expect(page.getByRole("button", { name: /تكويدية/ })).toBeVisible();
      await expect(page.getByRole("button", { name: /الهوية البصرية/ })).toBeVisible();
      for (const action of ["تحديث", "حفظ", "تعديل", "معاينة", "طباعة", "Excel", "PDF"]) {
        await expect(page.locator(".pp-quick-actions").getByRole("button", { name: new RegExp(action) })).toBeVisible();
      }
    }
  }

  expect(pageErrors).toEqual([]);
});


test("warehouse management opens the live Supabase workspace", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await page.locator(".nav-main-toggle").filter({ hasText: "المخازن" }).click();
  await page.locator(".nav-subgroup-toggle").filter({ hasText: "بيانات أساسية" }).click();
  await page.locator(".nav-item").filter({ hasText: "إدارة المخازن" }).click();
  await expect(page.getByRole("heading", { name: "إدارة المخازن", exact: true })).toBeVisible();
  await expect(page.getByText(/تعريف المخازن وربط كل مخزن بفرعه/)).toBeVisible();
  await expect(page.getByRole("button", { name: "تحديث", exact: true })).toBeVisible();
  expect(pageErrors).toEqual([]);
});



test("item catalog opens the live Supabase workspace", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await page.locator(".nav-main-toggle").filter({ hasText: "المخازن" }).click();
  await page.locator(".nav-subgroup-toggle").filter({ hasText: "بيانات أساسية" }).click();
  await page.locator(".nav-item").filter({ hasText: "المخازن والأصناف" }).click();
  await expect(page.getByRole("heading", { name: "المخازن والأصناف", exact: true })).toBeVisible();
  await expect(page.getByText(/دليل الأصناف · بيانات المنشأة المباشرة/)).toBeVisible();
  await expect(page.getByRole("button", { name: "تحديث", exact: true })).toBeVisible();
  await expect(page.getByText(/سجّل الدخول إلى المنشأة لعرض سجل الأصناف الفعلي/)).toBeVisible();
  await page.getByRole("button", { name: /إضافة صنف/ }).click();
  await expect(page.getByRole("heading", { name: "إضافة صنف جديد" })).toBeVisible();
  await expect(page.getByLabel("اسم الصنف *")).toBeVisible();
  await expect(page.getByLabel("الفئة الثانوية *")).toBeVisible();
  await expect(page.getByRole("button", { name: /حفظ الصنف وتوليد الكود/ })).toBeVisible();
  expect(pageErrors).toEqual([]);
});


test("chart of accounts is connected to the live Supabase ledger", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await page.locator(".nav-main-toggle").filter({ hasText: "الإدارة المالية" }).click();
  await page.locator(".nav-subgroup-toggle").filter({ hasText: "بيانات أساسية" }).click();
  await page.locator(".nav-item").filter({ hasText: "دليل الحسابات" }).click();
  await expect(page.getByRole("heading", { name: "دليل الحسابات", exact: true })).toBeVisible();
  await expect(page.getByText(/erp_accounts وerp_account_tree_metrics/)).toBeVisible();
  await expect(page.getByRole("button", { name: "تحديث", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: /إضافة حساب/ })).toBeDisabled();
  await expect(page.getByText(/سجّل الدخول إلى المنشأة لعرض دليل الحسابات الحقيقي/)).toBeVisible();
  expect(pageErrors).toEqual([]);
});


test("journal workspace separates draft saving from posting", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await page.locator(".nav-main-toggle").filter({ hasText: "الإدارة المالية" }).click();
  await page.locator(".nav-subgroup-toggle").filter({ hasText: "حركات" }).click();
  await page.locator(".nav-item").filter({ hasText: "قيود اليومية" }).click();
  await expect(page.getByRole("heading", { name: "قيود اليومية", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "قيد جديد", exact: true })).toBeDisabled();
  await expect(page.locator(".operation-feedback.warning")).toContainText("سجّل الدخول إلى المنشأة لعرض دفتر القيود الفعلي");
  expect(pageErrors).toEqual([]);
});
